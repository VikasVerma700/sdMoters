@IsTest
private class NotificationHandler_Test {
	@IsTest static private void testCreateSends() {
		TestFactory.genTriggerSettings('Notification', true);
		List<User_Message_Token__c> msgTokens = TestFactory.genUserMessageToken(2, true);
		Notification__c n = TestFactory.genNotification(1, false)[0];
		Test.startTest();
		insert n;
		Test.stopTest();
		List<Notification_Send__c> sends = [SELECT Id FROM Notification_Send__c WHERE Notification__c = :n.Id];
		System.assertEquals(sends.size(), 2);
	}

	@IsTest static private void testSendCustApp() {
		TestFactory.genTriggerSettings('Notification', true);
		Account acc = TestFactory.genAccount(1, true)[0];
		Notification__c n = TestFactory.genNotification(1, false)[0];
		n.Account__c = acc.Id;
		n.App_ID__c = new List<String>(CustAppAccount.REV_TYPE.keySet())[0];
		Test.startTest();
		insert n;
		Test.stopTest();
		List<AsyncApexJob> jobInfo = [SELECT Status,NumberOfErrors FROM AsyncApexJob WHERE ApexClass.Name = 'CustAppNotification'];
		System.assert(jobInfo.size() > 0);
	}
}