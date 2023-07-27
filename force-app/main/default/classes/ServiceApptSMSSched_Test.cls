@isTest
private class ServiceApptSMSSched_Test {

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
			, RemindDayPrior__c = 1
		);
 	}

 	@isTest static void testSched() {
		Test.startTest();
		String jobId = ServiceApptSMSSched.scheduleJob();
		Test.stopTest();
		List<CronTrigger> ctList = [SELECT Id, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
		System.assertEquals(ctList.size(), 1);
	}

	@isTest static void testBatchReminder() {
		Service_Appointment__c sa = TestFactory.genSvcAppt(1, false)[0];
		sa.Appointment_Date__c = DateTime.newInstance(Date.today().addDays(1), sa.Appointment_Date__c.time());
		sa.Apppointment_Status__c = 'ACTIVE';
		sa.Service_Request__c = 'Service';
		sa.SmsTemplate__c = [SELECT Id FROM SmsTemplate__c LIMIT 1].Id;
		insert sa;
		Test.startTest();
		ServiceApptSMSSched sms = new ServiceApptSMSSched();
		Id batchId = Database.executeBatch(sms, 1);
		Test.stopTest();

		List<AsyncApexJob> job = [SELECT Id, Status FROM AsyncApexJob WHERE Id = :batchId];
		System.assertEquals(job.size(), 1);
		System.assertEquals(job[0].Status, 'Completed');
	}

	@isTest static void testBatchMissed() {
		Service_Appointment__c sa = TestFactory.genSvcAppt(1, false)[0];
		sa.Appointment_Date__c = DateTime.newInstance(Date.today().addDays(-1), sa.Appointment_Date__c.time());
		sa.Apppointment_Status__c = 'NO SHOW';
		sa.Service_Request__c = 'Service';
		sa.SmsTemplate__c = [SELECT Id FROM SmsTemplate__c LIMIT 1].Id;
		insert sa;
		Test.startTest();
		ServiceApptSMSSched sms = new ServiceApptSMSSched();
		Id batchId = Database.executeBatch(sms, 1);
		Test.stopTest();

		List<AsyncApexJob> job = [SELECT Id, Status FROM AsyncApexJob WHERE Id = :batchId];
		System.assertEquals(job.size(), 1);
		System.assertEquals(job[0].Status, 'Completed');
	}
}