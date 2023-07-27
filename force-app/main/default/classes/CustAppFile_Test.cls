@IsTest
public class CustAppFile_Test {

	@TestSetup
	static void setup() {
		TestFactory.genCustExtAcc(1, true);
	}
	
	@IsTest
	static void testFile() {
		Attachment att = TestFactory.genAttachment(1)[0];
		Test.startTest();
		CustAppFile.FileCls file = new CustAppFile.FileCls(att);
		Test.stopTest();
		System.assertEquals(file.name, att.Name);
	}

	@IsTest
	static void testSaveFile() {
		Customer_External_Account__c extAcc = [SELECT Id, UUID__c, Account__c FROM Customer_External_Account__c LIMIT 1];
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppFile.saveFile('test.com', 'Test File', extAcc.Account__c, 'UPDATE_ACCOUNT', extAcc.Account__c);
		Test.stopTest();
		List<Attachment> attCheck = [SELECT Id FROM Attachment WHERE ParentId = :extAcc.Account__c];
		System.assert(attCheck.size() > 0);
	}
}