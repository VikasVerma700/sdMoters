@IsTest
public class CustMatch_Test {
	@TestSetup
	static void setup() {
		TestFactory.getCompany('028');
	}

	@IsTest
	static void testAcc() {
		Account acc = TestFactory.genAccount(1, true)[0];
		Test.startTest();
		Account checkAcc = CustMatch.checkAcc(new Set<String> { '028' }, null, null, acc.Mobile_Preferred__pc, '', '', acc.LastName);
		Test.stopTest();
		System.assertEquals(checkAcc.Id, acc.Id);
	}

	// @IsTest
	// static void testBusinessAcc() {
	// 	Account busAcc = TestFactory.genBusinessAccount(1, true)[0];
	// 	Test.startTest();
	// 	Account checkBusAcc = CustMatch.checkBusinessAcc(busAcc.NRIC_Number__c.right(4).toUppercase(), busAcc.Name);
	// 	Test.stopTest();
	// 	System.assertEquals(checkBusAcc.Id, busAcc.Id);
	// }

	@IsTest
	static void testNoMatch() {
		Account acc = TestFactory.genAccount(1, true)[0];
		Test.startTest();
		// need 2 matches
		Account checkAcc = CustMatch.checkAcc(new Set<String> { '028' }, null, null, acc.Mobile_Preferred__pc + '1', '', '', acc.LastName + 'Testingonly');
		Test.stopTest();
		System.assert(checkAcc == null);
	}

	// @IsTest
	// static void testLead() {
	// 	Lead ld = TestFactory.genLead(1, true)[0];
	// 	Test.startTest();
	// 	Lead checkLd = CustMatch.checkLead(new Set<String> { '028' }, null, ld.Mobile_Preferred__c, '', '', ld.LastName);
	// 	Test.stopTest();
	// 	System.assertEquals(ld.Id, checkLd.Id);
	// }

	@IsTest
	static void testAccMatchEmail() {
		Account acc = TestFactory.genAccount(1, true)[0];
		acc.Home_Email__c = 'email@email.com';
		update acc;

		Test.startTest();
		Account checkAcc = CustMatch.checkAcc(new Set<String> { '028' }, null, null, '', acc.Home_Email__c, '', '');
		Test.stopTest();
		System.assertEquals(checkAcc.Id, acc.Id);
	}

	@IsTest
	static void testAccMatchDoc() {
		Account acc = TestFactory.genAccount(1, true)[0];
		Test.startTest();
		Account checkAcc = CustMatch.checkAcc(new Set<String> { '028' }, acc.NRIC_Number__c, acc.Doc_Type__c, '', '', '', '');
		Test.stopTest();
		System.assertEquals(checkAcc.Id, acc.Id);
	}

	@IsTest
	static void testAccMatchDocPartial() {
		Account acc = TestFactory.genAccount(1, true)[0];
		Test.startTest();
		Account checkAcc = CustMatch.checkAcc(new Set<String> { '028' }, acc.NRIC_Number__c + '1', acc.Doc_Type__c, '', '', '', '');
		Test.stopTest();
		System.assertEquals(checkAcc, null);
	}
}