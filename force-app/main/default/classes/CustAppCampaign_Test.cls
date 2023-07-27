@IsTest
public class CustAppCampaign_Test {
	@TestSetup
	static void setup() {
		TestFactory.genTriggerSettings('Customer App Callback', true);
		CampaignMember mem = TestFactory.genCampaignMember(1, false)[0];
		Customer_External_Account__c extAcc = TestFactory.genCustExtAcc(1, true)[0];
		Account acc = [SELECT Id, PersonContactId FROM Account WHERE Id = :extAcc.Account__c];
		mem.ContactId = acc.PersonContactId;
		mem.Account_Name__c = acc.Id;
		insert mem;
	}

	@IsTest
	static void testAddWebhook() {
		Campaign cmpg = [SELECT Id FROM Campaign LIMIT 1];
		Customer_App_Callback__e evt = new Customer_App_Callback__e(Id__c = cmpg.Id, Event__c = CustAppCampaign.EVENT_NAME);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppCampaign.sendWebhook(evt);
		Test.stopTest();
		// refer to debug logs if there are any errors, no return value
	}

	@IsTest
	static void testRemoveWebhook() {
		Campaign cmpg = [SELECT Id FROM Campaign LIMIT 1];
		Customer_App_Callback__e evt = new Customer_App_Callback__e(Id__c = cmpg.Id, Event__c = CustAppCampaign.REM_EVENT);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppCampaign.sendWebhook(evt);
		Test.stopTest();
		// refer to debug logs if there are any errors
	}
}