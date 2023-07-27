@isTest
private class SmsTemplateHandler_Test {
	@TestSetup
	static void makeData(){
		// TestFactory.genCompany(1, true);
		TestFactory.genTriggerSettings('SMS Template', true);
		TestFactory.genCompany(1, true);
		TestFactory.genWorkshop(1, true);
		SQL_API_Base_Test.makeData();

		/** Patch data */
		Company__c c = TestFactory.getCompany('028');
		Workshop__c[] ws = [SELECT Id, Company__c FROM Workshop__c];
		for (Workshop__c w :ws) { w.Company__c = c.Id; }
		update ws;
	}

	@isTest
	static void testCreate() {
		SmsTemplate__c st = new SmsTemplate__c();
		Company__c c = [SELECT Id, Name FROM Company__c LIMIT 1];
		Workshop__c w = [SELECT Id, Name FROM Workshop__c LIMIT 1];
		string serviceType = 'Service';
		st.Company__c = c.Id; 
		st.Workshop__c = w.Id;
		st.Type__c = serviceType;
		Test.startTest();
		insert st;
		Test.stopTest();
		string expected = string.format('{0}_{1}_{2}', new string[] { c.Name, w.Name, serviceType });

		SmsTemplate__c st1 = [SELECT Id, Key__c FROM SmsTemplate__c LIMIT 1];
		string actual = st1.Key__c;
		System.assertEquals(expected, actual, 'Keys do not match.');
	}

	@isTest
	static void testUpdate() {
		SmsTemplate__c st = new SmsTemplate__c();
		Company__c c = [SELECT Id, Name FROM Company__c LIMIT 1];
		Workshop__c w = [SELECT Id, Name FROM Workshop__c LIMIT 1];
		string serviceType = 'Repair';
		st.Company__c = c.Id; 
		st.Workshop__c = w.Id;
		st.Type__c = 'Service';
		insert st;
		Test.startTest();
		st.Type__c = serviceType;
		update st;
		Test.stopTest();
		string expected = string.format('{0}_{1}_{2}', new string[] { c.Name, w.Name, serviceType });

		SmsTemplate__c st1 = [SELECT Id, Key__c FROM SmsTemplate__c LIMIT 1];
		string actual = st1.Key__c;
		System.assertEquals(expected, actual, 'Keys do not match.');
	}

}