@IsTest
private class CareRegister_Test {
	@TestSetup
	static void makeData() {
		TestFactory.genAccount(1, true);
		/** M3 Tech WS setup */
		M3TechApiWrapper_Test.setup();
	}

	@IsTest
	private static void testRegister() {
		Account acc = [SELECT Id FROM Account LIMIT 1];
		String mobile = '81001660';
		RestContext.response = new RestResponse();
		Test.setMock(WebServiceMock.class, new TestWSMock.M3TechAPI_Mock('success'));
		CareToken.RegistrationResp regResp = CareToken.issuePartialTokenForReg('028', '', acc, DateTime.now());
		Test.startTest();
		CareRegister.register(regResp.token, mobile);
		Test.stopTest();
		CareToken.VerificationResp testResp = (CareToken.VerificationResp) JSON.deserialize(RestContext.response.responseBody.toString(),
																							CareToken.VerificationResp.class);
		CareToken.AdditionalClaims claims = CareToken.parseToken(testResp.token);
		System.assertEquals(claims.mobile, mobile);
	}

	@IsTest
	private static void testRegErr() {
		Account acc = [SELECT Id FROM Account LIMIT 1];
		RestContext.response = new RestResponse();
		CareToken.RegistrationResp regResp = CareToken.issuePartialTokenForReg('028', '', acc, DateTime.now());
		Test.startTest();
		CareRegister.register(regResp.token, '');
		Test.stopTest();
		System.assertEquals(RestContext.response.statusCode, 400);
	}
}