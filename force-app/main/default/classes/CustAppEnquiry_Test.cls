@IsTest
public class CustAppEnquiry_Test {
	@TestSetup
	public static void setup() {
		TestFactory.genTriggerSettings('Customer App Callback', true);
		Account acc = TestFactory.genAccount(1, true)[0];
		Customer_External_Account__c extAcc = TestFactory.genCustExtAcc(1, false)[0];
		extAcc.Account__c = acc.Id;
		insert extAcc;
		Case[] cases = new List<Case>();
		for (Integer i = 1; i <= 5; i++) {
			Case cs = new Case();
			cs.Subject = 'Subject ' + i;
			cs.Description = 'Description for ' + i;
			cs.Status = 'New';
			cs.AccountId = acc.Id;
			cases.add(cs);
		}
		insert cases;
	}

	@IsTest
	public static void testCallback() {
		Customer_External_Account__c extAcc = [SELECT Id, Account__c, UUID__c FROM Customer_External_Account__c LIMIT 1];
		CustAppEnquiry.EnquiryCallback req = new CustAppEnquiry.EnquiryCallback();
		req.event = CustAppEnquiry.EVENT_NAME;
		req.payload = new CustAppEnquiry.EnquiryBody();
		req.payload.enquiry = new CustAppEnquiry.EnquiryPayload();
		req.payload.enquiry.accountUuid = extAcc.UUID__c;
		req.payload.enquiry.name = 'Test';
		req.payload.enquiry.email = 'test@example.com';
		req.payload.enquiry.subject = 'This is a test';
		req.payload.enquiry.details = 'Testing';
		req.payload.enquiry.division = 'Sime Darby Auto Bavaria';
		req.payload.enquiry.companyId = '028';
		RestContext.request = new RestRequest();
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
		Test.startTest();
		CustAppEnquiry.processCallback();
		Test.stopTest();
		List<Case> caseTest = [SELECT Id FROM Case WHERE AccountId = :extAcc.Account__c];
		System.assert(caseTest.size() > 0);
	}

	@IsTest
	public static void testGetEnquiry() {
		Customer_External_Account__c extAcc = [SELECT Id, Account__c, UUID__c FROM Customer_External_Account__c LIMIT 1];
		RestContext.request = new RestRequest();
		RestContext.response = new RestResponse();
		RestContext.request.params.put('accountUuid', extAcc.UUID__c);
		RestContext.request.params.put('page', '1');
		RestContext.request.params.put('count', '1');
		
		Test.startTest();
		CustAppEnquiry.getEnquiry();
		Test.stopTest();
		if (RestContext.response.statusCode == 200) {
			CustAppEnquiry.EnquiryResponse[] response = (CustAppEnquiry.EnquiryResponse[])JSON.deserialize(RestContext.response.responseBody.toString(), CustAppEnquiry.EnquiryResponse[].class);
			System.assertEquals(1, response.size());
		}
	}

	@IsTest
	public static void testGetEnquiryNoUuid() {
		RestContext.request = new RestRequest();
		RestContext.response = new RestResponse();

		Test.startTest();
		CustAppEnquiry.getEnquiry();
		Test.stopTest();
		System.assertEquals(500, RestContext.response.statusCode);
	}
}