@isTest
private class AttachmentHandler_Test {

	@TestSetup
	static void makeData(){
		TestFactory.genTriggerSettings('Attachment', true);
		Workshop__c ws = TestFactory.genWorkshop(1, false)[0];
		ws.InAppPayment__c = true;
		insert ws;
		ServiceOrder__c so = TestFactory.genServiceOrder(1, false)[0];
		so.Workshop__c = ws.Id;
		insert so;
		ServiceInvoice__c si = TestFactory.genServiceInvoice(1, false)[0];
		si.Workshop__c = ws.Id;
		si.RepairOrder__c = so.Id;
		si.AccountNumber__c = 'C0000002';
		si.ServiceDetails__c = 'A1/Front Brake Pad/Disc';
		insert si;
	}

	@isTest
	static void testCreate() {
		ServiceInvoice__c si = [SELECT Id, Name, Workshop__r.InAppPayment__c, InvoiceReady__c, AccountNumber__c, PaymentRequired__c FROM ServiceInvoice__c LIMIT 1];
		Id siId = si.Id;
		System.debug('testCreate().Sinv1: ' + JSON.serialize(si));
		Test.startTest();
		Attachment att = TestFactory.genAttachment(1)[0];
		att.ParentId = si.Id;
		att.Name = 'Service Invoice ' + si.Name;
		insert att;
		System.debug('testCreate().Att: ' + JSON.serialize([SELECT Id, Name FROM Attachment]));
		Test.stopTest();
		si = [SELECT Id, Name, Workshop__r.InAppPayment__c, InvoiceReady__c, AccountNumber__c, PaymentRequired__c, PaymentRequired2__c FROM ServiceInvoice__c WHERE Id = :siId];
		System.debug('testCreate().Sinv2: ' + JSON.serialize(si));
		System.assertEquals(true, si.PaymentRequired__c);
	}

	@isTest
	static void testUpdate() {
		ServiceInvoice__c si = [SELECT Id, Name, Workshop__r.InAppPayment__c, InvoiceReady__c, AccountNumber__c, PaymentRequired__c, PaymentRequired2__c FROM ServiceInvoice__c LIMIT 1];
		Id siId = si.Id;
		System.debug('testUpdate().Sinv1: ' + JSON.serialize(si));
		Attachment att = TestFactory.genAttachment(1)[0];
		att.ParentId = si.Id;
		att.Name = 'Service Invoic1 ' + si.Name;
		insert att;
		System.debug('testUpdate().Att: ' + JSON.serialize([SELECT Id, Name FROM Attachment]));
		Test.startTest();
		att = [SELECT Id, Name FROM Attachment LIMIT 1];
		att.Name = 'Service Invoice ' + si.Name;
		update att;
		Test.stopTest();
		si = [SELECT Id, Name, Workshop__r.InAppPayment__c, InvoiceReady__c, AccountNumber__c, PaymentRequired__c, PaymentRequired2__c FROM ServiceInvoice__c WHERE Id = :siId];
		System.debug('testUpdate().Sinv2: ' + JSON.serialize(si));
		System.assertEquals(true, si.PaymentRequired__c);
	}	

	@isTest
	static void testDelete() {
		ServiceInvoice__c si = [SELECT Id, Name, Workshop__r.InAppPayment__c, InvoiceReady__c, AccountNumber__c, PaymentRequired__c, PaymentRequired2__c FROM ServiceInvoice__c LIMIT 1];
		Id siId = si.Id;
		System.debug('testDelete().Sinv1: ' + JSON.serialize(si));
		Attachment att = TestFactory.genAttachment(1)[0];
		att.ParentId = si.Id;
		att.Name = 'Service Invoice ' + si.Name;
		insert att;
		System.debug('testDelete().Att: ' + JSON.serialize([SELECT Id, Name FROM Attachment]));
		Test.startTest();
		att = [SELECT Id FROM Attachment WHERE ParentId = :si.Id];
		delete att;
		Test.stopTest();
		si = [SELECT Id, Name, Workshop__r.InAppPayment__c, InvoiceReady__c, AccountNumber__c, PaymentRequired__c, PaymentRequired2__c FROM ServiceInvoice__c WHERE Id = :siId];
		System.debug('testDelete().Sinv2: ' + JSON.serialize(si));
		System.assertEquals(false, si.PaymentRequired__c);
	}
}