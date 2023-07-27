@IsTest
public with sharing class FinologyVehicleInfo_Test {
	@IsTest
	public static void testgetVehicleInfoAPI() {
        Vehicle_Ownership__c ownership = TestFactory.genVO(1, false)[0];
        insert ownership;

		Test.setMock(HttpCalloutMock.class, new FinologyMockHttpResponseGenerator());
        
		Test.startTest();
		String res = FinologyVehicleInfo.getVehicleInfo(ownership.Registration_No__c, 'IC','47400', false);
		Test.stopTest();
        
		System.assert(!String.isBlank(res), 'Test API');
        System.assertEquals(res, 'this is test API', 'msg not null');
	}
}