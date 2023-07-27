@IsTest
public class CustAppVehicle_Test {
	@TestSetup
	static void setup() {
		TestFactory.genTriggerSettings('Customer App Callback', true);
		TestFactory.genTriggerSettings('Vehicle Model', true);
		TestFactory.genTriggerSettings('Vehicle', true);
		List<Customer_External_Account__c> extAcc = TestFactory.genCustExtAcc(2, true);
		Alternative_Driver__c altD = TestFactory.genAltDriver(1, false)[0];
		altD.Account__c = extAcc[0].Account__c;
		insert altD;
		update new Vehicle_Ownership__c(Id = altD.Vehicle_Ownership__c, Customer__c = extAcc[1].Account__c);
		Company__c ppsl = TestFactory.getCompany('168');
		Vehicle_Type__c uc = TestFactory.genVehType('UC', false);
		uc.Company__c = ppsl.Id;
		insert uc;
		Vehicle_Ownership__c voUpd = [SELECT Id, Vehicle__c FROM Vehicle_Ownership__c WHERE Id = :altD.Vehicle_Ownership__c];
		Vehicle_Make__c make = TestFactory.genVehMake('B', false);
		insert make;
		Vehicle_Model__c model = TestFactory.genVehModel(1, false)[0];
		model.Fuel__c = 'Petrol';
		insert model;
		VehicleVariant__c variant = new VehicleVariant__c(Name = '328', Company__c = ppsl.Id, Make__c = make.Id, Model__c = model.Id);
		update new Vehicle__c(Id = voUpd.Vehicle__c, Vehicle_Make__c = make.Id, Vehicle_Type__c = uc.Id, Vehicle_Model__c = model.Id, VehicleVariant__c = variant.Id);
	}

	@IsTest
	public static void testTrigger() {
		EventBusSubscriber sub = [SELECT Name, Position, Retries, LastError FROM EventBusSubscriber WHERE Topic='Customer_App_Callback__e' AND
									Type='ApexTrigger'];
		Test.startTest();
		List<Vehicle__c> vehList = [SELECT Id FROM Vehicle__c];
		List<Id> vehId = new List<Id>();
		for (Vehicle__c v : vehList) { vehId.add(v.Id); }
		CustAppVehicle.vehicleUpdate(vehId);
		Test.stopTest();
		EventBusSubscriber subNew = [SELECT Name, Position, Retries, LastError FROM EventBusSubscriber WHERE Topic='Customer_App_Callback__e' AND
									Type='ApexTrigger'];
		System.assertNotEquals(subNew.Position, sub.Position);
	}

	@IsTest
	static void testAppCallback() {
		List<Customer_External_Account__c> extAcc = [SELECT Id, Account__c FROM Customer_External_Account__c];
		Set<Id> accId = new Set<Id>();
		for (Customer_External_Account__c e : extAcc) { accId.add(e.Account__c); }
		Vehicle_Ownership__c vo = [SELECT Id, Vehicle__c FROM Vehicle_Ownership__c WHERE Customer__c IN :accId LIMIT 1];
		Test.startTest();
		CustAppVehicle.createAppCallbackFromVeh(new List<Id> { vo.Vehicle__c });
		Test.stopTest();
		List<AsyncApexJob> jobInfo = [SELECT Status,NumberOfErrors FROM AsyncApexJob WHERE ApexClass.Name = 'CustAppCallbackQueue'];
		System.assert(jobInfo.size() > 0);
	}

	@IsTest
	static void testSendWebhook() {
		List<Customer_External_Account__c> extAcc = [SELECT Id, Account__c FROM Customer_External_Account__c];
		Set<Id> accId = new Set<Id>();
		for (Customer_External_Account__c e : extAcc) { accId.add(e.Account__c); }
		Vehicle_Ownership__c vo = [SELECT Id FROM Vehicle_Ownership__c WHERE Customer__c IN :accId LIMIT 1];
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Customer_App_Callback__e callback = new Customer_App_Callback__e();
		callback.Id__c = vo.Id;
		Test.startTest();
		CustAppVehicle.sendWebhook(callback);
		Test.stopTest();
		// check debug logs
	}

