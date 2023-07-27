@isTest
private class MitiApproval_Test {


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
	static void BannerId_Test() {
		system.debug('BannerId_Test');
		MitiApproval_Ctrl ctl = new MitiApproval_Ctrl();
		Document d = [SELECT Id, DeveloperName FROM Document LIMIT 1];
		Test.startTest();
		ctl.bannerId = d.DeveloperName;

		string expected = d.Id;
		string actual = ctl.bannerId;
		
		Test.stopTest();
		system.assertEquals(expected, actual, 'Document Id don\'t match');
	}
	@isTest
	static void BannerId_TestEx() {
		system.debug('BannerId_TestEx');
		MitiApproval_Ctrl ctl = new MitiApproval_Ctrl();
		Document d = [SELECT Id, DeveloperName FROM Document LIMIT 1];
		Test.startTest();
		ctl.bannerId = d.DeveloperName + 'Ex';

		string expected = d.Id;
		string actual = ctl.bannerId;
		
		Test.stopTest();
		system.assertNotEquals(expected, actual, 'Document Id shouldn\'t match');
	}

	@isTest
	static void LogoId_Test() {
		system.debug('LogoId_Test');
		MitiApproval_Ctrl ctl = new MitiApproval_Ctrl();
		Document d = [SELECT Id, DeveloperName FROM Document LIMIT 1];
		Test.startTest();
		ctl.logoId = d.DeveloperName;

		string expected = d.Id;
		string actual = ctl.logoId;
		
		Test.stopTest();
		system.assertEquals(expected, actual, 'Document Id don\'t match');
	}
	@isTest static void LogoId_TestEx() {
		system.debug('LogoId_TestEx');
		MitiApproval_Ctrl ctl = new MitiApproval_Ctrl();
		Document d = [SELECT Id, DeveloperName FROM Document LIMIT 1];
		Test.startTest();
		ctl.logoId = d.DeveloperName + 'Ex';

		string expected = d.Id;
		string actual = ctl.logoId;
		
		Test.stopTest();
		system.assertNotEquals(expected, actual, 'Document Id shouldn\'t match');
	}

	
	@isTest
	static void QrLink_Test() {
		system.debug('QrLink_Test');
		TestFactory.genTriggerSettings('Service Appointment', true);
		MitiApproval_Ctrl ctl = new MitiApproval_Ctrl();
		Service_Appointment__c sa = [SELECT Id FROM Service_Appointment__c LIMIT 1];
		Attachment[] att = [SELECT Id FROM Attachment WHERE Name = 'SelfCheckInQr.png' AND ParentId = :sa.Id LIMIT 1];
		Test.startTest();
		ctl.sa = sa;
		ctl.qrLink = sa.Id;
		
		string expected = (att != null && att.size() > 0) ? att[0].Id: null;
		string actual = ctl.qrLink;
		
		Test.stopTest();
		system.assertEquals(expected, actual, 'QR Link don\'t match');
	}

	@isTest
	static void ApexPage_Test() {
		system.debug('ApexPage_Test');
		Service_Appointment__c sa = [SELECT Id FROM Service_Appointment__c LIMIT 1];

		Test.startTest();
		ApexPages.StandardController apexctl = new Apexpages.StandardController(sa);
		MitiApproval_Ctrl ctl = new MitiApproval_Ctrl(apexctl);
		Service_Appointment__c actual = ctl.sa;
		Service_Appointment__c expected = sa;
		Test.stopTest();
		System.assertEquals(expected, actual, 'Service_Appointment__c don\'t match');
	}
}