@IsTest
public class CustAppNotification_Test {
	@TestSetup
	static void setup() {
		TestFactory.genCustExtAcc(1, true);
		TestFactory.genTriggerSettings('Notification', true);
	}

	@IsTest
	static void testSendErr() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppNotification(null, 400));
		Customer_External_Account__c extAcc = [SELECT Id, Account__c FROM Customer_External_Account__c LIMIT 1];
		Notification__c n = new Notification__c();
		n.Account__c = extAcc.Account__c;
		n.Company__c = TestFactory.getCompany('028').Id;
		n.Subtitle__c = 'Test';
		n.Message__c = 'Test';
		n.Action__c = '{ "action": "test" }';
		n.App_ID__c = new List<String>(CustAppAccount.REV_TYPE.keySet())[0];
		Test.startTest();
		insert n;
		Test.stopTest();
		String checkSubj = CustAppNotification.NOTIFICATION_PREFIX_ERR + '%';
		List<Task> checkSend = [SELECT Id FROM Task WHERE WhatId = :n.Id AND Subject LIKE :checkSubj];
		System.assert(checkSend.size() > 0);
	}

	@IsTest
	static void testSendOne() {
		Customer_External_Account__c extAcc = [SELECT Id, UUID__c, Account__c FROM Customer_External_Account__c LIMIT 1];
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppNotification(extAcc.UUID__c, 200));
		Notification__c n = new Notification__c();
		n.Account__c = extAcc.Account__c;
		n.Company__c = TestFactory.getCompany('028').Id;
		n.Subtitle__c = 'Test';
		n.Message__c = 'Test';
		n.Action__c = '{ "action": "test" }';
		n.App_ID__c = new List<String>(CustAppAccount.REV_TYPE.keySet())[0];
		insert n;
		Task sentTask = new Task(Subject = CustAppNotification.NOTIFICATION_PREFIX_SUCC, WhatId = n.Id);
		insert sentTask;
		CustAppNotification notifier = new CustAppNotification(new List<Id> { n.Id });
		Test.startTest();
		notifier.execute(null);
		Test.stopTest();
		String checkSubj = CustAppNotification.NOTIFICATION_PREFIX_SUCC + '%';
		List<Task> checkSend = [SELECT Id FROM Task WHERE WhatId = :n.Id AND Subject LIKE :checkSubj];
		System.assertEquals(checkSend.size(), 1);
	}

	@IsTest
	static void testSend() {
		Customer_External_Account__c extAcc = [SELECT Id, UUID__c, Account__c FROM Customer_External_Account__c LIMIT 1];
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppNotification(extAcc.UUID__c, 200));
		Notification__c n = new Notification__c();
		n.Account__c = extAcc.Account__c;
		n.Company__c = TestFactory.getCompany('028').Id;
		n.Subtitle__c = 'Test';
		n.Message__c = 'Test';
		n.Action__c = '{ "action": "test" }';
		n.App_ID__c = new List<String>(CustAppAccount.REV_TYPE.keySet())[0];
		insert n;
		CustAppNotification notifier = new CustAppNotification(new List<Id> { n.Id });
		Test.startTest();
		notifier.execute(null);
		Test.stopTest();
		String checkSubj = CustAppNotification.NOTIFICATION_PREFIX_SUCC + '%';
		List<Task> checkSend = [SELECT Id FROM Task WHERE WhatId = :n.Id AND Subject LIKE :checkSubj];
		System.assertEquals(checkSend.size(), 1);
	}
	
	@IsTest
	static void testProcessRead() {
		Customer_External_Account__c extAcc = [SELECT Id, UUID__c, Account__c FROM Customer_External_Account__c LIMIT 1];
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppNotification(extAcc.UUID__c, 200));
		Notification__c n = new Notification__c();
		n.Account__c = extAcc.Account__c;
		n.Company__c = TestFactory.getCompany('028').Id;
		n.Subtitle__c = 'Test';
		n.Message__c = 'Test';
		n.Action__c = '{ "action": "test" }';
		n.Ext_UUID__c = 'Test123';
		n.App_ID__c = new List<String>(CustAppAccount.REV_TYPE.keySet())[0];
		insert n;

		CustAppNotification.NotificationReadPayload reqBody = new CustAppNotification.NotificationReadPayload();
		reqBody.payload = new CustAppNotification.NotificationReadReq();
		reqBody.payload.readAt = DateTime.now();
		reqBody.payload.accountUuid = extAcc.UUID__c;
		reqBody.payload.inboxMessageUuid = n.Ext_UUID__c;
		RestContext.request = new RestRequest();
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(reqBody));
		Test.startTest();
		CustAppNotification.processCallback();
		Test.stopTest();
		List<Notification__c> checkNotification = [SELECT Id, First_Read_Datetime__c FROM Notification__c WHERE Id = :n.Id];
		System.assertEquals(checkNotification[0].First_Read_Datetime__c, reqBody.payload.readAt);
	}

	@isTest
	static void testSendBatch() {
		Customer_External_Account__c extAcc = [SELECT Id, UUID__c, Account__c FROM Customer_External_Account__c LIMIT 1];
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppNotification(extAcc.UUID__c, 200));
		Notification__c n = new Notification__c();
		n.Account__c = extAcc.Account__c;
		n.Company__c = TestFactory.getCompany('028').Id;
		n.Subtitle__c = 'Test';
		n.Message__c = 'Test';
		n.Action__c = '{ "action": "test" }';
		n.App_ID__c = new List<String>(CustAppAccount.REV_TYPE.keySet())[0];
		insert n;
		CustAppNotification notifier = new CustAppNotification(new List<Id> { n.Id });
		Test.startTest();
		Database.executeBatch(notifier, 1);
		Test.stopTest();
		String checkSubj = CustAppNotification.NOTIFICATION_PREFIX_SUCC + '%';
		List<Task> checkSend = [SELECT Id FROM Task WHERE WhatId = :n.Id AND Subject LIKE :checkSubj];
		System.assertEquals(checkSend.size(), 1);
	}
}