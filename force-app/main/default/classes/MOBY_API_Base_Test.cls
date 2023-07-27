@IsTest
public class MOBY_API_Base_Test {

	@TestSetup
	public static void makeData() {
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

	@IsTest
	public static void testLogin() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.MOBY_API_Mock(200));
		Test.startTest();
		MOBY_API_Base.MobyLoginResponse resLogin = MOBY_API_Base.Login();
		Test.stopTest();
		System.assertNotEquals(null, resLogin, 'MobyLoginResponse is null.');
		System.assertEquals(true, resLogin.IsAuthenticated, 'IsAuthenticated is false.');
	}
	@IsTest
	public static void testLoginFail() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.MOBY_API_Mock(400));
		Test.startTest();
		MOBY_API_Base.MobyLoginResponse resLogin = MOBY_API_Base.Login();
		Test.stopTest();
		System.assertNotEquals(null, resLogin, 'MobyLoginResponse is null.');
		System.assertEquals(false, resLogin.IsAuthenticated, 'IsAuthenticated is not false.');
	}
}