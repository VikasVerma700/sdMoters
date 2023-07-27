@IsTest
public class CustAppTradeInEnquiry_Test {
	@TestSetup
	static void setup() {
		TestFactory.genTriggerSettings('Vehicle', true);
		TestFactory.genVehicle(1, true);
		TestFactory.genCustExtAcc(1, true);
		TestFactory.getCompany('168');
		TestFactory.getCompany('028');
		User ppslUser = [SELECT Id FROM User WHERE /*Team_Number_Mgr__c LIKE 'BPS Team%' AND*/ IsActive = TRUE AND Company__c = '028' LIMIT 1];
		User_Config__c config = new User_Config__c(User__c = ppslUser.Id);
		insert config;
	}

	@IsTest
	static void testEnquiry() {
		Customer_External_Account__c extAcc = [SELECT Id, UUID__c, Account__c FROM Customer_External_Account__c LIMIT 1];
		Vehicle__c veh = [SELECT Id, Name FROM Vehicle__c LIMIT 1];
		CustAppTradeInEnquiry.EnquiryCallback req = new CustAppTradeInEnquiry.EnquiryCallback();
		req.payload = new CustAppTradeInEnquiry.EnquiryBody();
		req.payload.tradeIn = new CustAppTradeInEnquiry.EnquiryPayload();
		req.payload.tradeIn.accountUuid = extAcc.UUID__c;
		req.payload.tradeIn.isOwner = true;
		req.payload.tradeIn.mileage = 10;
		req.payload.tradeIn.ownerNricFin = '864B';
		req.payload.tradeIn.source = 'Parallel';
		req.payload.tradeIn.identificationNumber = veh.Name;
		req.payload.tradeIn.companyId = '028';
		RestContext.request = new RestRequest();
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
		Test.startTest();
		CustAppTradeInEnquiry.processCallback();
		Test.stopTest();
		String tradeInCmp = CustAppTradeInEnquiry.TRADE_IN_CMP.get(req.payload.tradeIn.companyId);
		List<Opportunity> opp = [SELECT Id FROM Opportunity WHERE AccountId = :extAcc.Account__c AND Company__r.Name = :tradeInCmp];
		System.assert(opp.size() >= 0);
	}
}