	@IsTest
	static void testSendWebhookWithVoRemoved() {
		List<Customer_External_Account__c> extAcc = [SELECT Id, Account__c FROM Customer_External_Account__c];
		Set<Id> accId = new Set<Id>();
		for (Customer_External_Account__c e : extAcc) { accId.add(e.Account__c); }
		Vehicle_Ownership__c vo = [SELECT Id FROM Vehicle_Ownership__c WHERE Customer__c IN :accId LIMIT 1];
		vo.End_Date__c = Date.today();
		update vo;
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Customer_App_Callback__e callback = new Customer_App_Callback__e();
		callback.Id__c = vo.Id;
		Test.startTest();
		CustAppVehicle.sendWebhook(callback);
		Test.stopTest();
		// check debug logs
	}

	@IsTest
	static void testSendWebhookRemoveVo() {
		List<Customer_External_Account__c> extAcc = [SELECT Id, Account__c FROM Customer_External_Account__c];
		Set<Id> accId = new Set<Id>();
		for (Customer_External_Account__c e : extAcc) { accId.add(e.Account__c); }
		Vehicle_Ownership__c vo = [SELECT Id, End_Date__c FROM Vehicle_Ownership__c WHERE Customer__c IN :accId LIMIT 1];
		vo.End_Date__c = Date.today();
		update vo;
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Customer_App_Callback__e callback = new Customer_App_Callback__e();
		callback.Id__c = vo.Id;
		Test.startTest();
		CustAppVehicle.sendWebhookRemoveVo(callback);
		Test.stopTest();
		// check debug logs
	}

	@IsTest
	static void testSendWarrantyWebhook() {
		Vehicle_Ownership__c vo = [SELECT Id, Vehicle__c, End_Date__c FROM Vehicle_Ownership__c LIMIT 1];
		VehicleWarranty__c vw = TestFactory.genVehWty(1, false)[0];
		vw.Vehicle__c = vo.Vehicle__c;
		insert vw;
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Customer_App_Callback__e callback = new Customer_App_Callback__e();
		callback.Id__c = vo.Id;
		Test.startTest();
		CustAppVehicle.sendWebhook(callback);
		Test.stopTest();
	}

	@IsTest
	static void testSendWebhookAltDriver() {
		List<Customer_External_Account__c> extAcc = [SELECT Id, Account__c FROM Customer_External_Account__c];
		Set<Id> accId = new Set<Id>();
		for (Customer_External_Account__c e : extAcc) { accId.add(e.Account__c); }
		Alternative_Driver__c altD = [SELECT Id FROM Alternative_Driver__c WHERE Account__c IN :accId LIMIT 1];
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Customer_App_Callback__e callback = new Customer_App_Callback__e();
		callback.Id__c = altD.Id;
		Test.startTest();
		CustAppVehicle.sendWebhook(callback);
		Test.stopTest();
		// check debug logs
	}

	// @IsTest
	// static void testLTACallbackAltD() {
	// 	Customer_External_Account__c extAcc = [SELECT Id, UUID__c, Account__c FROM Customer_External_Account__c LIMIT 1];
	// 	CustAppVehicle.LtaVehCallback req = new CustAppVehicle.LtaVehCallback();
	// 	req.payload = new CustAppVehicle.LtaVOCls();
	// 	req.payload.accountUuid = extAcc.UUID__c;
	// 	req.payload.vehicle = createVehCls('964D');
	// 	RestContext.request = new RestRequest();
	// 	RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
	// 	Test.startTest();
	// 	CustAppVehicle.processCallback();
	// 	Test.stopTest();
	// 	List<Alternative_Driver__c> altD = [SELECT Id FROM Alternative_Driver__c WHERE Account__c = :extAcc.Account__c AND
	// 										Vehicle_Ownership__r.Vehicle__r.Name = :req.payload.vehicle.vehicleDetails.chassisNo];
	// 	System.assert(altD.size() > 0);
	// }

	// @IsTest
	// static void testLTACallbackVO() {
	// 	Customer_External_Account__c extAcc = [SELECT Id, Account__c, UUID__c FROM Customer_External_Account__c LIMIT 1];
	// 	Account acc = new Account(Id = extAcc.Account__c, Doc_Type__c = 'Malaysian NRIC', NRIC_Number__c = '010203040506');
	// 	update acc;
	// 	CustAppVehicle.LtaVehCallback req = new CustAppVehicle.LtaVehCallback();
	// 	req.payload = new CustAppVehicle.LtaVOCls();
	// 	req.payload.accountUuid = extAcc.UUID__c;
	// 	req.payload.vehicle = createVehCls(acc.Partial_NRIC__c);
	// 	RestContext.request = new RestRequest();
	// 	RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
	// 	Test.startTest();
	// 	CustAppVehicle.processCallback();
	// 	Test.stopTest();
	// 	List<Vehicle_Ownership__c> vo = [SELECT Id FROM Vehicle_Ownership__c WHERE Customer__c = :extAcc.Account__c AND
	// 									Vehicle__r.Name = :req.payload.vehicle.vehicleDetails.chassisNo];
	// 	System.assert(vo.size() > 0);
	// }

