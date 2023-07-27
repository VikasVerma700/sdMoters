@IsTest
private class CareVerify_Test {
	@TestSetup
	static void makeData() {
		List<Account> accList = TestFactory.genAccount(2, true);
		/** M3 Tech WS setup */
		M3TechApiWrapper_Test.setup();
	}

	@IsTest
	private static void testVerify() {
		RestContext.response = new RestResponse();
		String cmp = '028';
		List<Account> accList = [SELECT Id, Mobile_Preferred__pc FROM Account LIMIT 2];
		Account verifyAcc = accList[0];
		Account dupAcc = accList[1];
		verifyAcc.Mobile_Preferred__pc = dupAcc.Mobile_Preferred__pc;
		CareToken.VerificationResp verifyResp = CareToken.issuePartialToken(cmp, '', verifyAcc, DateTime.now());
		String code = CareToken.generateVerificationCode(verifyAcc.Id, DateTime.now());
		Test.startTest();
		CareVerify.verify(verifyResp.token, code);
		Test.stopTest();
		Account checkVerifyAcc = [SELECT Id, Mobile_Preferred__pc, X2FA_Verified_List__c FROM Account WHERE Id = :verifyAcc.Id];
		system.debug('checkVerifyAcc: ' + JSON.serialize(checkVerifyAcc));
		system.debug(checkVerifyAcc.X2FA_Verified_List__c);
		System.assertEquals(checkVerifyAcc.Mobile_Preferred__pc, verifyAcc.Mobile_Preferred__pc);
		Set<String> verifyList = new Set<String>(checkVerifyAcc.X2FA_Verified_List__c.split(';'));
		System.assert(verifyList.contains(cmp));
		Account checkDupAcc = [SELECT Id, Mobile_Preferred__pc FROM Account WHERE Id = :dupAcc.Id];
		System.assertEquals(checkDupAcc.Mobile_Preferred__pc, 'CRM');
		CareLogin.LoginResp loginResp = (CareLogin.LoginResp) JSON.deserialize(RestContext.response.responseBody.toString(), CareLogin.LoginResp.class);
		System.assert(!String.isBlank(loginResp.token));
		System.assert(CareToken.parseToken(loginResp.token).isVerified);
	}

	@IsTest
	private static void testErrVerify() {
		RestContext.response = new RestResponse();
		String cmp = '028';
		List<Account> accList = [SELECT Id, Mobile_Preferred__pc FROM Account LIMIT 2];
		Account verifyAcc = accList[0];
		Account dupAcc = accList[1];
		verifyAcc.Mobile_Preferred__pc = dupAcc.Mobile_Preferred__pc;
		CareToken.VerificationResp verifyResp = CareToken.issuePartialToken(cmp, '', verifyAcc, DateTime.now());
		Test.startTest();
		CareVerify.verify(verifyResp.token, '12345678');
		Test.stopTest();
		Account checkVerifyAcc = [SELECT Id, Mobile_Preferred__pc, X2FA_Verified_List__c FROM Account WHERE Id = :verifyAcc.Id];
		System.assertNotEquals(checkVerifyAcc.Mobile_Preferred__pc, verifyAcc.Mobile_Preferred__pc);
		Account checkDupAcc = [SELECT Id, Mobile_Preferred__pc FROM Account WHERE Id = :dupAcc.Id];
		System.assertEquals(checkDupAcc.Mobile_Preferred__pc, dupAcc.Mobile_Preferred__pc);
	}
}