@isTest
public with sharing class CampaignMemberTriggerHandler_Test {

	@TestSetup
	static void makeData(){
		// TestFactory.genCampaign(1, true);
        TestFactory.genTriggerSettings(CampaignMemberTriggerHandler.TRIG_SETTING, true);
	}

	@isTest
	static void testCreateUpdateMember() {
		Campaign c = TestFactory.genCampaign(1, true)[0];
		CampaignMember cm = TestFactory.genCampaignMember(1, false)[0];
		cm.CampaignId = c.Id;

		Test.startTest();
		insert cm;
		cm.Status = 'Sent';
		cm.CheckInMethod__c = 'QR';
		update cm;
		Test.stopTest();
	}

	@isTest
	static void testDelete() {
		Campaign c = TestFactory.genCampaign(1, true)[0];
		CampaignMember cm = TestFactory.genCampaignMember(1, false)[0];
		cm.CampaignId = c.Id;
		insert cm;

		Test.startTest();
		delete cm;
		Test.stopTest();
	}
}