	@isTest
	static void testResyncVO() {
		Vehicle_Ownership__c vo = [SELECT Id FROM Vehicle_Ownership__c LIMIT 1];
		Test.startTest();
		CustAppVehicle.pushToAbApp(vo.Id);
		Test.stopTest();
	}

	@isTest
	public static void testPushToAbApp() {
		Vehicle_Ownership__c vo = [SELECT Id FROM Vehicle_Ownership__c LIMIT 1];
		Test.startTest();
		CustAppVehicle.pushToAbApp(vo.Id);
		Test.stopTest();
	}

	@isTest
	public static void testPushToAbAppRemoveVo() {
		Vehicle_Ownership__c vo = [SELECT Id FROM Vehicle_Ownership__c LIMIT 1];
		vo.End_Date__c = Date.today();
		update vo;
		Test.startTest();
		CustAppVehicle.pushToAbApp(vo.Id);
		Test.stopTest();
	}

	@isTest
	public static void testVehAndInsClsCoverage() {
		string voQuery =	'SELECT ' + String.join(CustAppVehicle.VO_FIELDS, ',') + ' ' +
							'FROM Vehicle_Ownership__c';
		Vehicle_Ownership__c[] vos = Database.query(voQuery);
		// Vehicle_Ownership__c vo = [
		// 	SELECT
		// 		Id, Customer__c, Registration_No__c, Registration_Date__c, Vehicle__r.Name, 
		// 		Vehicle__r.IU_Number__c, Status__c, Vehicle__r.Vehicle_Make__c,
		// 		Vehicle__r.Vehicle_Make__r.Name, Vehicle__r.Vehicle_Model__r.Fuel__c,
		// 		Vehicle__r.Production_Month__c, Vehicle__r.Production_Year__c,
		// 		Vehicle__r.IsAllowIService__c
		// 	FROM Vehicle_Ownership__c LIMIT 1];
		Test.startTest();
		CustAppVehicle.VehAndInsCls veh = new CustAppVehicle.VehAndInsCls(vos[0], '028');

		vos[0].Vehicle__r.Vehicle_Make__r.Name = 'C';
		vos[0].Vehicle__r.Vehicle_Model__r.Fuel__c = 'Diesel';
		vos[0].Vehicle__r.Production_Month__c = '1';
		vos[0].Vehicle__r.Production_Year__c = '2020';
		veh = new CustAppVehicle.VehAndInsCls(vos[0], '028');

		vos[0].Vehicle__r.Vehicle_Make__r.Name = 'NFR';
		vos[0].Vehicle__r.Vehicle_Model__r.Fuel__c = 'Hybrid';
		veh = new CustAppVehicle.VehAndInsCls(vos[0], '028');

		vos[0].Vehicle__r.Vehicle_Model__r.Fuel__c = 'Electric';
		veh = new CustAppVehicle.VehAndInsCls(vos[0], '028');

		vos[0].Vehicle__r.Vehicle_Model__r.Fuel__c = 'Tatau';
		veh = new CustAppVehicle.VehAndInsCls(vos[0], '028');

		Test.stopTest();
	}


	@isTest
	public static void testVehAndInsClsCoverageUnmapped() {
		string voQuery =	'SELECT ' + String.join(CustAppVehicle.VO_FIELDS, ',') + ' ' +
							'FROM Vehicle_Ownership__c';
		Vehicle_Ownership__c[] vos = Database.query(voQuery);
		// Vehicle_Ownership__c vo = [
		// 	SELECT
		// 		Id, Customer__c, Registration_No__c, Registration_Date__c, Vehicle__r.Name, 
		// 		Vehicle__r.IU_Number__c, Status__c, Vehicle__r.Vehicle_Make__c,
		// 		Vehicle__r.Vehicle_Make__r.Name, Vehicle__r.Vehicle_Model__r.Fuel__c,
		// 		Vehicle__r.Production_Month__c, Vehicle__r.Production_Year__c,
		// 		Vehicle__r.IsAllowIService__c
		// 	FROM Vehicle_Ownership__c LIMIT 1];
		Test.startTest();
		vos[0].Vehicle__r.Vehicle_Make__r.Name = 'Nana';
		CustAppVehicle.VehAndInsCls veh;
		try {
			veh = new CustAppVehicle.VehAndInsCls(vos[0], '028');
		}
		catch (Exception e) {
			System.assertEquals(CustAppAPI.CustAppException.class.getName(), e.getTypeName());
			System.assert(e.getMessage().contains('Unmapped vehicle type'));
		}
		Test.stopTest();
	}

