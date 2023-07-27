@IsTest
private class CareToken_Test {
	@TestSetup
	static void makeData() {
		TestFactory.genAccount(1, true);
	}

	@IsTest
	private static void testPartialRegToken() {
		Account acc = [SELECT Id FROM Account LIMIT 1];
		String cmp = '028';
		String div = 'test';
		Test.startTest();
		CareToken.RegistrationResp resp = CareToken.issuePartialTokenForReg(cmp, div, acc, DateTime.now());
		Test.stopTest();
		CareToken.AdditionalClaims claims = CareToken.parseToken(resp.token);
		System.assertEquals(claims.company, cmp);
		System.assertEquals(claims.division, div);
		System.assertEquals(claims.accountId, acc.Id);
	}

	@IsTest
	private static void testPartialToken() {
		Account acc = [SELECT Id, Mobile_Preferred__pc FROM Account LIMIT 1];
		String cmp = '028';
		String div = 'test';
		Test.startTest();
		CareToken.VerificationResp resp = CareToken.issuePartialToken(cmp, div, acc, DateTime.now());
		Test.stopTest();
		CareToken.AdditionalClaims claims = CareToken.parseToken(resp.token);
		System.assertEquals(claims.company, cmp);
		System.assertEquals(claims.division, div);
		System.assertEquals(claims.accountId, acc.Id);
		System.assertEquals(claims.mobile, acc.Mobile_Preferred__pc);
	}

	@IsTest
	private static void testFullJWTToken() {
		Account acc = [SELECT Id, Mobile_Preferred__pc FROM Account LIMIT 1];
		String cmp = '028';
		String div = 'test';
		Test.startTest();
		String token = CareToken.issueJWTToken(cmp, div, acc, DateTime.now());
		Test.stopTest();
		CareToken.AdditionalClaims claims = CareToken.parseToken(token);
		System.assertEquals(claims.company, cmp);
		System.assertEquals(claims.division, div);
		System.assertEquals(claims.accountId, acc.Id);
		System.assertEquals(claims.mobile, acc.Mobile_Preferred__pc);
		System.assert(claims.isVerified);
	}

	@IsTest
	private static void testToken() {
		Account acc = [SELECT Id FROM Account LIMIT 1];
		DateTime now = DateTime.now();
		DateTime prevTimestep = now.addSeconds(-1 * CareToken.TIMESTEP);
		DateTime curBackHalfTimestep = now.addSeconds(CareToken.TIMESTEP / 2 * -1);
		DateTime curForwardHalfTimestep = now.addSeconds(CareToken.TIMESTEP / 2);
		DateTime nextTimestep = now.addSeconds(CareToken.TIMESTEP);
		Test.startTest();
		String curCode = CareToken.generateVerificationCode(acc.Id, now);
		String prevCode = CareToken.generateVerificationCode(acc.Id, prevTimestep);
		String curBackHalfStepCode = CareToken.generateVerificationCode(acc.Id, curBackHalfTimestep);
		String curForwardHalfStepCode = CareToken.generateVerificationCode(acc.Id, curForwardHalfTimestep);
		String nextCode = CareToken.generateVerificationCode(acc.Id, nextTimestep);
		Test.stopTest();
		System.assert(curCode == curBackHalfStepCode || curCode == curForwardHalfStepCode);
		System.assertNotEquals(curCode, prevCode);
		System.assertNotEquals(curCode, nextCode);
		System.assertNotEquals(prevCode, nextCode);
	}
}