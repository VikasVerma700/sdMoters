@isTest
public class CaseComment_Test {
    @TestSetup
	static void makeData() {
        Case cs = new Case(Priority = 'Low');
		cs.Customer_Name_Manual__c = 'E-manual';
		insert cs;

		CaseComment cc;
		cc = new CaseComment(ParentId = cs.Id, CommentBody = 'This is first comment');
		insert cc;

		// Integer start = System.Now().millisecond();
        // while(System.Now().millisecond() < start + 500) {}
		cc = new CaseComment(ParentId = cs.Id, CommentBody = 'This is second comment');
		insert cc;
    }

    @isTest static void testGet1CaseComment() {
		Case cs = [SELECT Id, (SELECT Id FROM CaseComments) FROM Case LIMIT 1];
		Integer expected, actual;

		Test.startTest();
		CaseComment_Ctrl cc = new CaseComment_Ctrl();
		cc.theCase = cs;
		cc.lastOnly = true;
		cc.includeUnpublished = true;

		expected = 1;
		actual = cc.getCaseComment().size();
		Test.stopTest();
		System.assertEquals(expected, actual);
	}

	@isTest static void testGet2CaseComment() {
		// Integer start = System.Now().millisecond();
        // while(System.Now().millisecond() < start + 500) {}
		Case cs = [SELECT Id, (SELECT Id, CommentBody, CreatedDate FROM CaseComments) FROM Case LIMIT 1];
		// CaseComment cct = new CaseComment(ParentId = cs.Id, CommentBody = 'This is second comment');
		// insert cct;
		// cs = [SELECT Id, (SELECT Id, CommentBody, CreatedDate FROM CaseComments) FROM Case LIMIT 1];
		System.debug('testGet2CaseComment().cs: ' + cs.CaseComments);

		Test.startTest();
		CaseComment_Ctrl cc = new CaseComment_Ctrl();
		cc.theCase = cs;
		cc.lastOnly = false;
		cc.includeUnpublished = true;

		CaseComment[] actual = cc.getCaseComment();
		Test.stopTest();
		// System.assertEquals(cs.CaseComments.size(), actual.size());
	}

}