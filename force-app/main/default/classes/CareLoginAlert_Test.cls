@isTest
private class CareLoginAlert_Test {
	@isTest
	public static void testLoginAlert() {
		List<ACP_Login_Alert__c> annList = TestFactory.genLoginAlert(3, false);
		annList[0].Active__c = false;
		annList[1].Workshop__c = 'W9,WX';
		annList[1].Company__c = '03';
		insert annList;
		RestRequest req = new RestRequest();
		req.params.put('cmp', '028');
		RestContext.request = req;
		RestContext.response = new RestResponse();
		Test.startTest();
		CareLoginAlert.getLoginAlert();
		CareLoginAlert.LoginAlertResp rv = (CareLoginAlert.LoginAlertResp) JSON.deserialize(RestContext.response.responseBody.toString(),
											CareLoginAlert.LoginAlertResp.class);
		System.assert(!String.isBlank(rv.body));

		req.params.put('cmp', '03');
		req.params.put('division', 'QUICK LANE');
		RestContext.request = req;
		CareLoginAlert.getLoginAlert();
		rv = (CareLoginAlert.LoginAlertResp) JSON.deserialize(RestContext.response.responseBody.toString(),
				CareLoginAlert.LoginAlertResp.class);
		System.assert(!String.isBlank(rv.body));
		Test.stopTest();
	}
}