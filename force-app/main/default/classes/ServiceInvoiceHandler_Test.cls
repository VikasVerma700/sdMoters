@isTest
public class ServiceInvoiceHandler_Test {
	@TestSetup
	static void makeData(){
		TestFactory.genTriggerSettings('Service Invoice', true);
		CustAppRO_Test.setup();
	}

	// @isTest
	// static void testAfterInsert() {
	// 	Test.startTest();
	// 	sinv.InvoiceValue__c = 20;
	// 	sinv.PaymentRequired2__c = true;
	// 	sinv.PaymentStatus__c = 'PENDING';
	// 	sinv.InvoiceReady__c = true;
	// 	insert sinv;
	// 	Test.stopTest();
	// }

	@isTest
	static void testAfterUpdate() {
		string querySinv =	'SELECT ' + String.join(CustAppRO.INV_FIELDS, ', ') + ' ' +
							'FROM ServiceInvoice__c ';
		ServiceInvoice__c[] sis = Database.query(querySinv);
		System.debug('sis: ' + JSON.serialize(sis));

		string queryAcc =	'SELECT ' + String.join(CustAppAccount.ACC_FIELDS, ', ') + ' FROM Account ';
		Account[] acc = Database.query(queryAcc);
		Map<Id, Account> mapAcc = new Map<Id, Account>();
		for (Account ac :acc) { if (!mapAcc.containsKey(ac.Id)) { mapAcc.put(ac.Id, ac); }}

		string queryRo =	'SELECT ' + String.join(CustAppRO.RO_FIELDS, ', ') + ' FROM ServiceOrder__c';
		ServiceOrder__c[] ros = Database.query(queryRo);
		for (ServiceOrder__c ro :ros) {
			Account ac = mapAcc.get(ro.Account__c);
			ro.ContactPhone__c = u.beautifyPhone(ac.Mobile_Country_Code_1__pc, ac.Mobile_Preferred__pc);
		}
		Database.update(ros, false);
		
		for (ServiceInvoice__c si :sis) {
			si.InvoiceValue__c = 20;
			si.PaymentRequired2__c = false;
			si.InvoiceReady__c = true;
		}
		Database.update(sis, false);
		Test.startTest();
		for (ServiceInvoice__c si :sis) {
			si.InvoiceValue__c = 20;
			si.PaymentRequired2__c = true;
			si.InvoiceReady__c = true;
		}
		Database.update(sis, false);
		Test.stopTest();
	}
}