@isTest
private class AbServiceApptEmail_Test {

    @TestSetup
    static void makeData(){
		system.debug('makeData');
		Service_Appointment__c sa = TestFactory.genSvcAppt(1, true)[0];
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
		AbServiceApptEmail_Ctrl ctl = new AbServiceApptEmail_Ctrl();
		Document d = [SELECT Id, DeveloperName FROM Document LIMIT 1];
		Test.startTest();
		ctl.headerId = d.DeveloperName;

		string expected = d.Id;
		string actual = ctl.headerId;
			
		Test.stopTest();
		system.assertEquals(expected, actual, 'Document Id don\'t match');
    }
    @isTest
    static void HeaderId_TestEx() {
		system.debug('HeaderId_TestEx');
		AbServiceApptEmail_Ctrl ctl = new AbServiceApptEmail_Ctrl();
		Document d = [SELECT Id, DeveloperName FROM Document LIMIT 1];
		Test.startTest();
		ctl.headerId = d.DeveloperName + 'Ex';

		string expected = d.Id;
		string actual = ctl.headerId;
			
		Test.stopTest();
		system.assertNotEquals(expected, actual, 'Document Id shouldn\'t match');
    }

    @isTest
    static void DetailsId_Test() {
		system.debug('DetailsId_Test');
		AbServiceApptEmail_Ctrl ctl = new AbServiceApptEmail_Ctrl();
		Document d = [SELECT Id, DeveloperName FROM Document LIMIT 1];
		Test.startTest();
		ctl.detailsId = d.DeveloperName;

		string expected = d.Id;
		string actual = ctl.detailsId;
			
		Test.stopTest();
		system.assertEquals(expected, actual, 'Document Id don\'t match');
    }
    @isTest
    static void DetailsId_TestEx() {
		system.debug('DetailsId_TestEx');
		AbServiceApptEmail_Ctrl ctl = new AbServiceApptEmail_Ctrl();
		Document d = [SELECT Id, DeveloperName FROM Document LIMIT 1];
		Test.startTest();
		ctl.detailsId = d.DeveloperName + 'Ex';

		string expected = d.Id;
		string actual = ctl.detailsId;
			
		Test.stopTest();
		system.assertNotEquals(expected, actual, 'Document Id shouldn\'t match');
    }
    
    @isTest
    static void LineId_Test() {
		system.debug('LineId_Test');
		AbServiceApptEmail_Ctrl ctl = new AbServiceApptEmail_Ctrl();
		Document d = [SELECT Id, DeveloperName FROM Document LIMIT 1];
		Test.startTest();
		ctl.lineId = d.DeveloperName;

		string expected = d.Id;
		string actual = ctl.lineId;
			
		Test.stopTest();
		system.assertEquals(expected, actual, 'Document Id don\'t match');
    }
    @isTest
    static void LineId_TestEx() {
		system.debug('LineId_TestEx');
		AbServiceApptEmail_Ctrl ctl = new AbServiceApptEmail_Ctrl();
		Document d = [SELECT Id, DeveloperName FROM Document LIMIT 1];
		Test.startTest();
		ctl.lineId = d.DeveloperName + 'Ex';

		string expected = d.Id;
		string actual = ctl.lineId;
			
		Test.stopTest();
		system.assertNotEquals(expected, actual, 'Document Id shouldn\'t match');
    }

    @isTest
    static void SpacerId_Test() {
		system.debug('SpacerId_Test');
		AbServiceApptEmail_Ctrl ctl = new AbServiceApptEmail_Ctrl();
		Document d = [SELECT Id, DeveloperName FROM Document LIMIT 1];
		Test.startTest();
		ctl.spacerId = d.DeveloperName;

		string expected = d.Id;
		string actual = ctl.spacerId;
			
		Test.stopTest();
		system.assertEquals(expected, actual, 'Document Id don\'t match');
    }
    @isTest
    static void SpacerId_TestEx() {
		system.debug('SpacerId_TestEx');
		AbServiceApptEmail_Ctrl ctl = new AbServiceApptEmail_Ctrl();
		Document d = [SELECT Id, DeveloperName FROM Document LIMIT 1];
		Test.startTest();
		ctl.spacerId = d.DeveloperName + 'Ex';

		string expected = d.Id;
		string actual = ctl.spacerId;
			
		Test.stopTest();
		system.assertNotEquals(expected, actual, 'Document Id shouldn\'t match');
    }

	@isTest
	static void ApexPage_Test() {
		system.debug('ApexPage_Test');
		Service_Appointment__c sa = [SELECT Id FROM Service_Appointment__c LIMIT 1];

		Test.startTest();
		ApexPages.StandardController apexctl = new Apexpages.StandardController(sa);
		AbServiceApptEmail_Ctrl ctl = new AbServiceApptEmail_Ctrl(apexctl);
		Service_Appointment__c actual = ctl.sa;
		Service_Appointment__c expected = sa;
		Test.stopTest();
		System.assertEquals(expected, actual, 'Service_Appointment__c don\'t match');
	}

}