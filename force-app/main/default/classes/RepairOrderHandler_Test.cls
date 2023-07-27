@isTest
private class RepairOrderHandler_Test {
	@TestSetup
	public static void setup() {
		TestFactory.genTriggerSettings('Repair Order', true);
	}

	@isTest static void testAfterInsert() {
		Test.startTest();
		ServiceOrder__c ro = TestFactory.genServiceOrder(1, true)[0];
		Test.stopTest();
	}

	@isTest static void testAfterUpdate() {
		Test.startTest();
		ServiceOrder__c ro = TestFactory.genServiceOrder(1, true)[0];
		ro.ACP_Service_Started__c = false;
		ro.ACP_Service_Completed__c = false;
		ro.ACP_Ready_for_Collection__c = false;
		ro.Status__c = 'Memo';
		update ro;
		Test.stopTest();
	}
}