	@isTest
	public static void testWarrantyClsCoverage() {
		VehicleWarranty__c vw = TestFactory.genVehWty(1, true)[0];
		Test.startTest();
		CustAppVehicle.WarrantyCls wty = new CustAppVehicle.WarrantyCls();
		wty = new CustAppVehicle.WarrantyCls(vw);
		Test.stopTest();
	}

	public static CustAppVehicle.LtaVehCls createVehCls(String nric) {
		CustAppVehicle.LtaVehCls veh = new CustAppVehicle.LtaVehCls();
		veh.vehicleOwnerParticulars = new CustAppVehicle.OwnerCls();
		veh.vehicleOwnerParticulars.id = nric;
		veh.vehicleOwnerParticulars.idType = 'SINGAPORE_NRIC';
		veh.vehicleDetails = new CustAppVehicle.VehDetailsCls();
		veh.vehicleDetails.no = 'SBM8989C';
		veh.vehicleDetails.vehicleToBeExported = true;
		veh.vehicleDetails.intendedDeregistrationDate = DateTime.now();
		veh.vehicleDetails.make = 'B.M.W.';
		veh.vehicleDetails.model = 'A200 FL STYLE (R17 HLG)';
		veh.vehicleDetails.primaryColor = 'Silver';
		veh.vehicleDetails.manufacturerYear = 2017;
		veh.vehicleDetails.engineNo = '27091031410222';
		veh.vehicleDetails.chassisNo = 'WDD1760432J667557';
		veh.vehicleDetails.maximumPowerOutput = '115.0 kW  (154 bhp)';
		veh.vehicleDetails.openMarketValue = '$25,996.00';
		veh.vehicleDetails.originalRegistrationDate = DateTime.now();
		veh.vehicleDetails.firstRegistrationDate = DateTime.now();
		veh.vehicleDetails.transferCount = 0;
		veh.vehicleDetails.actualArfPaid = '$23,395.00';
		veh.vehicleDetails.vehicleType = 'P10 - Passenger Motor Car';
		veh.vehicleDetails.scheme = 'Normal';
		veh.vehicleDetails.propellant = 'Petrol';
		veh.vehicleDetails.motorNo = '-';
		veh.vehicleDetails.powerRating = '-';
		veh.vehicleDetails.maximumLadenWeight = '1920  kg';
		veh.vehicleDetails.lifespanExpiryDate = null;
		veh.vehicleDetails.roadTaxExpiryDate = DateTime.now();
		veh.vehicleDetails.inspectionDueDate = DateTime.now();
		veh.vehicleDetails.co2Emission = '126.00  (g/km)';
		veh.vehicleDetails.coEmission = '-';
		veh.vehicleDetails.noxEmission = '-';
		veh.vehicleDetails.attachment = 'No Attachment';
		veh.vehicleDetails.engineCapacity = '1595  cc';
		veh.vehicleDetails.unladenWeight = '1395  kg';
		veh.vehicleDetails.intendedTransferDate = DateTime.now();
		veh.vehicleDetails.cevVesRebateUtilisedAmount = '$5,000.00';
		veh.vehicleDetails.hcEmission = 'HC Emission :';
		veh.vehicleDetails.pmEmission = '-';
		veh.intendedParfRebateDetails = new CustAppVehicle.ParfRebateCls();
		veh.intendedParfRebateDetails.eligibility = 'Yes';
		veh.intendedParfRebateDetails.eligibilityExpireDate = DateTime.now();
		veh.intendedParfRebateDetails.rebateAmount = '$17,546.00';
		veh.intendedCoeRebateDetails = new CustAppVehicle.COERebateCls();
		veh.intendedCoeRebateDetails.expiryDate = DateTime.now();
		veh.intendedCoeRebateDetails.category = 'B - Car above 1600cc or 97kW (130bhp)';
		veh.intendedCoeRebateDetails.period = 10;
		veh.intendedCoeRebateDetails.qpPaid = '$57,414.00';
		veh.intendedCoeRebateDetails.rebateAmount = '$41,841.00';
		veh.intendedCoeRebateDetails.totalRebateAmount = '$59,387.00';
		return veh;
	}
}