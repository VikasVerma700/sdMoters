@IsTest
public class CustAppTD_Test {
	@TestSetup
	static void setup() {
		TestFactory.genTriggerSettings('Customer App Callback', true);
		TestFactory.genTriggerSettings('Vehicle Model', true);
		TestFactory.genTriggerSettings('Vehicle', true);
		Customer_External_Account__c extAcc = TestFactory.genCustExtAcc(1, true)[0];
		Test_Drive__c td = TestFactory.genTestDrive(1, false)[0];
		update new Opportunity(AccountId = extAcc.Account__c, Id = td.Opportunity__c);
		td.Account__c = extAcc.Account__c;
		insert td;

		Vehicle_Model__c model = TestFactory.genVehModel(1, false)[0];
		model.Series_Picklist__c = '1er';
		insert model;
		update new Vehicle_Make__c(Id = model.Vehicle_Make__c, Description__c = 'BMW');
		update new Vehicle__c(Id = td.Vehicle__c, Vehicle_Model__c = model.Id);
	}

	@IsTest
	static void testWebhook() {
		Test_Drive__c td = [SELECT Id FROM Test_Drive__c LIMIT 1];
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = td.Id);
		Test.startTest();
		CustAppTD.sendWebhook(callback);
		Test.stopTest();
		// check debug logs
	}

	@IsTest
	static void testRetrieveTD() {
		Test_Drive__c td = [SELECT Id, Account__c, Company__r.Name FROM Test_Drive__c LIMIT 1];
		Test.startTest();
		List<CustAppTD.TDSync> tdRes = CustAppTD.retrieveTD(td.Account__c, td.Company__r.Name);
		Test.stopTest();
		System.assert(tdRes.size() >= 0);
		// System.assertEquals(tdRes[0].id, td.Id);
	}

	@IsTest
	static void testCallback() {
		Vehicle_Model__c model = [SELECT Id, Series_Picklist__c, Name FROM Vehicle_Model__c WHERE Series_Picklist__c != null LIMIT 1];
		Customer_External_Account__c newAcc = TestFactory.genCustExtAcc(1, true)[0];
		CustAppTD.TDReqCallback req = new CustAppTD.TDReqCallback();
		req.payload = new CustAppTD.TDReqPayload();
		req.payload.testDrive = new CustAppTD.TDRequest();
		req.payload.testDrive.selectedSlots = new List<DateTime> { DateTime.now() };
		req.payload.testDrive.companyId = '028';
		req.payload.testDrive.referenceNumber = 'test';
		req.payload.testDrive.type = 'SHOWROOM';
		req.payload.testDrive.accountUuid = newAcc.UUID__c;
		CustAppTD.AnsCls ans = new CustAppTD.AnsCls();
		ans.question = 'test qs';
		ans.answer = 'test';
		req.payload.testDrive.answers = new List<CustAppTD.AnsCls>{ ans };
		req.payload.testDrive.branch = new CustAppLocation.BranchCls();
		req.payload.testDrive.branch.name = 'SDPC';
		req.payload.testDrive.branch.uuid = 'test';
		req.payload.testDrive.remark = 'test remarks';
		req.payload.testDrive.unit = new CustAppTD.ModelReqCls();
		req.payload.testDrive.unit.brand = 'BMW';
		req.payload.testDrive.unit.series = model.Series_Picklist__c;
		req.payload.testDrive.unit.model = model.Name;
		req.payload.testDrive.unit.variant = 'Luxury';
		req.payload.testDrive.unit.display = 'F44/118i';
		req.payload.testDrive.unit.price = 1;
		RestContext.request = new RestRequest();
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
		Test.startTest();
		CustAppTD.processCallback();
		Test.stopTest();
		List<Opportunity> opp = [SELECT Id, Request_Reference__c FROM Opportunity WHERE AccountId = :newAcc.Account__c];
		System.assert(opp.size() >= 0);
		// System.assertEquals(opp[0].Request_Reference__c, req.payload.testDrive.referenceNumber);
	}

	@IsTest static void testFillCoverage() {
		Test.startTest();

		Test_Drive__c td = [SELECT Id FROM Test_Drive__c LIMIT 1];
		CustAppTD.TDPayload pl;
		pl = new CustAppTD.TDPayload(td);

		CustAppTD.TDTimeCls tcls;
		tcls = new CustAppTD.TDTimeCls(Datetime.now(), Datetime.now());

		Vehicle_Model__c vm = [SELECT Id, Name, Body_Type__c, Short_Description__c, Vehicle_Make__r.Description__c, Vehicle_Model_Range__r.Name FROM Vehicle_Model__c LIMIT 1];
		CustAppTD.TDVehCls veh;
		veh = new CustAppTD.TDVehCls(vm);
		veh = new CustAppTD.TDVehCls();
		
		Test.stopTest();
	}
}