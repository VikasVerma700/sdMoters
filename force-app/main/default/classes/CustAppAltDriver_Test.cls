@IsTest
public class CustAppAltDriver_Test {
	@TestSetup
	public static void setup() {
		// TestFactory.genTriggerSettings('Customer App Callback', true);
		TestFactory.genTriggerSettings('Vehicle', true);
		TestFactory.genCustExtAcc(1, true);
		TestFactory.genAltDriver(1, true);
	}

	@IsTest
	public static void testRemoveWebhook() {
		Alternative_Driver__c altD = [SELECT Id FROM Alternative_Driver__c LIMIT 1];
		altD.Status__c = 'Inactive';
		update altD;
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = altD.Id, Event__c = CustAppAltDriver.REM_ALT_DVR_EVT);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppAltDriver.sendWebhook(callback);
		Test.stopTest();
		// refer to debug logs if there are any errors, no return value
	}

	@IsTest
	public static void testProcessAddCallback() {
		Customer_External_Account__c extAcc = [SELECT Id, Account__c, UUID__c FROM Customer_External_Account__c LIMIT 1];
		Vehicle_Ownership__c vo = TestFactory.genVO(1, true)[0];
		Vehicle__c veh = [SELECT Id, Name FROM Vehicle__c WHERE Id = :vo.Vehicle__c];
		RestContext.request = new RestRequest();
		CustAppAltDriver.AddDriverCls vehicle = new CustAppAltDriver.AddDriverCls();
		vehicle.identificationNumber = veh.Name;
		CustAppAltDriver.AltDriverCls alternateDriver = new CustAppAltDriver.AltDriverCls();
		alternateDriver.accountUuid = extAcc.UUID__c;
		alternateDriver.relationship = 'PERSONAL_DRIVER';
		vehicle.alternateDriver = alternateDriver;
		CustAppAltDriver.AddDriverPayload payload = new CustAppAltDriver.AddDriverPayload();
		payload.vehicle = vehicle;
		CustAppAltDriver.AddDriverHook req = new CustAppAltDriver.AddDriverHook('UPSERT_VEHICLE_ALTERNATE_DRIVER', payload);
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
		Test.startTest();
		CustAppAltDriver.processAddCallback();
		Test.stopTest();
		List<Alternative_Driver__c> altDList = [SELECT Id FROM Alternative_Driver__c WHERE Account__c = :extAcc.Account__c AND Vehicle_Ownership__c = :vo.Id];
		System.assert(altDList.size() > 0);
	}

	@IsTest
	public static void testProcessRemoveCallback() {
		Customer_External_Account__c extAcc = [SELECT Id, Account__c, UUID__c, Type__c FROM Customer_External_Account__c LIMIT 1];
		Alternative_Driver__c altD = [SELECT Id, Vehicle_Ownership__r.Vehicle__r.Name FROM Alternative_Driver__c LIMIT 1];
		altD.Account__c = extAcc.Account__c;
		altD.Type__c = extAcc.Type__c;
		update altD;
		RestContext.request = new RestRequest();
		CustAppAltDriver.RemoveDriverPayload payload = new CustAppAltDriver.RemoveDriverPayload(altD, extAcc.UUID__c);
		CustAppAltDriver.RemoveDriverHook hook = new CustAppAltDriver.RemoveDriverHook('REMOVE_VEHICLE_ALTERNATE_DRIVER', payload);
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(hook));
		Test.startTest();
		CustAppAltDriver.processRemoveCallback();
		Test.stopTest();
		List<Alternative_Driver__c> altDList = [SELECT Id, Status__c FROM Alternative_Driver__c WHERE Id = :altD.Id];
		System.assert(altDList.size() > 0);
		System.assertEquals(altDList[0].Status__c, 'Removed');
	}

	@IsTest
	public static void testRetrieve() {
		List<Customer_External_Account__c> extAcc = [SELECT Id, Account__c, UUID__c, Type__c FROM Customer_External_Account__c LIMIT 1];
		Alternative_Driver__c altD = [SELECT Id, Vehicle_Ownership__c FROM Alternative_Driver__c LIMIT 1];
		altD.Account__c = extAcc[0].Account__c;
		altD.Type__c = extAcc[0].Type__c;
		update altD;
		String cmp = CustAppAccount.REV_TYPE.get(extAcc[0].Type__c);
		Test.startTest();
		Map<Id, List<CustAppAltDriver.AltDriverCls>> res = CustAppAltDriver.retrieveAltDriver(new Set<Id> { altD.Vehicle_Ownership__c }, cmp);
		Test.stopTest();
		System.assertEquals(res.size(), 1);
		System.assertEquals(res.values()[0].size(), 1);
		System.assertEquals(res.values()[0][0].accountUuid, extAcc[0].UUID__c);
	}

	@isTest
	public static void testResyncAltD() {
		Alternative_Driver__c ad = [SELECT Id, Status__c FROM Alternative_Driver__c LIMIT 1];
		Test.startTest();
		CustAppAltDriver.pushToAbApp(ad.Id);
		Test.stopTest();
	}
}