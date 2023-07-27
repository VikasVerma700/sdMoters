@isTest
private class ServiceAppointmentHandler_Test {
	@TestSetup
	static void setup() {
		Company__c c = TestFactory.getCompany('028');
		TestFactory.genWorkshop(1, true);
		SQL_API_Base_Test.makeData();

		/** Patch data */
		// Company__c c = TestFactory.getCompany('028');
		Workshop__c[] ws = [SELECT Id, Company__c FROM Workshop__c];
		for (Workshop__c w :ws) { w.Company__c = c.Id; }
		update ws;
		
		/** Generate Sms Template */
		SmsTemplate__c st = new SmsTemplate__c();
		st.Company__c = c.Id;
		st.Workshop__c = ws[0].Id;
		st.Type__c = 'Service';
		insert st;
	}

	@isTest
	static void testDeleteUtil() {
		// TestFactory.genTriggerSettings('Service Appointment', true);
		Service_Appointment__c srvc = TestFactory.genSvcAppt(1, true)[0];

		List<Service_Quota__c> quotaList = TestFactory.genServiceQuota(2, true);
		List<Appointment_Utilization__c> utilList = new List<Appointment_Utilization__c>();
		for (Service_Quota__c q : quotaList) { utilList.add(new Appointment_Utilization__c(Service_Appointment__c = srvc.Id, Service_Quota__c = q.Id)); }
		insert utilList;
		// TriggerHelper.bTriggerRun = null;
		// Test.setMock(HttpCalloutMock.class, new TestWSMock.QrServer());
		Test.startTest();
		update (new Service_Appointment__c(Id = srvc.Id, Apppointment_Status__c = 'CANCELLED'));
		Test.stopTest();
		List<Id> checkIds = new List<Id>();
		for (Appointment_Utilization__c u : utilList) { checkIds.add(u.Id); }
		List<Appointment_Utilization__c> checkList = [SELECT Id, IsDeleted FROM Appointment_Utilization__c WHERE Id = :checkIds AND IsDeleted = TRUE ALL ROWS];
		// System.assert(checkList.size() > 0);
		System.assertEquals(0, checkList.size());
	}

	@isTest
	static void testQrAttach() {
		TestFactory.genTriggerSettings('Service Appointment', true);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.QrServer());
		Test.startTest();
		Service_Appointment__c srvc = TestFactory.genSvcAppt(1, true)[0];
		// update (new Service_Appointment__c(Id = srvc.Id, Apppointment_Status__c = 'CANCELLED'));
		Test.stopTest();
		Attachment[] atts = [SELECT Id FROM Attachment WHERE ParentId = :srvc.Id];
		System.assertEquals(1, atts.size());
	}
	@isTest
	static void testQrRemove() {
		Service_Appointment__c srvc = TestFactory.genSvcAppt(1, true)[0];
		TestFactory.genTriggerSettings('Service Appointment', true);
		Test.startTest();
		update (new Service_Appointment__c(Id = srvc.Id, Apppointment_Status__c = 'CANCELLED'));
		Test.stopTest();
		Attachment[] atts = [SELECT Id FROM Attachment WHERE ParentId = :srvc.Id];
		System.assertEquals(0, atts.size());
	}

	@isTest
	static void testRescheduleMobility() {
		Service_Appointment__c[] sas = TestFactory.genSvcAppt(2, true);
		for (Service_Appointment__c sa :sas) { sa.Service_Request__c = 'Mobility'; }
		update sas;
		TestFactory.genTriggerSettings('Service Appointment', true);
		
		TestWSMock.M3TechAPI2_SUCC mock = new TestWSMock.M3TechAPI2_SUCC();
		Test.setMock(WebServiceMock.class, mock);
		Test.startTest();
		Service_Appointment__c sa = sas[0];
		sa.Appointment_Date__c = Datetime.now().addDays(1);
		update sa;
		Test.stopTest();
	}

}