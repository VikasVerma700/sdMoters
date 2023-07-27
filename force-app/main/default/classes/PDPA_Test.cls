@IsTest
public class PDPA_Test {
	@TestSetup
	public static void makeData(){
		Legislation_Type__c legType = TestFactory.genLegislationType('PDPA Consent T&C for Existing Customers', true);
		Attachment att = new Attachment();
		att.Body = Blob.valueOf('test');
		att.Name = PDPA.CMP_EMBED_TNC.get('028');
		att.ParentId = legType.Id;
		att.ContentType = 'text/html';
		Attachment att2 = att.clone();
		att2.Name = PDPA.CMP_TNC.get('028');
		insert new List<Attachment> { att, att2 };
	}

	@IsTest
	public static void testConsentTerms() {
		String cmp = '028';
		Test.startTest();
		PDPA_Consent__mdt pdpaTerms = PDPA.consentTerms(cmp);
		Test.stopTest();
		System.assert(pdpaTerms != null);
		System.assertEquals(pdpaTerms.Company__c, cmp);
	}

	@IsTest
	public static void testGetEmbeddedTNC() {
		String cmp = '028';
		Test.startTest();
		String terms = PDPA.getEmbeddedTNC(cmp);
		Test.stopTest();
		System.assert(!String.isBlank(terms));
	}

	@IsTest
	public static void testGetTNC() {
		String cmp = '028';
		Test.startTest();
		Attachment terms = PDPA.getTNC(cmp);
		Test.stopTest();
		System.assert(!String.isBlank(terms.Body.toString()));
	}

	@IsTest
	public static void testGetTNCString() {
		String cmp = '028';
		Test.startTest();
		String terms = PDPA.getTNCString(cmp);
		Test.stopTest();
		System.assert(!String.isBlank(terms));
	}

	@IsTest
	public static void testCreatePDPA() {
		Account acc = TestFactory.genAccount(1, true)[0];
		Test.startTest();
		Local_Legislation__c leg = PDPA.createPDPA(acc, 'Test');
		Test.stopTest();
		System.assertNotEquals(leg.Id, null);
		System.assertEquals(leg.Account_Name__c, acc.Id);
	}
}