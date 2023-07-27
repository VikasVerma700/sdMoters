@IsTest public with sharing class MobyApiBase_Test {

	@TestSetup public static void makeData(){
		TestFactory.getCompany('028');
		List<String> apiSetups = new List<String> { 
			'MobyMyUat Username', 'MobyMyUat Password', 'MobyMyUat Endpoint',
			'MobyMyPrd Username', 'MobyMyPrd Password', 'MobyMyPrd Endpoint'
		};
		List<API_Setup__c> setupList = new List<API_Setup__c>();
		for (String s : apiSetups) {
			setupList.add(new API_Setup__c(Name = s, Value__c = 'Test'));
		}
		insert setupList;
	}

	@IsTest public static void testLogin() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.MOBY_API_Mock(200));
		Test.startTest();
		MobyApiBase.MobyAuthResponse response = MobyApiBase.Login();
		Test.stopTest();
		System.assertNotEquals(null, response, 'MobyAuthResponse is null.');
		System.assertEquals(true, response.IsAuthenticated, 'IsAuthenticated is false.');
	}
	@IsTest public static void testLoginFail() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.MOBY_API_Mock(400));
		Test.startTest();
		MobyApiBase.MobyAuthResponse response = MobyApiBase.Login();
		Test.stopTest();
		System.assertNotEquals(null, response, 'MobyAuthResponse is null.');
		System.assertEquals(false, response.IsAuthenticated, 'IsAuthenticated is not false.');
	}
}