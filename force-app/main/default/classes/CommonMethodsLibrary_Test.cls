@isTest
public with sharing class CommonMethodsLibrary_Test {

	static testMethod void testEmailResultFailure() {
		Account acc = new Account();
		List<Account> accList = new List<Account>{acc};
		List<Database.SaveResult> srList = Database.insert(accList, false);
		List<Database.UpsertResult> urList = Database.upsert(accList, false);
		List<User> u = [SELECT Id, Email FROM User WHERE Alias = 'godlike' LIMIT 1];
		String ur, sr;
		sr = CommonMethodsLibrary.emailResultFailure(srList, accList, 'testEmailResultFailure (accList)', 'TestMethod_CommonMethodsLibrary', u);
		ur = CommonMethodsLibrary.emailResultFailure(urList, accList, 'testEmailResultFailure (accList)', 'TestMethod_CommonMethodsLibrary', u);
		System.assertNotEquals('No Error', sr);
		System.assertNotEquals('No Error', ur);
	}


	static testMethod void testSendErrEmail() {
		// test constructErrEmail as well
		String header = 'header text';
		String footer = 'footer text';
		String err = 'error text';
		List<User> userList = TestFactory.genUser(2, true);
		Set<User> checkSet = new Set<User>(userList);
		Test.startTest();
		String body = CommonMethodsLibrary.constructErrEmail(header, footer, err);
		List<Messaging.SingleEmailMessage> emails = CommonMethodsLibrary.sendErrorEmail(userList, body);
		Test.stopTest();

		System.assert(body.contains(header));
		System.assert(body.contains(footer));
		System.assert(body.contains(err));
		System.assertEquals(userList.size(), emails.size());
		for (Messaging.SingleEmailMessage e : emails) {
			//System.assertEquals(body, e.getHtmlBody());
		}
	}

	@IsTest
	static void testSendErrEmail2() {
		// test constructErrEmail as well
		String header = 'header text';
		String footer = 'footer text';
		String err = 'error text';
		Boolean send = true;
		List<User> userList = TestFactory.genUser(2, true);
		Set<User> checkSet = new Set<User>(userList);
		Test.startTest();
		String body = CommonMethodsLibrary.constructErrEmail(header, footer, err);
		List<Messaging.SingleEmailMessage> emails = CommonMethodsLibrary.sendErrorEmail(userList, body, send);
		Test.stopTest();

		System.assert(body.contains(header));
		System.assert(body.contains(footer));
		System.assert(body.contains(err));
		System.assertEquals(userList.size(), emails.size());
		for (Messaging.SingleEmailMessage e : emails) {
			//System.assertEquals(body, e.getHtmlBody());
		}
	}

	static testMethod void testCreation(){
		Account acc = TestFactory.genAccount(1, true)[0];
		CommonMethodsLibrary.createTask(null, null, String.valueOf(UserInfo.getUserId()), 'Automated Tasks', 'Automated Tasks', 'TEST', 'Normal', 'Test', true, 4);
	}


	@IsTest static void testEmail() {
		Account a = TestFactory.genAccount(1, false)[0];
		a.Home_Email__c = 'test1@x.com';
		a.Office_Email__c = 'test1@y.com';
		a.Other_Email__c = 'test1@z.com';
		Test.startTest();
		Boolean didChange = CommonMethodsLibrary.setEmail(a, 'test2@x.com');
		Test.stopTest();
		System.assert(didChange);
	}

	@IsTest static void testSendEmail() {
		Account newAcc = new Account(Name='Test');
		insert newAcc;
		List<EmailTemplate> tempList = [SELECT Id, Name FROM EmailTemplate];
		if (tempList.size() <= 0) { return; }
		List<OrgWideEmailAddress> emailList = [SELECT Id, DisplayName FROM OrgWideEmailAddress];

		Test.startTest();
		List<Messaging.SingleEmailMessage> msgList = CommonMethodsLibrary.sendEmail(
			newAcc.Id, tempList[0].Id, emailList[0].Id, null, true
		);
		Test.stopTest();
	}

	@IsTest static void testRemoveEmail() {
		Account a = TestFactory.genAccount(1, false)[0];
		a.Home_Email__c = 'test1@x.com';
		a.Office_Email__c = 'test1@y.com';
		a.Other_Email__c = 'test1@z.com';
		a.Active_Other__c = true;
		insert a;
		Test.startTest();
		Boolean didChange = CommonMethodsLibrary.setEmail(a, '');
		Test.stopTest();
		System.assert(didChange);
	}

	static testMethod void testAssignSC() {
		List<User_Config__c> ucList = TestFactory.genUserConfig(1, true);
		CommonMethodsLibrary.assignSC(ucList, 1);
	}

	@isTest static void testSetEmail() {
		Account newAcc = new Account(Name='Test');
		CommonMethodsLibrary.setEmail(newAcc, 'home@email.com');
		CommonMethodsLibrary.setEmail(newAcc, 'office@email.com');
		CommonMethodsLibrary.setEmail(newAcc, 'other@email.com');
		System.debug(JSON.serialize(newAcc));
		insert newAcc;
		newAcc.Active_Work__c = true;
		newAcc.Active_Home__c = true;
		newAcc.Active_Work__c = true;
		CommonMethodsLibrary.setEmail(newAcc, '');

		newAcc.Office_Email__c = 'office@email.com';
		CommonMethodsLibrary.setEmail(newAcc, '');
		newAcc.Home_Email__c = 'home@email.com';
		CommonMethodsLibrary.setEmail(newAcc, '');
		newAcc.Other_Email__c = 'other@email.com';
		CommonMethodsLibrary.setEmail(newAcc, '');
	}
}