@isTest
public class SQL_Appt_Queue_Test {

	@TestSetup
	public static void makeData() {
		SQL_VO_Queue_Test.makeData();

		TestFactory.genWorkshop(1, true);
		TestFactory.genEmpMaster(1, true);

		SQL_VO_Queue.CareVehOwnRes[] vows = SQL_VO_Queue_Test.createObj();
		SQL_VO_Queue s = new SQL_VO_Queue();
		s.upsertVO(vows);
		s.upsertVO(vows);

		TestFactory.genSvcAppt(4, true);
		/** Patch Service Appoinments */
		Company__c[] cs = [SELECT Id FROM Company__c];
		Workshop__c[] ws = [SELECT Id, Company__c FROM Workshop__c];
		for (Workshop__c w :ws) { w.Company__c = cs[0].Id; }
		Service_Appointment__c[] sas = [SELECT Id, Name, Workshop__c, Company__c FROM Service_Appointment__c];
		for (Service_Appointment__c sa :sas) {
			sa.Company__c = cs[0].Id;
			sa.Workshop__c = ws[0].Id;
		}
		update sas;
	}

	@isTest static void testPush() {
		Service_Appointment__c[] sas = [SELECT Id, Name FROM Service_Appointment__c];
		SQL_Appt_Queue.CareApptSetRes res = new SQL_Appt_Queue.CareApptSetRes();
		res.success = new Map<string, string>();
		res.failure = new Map<string, string>();
		for (Integer i = 0; i < sas.size(); i++) {
			if (Math.mod(i, 2) == 1) {
				res.success.put(sas[i].Id, sas[i].Name);
			}
			else {
				res.failure.put(sas[i].Id, sas[i].Name);
			}
		}
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Appt_Queue job = new SQL_Appt_Queue();
		job.followOnToPull = false;
		Database.executeBatch(job, 10);
		Test.stopTest();
	}
	@isTest static void testPushApp_Rows() {
		Service_Appointment__c[] sas = [SELECT Id, Name FROM Service_Appointment__c];
		// Set<Id> saIds = new Set<Id>();
		Id[] saIds = new Id[]{};
		
		SQL_Appt_Queue.CareApptSetRes res = new SQL_Appt_Queue.CareApptSetRes();
		res.success = new Map<string, string>();
		res.failure = new Map<string, string>();
		for (Integer i = 0; i < sas.size(); i++) {
			if (Math.mod(i, 2) == 1) {
				res.success.put(sas[i].Id, sas[i].Name);
			}
			else {
				res.failure.put(sas[i].Id, sas[i].Name);
			}
			saIds.add(sas[i].Id);
		}
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Appt_Queue job = new SQL_Appt_Queue();
		job.salesforceId = saIds;
		job.followOnToPull = false;
		Database.executeBatch(job, 10);
		Test.stopTest();
	}

	@isTest static void testPushStatusNotOK() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
		SQL_Appt_Queue job = new SQL_Appt_Queue();
        job.followOnToPull = true;
		Database.executeBatch(job, 10);
        Test.stopTest();
	}

	@isTest static void testPush_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SQL_Appt_Queue job = new SQL_Appt_Queue();
		job.followOnToPull = true;
		Database.executeBatch(job, 10);
		Test.stopTest();
	}
	@isTest static void testPush_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_Appt_Queue job = new SQL_Appt_Queue();
		job.followOnToPull = true;
		Database.executeBatch(job, 10);
		Test.stopTest();
	}

	@isTest static void testPull() {
		Service_Appointment__c[] sas = [
			SELECT
				Company__r.Name, Workshop__r.Name, Employee_Master__r.Name
				, Employee_Master__r.Employee_Reference__c
				, Employee_Master__r.Employee_Number__c, Employee_Master__c
				, Vehicle_Ownership__r.VehicleOwnershipNumber__c
				, Vehicle_Ownership__r.Customer__c, Vehicle_Ownership__r.Registration_No__c
				, Vehicle_Ownership__r.Vehicle__r.Name, Chassis__r.Vehicle_Number__c
				, Vehicle_Make__c, Account__r.Customer_Number__c, Contact_Name__c
				, Contact_No__c, Email_Address_Notification__c, Id
				, Appointment_Date__c, Created_From__c, Service_Request__c
				, Customer_Comment__c, Apppointment_Status__c, Remarks__c
				, CreatedDate, CreatedBy.Name
			FROM Service_Appointment__c
		];
		SQL_Appt_Queue.CareApptRes[] res = new SQL_Appt_Queue.CareApptRes[]{};
		for (Integer i = 0; i < sas.size(); i++) {
			if (i == 0) { sas[i].Apppointment_Status__c = 'CONVERTED TO RO'; }
			if (i == 1) { sas[i].Apppointment_Status__c = 'NO SHOW'; }
			if (i == 2) { sas[i].Apppointment_Status__c = 'ARRIVED'; }
			SQL_Appt_Queue.CareApptRes ao = new SQL_Appt_Queue.CareApptRes();
			SQL_Appt_Queue q = new SQL_Appt_Queue();
			q.setValues(sas[i], ao);
			res.add(ao);
		}

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Appt_Queue job = new SQL_Appt_Queue();
		job.followOnToRO = true;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPullNoRow() {
		SQL_Appt_Queue.CareApptRes[] res = new SQL_Appt_Queue.CareApptRes[]{};

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Appt_Queue job = new SQL_Appt_Queue();
		job.followOnToRO = true;
		System.enqueueJob(job);
		job.dateFrom = job.dateTo = null;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPullStatusNotOK() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
		SQL_Appt_Queue job = new SQL_Appt_Queue();
        job.followOnToRO = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPull_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SQL_Appt_Queue job = new SQL_Appt_Queue();
		job.followOnToRO = true;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPull_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_Appt_Queue job = new SQL_Appt_Queue();
		job.followOnToRO = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void pullAppt_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_Appt_Queue job = new SQL_Appt_Queue();
		job.followOnToRO = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPushToCareRetSuccess() {
		Service_Appointment__c sa = [SELECT Id, Name FROM Service_Appointment__c LIMIT 1];
		SQL_Appt_Queue.CareApptSetRes res = new SQL_Appt_Queue.CareApptSetRes();
		res.success = new Map<string, string>();
		res.failure = new Map<string, string>();
		res.success.put(sa.Id, sa.Name);

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Appt_Queue.pushToCare(sa.Id);
		Test.stopTest();
	}


	@isTest static void testPushToCareRetFailure() {
		Service_Appointment__c sa = [SELECT Id, Name FROM Service_Appointment__c LIMIT 1];
		SQL_Appt_Queue.CareApptSetRes res = new SQL_Appt_Queue.CareApptSetRes();
		res.success = new Map<string, string>();
		res.failure = new Map<string, string>();
		res.failure.put(sa.Id, sa.Name);

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Appt_Queue.pushToCare(sa.Id);
		Test.stopTest();
	}

}