@IsTest
public class CustAppLocation_Test {
	@IsTest
	static void testLocation() {
		Test.startTest();
		CustAppLocation.LocationCls loc = new CustAppLocation.LocationCls('No1', 'B1', 'test', 1, 2);
		Test.stopTest();
		System.assertEquals(loc.address, 'test');
	}
}