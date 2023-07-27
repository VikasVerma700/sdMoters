@IsTest
public class CustAppCampaignMember_Test {
	@TestSetup
	public static void setup() {
		TestFactory.genTriggerSettings('Customer App Callback', true);
		Customer_External_Account__c extAcc = TestFactory.genCustExtAcc(1, true)[0];
	}

	@IsTest
	static void testUpdateCM() {
		Customer_External_Account__c extAcc = [SELECT Id, UUID__c, Account__c, Account__r.PersonContactId FROM Customer_External_Account__c LIMIT 1];
		CampaignMember mem = TestFactory.genCampaignMember(1, false)[0];
		mem.ContactId =extAcc.Account__r.PersonContactId;
		mem.Account_Name__c = extAcc.Account__c;
		insert mem;
		Campaign cm = new Campaign(Id = mem.CampaignId, External_Display_Name__c = 'Test');
		update cm;
		CustAppCampaignMember.CmpgMemberHook cmHook = new CustAppCampaignMember.CmpgMemberHook();
		cmHook.event = CustAppCampaignMember.EVENT_NAME;
		cmHook.payload = new CustAppCampaignMember.CmpgMemberInfo();
		cmHook.payload.campaign = cm.External_Display_Name__c;
		cmHook.payload.selectedDate = new CustAppCampaignMember.CmpgDate();
		cmHook.payload.selectedDate.startDate = Date.today();
		cmHook.payload.selectedDate.endDate = Date.today();
		cmHook.payload.accountUuid = extAcc.UUID__c;
		cmHook.payload.companyId = '028';
		cmHook.payload.pax = 1;
		cmHook.payload.referenceNumber = 'Test123';
		cmHook.payload.status = 'RESERVED';
		RestContext.request = new RestRequest();
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(cmHook));
		Test.startTest();
		CustAppCampaignMember.processCallback();
		Test.stopTest();
		CampaignMember checkCM = [SELECT Id, RSVP_Status__c FROM CampaignMember WHERE Id = :mem.Id];
		System.assertEquals(checkCM.RSVP_Status__c, 'Accepted');
	}

	@IsTest
	static void testAddCM() {
		Customer_External_Account__c extAcc = [SELECT Id, UUID__c, Account__c, Account__r.PersonContactId FROM Customer_External_Account__c LIMIT 1];
		Campaign cm = TestFactory.genCampaign(1, false)[0];
		cm.External_Display_Name__c = 'Test';
		insert cm;
		CustAppCampaignMember.CmpgMemberHook cmHook = new CustAppCampaignMember.CmpgMemberHook();
		cmHook.event = CustAppCampaignMember.EVENT_NAME;
		cmHook.payload = new CustAppCampaignMember.CmpgMemberInfo();
		cmHook.payload.campaign = cm.External_Display_Name__c;
		cmHook.payload.selectedDate = new CustAppCampaignMember.CmpgDate();
		cmHook.payload.selectedDate.startDate = Date.today();
		cmHook.payload.selectedDate.endDate = Date.today();
		cmHook.payload.accountUuid = extAcc.UUID__c;
		cmHook.payload.companyId = '028';
		cmHook.payload.pax = 1;
		cmHook.payload.referenceNumber = 'Test123';
		cmHook.payload.status = 'RESERVED';
		RestContext.request = new RestRequest();
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(cmHook));
		Test.startTest();
		CustAppCampaignMember.processCallback();
		Test.stopTest();
		List<CampaignMember> checkCM = [SELECT Id, RSVP_Status__c FROM CampaignMember WHERE CampaignId = :cm.Id];
		System.assert(checkCM.size() > 0);
		System.assertEquals(checkCM[0].RSVP_Status__c, 'Accepted');
	}
}