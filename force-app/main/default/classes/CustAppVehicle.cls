global without sharing class CustAppVehicle {
	public final static Map<String, String> NFR_CMP = new Map<String, String> { '028' => '168' };
	public final static Map<String, Set<String>> CASE_MAKE = new Map<String, Set<String>> { '028' => new Set<String> { 'B.M.W.' }};
	public final static String EVENT_NAME = 'UPSERT_VEHICLE';
	public final static String REM_EVENT = 'REMOVE_VEHICLE';
	public static List<String> MODEL_FIELDS;
	public static List<String> VEH_FIELDS;
	public static List<String> VO_FIELDS;
	List<Id> vehicleIds;
	public CustAppVehicle() {}
	public CustAppVehicle(List<Id> vehicleIds) { this.vehicleIds = vehicleIds; }

	static {
		MODEL_FIELDS = new List<String> { 'Vehicle_Make__r.Description__c', 'Vehicle_Model_Range__r.Name', 'Name', 'Body_Type__c', 'Short_Description__c', 'Description__c' };
		VEH_FIELDS = new List<String> { 'Registration_Number__c', 'Name', 'IU_Number__c', 'Vehicle_Colour_Description__c', 'Vehicle_Trim_Description__c',
										'Production_Month__c', 'Production_Year__c', 'Vehicle_Type__r.Name', 'Vehicle_Model__r.Fuel__c',
										'Vehicle_Make__c', 'Vehicle_Make__r.Name', 'Vehicle_Model__r.ModelForWhip__c', 'VehicleVariant__r.Name',
										'VehicleVariant__r.VariantForWhip__c', 'VehicleVariant__r.Description__c', 'IsAllowIService__c', 'Description__c' };
		VEH_FIELDS.addAll(CustAppAPI.prefixFields(MODEL_FIELDS, 'Vehicle_Model__r.'));
		VO_FIELDS = new List<String> { 'Id', 'Registration_No__c', 'Registration_Date__c', 'Customer__c', 'Status__c' };
		VO_FIELDS.addAll(CustAppAPI.prefixFields(CustAppVehicle.VEH_FIELDS, 'Vehicle__r.'));
	}

	@InvocableMethod(label='Vehicle Updates to Cust App' description='Sends vehicle updates to Customer App')
	public static void vehicleUpdate(List<Id> vehicleId) {
		CustAppVehicle.createAppCallbackFromVeh(vehicleId);
	}

	public static void createAppCallbackFromVeh(List<Id> vehIds) {
		try {
			if (vehIds == null || vehIds.size() <= 0) { return; }
			List<Vehicle__c> vehicles = [SELECT Id, (SELECT Id FROM Vehicle_Ownerships1__r WHERE Status__c = 'Active') FROM Vehicle__c WHERE Id IN :vehIds];
			Set<Id> vehOwnerId = new Set<Id>();
			List<Customer_App_Callback__e> callback = new List<Customer_App_Callback__e>();
			for (Vehicle__c v : vehicles) {
				for (Vehicle_Ownership__c vo : v.Vehicle_Ownerships1__r) {
					if (vehOwnerId.contains(vo.Id)) { continue; }
					Customer_App_Callback__e newE = new Customer_App_Callback__e();
					newE.Id__c = vo.Id;
					newE.Event__c = CustAppVehicle.EVENT_NAME;
					callback.add(newE);
					vehOwnerId.add(vo.Id);
				}
			}
			List<Alternative_Driver__c> altDList = [SELECT Id FROM Alternative_Driver__c WHERE Vehicle_Ownership__c IN :vehOwnerId AND Status__c = 'Active' AND
													Type__c IN :CustAppAccount.EXT_ACC_TYPE.values()];
			for (Alternative_Driver__c altD : altDList) {
				Customer_App_Callback__e newE = new Customer_App_Callback__e();
				newE.Id__c = altD.Id;
				newE.Event__c = CustAppVehicle.EVENT_NAME;
				Customer_App_Callback__e altDEvt = new Customer_App_Callback__e();
				altDEvt.Id__c = altD.Id;
				altDEvt.Event__c = CustAppAltDriver.ADD_ALT_DVR_EVT;
				callback.addAll(new List<Customer_App_Callback__e> { newE, altDEvt });
			}
			if (callback.size() > 0) { EventBus.publish(callback); }
		} catch (Exception e) {
			String emailBody = CommonMethodsLibrary.constructErrEmail('Error from CustAppVehicle', e.getStackTraceString(), e.getMessage());
			System.debug('CustAppVehicle Error: ' + emailBody);
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
		}
	}

	public static void sendWebhook(Customer_App_Callback__e callback) {
		Id altDvrOrVehOwnerId = callback.Id__c;
		Id vehOwnerId;
		Boolean isAltDriver = false;
		List<Customer_External_Account__c> accounts;
		// if alt driver, we send uuid of alt driver
		if (altDvrOrVehOwnerId.getSobjectType() == Schema.Alternative_Driver__c.SObjectType) {
			isAltDriver = true;
			String query = 'SELECT ' + String.join(CustAppAltDriver.ALT_DRIVER_FIELDS, ',') + ' FROM Alternative_Driver__c WHERE Id = :altDvrOrVehOwnerId';
			List<Alternative_Driver__c> driverList = Database.query(query);
			if (driverList.size() <= 0) { return; }
			accounts = CustAppAccount.getExtAccounts(driverList[0].Account__c, new Set<String> { driverList[0].Type__c });
			vehOwnerId = driverList[0].Vehicle_Ownership__c;
		} else {
			vehOwnerId = altDvrOrVehOwnerId;
		}
		// List<String> voFields = new List<String>(VO_FIELDS);
		String query = 'SELECT ' + String.join(VO_FIELDS, ',') + ' FROM Vehicle_Ownership__c WHERE Id = :vehOwnerId';
		List<Vehicle_Ownership__c> voList = Database.query(query);
		if (voList.size() <= 0) { return; }
		Vehicle_Ownership__c vo = voList[0];
		if (!isAltDriver) { // not alt driver, have to get all possible uuids that need updating
			Set<String> types = CustAppAccount.REV_TYPE.keySet();
			accounts = CustAppAccount.getExtAccounts(vo.Customer__c, types);
		}
		if (accounts.size() <= 0) { return; }
		for (Customer_External_Account__c custAcc : accounts) {
			String cmp = CustAppAccount.REV_TYPE.get(custAcc.Type__c);
			if (cmp == null) { continue; }
			if (vo.Status__c == 'Active') {
				VehHookPayload payload = new VehHookPayload(vo, cmp, custAcc);
				VehWebhook hook = new VehWebhook(EVENT_NAME, payload);
				CustAppAPI.sendWebhook(JSON.serialize(hook));
			} else {
				RemoveVehWebhookPayload payload = new RemoveVehWebhookPayload(vo.Id);
				RemoveVehWebhook hook = new RemoveVehWebhook(REM_EVENT, payload);
				CustAppAPI.sendWebhook(JSON.serialize(hook));
				List<ServiceOrder__c> roList = [SELECT Id, VehicleOwnership__r.Vehicle__r.Name FROM ServiceOrder__c WHERE VehicleOwnership__c = :vo.Id];
				List<Service_Appointment__c> apptList = [SELECT Id, Vehicle_Ownership__r.Vehicle__r.Name FROM Service_Appointment__c WHERE
														Vehicle_Ownership__c = :vo.Id];
				CustAppRO.RemoveROPayload remROPayload = new CustAppRO.RemoveROPayload(roList);
				CustAppRO.RemoveROWebhook remROHook = new CustAppRO.RemoveROWebhook(CustAppRO.REM_EVENT_NAME, remROPayload);
				CustAppAPI.sendWebhook(JSON.serialize(remROHook));
				CustAppAppt.RemoveApptPayload remApptPayload = new CustAppAppt.RemoveApptPayload(apptList);
				CustAppAppt.RemoveApptWebHook remApptHook = new CustAppAppt.RemoveApptWebHook(CustAppAppt.REM_EVENT, remApptPayload);
				// CustAppAPI.sendWebhook(JSON.serialize(remApptHook));
			}
		}
	}

	public static void sendWebhookRemoveVo(Customer_App_Callback__e callback) {
		VehHookPayload payload = new VehHookPayload();
		payload.vehicle.id = callback.Id__c;
		VehWebhook hook = new VehWebhook(REM_EVENT, payload);
		System.debug('sendWebhookRemoveVo: ' + JSON.serialize(hook));
		CustAppAPI.sendWebhook(JSON.serialize(hook));
	}

	public static void sendWarrantyWebhook(Customer_App_Callback__e callback) {
		Id wtyId = callback.Id__c;
		VehicleWarranty__c[] vws = [SELECT Id, Vehicle__c FROM VehicleWarranty__c WHERE Id = :wtyId];
		if (vws != null && vws.size() > 0) {
			Set<Id> vehIdset = new Set<Id>();
			for (VehicleWarranty__c vw :vws) { vehIdset.add(vw.Vehicle__c); }

			Vehicle_Ownership__c[] vos = [SELECT Id FROM Vehicle_Ownership__c WHERE Status__c = 'Active' AND Vehicle__c IN :vehIdset];
			if (vos != null && vos.size() > 0) {
				Customer_App_Callback__e[] callbacks = new Customer_App_Callback__e[]{};
				for (Vehicle_Ownership__c vo :vos) { callbacks.add(new Customer_App_Callback__e(Id__c = vo.Id, Event__c = 'UPSERT_VEHICLE')); }
				if (callbacks != null && callbacks.size() > 0) { EventBus.publish(callbacks); }
			}
		}
	}
	// public static void processCallback() {
	// 	RestRequest req = RestContext.request;
	// 	LtaVehCallback reqBody = (LtaVehCallback) JSON.deserialize(req.requestBody.toString(), LtaVehCallback.class);
	// 	if (reqBody == null || reqBody.payload == null) { throw new CustAppAPI.CustAppException('Empty payload.'); }
	// 	LtaVOCls payload = reqBody.payload;
	// 	if (String.isBlank(payload.accountUuid) || payload.vehicle == null) { throw new CustAppAPI.CustAppException('Empty payload'); }
	// 	List<Customer_External_Account__c> custAccList = [SELECT Id, Type__c, Account__c, Account__r.Partial_NRIC__c, Account__r.NRIC_Number_wo_Prefix__c,
	// 														Account__r.NRIC_Number__c,
	// 														Account__r.Doc_Type__c FROM Customer_External_Account__c WHERE UUID__c = :payload.accountUuid];
	// 	if (custAccList.size() <= 0) { throw new CustAppAPI.CustAppException('Unknown customer uuid'); }
	// 	String cmpName = CustAppAccount.REV_TYPE.get(custAccList[0].Type__c);
	// 	if (String.isBlank(cmpName)) { throw new CustAppAPI.CustAppException('Unable to map customer UUID Type.'); }
	// 	Company__c cmp = CustAppAPI.CMP_MAP.get(cmpName);
	// 	Company__c makeCmp = isFranchise(payload.vehicle.vehicleDetails.make, cmp) ? cmp : CustAppAPI.CMP_MAP.get(NFR_CMP.get(cmp.Name));
	// 	Vehicle__c veh = saveVeh(payload.vehicle, makeCmp);
	// 	String docType = CustAppAccount.mapDocType(payload.vehicle.vehicleOwnerParticulars.idType);
	// 	String docNum = payload.vehicle.vehicleOwnerParticulars.id;
	// 	String docNumCheck = '%' + docNum;
	// 	Boolean isOwner = (docType == custAccList[0].Account__r.Doc_Type__c && (docNum == custAccList[0].Account__r.Partial_NRIC__c ||
	// 						custAccList[0].Account__r.NRIC_Number_wo_Prefix__c.endsWithIgnoreCase(docNum))
	// 						|| docNum == custAccList[0].Account__r.NRIC_Number__c);

	// 	Map<Id, Account> dummyAcct = new Map<Id, Account>([SELECT Id FROM Account WHERE Name = 'Pls key into Salesforce updated owner details' LIMIT 1]);
	// 	// we get either the VO that matches the doc num and type or the dummy VO that was created previously
	// 	List<Vehicle_Ownership__c> existingVOList = [SELECT Id, Customer__c, Vehicle__c, (SELECT Id FROM Drivers__r WHERE Status__c = 'Active' AND
	// 												Account__c = :custAccList[0].Account__c) FROM Vehicle_Ownership__c WHERE Vehicle__c = :veh.Id AND
	// 												Status__c = 'Active' AND ((Customer__r.Doc_Type__c = :docType AND (Customer__r.Partial_NRIC__c = :docNum OR
	// 												Customer__r.NRIC_Number_wo_Prefix__c LIKE :docNumCheck)) OR Customer__c IN :dummyAcct.keySet()) ORDER BY
	// 												Start_Date__c DESC LIMIT 1];
	// 	Id checkId = (isOwner) ? custAccList[0].Account__c : dummyAcct.values()[0].Id;
	// 	Vehicle_Ownership__c curVO = (existingVOList.size() <= 0) ? upsertVO(veh, checkId) : existingVOList[0];
	// 	if (!isOwner && curVO.Drivers__r.size() <= 0) {
	// 		upsertAltDriver(curVO, custAccList[0].Type__c, custAccList[0].Account__r, payload.vehicle.vehicleOwnerParticulars);
	// 	}
	// 	Attachment att = new Attachment();
	// 	att.Name = custAccList[0].Type__c + ' LTA Request.json';
	// 	att.ParentId = curVO.Id;
	// 	att.Body = req.requestBody;
	// 	att.ContentType = 'application/json';
	// 	insert att;
	// 	if (!isOwner) { // avoid hitting limits
	// 		CustAppVehVerifyCase caseQ = new CustAppVehVerifyCase(curVO.Id, payload.vehicle, cmp.Name);
	// 		if (Limits.getLimitQueueableJobs() > Limits.getQueueableJobs()) { System.enqueueJob(caseQ); }
	// 	}
	// }

	// public static Vehicle__c saveVeh(LTAVehCls veh, Company__c cmp) {
	// 	List<Vehicle__c> vehList = [SELECT Id, Engine_Number__c, /* LTA_TCOE_Category__c, LTA_TCOE_Expiry_Date__c, LTA_Quota_Premium__c, */
	// 								/*LTA_Total_COE_Rebate_Amount__c, LTA_PARF_Eligibility_Expiry_Date__c, LTA_PARF_Eligibility__c, */Vehicle_Type__c,
	// 								/*LTA_Total_PARF_Rebate_Amount__c, LTA_Actual_ARF_Paid__c, LTA_Chassis_No__c, LTA_Engine_No__c, */Vehicle_Make__c,
	// 								/*LTA_Intended_Deregistration_Date__c, LTA_First_Registration_Date__c, LTA_Vehicle_Make__c, LTA_Vehicle_Model__c,*/
	// 								/*LTA_Engine_Capacity__c, */Registration_Number__c, /*LTA_Open_Market_Value__c, LTA_Primary_Colour__c, */Registration_Date__c/*,*/
	// 								/*LTA_Transfer_Count__c, Vehicle_Model__c, Vehicle_Colour__c, LTA_Vehicle_Type__c, LTA_Motor_No__c, LTA_Propellant__c,
	// 								LTA_Vehicle_Scheme__c, LTA_Power_Rating__c, LTA_Maximum_Laden_Weight__c, LTA_Lifespan_Expiry_Date__c,
	// 								LTA_Unladen_Weight__c, LTA_Road_Tax_Expiry_Date__c, LTA_Next_Inspection_Due_Date__c, LTA_CO2_Emission__c,
	// 								LTA_CO_Emission__c, LTA_NOx_Emission__c, LTA_HC_Emission__c, LTA_PM_Emission__c, LTA_Vehicle_Attachment__c,
	// 								LTA_Intended_Transfer_Date__c, LTA_CEV_VES_Rebate_Utilised_Amount__c*/ FROM Vehicle__c WHERE
	// 								Name = :veh.vehicleDetails.chassisNo];
	// 	Vehicle__c curVeh = (vehList.size() > 0) ? vehList[0] : new Vehicle__c();
	// 	if (curVeh.Id == null) {
	// 		curVeh.Name = veh.vehicleDetails.chassisNo;
	// 	}
	// 	// String category = String.isBlank(veh.intendedCoeRebateDetails.category) ? '' : veh.intendedCoeRebateDetails.category.left(1);,

	// 	// curVeh.LTA_TCOE_Category__c = compareStringValue(category, curVeh.LTA_TCOE_Category__c);
	// 	// setVehicleType(curVeh, curVeh.LTA_TCOE_Category__c, cmp);
	// 	// curVeh.LTA_TCOE_Expiry_Date__c = veh.intendedCoeRebateDetails.expiryDate == null ? curVeh.LTA_TCOE_Expiry_Date__c :
	// 	// 								veh.intendedCoeRebateDetails.expiryDate.date();
	// 	Decimal qpPaid = getDecimalValue(veh.intendedCoeRebateDetails.qpPaid);
	// 	// curVeh.LTA_Quota_Premium__c = (qpPaid != null) ? qpPaid : curVeh.LTA_Quota_Premium__c;
	// 	Decimal coeRebateAmt = getDecimalValue(veh.intendedCoeRebateDetails.rebateAmount);
	// 	// curVeh.LTA_Total_COE_Rebate_Amount__c = (coeRebateAmt != null) ? coeRebateAmt : curVeh.LTA_Total_COE_Rebate_Amount__c;
	// 	// curVeh.LTA_PARF_Eligibility__c = (veh.intendedParfRebateDetails.eligibility != null) ? veh.intendedParfRebateDetails.eligibility :
	// 	// 								curVeh.LTA_PARF_Eligibility__c;
	// 	// curVeh.LTA_PARF_Eligibility_Expiry_Date__c = (veh.intendedParfRebateDetails.eligibilityExpireDate == null) ? curVeh.LTA_PARF_Eligibility_Expiry_Date__c 											: veh.intendedParfRebateDetails.eligibilityExpireDate.date();
	// 	Decimal parfRebateAmt = getDecimalValue(veh.intendedParfRebateDetails.rebateAmount);
	// 	// curVeh.LTA_Total_PARF_Rebate_Amount__c = (parfRebateAmt != null) ? parfRebateAmt : curVeh.LTA_Total_PARF_Rebate_Amount__c;
	// 	Decimal arfPaid = getDecimalValue(veh.vehicleDetails.actualArfPaid);
	// 	// curVeh.LTA_Actual_ARF_Paid__c = (arfPaid != null) ? arfPaid : curVeh.LTA_Actual_ARF_Paid__c;
	// 	// curVeh.LTA_Chassis_No__c = compareStringValue(veh.vehicleDetails.chassisNo, curVeh.LTA_Chassis_No__c);
	// 	// curVeh.LTA_Engine_No__c = compareStringValue(veh.vehicleDetails.engineNo, curVeh.LTA_Engine_No__c);
	// 	curVeh.Engine_Number__c = compareStringValue(veh.vehicleDetails.engineNo, curVeh.Engine_Number__c);
	// 	// curVeh.LTA_First_Registration_Date__c = veh.vehicleDetails.firstRegistrationDate == null ? curVeh.LTA_First_Registration_Date__c :
	// 	// 										veh.vehicleDetails.firstRegistrationDate.date();
	// 	// curVeh.Registration_Date__c = (curVeh.LTA_First_Registration_Date__c != null) ? curVeh.LTA_First_Registration_Date__c : curVeh.Registration_Date__c;
	// 	// curVeh.LTA_Intended_Deregistration_Date__c = veh.vehicleDetails.intendedDeregistrationDate == null ? curVeh.LTA_Intended_Deregistration_Date__c :
	// 	// 											veh.vehicleDetails.intendedDeregistrationDate.date();
	// 	// MobyPurchaseVeh.saveMake(curVeh, veh.vehicleDetails.make, cmp);
	// 	// MobyPurchaseVeh.saveModel(curVeh, veh.vehicleDetails.model, cmp, null, null, null);
	// 	curVeh.Registration_Number__c = compareStringValue(veh.vehicleDetails.no, curVeh.Registration_Number__c);
	// 	Decimal omv = getDecimalValue(veh.vehicleDetails.openMarketValue);
	// 	// curVeh.LTA_Open_Market_Value__c = (omv != null) ? omv : curVeh.LTA_Open_Market_Value__c;
	// 	// MobyPurchaseVeh.saveColor(curVeh, veh.vehicleDetails.primaryColor, cmp);
	// 	// curVeh.LTA_Transfer_Count__c = (veh.vehicleDetails.transferCount != null) ? veh.vehicleDetails.transferCount : curVeh.LTA_Transfer_Count__c;
	// 	// curVeh.LTA_Vehicle_Type__c = compareStringValue(veh.vehicleDetails.vehicleType, curVeh.LTA_Vehicle_Type__c);
	// 	// curVeh.LTA_Vehicle_Scheme__c = compareStringValue(veh.vehicleDetails.scheme, curVeh.LTA_Vehicle_Scheme__c);
	// 	// curVeh.LTA_Propellant__c = compareStringValue(veh.vehicleDetails.propellant, curVeh.LTA_Propellant__c);
	// 	// curVeh.LTA_Motor_No__c = compareStringValue(veh.vehicleDetails.motorNo, curVeh.LTA_Motor_No__c);
	// 	// curVeh.LTA_Power_Rating__c = compareStringValue(veh.vehicleDetails.powerRating, curVeh.LTA_Power_Rating__c);
	// 	// curVeh.LTA_Maximum_Laden_Weight__c = compareStringValue(veh.vehicleDetails.maximumLadenWeight, curVeh.LTA_Maximum_Laden_Weight__c);
	// 	// curVeh.LTA_Lifespan_Expiry_Date__c = (veh.vehicleDetails.lifespanExpiryDate != null) ? veh.vehicleDetails.lifespanExpiryDate.date() :
	// 	// 										curVeh.LTA_Lifespan_Expiry_Date__c;
	// 	// curVeh.LTA_Road_Tax_Expiry_Date__c = (veh.vehicleDetails.roadTaxExpiryDate != null) ? veh.vehicleDetails.roadTaxExpiryDate.date() :
	// 	// 										curVeh.LTA_Road_Tax_Expiry_Date__c;
	// 	// curVeh.LTA_Next_Inspection_Due_Date__c = (veh.vehicleDetails.inspectionDueDate != null) ? veh.vehicleDetails.inspectionDueDate.date() :
	// 	// 											curVeh.LTA_Next_Inspection_Due_Date__c;
	// 	// curVeh.LTA_CO2_Emission__c = compareStringValue(veh.vehicleDetails.co2Emission, curVeh.LTA_CO2_Emission__c);
	// 	// curVeh.LTA_CO_Emission__c = compareStringValue(veh.vehicleDetails.COEmission, curVeh.LTA_CO_Emission__c);
	// 	// curVeh.LTA_NOx_Emission__c = compareStringValue(veh.vehicleDetails.NOxEmission, curVeh.LTA_NOx_Emission__c);
	// 	// curVeh.LTA_Vehicle_Attachment__c = compareStringValue(veh.vehicleDetails.attachment, curVeh.LTA_Vehicle_Attachment__c);
	// 	// curVeh.LTA_Engine_Capacity__c = compareStringValue(veh.vehicleDetails.engineCapacity, curVeh.LTA_Engine_Capacity__c);
	// 	// curVeh.LTA_Unladen_Weight__c = compareStringValue(veh.vehicleDetails.unladenWeight, curVeh.LTA_Unladen_Weight__c);
	// 	// curVeh.LTA_Intended_Transfer_Date__c = (veh.vehicleDetails.intendedTransferDate != null) ? veh.vehicleDetails.intendedTransferDate.date() :
	// 	// 										curVeh.LTA_Intended_Transfer_Date__c;
	// 	// Decimal rebate = getDecimalValue(veh.vehicleDetails.cevVesRebateUtilisedAmount);
	// 	// curVeh.LTA_CEV_VES_Rebate_Utilised_Amount__c = rebate != null ? rebate : curVeh.LTA_CEV_VES_Rebate_Utilised_Amount__c;
	// 	// curVeh.LTA_HC_Emission__c = compareStringValue(veh.vehicleDetails.hcEmission, curVeh.LTA_HC_Emission__c);
	// 	// curVeh.LTA_PM_Emission__c = compareStringValue(veh.vehicleDetails.pmEmission, curVeh.LTA_PM_Emission__c);
	// 	upsert curVeh;
	// 	return curVeh;
	// }

	// public static Alternative_Driver__c upsertAltDriver(Vehicle_Ownership__c vo, String type, Account acc, OwnerCls ownerInfo) {
	// 	Alternative_Driver__c curD = new Alternative_Driver__c();
	// 	curD.Account__c = acc.Id;
	// 	curD.Created_From__c = 'Customer App';
	// 	curD.Status__c = 'Active';
	// 	curD.Type__c = type;
	// 	curD.Vehicle_Ownership__c = vo.Id;
	// 	insert curD;
	// 	return curD;
	// }

	// public static Vehicle_Ownership__c insertVO(Vehicle__c veh, Id accId) {
	// 	Vehicle_Ownership__c vo = new Vehicle_Ownership__c();
	// 	vo.Customer__c = accId;
	// 	vo.Registration_No__c = veh.Registration_Number__c;
	// 	vo.Start_Date__c = Date.today();
	// 	vo.Vehicle_Make__c = veh.Vehicle_Make__c;
	// 	vo.Vehicle__c = veh.Id;
	// 	insert vo;
	// 	return vo;
	// }

	/** Button: Resync To AB App (VehicleOwnership__c) */
	Webservice static string pushToAbApp(Id vehOwnId) {
		try {
			Vehicle_Ownership__c[] vos = [SELECT Id, Status__c FROM Vehicle_Ownership__c WHERE Id = :vehOwnId];
			if (vos == null || vos.size() <= 0) { return 'Error. Unable to find vehicle ownership for id: \'' + vehOwnId + '\'.'; }
			string event;
			if (vos[0].Status__c == 'Active') { event = EVENT_NAME; }
			else { event = REM_EVENT; }
			Customer_App_Callback__e cb = new Customer_App_Callback__e();
			cb.Id__c = vehOwnId;
			cb.Event__c = event;
			EventBus.publish(new List<Customer_App_Callback__e>{ cb });
			return 'Done!';
		}
		catch (Exception e) {
			return 'Error: ' + e.getMessage() + (Envir.isSandbox ? '\n\n' + e.getStackTraceString() : '');
		}
	}
	// private static Boolean isFranchise(String make, Company__c cmp) {
	// 	return (cmp.Name == '02' && make == 'BMW') || (cmp.Name == '03' && (make == 'FORD' || make == 'PEUGEOT' || make == 'BYD'))
	// 		   || (cmp.Name == '028' && new string[] { 'B', 'BMW', 'C', 'E', 'M', 'MIN', 'MINI', 'MRAD' }.contains(make));
	// }

	// private static String compareStringValue(String newValue, String oldValue) {
	// 	return (!String.isBlank(newValue)) ? newValue : ((!String.isBlank(oldValue)) ? oldValue : '');
	// }

	// private static Decimal getDecimalValue(String value) {
	// 	String cleanValue = String.isBlank(value) ? '' : value.replaceAll('[$,-]', '');
	// 	return String.isBlank(cleanValue) ? null : Decimal.valueOf(cleanValue);
	// }

	// private static void setVehicleType(Vehicle__c veh, String coeCat, Company__c cmp) {
	// 	List<Vehicle_Type__c> vehTypes = [SELECT Id, Name FROM Vehicle_Type__c WHERE Company__c = :cmp.Id AND Name LIKE 'U%'];
	// 	Map<String, Vehicle_Type__c> vehTypeMap = new Map<String, Vehicle_Type__c>();
	// 	for (Vehicle_Type__c v : vehTypes) { vehTypeMap.put(v.Name, v); }
	// 	switch on (coeCat) {
	// 		when 'A', 'B', 'E' {
	// 			Vehicle_Type__c type = vehTypeMap.get('UC');
	// 			veh.Vehicle_Type__c = (type != null) ? type.Id : veh.Vehicle_Type__c;
	// 		} when 'D' {
	// 			Vehicle_Type__c type = vehTypeMap.get('UB');
	// 			veh.Vehicle_Type__c = (type != null) ? type.Id : veh.Vehicle_Type__c;
	// 		} when else {
	// 			throw new CustAppAPI.CustAppException('Unknown vehicle type mapping.');
	// 		}
	// 	}
	// }

	global class RemoveVehWebhook {
		public String event;
		global RemoveVehWebhookPayload payload;
		global RemoveVehWebhook(String event, RemoveVehWebhookPayload payload) {
			this.event = event;
			this.payload = payload;
		}
	}

	global class RemoveVehWebhookPayload {
		public Map<String, String> vehicle;
		public RemoveVehWebhookPayload(String vehOwnerId) {
			this.vehicle = new Map<String, String> { 'id' => vehOwnerId };
		}
	}

	global class VehWebhook {
		public String event;
		public VehHookPayload payload;
		global VehWebhook(String event, VehHookPayload payload) {
			this.event = event;
			this.payload = payload;
		}
	}

	global class VehHookPayload {
		public String accountUuid;
		public VehAndInsCls vehicle;
		global VehHookPayload() {
			this.vehicle = new VehAndInsCls();
		}
		global VehHookPayload(Vehicle_Ownership__c vo, String cmp, Customer_External_Account__c extAcc) {
			this.vehicle = new VehAndInsCls(vo, cmp, extAcc);
			/** Vehicle Warranties */
			Map<Id, List<WarrantyCls>> mapVehWty = retrieveWarranties(vo.Customer__c);
			if (mapVehWty != null && mapVehWty.containsKey(vo.Id)) { this.vehicle.warrantyPackages = mapVehWty.get(vo.Id); }
			this.accountUuid = extAcc.UUID__c;
		}
	}

	global class VehAndInsCls extends VehCls {
		List<CustAppInsurance.InsuranceCls> insurancePackages;
		List<WarrantyCls> warrantyPackages;
		global VehAndInsCls() { super(); }
		global VehAndInsCls(Vehicle_Ownership__c vo, String cmp) {
			this(vo, cmp, null);
		}

		global VehAndInsCls(Vehicle_Ownership__c vo, String cmp, Customer_External_Account__c extAcc) {
			super(vo, cmp, extAcc);
			Map<Id, List<CustAppInsurance.InsuranceCls>> insPolicies = CustAppInsurance.retrieveInsurance(vo.Customer__c, cmp);
			this.insurancePackages = insPolicies.get(vo.Id);
		}
	}

	global virtual class VehSpec {
		public String brand;
		public String model;
		public String variant;
		public String display;
		public String bodyStyle;
		public String exteriorColor;
		public String interiorColor;
		global VehSpec(Vehicle__c veh) {
			this(veh.Vehicle_Model__r);
			this.model = String.isBlank(veh.Vehicle_Model__r.ModelForWhip__c) ? veh.Vehicle_Model__r.Name : veh.Vehicle_Model__r.ModelForWhip__c;
			this.variant = String.isBlank(veh.VehicleVariant__r.VariantForWhip__c) ? veh.VehicleVariant__r.Name : veh.VehicleVariant__r.VariantForWhip__c;
			this.display = String.isBlank(veh.VehicleVariant__r.Description__c) ? veh.Description__c : veh.VehicleVariant__r.Description__c;
			this.exteriorColor = veh.Vehicle_Colour_Description__c;
			this.interiorColor = veh.Vehicle_Trim_Description__c;
		}
		global VehSpec() {}
		global VehSpec(Vehicle_Model__c model) {
			this.brand = model.Vehicle_Make__r.Description__c;
			if (String.isBlank(model.Vehicle_Model_Range__r.Name)) { // means non franchise car or model
				this.model = model.Name;
				this.display = model.Name;
				this.variant = model.Name;
			} else {
				this.model = model.Vehicle_Model_Range__r.Name;
				this.variant = model.Name;
				this.display = model.Description__c;
			}
			this.bodyStyle = model.Body_Type__c; // TODO: patch data
		}
	}

	global virtual class VehCls {
		public transient Vehicle_Ownership__c vo;
		public String association;
		public String id;
		public String status;
		public String type;
		public String numberPlate;
		public String identificationNumber;
		public String inVehicularUnit;
		public CustAppVehicle.VehSpec unit;
		public DateTime manufactureDate;
		public DateTime registrationDate;
		public String qrCodeUrl;
		public Boolean allowIService;
		global VehCls() {}
		global VehCls(Vehicle_Ownership__c vo, String cmp) {
			this(vo, cmp, null);
		}

		global VehCls(Vehicle_Ownership__c vo, String cmp, Customer_External_Account__c extAcc) {
			this.vo = vo;
			this.id = vo.Id;
			this.association = (extAcc == null || extAcc.Account__c == vo.Customer__c) ? 'OWNER' : 'ALTERNATE_DRIVER';
			this.numberPlate = vo.Registration_No__c;
			this.identificationNumber = vo.Vehicle__r.Name;
			this.inVehicularUnit = vo.Vehicle__r.IU_Number__c;
			this.status = vo.Status__c.toUppercase();
			String vehType, fuelType;
			// if (vo.Vehicle__r.Vehicle_Type__r.Name.containsIgnoreCase('B')) { // bike
			// 	vehType = 'BIKE';
			// } else if (vo.Vehicle__r.Vehicle_Type__r.Name.containsIgnoreCase('C')) { // car
			// 	vehType = 'CAR';
			// } else {
			// 	throw new CustAppAPI.CustAppException('Unmapped vehicle type ' + vo.Vehicle__r.Vehicle_Type__r.Name);
			// }
			if (vo.Vehicle__r.Vehicle_Make__c != null) {
				switch on vo.Vehicle__r.Vehicle_Make__r.Name {
					when 'B', 'BMW', 'M', 'MIN', 'MINI', 'E' { vehType = 'CAR'; }
					when 'C', 'MRAD' { vehType = 'BIKE'; }
					when 'NFR', 'Z' { vehType = 'CAR'; }
					when else {
						throw new CustAppAPI.CustAppException('Unmapped vehicle type ' + vo.Vehicle__r.Vehicle_Make__r.Name);
					}
				}
			}
			if (vo.Vehicle__r.Vehicle_Model__r.Fuel__c == 'Petrol' /* || vo.Vehicle__r.LTA_Propellant__c == 'Petrol' */) {
				fuelType = 'PETROL';
			} else if (vo.Vehicle__r.Vehicle_Model__r.Fuel__c == 'Diesel' /* || vo.Vehicle__r.LTA_Propellant__c == 'Diesel' */) {
				fuelType = 'DIESEL';
			} else if (vo.Vehicle__r.Vehicle_Model__r.Fuel__c == 'Hybrid' /* || vo.Vehicle__r.LTA_Propellant__c == 'Hybrid' */) {
				fuelType = 'HYBRID';
			} else if (vo.Vehicle__r.Vehicle_Model__r.Fuel__c == 'Electric' /* || vo.Vehicle__r.LTA_Propellant__c == 'Electric' */) {
				fuelType = 'ELECTRIC';
			} else {
				fuelType = 'UNKNOWN';
			}
			this.type = vehType + '_' + fuelType;
			this.unit = new CustAppVehicle.VehSpec(vo.Vehicle__r);
			if (vo.Vehicle__r.Production_Month__c != null && vo.Vehicle__r.Production_Year__c != null) {
				this.manufactureDate = Date.newInstance(Integer.valueOf(vo.Vehicle__r.Production_Year__c), Integer.valueOf(vo.Vehicle__r.Production_Month__c), 1);
			}
			this.registrationDate = vo.Registration_Date__c;
			this.qrCodeUrl = ServiceApptBooking.getVOQR(new List<Vehicle_Ownership__c>{ vo }, cmp)[0];
			this.allowIService = vo.Vehicle__r.IsAllowIService__c;
		}
	}

	global class LtaVehCallback {
		public String event;
		public LtaVOCls payload;
	}

	global class LtaVOCls {
		public String accountUuid;
		public String source;
		public LtaVehCls vehicle;
	}

	public class LtaVehCls {
		public OwnerCls vehicleOwnerParticulars;
		public COERebateCls intendedCoeRebateDetails;
		public ParfRebateCls intendedParfRebateDetails;
		public VehDetailsCls vehicleDetails;
		public String transferFee;
	}

	global class OwnerCls {
		public String idType;
		public String id;
	}

	global class COERebateCls {
		public String category;
		public DateTime expiryDate;
		public Decimal period;
		public String qpPaid;
		public String rebateAmount;
		public String totalRebateAmount;
	}

	global class ParfRebateCls {
		public String eligibility;
		public DateTime eligibilityExpireDate;
		public String rebateAmount;
	}

	global class VehDetailsCls {
		public String actualArfPaid;
		public String chassisNo;
		public String engineNo;
		public DateTime firstRegistrationDate;
		public DateTime intendedDeregistrationDate;
		public String make;
		public Integer manufacturerYear;
		public String maximumPowerOutput;
		public String model;
		public String no;
		public String openMarketValue;
		public DateTime originalRegistrationDate;
		public String primaryColor;
		public Integer transferCount;
		public Boolean vehicleToBeExported;
		public String vehicleType;
		public String scheme;
		public String propellant;
		public String motorNo;
		public String powerRating;
		public String maximumLadenWeight;
		public DateTime lifespanExpiryDate;
		public DateTime roadTaxExpiryDate;
		public DateTime inspectionDueDate;
		public String co2Emission;
		public String coEmission;
		public String noxEmission;
		public String attachment;
		public String engineCapacity;
		public String unladenWeight;
		public DateTime intendedTransferDate;
		public String cevVesRebateUtilisedAmount;
		public String hcEmission;
		public String pmEmission;
	}

	global virtual class WarrantyCls {
		public String packageName;
		public Integer mileage;
		public Integer duration;
		public DateRangeCls dateRange;
		public WarrantyCls() {}
		public WarrantyCls(VehicleWarranty__c vehWty) {
			this.packageName = vehWty.ContractDescription__c;
			this.mileage = Integer.valueOf(vehWty.Distance__c);
			this.duration = Integer.valueOf(vehWty.Duration__c);
			this.dateRange = new DateRangeCls(vehWty.DateStart__c, vehWty.DateEnd__c);
		}

	}
	public class DateRangeCls {
		public Date startDate;
		public Date endDate;
		public DateRangeCls(Date startDate, Date endDate) {
			this.startDate = startDate;
			this.endDate = endDate;
		}
	}
	public static Map<Id, List<WarrantyCls>> retrieveWarranties(Id accId) {
		Alternative_Driver__c[] ads = [SELECT Id, Name, Vehicle_Ownership__c FROM Alternative_Driver__c WHERE Status__c = 'Active' AND Account__c = :accId];
		Set<Id> voIdset = new Set<Id>();
		for (Alternative_Driver__c ad :ads) { voIdset.add(ad.Vehicle_Ownership__c); }
		Vehicle_Ownership__c[] vos = [SELECT Id, Name, Vehicle__c FROM Vehicle_Ownership__c WHERE Status__c = 'Active' AND (Customer__c = :accId OR Id IN :voIdset)];
		Set<Id> vehIdset = new Set<Id>();
		for (Vehicle_Ownership__c vo :vos) { vehIdset.add(vo.Vehicle__c); }

		Vehicle__c[] vs = [
			SELECT Id, Name
				, (SELECT Company__c, Id, Name, ContractDescription__c, DateStart__c, DateEnd__c, Duration__c, Distance__c FROM VehicleWarranties__r)
			FROM Vehicle__c
			WHERE Id IN :vehIdset
		];
		Map<Id, Vehicle__c> mapVeh = new Map<Id, Vehicle__c>();
		for (Vehicle__c v :vs) { mapVeh.put(v.Id, v); }

		Map<Id, List<WarrantyCls>> mapWty = new Map<Id, List<WarrantyCls>>();
		for (Vehicle_Ownership__c vo :vos) {
			WarrantyCls[] wcs = new List<WarrantyCls>();
			for (VehicleWarranty__c vw :mapVeh.get(vo.Vehicle__c).VehicleWarranties__r) { wcs.add(new WarrantyCls(vw)); }
			if (wcs.size() > 0) { mapWty.put(vo.Id, wcs); }
		}
		return mapWty;
	}


}