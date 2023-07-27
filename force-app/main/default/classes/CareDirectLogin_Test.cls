@IsTest
private class CareDirectLogin_Test {
	@TestSetup
	static void makeData() {
		CareLogin_Test.setup();
	}

	@IsTest
	private static void testDirectLogin() {
		RestContext.response = new RestResponse();
		Account_Profile_with_Business_Unit__c apbu = [SELECT Id, Account_Name__c FROM Account_Profile_with_Business_Unit__c LIMIT 1];
		update new Account(Id = apbu.Account_Name__c, Skip_2FA_ACP__c = true);
		Vehicle_Ownership__c loginVO = [SELECT Id, Customer__r.Mobile_Preferred__pc, Registration_No__c FROM Vehicle_Ownership__c WHERE
										Customer__c = :apbu.Account_Name__c LIMIT 1];
		CareToken.KNOWN_AUD.add('test');
		String code = CareToken.generateDirectLoginToken('028', '', false, new List<String>(CareToken.KNOWN_AUD)[0]);
		Test.startTest();
		CareDirectLogin.login(loginVO.Customer__r.Mobile_Preferred__pc, loginVO.Registration_No__c, code);
		Test.stopTest();
		CareLogin.LoginResp resp = (CareLogin.LoginResp) JSON.deserialize(RestContext.response.responseBody.toString(), CareLogin.LoginResp.class);
		System.assert(resp.user != null);
		CareToken.AdditionalClaims claims = CareToken.parseToken(resp.token);
		System.assert(claims.isVerified);
		System.assertEquals(resp.user.accId, apbu.Account_Name__c);
		System.assertEquals(resp.user.vehicles.size(), 2);
		System.assertEquals(resp.user.apptList.size(), 1);
		System.assertEquals(resp.user.serviceList.size(), 0);
		System.assertEquals(resp.user.acctStatus, 'VIP');
	}

	@IsTest
	private static void testDirectLoginFail() {
		RestContext.response = new RestResponse();
		Account_Profile_with_Business_Unit__c apbu = [SELECT Id, Account_Name__c FROM Account_Profile_with_Business_Unit__c LIMIT 1];
		update new Account(Id = apbu.Account_Name__c, Skip_2FA_ACP__c = true);
		Vehicle_Ownership__c loginVO = [SELECT Id, Customer__r.Mobile_Preferred__pc, Registration_No__c FROM Vehicle_Ownership__c WHERE
										Customer__c = :apbu.Account_Name__c LIMIT 1];
		String code = CareToken.generateDirectLoginToken('028', '', false, '123');
		Test.startTest();
		CareDirectLogin.login(loginVO.Customer__r.Mobile_Preferred__pc, loginVO.Registration_No__c, code);
		Test.stopTest();
		System.assert(RestContext.response.statusCode >= 400);
	}
}