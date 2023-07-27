@isTest private class ServiceOrderThankYouSms_Test {
	@TestSetup static void makeData() {
		M3TechApiWrapper_Test.setup();
		SQL_RO_Queue_Test.makeData();

		/** Fix everything to CheckOut = YESTERDAY */
		ServiceOrder__c[] sos = [SELECT Id, CheckOut__c, SmsRetCode__c FROM ServiceOrder__c];
		for (ServiceOrder__c so :sos) {
			so.CheckOut__c = Datetime.now().addDays(-1);
			so.SmsRetCode__c = null;
		}
		update sos;
		sos = new List<ServiceOrder__c>();

		Workshop__c[] ws = TestFactory.genWorkshop(1, true);
		for (Workshop__c w :ws) { w.Name = 'AK'; }
		update ws;

		ServiceOrder__c ro = new ServiceOrder__c();
		ro.RepairOrderNo__c = String.valueOf(54321);
		ro.WipKey__c = Datetime.now().addSeconds(6).format('yyyyMMddHHmm') + 6;
		ro.Service_Order_Date__c = Date.today();
		ro.CheckIn__c = ro.Service_Order_Date__c;
		ro.CheckOut__c = Datetime.now().addDays(-1);
		// ro.VehicleOwnership__c = vo.Id;
		// ro.Vehicle__c = vo.Vehicle__c;
		ro.RegistrationNo__c = 'ABC1234';
		// ro.Account__c = vo.Customer__c;
		ro.Workshop__c = ws[0].Id;
		ro.WorkshopCode__c = ws[0].Name;
		// ro.Company__c = cmp.Id;
		// ro.CSA__c = em.Id;
		ro.ContactAccNumber__c = 'C0000001';
		ro.ContactPhone__c = null;
		/** Keys */
		ro.roKey__c = ro.WipKey__c + ws[0].Name;
		ro.ExternalId__c = String.format('{0}_{1}_{2}_{3}', new string[] { '028', ws[0].Name, ro.RepairOrderNo__c, 'ABCDEFGHIJKLMNOPQ' });
		sos.add(ro);
		insert sos;
	}

	@isTest static void testSched() {
		Test.startTest();
		String jobId = ServiceOrderThankYouSms.scheduleJob();
		Test.stopTest();
		List<CronTrigger> ctList = [SELECT Id, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
		System.assertEquals(ctList.size(), 1);
	}

	@isTest static void batchSendSmsAK() {
		TestWSMock.M3TechAPI2_SUCC mock = new TestWSMock.M3TechAPI2_SUCC();
		Test.setMock(WebServiceMock.class, mock);
		Test.startTest();
		ServiceOrderThankYouSms job = new ServiceOrderThankYouSms();
		Database.executeBatch(job, ServiceOrderThankYouSms.scopeSize);
		Test.stopTest();
	}

	@isTest static void batchSendSmsA1() {
		ServiceOrder__c[] sos = [SELECT Id, WorkshopCode__c FROM ServiceOrder__c];
		for (ServiceOrder__c so :sos) { so.WorkshopCode__c = 'A1'; }
		update sos;
		TestWSMock.M3TechAPI2_SUCC mock = new TestWSMock.M3TechAPI2_SUCC();
		Test.setMock(WebServiceMock.class, mock);
		Test.startTest();
		ServiceOrderThankYouSms job = new ServiceOrderThankYouSms();
		Database.executeBatch(job, ServiceOrderThankYouSms.scopeSize);
		Test.stopTest();
	}

	@isTest static void batchSendSmsA1WithPhone() {
		ServiceOrder__c[] sos = [SELECT Id, WorkshopCode__c FROM ServiceOrder__c];
		for (ServiceOrder__c so :sos) {
			so.WorkshopCode__c = 'A1';
			so.ContactPhone__c = '0123456789';
		}
		update sos;
		TestWSMock.M3TechAPI2_SUCC mock = new TestWSMock.M3TechAPI2_SUCC();
		Test.setMock(WebServiceMock.class, mock);
		Test.startTest();
		ServiceOrderThankYouSms job = new ServiceOrderThankYouSms();
		Database.executeBatch(job, ServiceOrderThankYouSms.scopeSize);
		Test.stopTest();
	}
	@isTest static void batchSend_E() {
		TestWSMock.WebServiceThrowE mock = new TestWSMock.WebServiceThrowE();
		Test.setMock(WebServiceMock.class, mock);
		Test.startTest();
		ServiceOrderThankYouSms job = new ServiceOrderThankYouSms();
		Database.executeBatch(job, ServiceOrderThankYouSms.scopeSize);
		Test.stopTest();
	}

	@isTest static void schedulable_Test() {
		Test.startTest();

		/** Schedule job */
		Id id = system.schedule('Test Unit', '0 0 0 3 9 ? 2022', new ServiceOrderThankYouSms());		
		CronTrigger ct = [
			Select Id, CronExpression, TimesTriggered, NextFireTime
			From CronTrigger
			Where Id = :id
		];
		system.assertEquals(0, ct.TimesTriggered);
		system.assertEquals('2022-09-03 00:00:00', string.valueOf(ct.NextFireTime));

		Test.stopTest();
	}
}