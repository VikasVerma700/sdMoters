global without sharing class CustAppAppt {
	public final static String EVENT_NAME = 'UPSERT_VEHICLE_APPOINTMENT';
	public final static String REM_EVENT = 'REMOVE_VEHICLE_APPOINTMENT';
	public final static Map<String, Set<String>> ALLOWED_WS = new Map<String, Set<String>> { '028' => new Set<String> { 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'AA', 'AD', 'AF', 'AP', 'A1M', 'A2M', 'A3M', 'A4M', 'A5M' } };
	public static List<String> APPT_FIELDS;
	static {
		APPT_FIELDS = new List<String> { 'Id', 'Name', 'Appointment_Date__c', 'Apppointment_Status__c', 'Workshop__c', 'Service_Request__c',
										'Employee_Master__c', 'Company__r.AbAppCompany__c', 'Contact_Name__c', 'Contact_No__c', 'Email_Address_Notification__c',
										'Customer_Comment__c', 'Company__r.Name', 'Vehicle_Ownership__c', 'Workshop__r.Name', 'Workshop__r.Contact_Number__c' };
		APPT_FIELDS.addAll(CustAppAPI.prefixFields(CustAppUser.EMPMASTER_FIELDS, 'Employee_Master__r.'));
		APPT_FIELDS.addAll(CustAppAPI.prefixFields(CustAppVehicle.VO_FIELDS, 'Vehicle_Ownership__r.'));
	}

	public static void sendWebhook(Customer_App_Callback__e callback) {
		String apptId = callback.Id__c;
		String query = 'SELECT ' + String.join(APPT_FIELDS, ',') + ' FROM Service_Appointment__c WHERE Id = :apptId';
		List<Service_Appointment__c> apptList = Database.query(query);
		if (apptList.size() <= 0) { return; }
		List<Service_Appointment__c> cleanAppt = new List<Service_Appointment__c>();
		for (Service_Appointment__c a : apptList) {
			Set<String> wsName = ALLOWED_WS.get(a.Company__r.Name);
			if (wsName.contains(a.Workshop__r.Name)) { cleanAppt.add(a); }
		}
		if (cleanAppt.size() <= 0) { return; }
		Set<String> types = new Set<String>();
		Set<String> roSet = new Set<String>();
		Set<String> cmpSet = new Set<String>();
		Set<Id> voSet = new Set<Id>();
		Set<Id> ownerIdSet = new Set<Id>();
		for (Service_Appointment__c appt : cleanAppt) {
			String curType = CustAppAccount.EXT_ACC_TYPE.get(appt.Company__r.Name);
			if (!String.isBlank(curType)) { types.add(curType); }
			roSet.add(appt.Id);
			cmpSet.add(appt.Company__r.Name);
			voSet.add(appt.Vehicle_Ownership__c);
			ownerIdSet.add(appt.Vehicle_Ownership__r.Customer__c);
		}
		String roQuery = 'SELECT ' + String.join(CustAppRO.RO_FIELDS, ',') + ' FROM ServiceOrder__c WHERE Company__r.Name IN :cmpSet AND ServiceAppointment__c IN :roSet AND StatusApp__c != null AND (NOT (ContactAccNumber__c LIKE \'I%\' OR ContactAccNumber__c IN (\'C0000001\', \'C1000009\'))) ORDER BY LastModifiedDate DESC';
		List<ServiceOrder__c> orderList = Database.query(roQuery);
		Map<String, ServiceOrder__c> roMap = new Map<String, ServiceOrder__c>();
		Set<Id> roIdSet = new Set<Id>();
		for (ServiceOrder__c ro : orderList) {
			roIdSet.add(ro.Id);
			for (Service_Appointment__c appt : cleanAppt) {
				if (appt.Id == ro.ServiceAppointment__c && appt.Company__r.Name == ro.Company__r.Name) {
					if (!roMap.containsKey(appt.Id)) {
						roMap.put(appt.Id, ro);
						break;
					}
				}
			}
		}
		/** Service Invoice + Attachments */
		String sinvQuery =	'SELECT ' + String.join(CustAppRO.INV_FIELDS, ',') + ', ' +
							'(SELECT ' + String.join(CustAppFile.ATT_FIELDS, ',') + ' FROM Attachments WHERE Name LIKE \'Service Invoice%\') ' +
							'FROM ServiceInvoice__c ' +
							'WHERE AccountNumber__c = \'C0000002\' ' +
							'AND InvoiceReady__c = true ' +
							'AND InvoiceValue__c > 0 ' + 
							'AND RepairOrder__c IN :roIdSet '
							;
		ServiceInvoice__c[] sis = Database.query(sinvQuery);
		Map<Id, ServiceInvoice__c[]> mapRoInv = new Map<Id, ServiceInvoice__c[]>();
		for (ServiceInvoice__c si :sis) {
			if (mapRoInv.containsKey(si.RepairOrder__c)) { mapRoInv.get(si.RepairOrder__c).add(si); }
			else { mapRoInv.put(si.RepairOrder__c, new ServiceInvoice__c[] { si }); }
		}
		Set<Id> altDSet = new Set<Id>();
		List<Alternative_Driver__c> altDList = [SELECT Id, Account__c, Account__r.Mobile_Preferred__pc FROM Alternative_Driver__c WHERE
												Vehicle_Ownership__c = :voSet AND Status__c = 'Active' AND Type__c IN :types];
		for (Alternative_Driver__c altD: altDList) { altDSet.add(altD.Account__c); }
		Set<Id> accIdSet = new Set<Id>(ownerIdSet);
		accIdSet.addAll(altDSet);
		Map<Id, List<Customer_External_Account__c>> extAccMap = CustAppAccount.getExtAccounts(new List<Id>(accIdSet), types);
		List<Customer_External_Account__c> accounts = new List<Customer_External_Account__c>();
		for (Id accId : ownerIdSet) {
			List<Customer_External_Account__c> curExtAccList = extAccMap.get(accId);
			if (curExtAccList == null) { continue; }
			for (Customer_External_Account__c extAcc : curExtAccList) { accounts.add(extAcc); }
		}
		if (accounts.size() <= 0) {
			for (Id accId : altDSet) {
				List<Customer_External_Account__c> curExtAccList = extAccMap.get(accId);
				if (curExtAccList == null) { continue; }
				for (Customer_External_Account__c extAcc : curExtAccList) { accounts.add(extAcc); }
			}
		}
		if (accounts.size() <= 0) { return; }
		for (Customer_External_Account__c custAcc : accounts) {
			String cmp = CustAppAccount.REV_TYPE.get(custAcc.Type__c);
			if (cmp == null) { continue; }
			for (Service_Appointment__c appt : cleanAppt) {
				if (appt.Vehicle_Ownership__r.Customer__c != custAcc.Account__c
					&& u.beautifyPhone(u.onlyPrefix(appt.Contact_No__c), u.onlyNumber(appt.Contact_No__c)) != u.beautifyPhone(custAcc.Account__r.Mobile_Country_Code_1__pc, custAcc.Account__r.Mobile_Preferred__pc)) { continue; }
				String hookBody;
				if (appt.Vehicle_Ownership__r.Status__c != 'Active') {
					RemoveApptPayload payload = new RemoveApptPayload(new List<Service_Appointment__c> { appt });
					RemoveApptWebHook hook = new RemoveApptWebHook(REM_EVENT, payload);
					hookBody = JSON.serialize(hook);
				} else {
					ServiceOrder__c ro = roMap.get(appt.Id);
					ServiceInvoice__c[] sinvs = new ServiceInvoice__c[]{};
					if (ro != null && mapRoInv.containsKey(ro.Id)) { sinvs = mapRoInv.get(ro.Id); }
					ApptPayload payload = new ApptPayload(appt, ro, sinvs);
					ApptWebhook hook = new ApptWebhook(EVENT_NAME, payload);
					hookBody = JSON.serialize(hook, true);
				}
				CustAppAPI.sendWebhook(hookBody);
			}
		}
	}
	
	/** Button: Resync To AB App (Service_Appointment__c) */
	Webservice static string pushToAbApp(Id apptId) {
		try {
			Customer_App_Callback__e cb = new Customer_App_Callback__e();
			cb.Id__c = apptId;
			cb.Event__c = EVENT_NAME;
			EventBus.publish(new List<Customer_App_Callback__e>{ cb });
			return 'Done!';
		}
		catch (Exception e) {
			return 'Error: ' + e.getMessage() + (Envir.isSandbox ? '\n\n' + e.getStackTraceString() : '');
		}
	}
	
	global class RemoveApptWebHook {
		public String event;
		public RemoveApptPayload payload;
		global RemoveApptWebHook(String event, RemoveApptPayload payload) {
			this.event = event;
			this.payload = payload;
		}
	}

	global class RemoveApptPayload {
		public List<RemoveApptInfo> vehicles;
		public RemoveApptPayload(List<Service_Appointment__c> appts) {
			this.vehicles = new List<RemoveApptInfo>();
			for (Service_Appointment__c sa : appts) {
				this.vehicles.add(new RemoveApptInfo(sa));
			}
		}
	}

	global class RemoveApptInfo {
		public String identificationNumber;
		public String appointmentId;
		public RemoveApptInfo(Service_Appointment__c appt) {
			this.identificationNumber = appt.Vehicle_Ownership__r.Vehicle__r.Name;
			this.appointmentId = appt.Id;
		}
	}

	global class ApptWebHook {
		public String event;
		public ApptPayload payload;
		global ApptWebhook(String event, ApptPayload payload) {
			this.event = event;
			this.payload = payload;
		}
	}

	global class ApptPayload {
		public ApptInfo vehicle;
		public ApptPayload(Service_Appointment__c appt, ServiceOrder__c ro) {
			this.vehicle = new ApptInfo(appt, ro);
		}
		public ApptPayload(Service_Appointment__c appt, ServiceOrder__c ro, ServiceInvoice__c[] sis) {
			this(appt, ro);
			if (ro != null) {
				this.vehicle.repairOrder = new CustAppRO.ROCls(ro, sis);
			}
		}
	}

	global class ApptInfo {
		public String identificationNumber;
		public ApptCls appointment;
		public CustAppRO.ROCls repairOrder;
		public ApptInfo(Service_Appointment__c appt, ServiceOrder__c ro) {
			this.identificationNumber = appt.Vehicle_Ownership__r.Vehicle__r.Name;
			this.appointment = new ApptCls(appt);
			if (ro != null && appt.Apppointment_Status__c != 'CANCELLED') {
				this.repairOrder = new CustAppRO.ROCls(ro);
				this.repairOrder.appointmentId = appt.Id;
			}
		}
	}

	global class ApptCls {
		public transient Service_Appointment__c sa;
		public String id;
		public String name;
		public DateTime dateAndTime;
		public String csaId;
		public String status;
		public String workshopId;
		public List<String> serviceTypes;
		public CustAppUser.UserCls serviceAdvisor;
		public String company;
		public AltDriverCls alternateDriver;
		public ValetCls valetService;
		public String remarks;
		public String qrCodeUrl;
		global ApptCls(Service_Appointment__c appt) {
			this.sa = appt;
			this.id = appt.Id;
			this.name = appt.Name;
			this.dateAndTime = appt.Appointment_Date__c;
			switch on appt.Apppointment_Status__c {
				when 'ACTIVE', 'NOT TRANSFERRED' {
					this.status = 'ACTIVE';
				} when 'CANCELLED' {
					this.status = 'CANCELLED';
				} when 'ARRIVED', 'CONVERTED TO RO', 'COMPLETED' {
					this.status = 'COMPLETED';
				} when 'NO SHOW' {
					this.status = 'MISSED';
				} when else {
					this.status = appt.Apppointment_Status__c;
				}
			}
			this.csaId = appt.Employee_Master__c;
			this.workshopId = appt.Workshop__c;
			this.serviceTypes = (String.isBlank(appt.Service_Request__c)) ? new List<String>() : appt.Service_Request__c.split(';');
			this.serviceAdvisor = (appt.Employee_Master__c != null) ? new CustAppUser.UserCls(appt.Employee_Master__r) : null;
			this.company = appt.Company__r.AbAppCompany__c;
			this.alternateDriver = new AltDriverCls(appt.Contact_Name__c, appt.Contact_No__c, appt.Email_Address_Notification__c);
			this.valetService = null; // TODO: link the 7PD appt in
			this.remarks = appt.Customer_Comment__c;
			this.qrCodeUrl = ServiceApptBooking.getApptQR(new List<Service_Appointment__c> { appt })[0];
		}
	}

	global class ValetCls {
		public CustAppLocation.LocationCls pickUpLocation;
		public CustAppLocation.LocationCls dropOffLocation;
		global ValetCls(CustAppLocation.LocationCls pickup, CustAppLocation.LocationCls dropoff) {
			this.pickUpLocation = pickup;
			this.dropOffLocation = dropoff;
		}
	}

	global class AltDriverCls {
		public String uuid;
		public String name;
		public CustAppAccount.PhoneCls phone;
		public String email;
		global AltDriverCls() {}
		global AltDriverCls(String name, String phone, String email) {
			this.name = name;
			this.phone = new CustAppAccount.PhoneCls(phone);
			this.email = email;
		}
	}
}