@isTest
public with sharing class SQL_Payment_Queue_Test {
	
	@TestSetup
	static void makeData(){
		System.debug('SQL_Payment_Queue_Test.makeData()');
        SQL_API_Base_Test.makeData();
		PaymentDetail__c pd = TestFactory.genPaymentDetail(1, true)[0];
	}

	@isTest static void testPull() {
		PaymentDetail__c[] pds = [
			SELECT
				Id, Name, Company__r.Name, Workshop__r.Name, Account__r.Name
				, Amount__c, AmountVat__c, OrderNumber__c, PaymentMethod__c, SequenceNumber__c
				, HashValue1__c, HashValue2__c, RespTime__c, BankRefNumber__c
				, PayForServiceInvoice__r.Name, PayForServiceInvoice__r.InvoiceKey__c
				, PayForServiceInvoice__r.AccountNumber__c, PayForServiceInvoice__r.InvoiceNumber__c
				, PayForServiceInvoice__r.InvoiceValue__c, PayForServiceInvoice__r.InvoiceDate__c
				, PayForServiceInvoice__r.RoKey__c
			FROM PaymentDetail__c
		];
		SQL_Payment_Queue.PaymentRes[] res = new SQL_Payment_Queue.PaymentRes[]{};
		for (PaymentDetail__c pd :pds) {
			SQL_Payment_Queue.PaymentRes po = new SQL_Payment_Queue.PaymentRes();
			po.accountNo = pd.PayForServiceInvoice__r.AccountNumber__c;
			po.bankAccount = Long.valueOf(pd.BankRefNumber__c);
			po.branchCode = pd.Workshop__r.Name;
			po.companyCode = pd.Company__r.Name;
			po.invNo = Integer.valueOf(pd.PayForServiceInvoice__r.InvoiceNumber__c);
			po.seq = Integer.valueOf(pd.SequenceNumber__c);
			po.invKey = pd.PayForServiceInvoice__r.InvoiceKey__c;
			po.roKey = pd.PayForServiceInvoice__r.RoKey__c;
			po.matchNumber = Long.valueOf(pd.HashValue2__c);
			po.paymentDate = (pd.RespTime__c != null) ? Date.valueOf(pd.RespTime__c) : null;
			po.paymentInvoiceStatus = 'X';
			po.paymentPostStatus = 'X';
			po.paymentType = pd.PaymentMethod__c;
			po.paymentValue = pd.PayForServiceInvoice__r.InvoiceValue__c;
			po.paymentVatCode = null;
			po.paymentVatValue = pd.AmountVat__c;
			po.referenceName = pd.OrderNumber__c;
			po.referenceNumber = Long.valueOf(pd.HashValue1__c);
			po.wipNo = null;
			po.paymentKey = po.invKey + po.seq;
			po.externalId = po.companyCode + '_' + po.branchCode + '_' + po.invNo + '_' + po.seq;
			res.add(po);
			/** 0 value seq = 2 */
			SQL_Payment_Queue.PaymentRes po1 = po.clone();
			po1.paymentValue = 0;
			po1.seq += 1;
			po1.paymentKey = pd.PayForServiceInvoice__r.InvoiceKey__c + po1.seq;
			po1.externalId = po1.companyCode + '_' + po1.branchCode + '_' + po1.invNo + '_' + po1.seq;
			res.add(po1);
			/** Invoice not found record skipping */
			SQL_Payment_Queue.PaymentRes po2 = po.clone();
			po2.invKey += '_';
			po2.paymentKey = po2.invKey + po2.seq;
			po2.externalId = po2.companyCode + '_' + po2.branchCode + '_' + po2.invNo + '_' + po2.seq;
			res.add(po2);			
		}

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SQL_Payment_Queue job = new SQL_Payment_Queue();
        job.followOnToNext = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPullByBatch() {
		ServiceInvoice__c[] sis = [SELECT Id FROM ServiceInvoice__c];
		for (ServiceInvoice__c si :sis) {
			si.PaymentStatus__c = 'PENDING';
		}
		Database.update(sis);

		PaymentDetail__c[] pds = [
			SELECT
				Id, Name, Company__r.Name, Workshop__r.Name, Account__r.Name
				, Amount__c, AmountVat__c, OrderNumber__c, PaymentMethod__c, SequenceNumber__c
				, HashValue1__c, HashValue2__c, RespTime__c, BankRefNumber__c
				, PayForServiceInvoice__r.Name, PayForServiceInvoice__r.InvoiceKey__c
				, PayForServiceInvoice__r.AccountNumber__c, PayForServiceInvoice__r.InvoiceNumber__c
				, PayForServiceInvoice__r.InvoiceValue__c, PayForServiceInvoice__r.InvoiceDate__c
				, PayForServiceInvoice__r.RoKey__c
			FROM PaymentDetail__c
		];
		SQL_Payment_Queue.PaymentRes[] res = new SQL_Payment_Queue.PaymentRes[]{};
		for (PaymentDetail__c pd :pds) {
			SQL_Payment_Queue.PaymentRes po = new SQL_Payment_Queue.PaymentRes();
			po.accountNo = pd.PayForServiceInvoice__r.AccountNumber__c;
			po.bankAccount = Long.valueOf(pd.BankRefNumber__c);
			po.branchCode = pd.Workshop__r.Name;
			po.companyCode = pd.Company__r.Name;
			po.invNo = Integer.valueOf(pd.PayForServiceInvoice__r.InvoiceNumber__c);
			po.seq = Integer.valueOf(pd.SequenceNumber__c);
			po.invKey = pd.PayForServiceInvoice__r.InvoiceKey__c;
			po.roKey = pd.PayForServiceInvoice__r.RoKey__c;
			po.matchNumber = Long.valueOf(pd.HashValue2__c);
			po.paymentDate = (pd.RespTime__c != null) ? Date.valueOf(pd.RespTime__c) : null;
			po.paymentInvoiceStatus = 'X';
			po.paymentPostStatus = 'X';
			po.paymentType = pd.PaymentMethod__c;
			po.paymentValue = pd.PayForServiceInvoice__r.InvoiceValue__c;
			po.paymentVatCode = null;
			po.paymentVatValue = pd.AmountVat__c;
			po.referenceName = pd.OrderNumber__c;
			po.referenceNumber = Long.valueOf(pd.HashValue1__c);
			po.wipNo = null;
			po.paymentKey = po.invKey + po.seq;
			po.externalId = po.companyCode + '_' + po.branchCode + '_' + po.invNo + '_' + po.seq;
			res.add(po);
			/** 0 value seq = 2 */
			SQL_Payment_Queue.PaymentRes po1 = po.clone();
			po1.paymentValue = 0;
			po1.seq += 1;
			po1.paymentKey = pd.PayForServiceInvoice__r.InvoiceKey__c + po1.seq;
			po1.externalId = po1.companyCode + '_' + po1.branchCode + '_' + po1.invNo + '_' + po1.seq;
			res.add(po1);
			/** Invoice not found record skipping */
			SQL_Payment_Queue.PaymentRes po2 = po.clone();
			po2.invKey += '_';
			po2.paymentKey = po2.invKey + po2.seq;
			po2.externalId = po2.companyCode + '_' + po2.branchCode + '_' + po2.invNo + '_' + po2.seq;
			res.add(po2);			
		}

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SQL_Payment_Queue job = new SQL_Payment_Queue();
        job.followOnToNext = true;
		job.sendCompletionEmail = true;
		Database.executeBatch(job, 10);
        Test.stopTest();
	}
	@isTest static void testPullNoRow() {
		SQL_Payment_Queue.PaymentRes[] res = new SQL_Payment_Queue.PaymentRes[]{};

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SQL_Payment_Queue job = new SQL_Payment_Queue();
        job.followOnToNext = true;
		job.followOnToBatch = true;
        System.enqueueJob(job);
		job.dateFrom = job.dateTo = null;
		job.sendCompletionEmail = true;
        System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPullStatusNotOK() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SQL_Payment_Queue job = new SQL_Payment_Queue();
        job.followOnToNext = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPull_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SQL_Payment_Queue job = new SQL_Payment_Queue();
		job.followOnToNext = true;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPullByBatch_E() {
		ServiceInvoice__c[] sis = [SELECT Id FROM ServiceInvoice__c];
		for (ServiceInvoice__c si :sis) {
			si.PaymentStatus__c = 'PENDING';
		}
		Database.update(sis);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SQL_Payment_Queue job = new SQL_Payment_Queue();
		job.followOnToNext = true;
		Database.executeBatch(job, 10);
		Test.stopTest();
	}

	@isTest static void testPull_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_Payment_Queue job = new SQL_Payment_Queue();
		job.followOnToNext = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPull_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_Payment_Queue job = new SQL_Payment_Queue();
		job.followOnToNext = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
}