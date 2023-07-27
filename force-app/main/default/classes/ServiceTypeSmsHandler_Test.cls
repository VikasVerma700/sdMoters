@isTest
private class ServiceTypeSmsHandler_Test {
	@TestSetup
	static void setup(){
		// TestFactory.genCompany(1, true);
		TestFactory.genTriggerSettings('Service Type SMS', true);
		TestFactory.getCompany('028');
		SQL_API_Base_Test.makeData();
	}
	
	@isTest
	static void testCreate() {
		ServiceTypeSms__c sts = new ServiceTypeSms__c();
		sts.Name = 'Service';
		sts.Company__c = [SELECT Id, Name FROM Company__c LIMIT 1].Id;
		Test.startTest();
		insert sts;
		Test.stopTest();
		ServiceTypeSms__c[] stses = [SELECT Id FROM ServiceTypeSms__c];
		System.assert(stses.size() > 0);
	}

	@isTest
	static void testUpdate() {
		ServiceTypeSms__c sts = new ServiceTypeSms__c();
		sts.Name = 'Service';
		sts.Company__c = [SELECT Id, Name FROM Company__c LIMIT 1].Id;
		insert sts;
		Test.startTest();
		sts.Name = 'Repair';
		update sts;
		Test.stopTest();
		ServiceTypeSms__c[] stses = [SELECT Id, Name FROM ServiceTypeSms__c];
		System.assert(stses[0].Name == 'Repair');
	}

}