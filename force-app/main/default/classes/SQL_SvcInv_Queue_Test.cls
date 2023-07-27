@isTest
public with sharing class SQL_SvcInv_Queue_Test {

	@TestSetup
	public static void makeData(){
		System.debug('SQL_RO_Queue_Test.makeData()');
		SQL_RO_Queue_Test.makeData();
		Company__c co = [SELECT Id, Name FROM Company__c LIMIT 1];
		Workshop__c ws = [SELECT Id, Name, Company__c FROM Workshop__c LIMIT 1];
		ws.Company__c = co.Id;
		update ws;
		TestFactory.genRepairOrder(4, true);
		// TestFactory.genServiceInvoice(1, true);
	}

	@isTest static void testPull() {
		ServiceOrder__c[] sos = [
			SELECT
				Id, Name, Company__r.Name, RoKey__c, ExternalId__c
				, Workshop__r.Name, RepairOrderNo__c, WipKey__c
				, CheckIn__c, CheckOut__c, StatusNumber__c, Status__c
				, LastModifiedDate, Account__r.Customer_Number__c
				, Account__r.NRIC_Number__c, ContactAccNumber__c
				, ContactName__c
				, ChassisNo__c, VehicleOwnership__r.Registration_No__c
				, VehicleOwnership__r.Vehicle__r.Name
				, Mileage__c
			FROM ServiceOrder__c
		];
		SQL_SvcInv_Queue.ServiceInvoiceRes[] res = new SQL_SvcInv_Queue.ServiceInvoiceRes[]{};
		for (ServiceOrder__c so :sos) {
			SQL_SvcInv_Queue.ServiceInvoiceRes sio = new SQL_SvcInv_Queue.ServiceInvoiceRes();
			sio.companyCode = so.Company__r.Name;
			sio.branchCode = so.Workshop__r.Name;
			sio.accountNo = so.ContactAccNumber__c;
			sio.chassisNo = so.VehicleOwnership__r.Vehicle__r.Name;
			sio.wipNo = so.RepairOrderNo__c;
			sio.serviceDetails = 'Test service invoice';
			sio.invoiceNo = sio.wipNo;
			sio.invoiceDate = Datetime.now().date();
			sio.invoiceValue = 123.45;
			sio.roKey = so.RoKey__c;
			sio.invKey = sio.invoiceNo + sio.branchCode;
			sio.externalId = String.format('{0}_{1}_{2}', new string[] { sio.companyCode, sio.branchCode, sio.invoiceNo });
			res.add(sio);
		}
		SQL_SvcInv_Queue job = new SQL_SvcInv_Queue();
		job.upsertSi(res);

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		System.enqueueJob(job);
		Test.stopTest();
	}
	
	@isTest static void testPullNoRow() {
		SQL_SvcInv_Queue.ServiceInvoiceRes[] res = new SQL_SvcInv_Queue.ServiceInvoiceRes[]{};
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_SvcInv_Queue job = new SQL_SvcInv_Queue();
		job.followOnToFile = true;
		System.enqueueJob(job);
		job.dateFrom = job.dateTo = null;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPullStatusNotOK() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SQL_SvcInv_Queue job = new SQL_SvcInv_Queue();
        job.followOnToFile = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPull_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SQL_SvcInv_Queue job = new SQL_SvcInv_Queue();
		job.followOnToFile = true;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPull_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_SvcInv_Queue job = new SQL_SvcInv_Queue();
		job.followOnToFile = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPull_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_SvcInv_Queue job = new SQL_SvcInv_Queue();
		job.followOnToFile = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testRefreshSi() {
		ServiceOrder__c[] sos = [
			SELECT
				Id, Name, Company__r.Name, RoKey__c, ExternalId__c
				, Workshop__r.Name, RepairOrderNo__c, WipKey__c
				, CheckIn__c, CheckOut__c, StatusNumber__c, Status__c
				, LastModifiedDate, Account__r.Customer_Number__c
				, Account__r.NRIC_Number__c, ContactAccNumber__c
				, ContactName__c
				, ChassisNo__c, VehicleOwnership__r.Registration_No__c
				, VehicleOwnership__r.Vehicle__r.Name
				, Mileage__c
			FROM ServiceOrder__c
		];
		SQL_SvcInv_Queue.ServiceInvoiceRes[] res = new SQL_SvcInv_Queue.ServiceInvoiceRes[]{};
		for (ServiceOrder__c so :sos) {
			SQL_SvcInv_Queue.ServiceInvoiceRes sio = new SQL_SvcInv_Queue.ServiceInvoiceRes();
			sio.companyCode = so.Company__r.Name;
			sio.branchCode = so.Workshop__r.Name;
			sio.accountNo = so.ContactAccNumber__c;
			sio.chassisNo = so.VehicleOwnership__r.Vehicle__r.Name;
			sio.wipNo = so.RepairOrderNo__c;
			sio.serviceDetails = 'Test service invoice';
			sio.invoiceNo = sio.wipNo;
			sio.invoiceDate = Datetime.now().date();
			sio.invoiceValue = 123.45;
			sio.roKey = so.RoKey__c;
			sio.invKey = sio.invoiceNo + sio.branchCode;
			sio.externalId = String.format('{0}_{1}_{2}', new string[] { sio.companyCode, sio.branchCode, sio.invoiceNo });
			res.add(sio);
		}
		SQL_SvcInv_Queue q = new SQL_SvcInv_Queue();
		q.upsertSi(res);
		ServiceInvoice__c si = [SELECT Id FROM ServiceInvoice__c LIMIT 1];

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		string ret = SQL_SvcInv_Queue.refreshSi(si.Id);
		Test.stopTest();
		System.assert(!ret.containsIgnoreCase('Error'));
	}
}