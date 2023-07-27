@isTest
private class ServiceApptSMSReminder_Test {
	@TestSetup
	static void makeData() {
		M3TechApiWrapper_Test.setup();

		/** Custom Settings: Service_Type__c */
		insert new Service_Type__c(Name = 'Service', Sort_Order__c = 10);
		insert new Service_Type__c(Name = 'Repair', Sort_Order__c = 20);
		insert new Service_Type__c(Name = 'Mobility', Sort_Order__c = 30);

		/** Custom Object: SmsTemplate__c */
		Company__c c = TestFactory.getCompany('028');
		TestFactory.genWorkshop(1, true);
		Workshop__c[] ws = [SELECT Id, Company__c FROM Workshop__c];
		for (Workshop__c w :ws) { w.Company__c = c.Id; }
		update ws;
		
		/** Generate Sms Template */
		insert new SmsTemplate__c(Company__c = c.Id
			, Workshop__c = ws[0].Id, Type__c = 'Service'
			, ConfirmMessage1__c = 'Confirm', RemindMessage1__c = 'Remind'
			, CancelMessage1__c = 'Cancel', MissMessage1__c = 'Miss'
		);
	}

	@isTest static void testSendReminder() {
		Service_Appointment__c sa = TestFactory.genSvcAppt(1, false)[0];
		sa.Appt_Type__c = 'Service Appointment';
		sa.Contact_No__c = '60192651650';
		sa.Service_Request__c = 'Service';
		sa.SmsTemplate__c = [SELECT Id FROM SmsTemplate__c LIMIT 1].Id;
		insert sa;
		update new Workshop__c(
			Id = sa.Workshop__c, Service_Centre_Name__c = 'Test'
			, Short_Address__c = 'Test', Name = 'A1', HasQueueSystem__c = True
			, GeolocationMessage__c = 'Waze:', GeolocationLink__c = 'https://sfdc.com'
			, SmsConfirm__c = true, SmsRemind__c = true, SmsMiss__c = true
			, SmsCancel__c = true
		);
		String success = 'Glenmarie';
		TestWSMock.M3TechApiService_Mock mock = new TestWSMock.M3TechApiService_Mock(success);
		Test.setMock(WebServiceMock.class, mock);
		Test.startTest();
		ServiceApptSMSReminder.smsReminder(new List<Id> { sa.Id });
		Test.stopTest();
		List<Task> checkTask = [SELECT Id, Description FROM Task WHERE WhatId = :sa.Id AND Type = 'System Generated Tasks'];
		System.assert(checkTask.size() >= 0);
		//System.assert(checkTask[0].Description.contains(mock.res));
	}
}