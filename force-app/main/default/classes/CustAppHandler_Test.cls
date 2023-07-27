@isTest
private class CustAppHandler_Test {
	@TestSetup
	static void setup() {
		TestFactory.genTriggerSettings('Customer App Callback', true);
		TestFactory.genCustExtAcc(2, true);
		Global_Trigger_Settings__c cacTrig = TestFactory.genTriggerSettings('Customer App Callback', true);
	}
	
	@isTest
	static void testAfterInsert() {
		Customer_External_Account__c cea = [SELECT Id FROM Customer_External_Account__c LIMIT 1];
		Test.startTest();
		Customer_App_Callback__e caa = new Customer_App_Callback__e(Id__c = cea.Id);
		Test.stopTest();
	}
}