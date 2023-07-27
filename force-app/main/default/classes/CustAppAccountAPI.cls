@RestResource(urlMapping='/cust/*/account/sync')
global without sharing class CustAppAccountAPI {
	public final static String RESYNC_EVT = 'RESYNC_ACCOUNT';
	@HttpPost
	global static CustomerSync getAccount() {
		RestRequest req = RestContext.request;
		RestResponse res = RestContext.response;
		Savepoint sp;
		List<CustAppTD.TDSync> tds;
		String mobyErrMsg = '';
		try {
			CustAppAccount.AccountReq reqBody;
			if (req.requestURI != null && req.requestURI.containsIgnoreCase('/v1.0/')) {
				CustAppAccount.AccountV1Req reqBodyV1 = (CustAppAccount.AccountV1Req) JSON.deserialize(req.requestBody.toString(),
														CustAppAccount.AccountV1Req.class);
				reqBody = reqBodyV1.toAccountReq();
			} else {
				reqBody = (CustAppAccount.AccountReq) JSON.deserialize(req.requestBody.toString(), CustAppAccount.AccountReq.class);
			}
			System.debug('reqBody: ' + JSON.serialize(reqBody));
			Company__c companyInfo = [SELECT Id, Name FROM Company__c WHERE AbAppCompany__c = :reqBody.company LIMIT 1];
			String type = CustAppAccount.EXT_ACC_TYPE.get(companyInfo.Name);
			if (companyInfo.Name == '028') {
				try { tds = MobyApiTestDrive.retrieveTD(reqBody.uuid, companyInfo.Name); }
				catch (Exception e) {
					mobyErrMsg += e.getTypeName() + ':\n' + e.getMessage() + ':\n\n' + e.getStackTraceString() + '\n\n';
					System.debug(mobyErrMsg);
				}
			}
			sp = Database.setSavePoint();
			Account acc = CustAppAccount.saveCustAcc(reqBody);
			Account syncAcc = retrieveAcc(acc.Id, companyInfo.Name, type, reqBody.uuid);
			Customer_External_Account__c extAcc = syncAcc.Customer_External_Accounts__r.size() > 0 ? syncAcc.Customer_External_Accounts__r[0] : null;
			CustomerSync sync = new CustomerSync(syncAcc, extAcc, companyInfo.Name);
			if (companyInfo.Name == '028') { sync.testDrives = tds; }
			if (String.isNotBlank(mobyErrMsg)) {
				String emailBody =  CommonMethodsLibrary.constructErrEmail('Error from CustAppAccountAPI', mobyErrMsg, 'CustAppAccountAPI.cls: Line 33');
				CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
			}
			return sync;
		}
		catch (Exception e) {
			System.debug(req.requestBody.toString());
			if (sp != null) { Database.rollback(sp); }
			String emailBody = CommonMethodsLibrary.constructErrEmail('Error from CustAppAccountAPI', e.getStackTraceString(), e.getMessage());
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
			throw e;
		}
	}

	webservice static String resyncAccountToApp(Id accId) {
		try {
			resyncAccount(accId);
			return '';
		} catch (Exception e) {
			return e.getMessage();
		}
	}

	static Map<Id, List<CustAppAppt.ApptCls>> vehAppts; // = CustAppAccountAPI.retrieveAppointments(acc.Service_Appointment__r, cmp);
	static Map<Id, List<CustAppRO.ROCls>> vehRepairs; // = CustAppAccountAPI.retrieveRO(acc.ServiceOrders__r, cmp);
	static Map<Id, List<CustAppInsurance.InsuranceCls>> vehInsurances; // = CustAppInsurance.retrieveInsurance(acc.Id, cmp);
	static Map<Id, List<CustAppVehicle.WarrantyCls>> vehWarranties; // = CustAppVehicle.retrieveWarranties(acc.Id);

	public static void sendResyncWebhook(Customer_App_Callback__e callback) {
		resyncAccount(callback.Id__c);
	}

	global static void resyncAccount(Id accId) {
		string[] errEmail = new string[]{};
		string[] payloadEmail = new string[]{};
		List<Account> accList = CustAppAccount.retrieveAccDetails(new List<Id> { accId }, new Set<String>(CustAppAccount.EXT_ACC_TYPE.values()));
		if (accList.size() <= 0 || accList[0].Customer_External_Accounts__r.size() <= 0) { return; }
		Account acc = accList[0];
		Map<String, List<Customer_External_Account__c>> cmpToAcc = new Map<String, List<Customer_External_Account__c>>();
		for (Customer_External_Account__c custAcc : acc.Customer_External_Accounts__r) {
			String cmp = CustAppAccount.REV_TYPE.get(custAcc.Type__c);
			if (String.isBlank(cmp)) { continue; }
			List<Customer_External_Account__c> extAcc = cmpToAcc.get(cmp);
			extAcc = (extAcc == null) ? new List<Customer_External_Account__c>() : extAcc;
			extAcc.add(custAcc);
			cmpToAcc.put(cmp, extAcc);
		}
		for (String cmp : cmpToAcc.keySet()) {
			List<Customer_External_Account__c> extAccs = cmpToAcc.get(cmp);
			if (extAccs.size() <= 0) { continue; }
			Account syncAcc = retrieveAcc(acc.Id, cmp, '', '');
			// use one external account to retrieve all account data first, since its repeated
			CustomerResync resyncBody = new CustomerResync(syncAcc, extAccs[0], cmp);
			for (Customer_External_Account__c extA : extAccs) {
				resyncBody.account = new CustAppAccount.AccountResync(syncAcc, extA, cmp);
				/** Add TD retrieval via Moby API call */
				try { resyncBody.testDrives = MobyApiTestDrive.retrieveTD(syncAcc.Id, cmp); }
				catch (Exception e) {
					string header = 'CustAppAccountAPI.resyncAccount(' + accId + ')';
					string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
					string error = 'resyncBody.testDrives = MobyApiTestDrive.retrieveTD(' + syncAcc.Id + ', ' + cmp + ');';
					String emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
					errEmail.add(emailBody);				
				}
				ResyncWebhook hook = new ResyncWebhook(RESYNC_EVT, resyncBody);
				string jsonHook = JSON.serialize(hook, true);
				CustAppAPI.sendWebhook(jsonHook, cmp);
				/** Email payload to Admin */
				String emailBody = RESYNC_EVT + ' Payload:<br /><br />' + jsonHook;
				System.debug(emailBody);
				payloadEmail.add(emailBody);
			}
		}
		if (errEmail != null && errEmail.size() > 0) {
			String subject = Envir.subject + ' CustAppAccountAPI error!';
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, String.join(errEmail, '<br/>'), true, subject);
		}
		if (payloadEmail != null && payloadEmail.size() > 0) {
			String subject = Envir.subject + ' CustAppAccountAPI Payload';
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, String.join(payloadEmail, '<br/>'), true, subject);
		}
	}

	public static Account retrieveAcc(Id accId, String cmp, String type, String uuid) {
		Set<String> allowedWS = CustAppAppt.ALLOWED_WS.get(cmp);
		String pdpaName = CustAppAccount.AGREEMENT_TYPE;
		String pdpaVer = CustAppAccount.AGREEMENT_VER;
		String tokenType = CustAppAccount.TOKEN_TYPE;
		String query = 'SELECT ';
		query += String.join(CustAppAccount.ACC_FIELDS, ',');
		query += ',(SELECT ' + String.join(CustAppVehicle.VO_FIELDS, ',') + ' FROM Vehicle_Ownerships__r WHERE Vehicle__r.Vehicle_Model__c != null AND Status__c = \'Active\')';
		query += ',(SELECT ' + String.join(CustAppAltDriver.ALT_DRIVER_FIELDS, ',') + ' FROM Alternative_Drivers__r WHERE Status__c = \'Active\')';
		query += ',(SELECT ' + String.join(CustAppAccount.DEVICE_FIELDS, ',') + ' FROM User_Message_Tokens__r WHERE Token_Type__c = :tokenType)';
		query += ',(SELECT ' + String.join(CustAppAccount.LEGISLATION_FIELDS, ',') + ' FROM Local_Legislations__r WHERE Legislation_Type__r.Name = :pdpaName AND Type_of_Legal_Legislation_Version__c = :pdpaVer ORDER BY Consent_Date_Time__c DESC LIMIT 1)';
		if (!String.isBlank(uuid)) {
			query += ',(SELECT ' + String.join(CustAppAccount.EXT_ACC_FIELDS, ',');
			query += ' FROM Customer_External_Accounts__r WHERE UUID__c = :uuid AND Type__c = :type)';
		}
		if (allowedWS != null) {
			query += ',(SELECT ' + String.join(CustAppRO.RO_FIELDS, ',') + ' FROM ServiceOrders__r ';
			query += 'WHERE Company__r.Name = :cmp AND Workshop__r.Name IN :allowedWS AND Date_Cancelled__c = null AND ';
			query += '(Service_Order_Date__c = THIS_MONTH OR Service_Order_Date__c = LAST_N_MONTHS:11) AND PreRegService__c != TRUE) ';
			query += ',(SELECT ' + String.join(CustAppAppt.APPT_FIELDS, ',') + ' FROM Service_Appointment__r ';
			query += 'WHERE Company__r.Name = :cmp AND Workshop__r.Name IN :allowedWS AND ';
			query += '(DAY_ONLY(convertTimezone(CreatedDate)) = THIS_MONTH OR DAY_ONLY(convertTimezone(CreatedDate)) = LAST_N_MONTHS:12) ';
			query += 'AND Apppointment_Status__c != \'CANCELLED\' ';
			query += 'LIMIT 50';
			query += ')';
			query += ',(SELECT ' + String.join(CustAppSurvey.SURVEY_FIELDS, ',') + ' FROM Survey_Lists__r ';
			query += 'WHERE Repair_Order__c != null AND Company__r.Name = :cmp)';
		}
		query += ' FROM Account WHERE Id = :accId AND IsPersonAccount = TRUE';
		System.debug('retrieveAcc: ' + query.replace('= :tokenType', '= \'' + tokenType + '\'')
											.replace('= :pdpaName', '= \'' + pdpaName + '\'')
											.replace('= :pdpaVer', '= \'' + pdpaVer + '\'')
											.replace('= :uuid', '= \'' + uuid + '\'')
											.replace('= :type', '= \'' + type + '\'')
											.replace('= :cmp', '= \'' + cmp + '\'')
											.replace('IN :allowedWS ', 'IN (\'' + String.join(new List<string>(allowedWS), '\',\'') + '\')')
											.replace('= :accId', '= \'' + accId + '\'')
											);
		List<Account> acc = Database.query(query);
		if (acc.size() <= 0) {
			throw new CustAppAPI.CustAppException('Unexpected Error. Cannot find account.');
		}
		return acc[0];
	}

	public static List<VOSync> retrieveVO(List<Vehicle_Ownership__c> voList, String cmp) {
		List<VOSync> res = new List<VOSync>();
		for (Vehicle_Ownership__c vo : voList) {
			res.add(new VOSync(vo, cmp));
		}
		return res;
	}

	public static List<VOSync> retrieveAltD(List<Alternative_Driver__c> altDList, Customer_External_Account__c extAcc, String cmp) {
		List<VOSync> res = new List<VOSync>();
		for (Alternative_Driver__c altD : altDList) {
			res.add(new VOSync(altD.Vehicle_Ownership__r, cmp, extAcc));
		}
		return res;
	}

	// organized by VO Id => RO[]
	public static Map<Id, List<CustAppRO.ROCls>> retrieveRO(List<ServiceOrder__c> roList, String cmp) {
		Map<Id, List<CustAppRO.ROCls>> res = new Map<Id, List<CustAppRO.ROCls>>();
		Set<Id> roIdSet = new Set<Id>();
		for (ServiceOrder__c ro :roList) { roIdSet.add(ro.Id); }
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

		for (ServiceOrder__c ro : roList) {
			List<CustAppRO.ROCls> curROList = res.get(ro.VehicleOwnership__c);
			curROList = (curROList == null) ? new List<CustAppRO.ROCls>() : curROList;
			ServiceInvoice__c[] sinvs = mapRoInv.get(ro.Id);
			curROList.add(new CustAppRO.ROCls(ro, sinvs));
			res.put(ro.VehicleOwnership__c, curROList);
		}
		return res;
	}

	// organized by VO Id => Appt[]
	public static Map<Id, List<CustAppAppt.ApptCls>> retrieveAppointments(List<Service_Appointment__c> appts, String cmp) {
		Map<Id, List<CustAppAppt.ApptCls>> res = new Map<Id, List<CustAppAppt.ApptCls>>();
		for (Service_Appointment__c appt : appts) {
			List<CustAppAppt.ApptCls> apptList = res.get(appt.Vehicle_Ownership__c);
			apptList = (apptList == null) ? new List<CustAppAppt.ApptCls>() : apptList;
			apptList.add(new CustAppAppt.ApptCls(appt));
			res.put(appt.Vehicle_Ownership__c, apptList);
		}
		return res;
	}

	public static void inviteAcc(Account acc, String cmp) { inviteAcc(acc, cmp, false); }
	public static void inviteAcc(Account acc, String cmp, Boolean skipVerify) {
		String type = CustAppAccount.EXT_ACC_TYPE.get(cmp);
		if (String.isBlank(type)) { throw new CustAppAPI.CustAppException('Unknown company for sync.'); }
		if (!skipVerify) {
			List<Customer_External_Account__c> extAccList = [SELECT Id FROM Customer_External_Account__c WHERE Type__c = :type AND Account__c = :acc.Id AND
															IsActive__c = TRUE AND IsDefault__c = TRUE];
			if (extAccList.size() > 0) { throw new CustAppAPI.CustAppException(acc.Name + ' already previously registered.'); }
		}
		Account syncAcc = retrieveAcc(acc.Id, cmp, type, '');
		CustomerSync sync = new CustomerSync(syncAcc, cmp);
		String jsonBody = JSON.serialize(sync, true);
		Http http = new Http();
		HttpRequest req = new HttpRequest();
		req.setEndpoint(CustAppAPI.URL_BASE + '/v1.0/account/invite/email');
		req.setMethod('POST');
		req.setHeader('Content-Type', 'application/json');
		req.setHeader('Authorization', 'Bearer ' + CustAppAPI.login(cmp));
		req.setTimeout(30000);
		req.setBody(jsonBody);
		HttpResponse resp = http.send(req);
		if (resp == null || String.isBlank(resp.getBody())) { throw new CustAppAPI.CustAppException('Invalid response'); }
		InviteResp invite = (InviteResp) JSON.deserialize(resp.getBody(), InviteResp.class);
		if (resp.getStatusCode() == 200 || resp.getStatusCode() == 201) {
			if (invite.response == null || invite.response.data == null || invite.response.data.account == null) {
				throw new CustAppAPI.CustAppException('Empty response.');
			}
			InviteAcc data = invite.response.data.account;
			CustAppAccount.updateCustAcc(null, acc.Id, type, data.email, data.uuid, '', acc.LastName);
			Boolean hasVehicleErr = sync.vehicles.size() != data.vehicles.confirmed;
			if (!data.isEmailDispatched || hasVehicleErr) {
				String emailBody = CommonMethodsLibrary.constructErrEmail('Error from CustAppAccount:syncResponse', jsonBody, resp.getBody());
				CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
			}
		} else {
			String message = (invite.response == null || String.isBlank(invite.response.message)) ? 'Error from sending invite.' : invite.response.message;
			throw new CustAppAPI.CustAppException(message + '\n' + jsonBody);
		}
	}

	global class CustomerSync extends CustomerSyncBase {
		CustAppAccount.AccountSync account;
		public CustomerSync(Account acc, String cmp) {
			this(acc, null, cmp);
		}
		public CustomerSync(Account acc, Customer_External_Account__c extAcc, String cmp) {
			super(acc, cmp);
			this.account = new CustAppAccount.AccountSync(acc, extAcc, cmp);
			if (acc.Alternative_Drivers__r != null && acc.Alternative_Drivers__r.size() > 0) {
				this.vehicles.addAll(CustAppAccountAPI.retrieveAltD(acc.Alternative_Drivers__r, extAcc, cmp));
			}
		}
	}

	global class CustomerResync extends CustomerSyncBase {
		CustAppAccount.AccountResync account;
		public CustomerResync(Account acc, Customer_External_Account__c extAcc, String cmp) {
			super(acc, cmp);
			this.account = new CustAppAccount.AccountResync(acc, extAcc, cmp);
			if (acc.Alternative_Drivers__r != null && acc.Alternative_Drivers__r.size() > 0) {
				this.vehicles.addAll(CustAppAccountAPI.retrieveAltD(acc.Alternative_Drivers__r, extAcc, cmp));
			}
		}

		public CustomerResync(Account acc, String cmp) {
			super(acc, cmp);
		}
	}

	global virtual class CustomerSyncBase {
		List<VOSync> vehicles;
		List<CustAppTD.TDSync> testDrives;
		public CustomerSyncBase(Account acc, String cmp) {
			/** Retrieve all child records, to be used by VOSync */
			vehAppts = CustAppAccountAPI.retrieveAppointments(acc.Service_Appointment__r, cmp);
			vehRepairs = CustAppAccountAPI.retrieveRO(acc.ServiceOrders__r, cmp);
			vehInsurances = CustAppInsurance.retrieveInsurance(acc.Id, cmp);
			vehWarranties = CustAppVehicle.retrieveWarranties(acc.Id);
			this.vehicles = CustAppAccountAPI.retrieveVO(acc.Vehicle_Ownerships__r, cmp);
			// this.mergeSurveyAndRO(repairOrders, acc.Survey_Lists__r);
			Set<Id> voIDs = new Set<Id>();
			for (VOSync vo : this.vehicles) {
				voIDs.add(vo.id);
				// vo.insurancePackages = insPackages.get(vo.id);
				// vo.appointments = appointments.get(vo.id);
				// vo.repairOrders = repairOrders.get(vo.id);
				// vo.warrantyPackages = vehWarranties.get(vo.id);
			}
			// this.mergeApptAndRO(this.vehicles);
			// adding in alt drivers
			Map<Id, List<CustAppAltDriver.AltDriverCls>> altDrivers = CustAppAltDriver.retrieveAltDriver(voIDs, cmp);
			this.addAltDrivers(this.vehicles, altDrivers);
			if (cmp != '028') { 
				this.testDrives = CustAppTD.retrieveTD(acc.Id, cmp); 
			}
			else if (cmp == '028') { /** Test Drive from Moby is called before this due to use of SavePoint. */ }
		}

		public void addAltDrivers(List<VOSync> voList, Map<Id, List<CustAppAltDriver.AltDriverCls>> altDrivers) {
			if (altDrivers == null || voList == null) { return; }
			for (VOSync vo : voList) {
				List<CustAppAltDriver.AltDriverCls> drivers = altDrivers.get(vo.id);
				if (drivers == null) { continue; }
				vo.alternateDrivers = (vo.alternateDrivers == null) ? new List<CustAppAltDriver.AltDriverCls>() : vo.alternateDrivers;
				vo.alternateDrivers.addAll(drivers);
			}
		}

		// public void mergeSurveyAndRO(Map<Id, List<CustAppRO.ROCls>> repairOrders, List<Survey_List__c> surveys) {
		// 	Map<Id, Survey_List__c> surveyMap = new Map<Id, Survey_List__c>();
		// 	for (Survey_List__c s : surveys) {
		// 		if (s.Repair_Order__c == null) { continue; }
		// 		surveyMap.put(s.Repair_Order__c, s);
		// 	}
		// 	for (List<CustAppRO.ROCls> roList : repairOrders.values()) {
		// 		for (CustAppRO.ROCls ro : roList) {
		// 			Survey_List__c curSurvey = surveyMap.get(ro.id);
		// 			if (curSurvey == null) { continue; }
		// 			ro.eSurvey = new CustAppSurvey.SurveyCls(curSurvey);
		// 		}
		// 	}
		// }
		// ro and appt is unique by Company, Workshop, Date, Chassis.
		// this is within one VO, so chassis is matched
		// public void mergeApptAndRO(List<VOSync> voList) {
		// 	for (VOSync vo : voList) {
		// 		if (vo.appointments == null || vo.repairOrders == null) { continue; }
		// 		Map<String, Service_Appointment__c> apptMap = new Map<String, Service_Appointment__c>();
		// 		for (CustAppAppt.ApptCls appt : vo.appointments) {
		// 			if (appt == null || appt.sa == null || String.isBlank(appt.sa.GDMS_Repair_Order_Number__c)) { continue; }
		// 			apptMap.put(appt.sa.GDMS_Repair_Order_Number__c, appt.sa);
		// 		}
		// 		for (CustAppRO.ROCls ro : vo.repairOrders) {
		// 			Service_Appointment__c sa = apptMap.get(ro.name);
		// 			if (sa == null) { continue; }
		// 			ro.appointmentId = sa.Id;
		// 		}
		// 	}
		// }
	}

	global class VOSync extends CustAppVehicle.VehCls {
		public List<CustAppInsurance.InsuranceCls> insurancePackages;
		public List<CustAppVehicle.WarrantyCls> warrantyPackages;
		public List<CustAppAppt.ApptCls> appointments;
		public List<CustAppRO.ROCls> repairOrders;
		public List<CustAppAltDriver.AltDriverCls> alternateDrivers;
		global VOSync(Vehicle_Ownership__c vo, String cmp) {
			super(vo, cmp);
			this.insurancePackages = vehInsurances.get(this.id);
			this.appointments = vehAppts.get(this.id);
			this.repairOrders = vehRepairs.get(this.id);
			this.warrantyPackages = vehWarranties.get(this.id);
		}

		global VOSync(Vehicle_Ownership__c vo, String cmp, Customer_External_Account__c extAcc) {
			super(vo, cmp, extAcc);
			this.insurancePackages = vehInsurances.get(this.id);
			this.appointments = vehAppts.get(this.id);
			this.repairOrders = vehRepairs.get(this.id);
			this.warrantyPackages = vehWarranties.get(this.id);
		}
	}

	global class InviteResp extends CustAPPAPI.APIResp {
		public InviteBody response;
	}

	global class InviteBody {
		public String message;
		public InviteData data;
	}

	global class InviteData {
		public InviteAcc account;
	}

	global class InviteAcc {
		public String uuid;
		public String email;
		public CustAppAccount.IdentityCls identity;
		public InviteVehCnt vehicles;
		public Boolean isEmailDispatched;
	}

	global class InviteVehCnt {
		public Integer confirmed;
		public Integer rejected;
	}

	global class ResyncWebhook {
		public String event;
		public CustomerResync payload;
		public ResyncWebhook(String event, CustomerResync payload) {
			this.event = event;
			this.payload = payload;
		}
	}
}