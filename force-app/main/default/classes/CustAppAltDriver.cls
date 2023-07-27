global without sharing class CustAppAltDriver {
	public final static string ADD_ALT_DVR_EVT = 'UPSERT_VEHICLE_ALTERNATE_DRIVER';
	public final static String REM_ALT_DVR_EVT = 'REMOVE_VEHICLE_ALTERNATE_DRIVER';
	public static List<String> ALT_DRIVER_FIELDS;

	static {
		ALT_DRIVER_FIELDS = new List<String> { 'Account__c', 'Vehicle_Ownership__c', 'Relationship_to_Owner__c', 'Type__c', 'Status__c' };
		ALT_DRIVER_FIELDS.addAll(CustAppAPI.prefixFields(CustAppVehicle.VO_FIELDS, 'Vehicle_Ownership__r.'));
	}

	public static void sendWebhook(Customer_App_Callback__e callback) {
		String altDId = callback.Id__c;
		Set<String> custAppType = CustAppAccount.REV_TYPE.keySet();
		String query = 	'SELECT ' + String.join(ALT_DRIVER_FIELDS, ',') + ' FROM Alternative_Driver__c WHERE Id = :altDId AND Type__c IN :custAppType';
		List<Alternative_Driver__c> driverList = Database.query(query);
		if (driverList.size() <= 0) { return; }
		List<Customer_External_Account__c> accounts = CustAppAccount.getExtAccounts(driverList[0].Account__c, new Set<String> { driverList[0].Type__c });
		if (accounts.size() <= 0) { return; }
		for (Customer_External_Account__c custAcc : accounts) {
			for (Alternative_Driver__c driver : driverList) {
				String hookBody;
				if (callback.Event__c == REM_ALT_DVR_EVT) {
					RemoveDriverPayload payload = new RemoveDriverPayload(driver, custAcc.UUID__c);
					RemoveDriverHook hook = new RemoveDriverHook(REM_ALT_DVR_EVT, payload);
					hookBody = JSON.serialize(hook);
				}
				else if (callback.Event__c == ADD_ALT_DVR_EVT) {
					// System.debug(callback.Event__c);
					AddDriverPayload payload = new AddDriverPayload(driver, custAcc.UUID__c);
					AddDriverHook hook = new AddDriverHook(ADD_ALT_DVR_EVT, payload);
					hookBody = JSON.serialize(hook);
				}
				// System.debug('hookbody: ' + hookBody);
				CustAppAPI.sendWebhook(hookBody);
			}
		}
	}

	public static void processAddCallback() {
		RestRequest req = RestContext.request;
		AddDriverHook reqBody = (AddDriverHook) JSON.deserialize(req.requestBody.toString(), AddDriverHook.class);
		if (reqBody == null || reqBody.payload == null) { throw new CustAppAPI.CustAppException('Empty payload.'); }
		AddDriverPayload payload = reqBody.payload;
		if (payload.vehicle == null || String.isBlank(payload.vehicle.identificationNumber) || String.isBlank(payload.vehicle.alternateDriver.accountUuid)) {
			throw new CustAppAPI.CustAppException('Empty payload');
		}
		String uuid = payload.vehicle.alternateDriver.accountUuid;
		List<Customer_External_Account__c> custAccList = [SELECT Id, Type__c, Account__c, Account__r.Partial_NRIC__c, Account__r.NRIC_Number_wo_Prefix__c,
															Account__r.Doc_Type__c FROM Customer_External_Account__c WHERE UUID__c = :uuid];
		if (custAccList.size() <= 0) { throw new CustAppAPI.CustAppException('Unknown customer uuid'); }
		List<Vehicle_Ownership__c> voList = [SELECT Id, (SELECT Id, Account__c, Type__c FROM Drivers__r) FROM Vehicle_Ownership__c WHERE
											Vehicle__r.Name = :payload.vehicle.identificationNumber AND Status__c = 'Active' ORDER BY Start_Date__c DESC
											LIMIT 1];
		if (voList.size() <= 0) { throw new CustAppAPI.CustAppException('No known ownership found.'); }
		for (Alternative_Driver__c altD : voList[0].Drivers__r) {
			if (altD.Account__c == custAccList[0].Account__c && altD.Type__c == custAccList[0].Type__c) { return; } // alr added before
		}
		Alternative_Driver__c altD = new Alternative_Driver__c();
		altD.Account__c = custAccList[0].Account__c;
		altD.Created_From__c = 'Customer App';
		altD.Status__c = 'Active';
		altD.Type__c = custAccList[0].Type__c;
		altD.Vehicle_Ownership__c = voList[0].Id;
		switch on (reqBody.payload.vehicle.alternateDriver.relationship) {
			when 'RELATIVE', 'FAMILY' {
				altD.Relationship_to_Owner__c = 'Relative';
			} when 'FRIEND' {
				altD.Relationship_To_Owner__c = 'Friend';
			} when 'PERSONAL_DRIVER' {
				altD.Relationship_To_Owner__c = 'Driver';
			} when else {
				altD.Relationship_To_Owner__c = '';
			}
		}
		insert altD;
	}

	public static void processRemoveCallback() {
		RestRequest req = RestContext.request;
		RemoveDriverHook reqBody = (RemoveDriverHook) JSON.deserialize(req.requestBody.toString(), RemoveDriverHook.class);
		if (reqBody == null || reqBody.payload == null) { throw new CustAppAPI.CustAppException('Empty payload.'); }
		RemoveDriverPayload payload = reqBody.payload;
		if (payload.vehicle == null || String.isBlank(payload.vehicle.identificationNumber) || String.isBlank(payload.vehicle.alternateDriverUuid)) {
			throw new CustAppAPI.CustAppException('Empty payload');
		}
		String uuid = payload.vehicle.alternateDriverUuid;
		List<Customer_External_Account__c> custAccList = [SELECT Id, Type__c, Account__c, Account__r.Partial_NRIC__c, Account__r.NRIC_Number_wo_Prefix__c,
															Account__r.Doc_Type__c FROM Customer_External_Account__c WHERE UUID__c = :uuid];
		if (custAccList.size() <= 0) { throw new CustAppAPI.CustAppException('Unknown customer uuid'); }
		List<Alternative_Driver__c> altDList = [SELECT Id, Status__c FROM Alternative_Driver__c WHERE Account__c = :custAccList[0].Account__c AND
												Vehicle_Ownership__r.Vehicle__r.Name = :payload.vehicle.identificationNumber AND
												Type__c = :custAccList[0].Type__c];
		if (altDList.size() <= 0) { throw new CustAppAPI.CustAppException('No known alternate driver found.'); }
		for (Alternative_Driver__c d : altDList) { d.Status__c = 'Removed'; }
		update altDList;
	}

	// return vo Id => list of alt driver map
	// only inserted if altDriver type and extAcc type matches
	public static Map<Id, List<AltDriverCls>> retrieveAltDriver(Set<Id> voIDs, String cmp) {
		Map<Id, List<AltDriverCls>> res = new Map<Id, List<AltDriverCls>>();
		String type = CustAppAccount.EXT_ACC_TYPE.get(cmp);
		if (String.isBlank(type)) { return res; }
		String query = 'SELECT ' + String.join(ALT_DRIVER_FIELDS, ',') + ' FROM Alternative_Driver__c WHERE Vehicle_Ownership__c = :voIDs AND ' +
						'Status__c = \'Active\' AND Type__c = :type';
		List<Alternative_Driver__c> altDriverList = Database.query(query);
		Set<Id> accId = new Set<Id>();
		for (Alternative_Driver__c altD : altDriverList) { accId.add(altD.Account__c); }
		Map<Id, List<Customer_External_Account__c>> extAccMap = CustAppAccount.getExtAccounts(new List<Id>(accId), new Set<String> { type });
		for (Alternative_Driver__c altD : altDriverList) {
			List<Customer_External_Account__c> extAccList = extAccMap.get(altD.Account__c);
			if (extAccList == null) { continue; }
			for (Customer_External_Account__c extAcc : extAccList) {
				if (altD.Type__c != extAcc.Type__c) { continue; }
				List<AltDriverCls> dList = res.get(altD.Vehicle_Ownership__c);
				dList = (dList == null) ? new List<AltDriverCls>() : dList;
				dList.add(new AltDriverCls(altD, extAcc.UUID__c));
				res.put(altD.Vehicle_Ownership__c, dList);
			}
		}
		return res;
	}

	/** Button: Resync To AB App (Alternative_Driver__c) */
	Webservice static string pushToAbApp(Id adId) {
		try {
			String[] events = new string[]{};
			Alternative_Driver__c ad = [SELECT Id, Status__c FROM Alternative_Driver__c WHERE Id = :adId];

			if (ad.Status__c.equalsIgnoreCase('Active')) {
				events.addAll(new string[] { CustAppVehicle.EVENT_NAME, ADD_ALT_DVR_EVT });
			}
			else { events.add(REM_ALT_DVR_EVT); }
	
			Customer_App_Callback__e[] cbs = new Customer_App_Callback__e[]{};
			for (string event :events) {
				Customer_App_Callback__e cb = new Customer_App_Callback__e();
				cb.Id__c = adId;
				cb.Event__c = event;
				cbs.add(cb);
			}
			EventBus.publish(cbs);
			return 'Done! ' + JSON.serialize(events);
		}
		catch (Exception e) {
			return 'Error: ' + e.getMessage() + (Envir.isSandbox ? '\n\n' + e.getStackTraceString() : '');
		}
	}

	global class AltDriverCls {
		public String accountUuid;
		public String relationship;
		global AltDriverCls() {}
		global AltDriverCls(Alternative_Driver__c altD, String uuid) {
			this.accountUuid = uuid;
			switch on (altD.Relationship_to_Owner__c) {
				when 'Relative', 'Wife', 'Son', 'Daughter', 'Brother', 'Sister', 'Father', 'Mother', 'Uncle', 'Husband' {
					this.relationship = 'FAMILY';
				} when 'Friend' {
					this.relationship = 'FRIEND';
				} when 'Employed', 'Driver' {
					this.relationship = 'PERSONAL_DRIVER';
				} when else {
					this.relationship = 'PERSONAL_DRIVER'; // WHIP doesn't accept empty string.
				}
			}
		}
	}

	global class AddDriverHook {
		public String event;
		public AddDriverPayload payload;
		global AddDriverHook(String event, AddDriverPayload payload) {
			this.event = event;
			this.payload = payload;
		}
	}

	global class AddDriverPayload {
		public AddDriverCls vehicle;
		global AddDriverPayload() {}
		global AddDriverPayload(Alternative_Driver__c altD, String uuid) {
			this.vehicle = new AddDriverCls(altD, uuid);
		}
	}

	global class AddDriverCls {
		public String identificationNumber;
		public AltDriverCls alternateDriver;
		global AddDriverCls() {}
		global AddDriverCls(Alternative_Driver__c altD, String uuid) {
			this.identificationNumber = altD.Vehicle_Ownership__r.Vehicle__r.Name;
			this.alternateDriver = new AltDriverCls(altD, uuid);
		}
	}

	global class RemoveDriverHook {
		public String event;
		public RemoveDriverPayload payload;
		global RemoveDriverHook(String event, RemoveDriverPayload payload) {
			this.event = event;
			this.payload = payload;
		}
	}

	global class RemoveDriverPayload {
		public RemoveDriverCls vehicle;
		global RemoveDriverPayload(Alternative_Driver__c driver, String uuid) {
			this.vehicle = new RemoveDriverCls(driver, uuid);
		}
	 }

	global class RemoveDriverCls {
		public String identificationNumber;
		public String alternateDriverUuid;
		global RemoveDriverCls(Alternative_Driver__c driver, String uuid) {
			this.identificationNumber = driver.Vehicle_Ownership__r.Vehicle__r.Name;
			this.alternateDriverUuid = uuid;
		}
	}
}