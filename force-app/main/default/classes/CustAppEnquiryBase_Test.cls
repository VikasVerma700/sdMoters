@IsTest
public class CustAppEnquiryBase_Test {
	@TestSetup
	static void setup() {
		TestFactory.genTriggerSettings('Customer App Callback', true);
		TestFactory.genCustExtAcc(1, true);
	}

	@IsTest
	static void testGetAccList() {
		Customer_External_Account__c extAcc = [SELECT Id, UUID__c FROM Customer_External_Account__c LIMIT 1];
		Test.startTest();
		List<Customer_External_Account__c> checkExt = CustAppEnquiryBase.getCustAccList(extAcc.UUID__c);
		Test.stopTest();
		System.assert(checkExt.size() > 0);
		System.assertEquals(checkExt[0].Id, extAcc.Id);
	}

	// @IsTest
	// static void testLeadTrafficAndExistingOpp() {
	// 	Customer_External_Account__c extAcc = [SELECT Id, UUID__c FROM Customer_External_Account__c LIMIT 1];
	// 	List<Customer_External_Account__c> checkExt = CustAppEnquiryBase.getCustAccList(extAcc.UUID__c);
	// 	Opportunity opp = TestFactory.genOpportunity(1, false)[0];
	// 	opp.AccountId = checkExt[0].Account__c;
	// 	opp.OwnerId = UserInfo.getUserId();
	// 	opp.Sales_Rep_Name__c = UserInfo.getUserId();
	// 	insert opp;
	// 	Company__c cmp = CustAppAPI.CMP_MAP.get('028');
	// 	Account acc = checkExt[0].Account__r;
	// 	User sc = new User(Id = UserInfo.getUserId());
	// 	Test.startTest();
	// 	Lead_Traffic__c traffic = CustAppEnquiryBase.createLeadTraffic(cmp, acc, sc, '1 Series');
	// 	Opportunity checkOpp = CustAppEnquiryBase.findExistingOrCreateOpp(checkExt[0], traffic.Id, sc, cmp, '1 Series');
	// 	Test.stopTest();
	// 	System.assert(traffic.Id != null);
	// 	System.assertEquals(traffic.Account_Name__c, acc.Id);
	// 	System.assertEquals(opp.Id, checkOpp.Id);
	// }

	// @IsTest
	// static void testNewOppAndTask() {
	// 	Customer_External_Account__c extAcc = [SELECT Id, UUID__c FROM Customer_External_Account__c LIMIT 1];
	// 	List<Customer_External_Account__c> checkExt = CustAppEnquiryBase.getCustAccList(extAcc.UUID__c);
	// 	Company__c cmp = CustAppAPI.CMP_MAP.get('028');
	// 	Account acc = checkExt[0].Account__r;
	// 	User sc = new User(Id = UserInfo.getUserId());
	// 	Test.startTest();
	// 	Opportunity checkOpp = CustAppEnquiryBase.findExistingOrCreateOpp(checkExt[0], null, sc, cmp, '1 Series');
	// 	insert checkOpp;
	// 	Task testTask = CustAppEnquiryBase.createTask(cmp, checkOpp, checkExt[0]);
	// 	Test.stopTest();
	// 	System.assertEquals(checkOpp.OwnerId, sc.Id);
	// 	System.assert(testTask.Id != null);
	// 	System.assertEquals(testTask.WhatId, checkOpp.Id);
	// }
}