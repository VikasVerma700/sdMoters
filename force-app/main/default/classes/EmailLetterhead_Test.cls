@isTest
public class EmailLetterhead_Test {

    @TestSetup
    static void makeData(){
		system.debug('makeData');
		Case cs = new Case(Priority = 'Low', Customer_Name_Manual__c = 'Case');
		insert cs;

		Document d = new Document();
		d.Name ='Test Document';
		d.DeveloperName = 'TestDocApi';
		// d.AuthorId = UserInfo.getUserId();
		d.FolderId = UserInfo.getUserId();
		d.IsPublic = true;
		insert d;
    }

    @isTest
    static void HeaderId_Test() {
		system.debug('HeaderId_Test');
		EmailLetterhead_Ctrl ctl = new EmailLetterhead_Ctrl();
		Document d = [SELECT Id, DeveloperName FROM Document LIMIT 1];
		Test.startTest();
		ctl.headerId = d.DeveloperName;

		string expected = d.Id;
		string actual = ctl.headerId;
			
		Test.stopTest();
		system.assertEquals(expected, actual, 'Document Id don\'t match');
    }

	@isTest
    static void NotFound_Test() {
		system.debug('NotFound_Test');
		EmailLetterhead_Ctrl ctl = new EmailLetterhead_Ctrl();
		Test.startTest();
		ctl.headerId = 'TestDocApi-nomatch';

		string expected = null;
		string actual = ctl.headerId;
			
		Test.stopTest();
		system.assertEquals(expected, actual, 'Document Id don\'t match');
    }

	@isTest
	static void ApexPage_Test() {
		system.debug('ApexPage_Test');
		Case cs = [SELECT Id FROM Case LIMIT 1];

		Test.startTest();
		ApexPages.StandardController apexctl = new Apexpages.StandardController(cs);
		EmailLetterhead_Ctrl ctl = new EmailLetterhead_Ctrl(apexctl);
		Case actual = ctl.cs;
		Case expected = cs;
		Test.stopTest();
		System.assertEquals(expected, actual, 'Case don\'t match');
	}

}