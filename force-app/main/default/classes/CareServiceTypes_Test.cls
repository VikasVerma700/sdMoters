@isTest
private class CareServiceTypes_Test {
	@TestSetup
	public static void setup() {
		List<Service_Type__c> stList = new List<Service_Type__c>();
		// Should appear for PML W1 only
		Service_Type__c pmlWS = TestFactory.genServiceType('AB A1', false);
		pmlWS.Workshop__c = 'A1';
		stList.add(pmlWS);
		// Should appear if no workshop specified for PML
		Service_Type__c pmlEmpty = TestFactory.genServiceType('AB No Workshop', false);
		stList.add(pmlEmpty);
		// Should appear if no workshop specified for PML and should appear for all VAL
		Service_Type__c multiCmp = TestFactory.genServiceType('Multiple Company', false);
		multiCmp.Company__c = '028, 02';
		stList.add(multiCmp);
		// Should never appear for CareApp
		Service_Type__c noExternal = TestFactory.genServiceType('No External', false);
		noExternal.Allow_External__c = false;
		stList.add(noExternal);
		// Only valid for PML VIP
		Service_Type__c vipST = TestFactory.genServiceType('VIP ST', false);
		vipST.VIP__c = true;
		stList.add(vipST);
		insert stList;

	}

	@IsTest
	public static void testServices() {
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		RestContext.request.params.put('cmp', '028');
		Test.startTest();
		CareServiceTypes.getTypes();
		Test.stopTest();
		List<CareServiceTypes.ServiceType> rv = (List<CareServiceTypes.ServiceType>) JSON.deserialize(RestContext.response.responseBody.toString(),
																									  List<CareServiceTypes.ServiceType>.class);
		System.assertEquals(rv.size(), 2);
		System.assertEquals(rv[0].Name, 'AB No Workshop');
		System.assertEquals(rv[1].Name, 'Multiple Company');
	}


	@IsTest
	public static void testVIP() {
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		RestContext.request.params.put('cmp', '028');
		RestContext.request.params.put('acctStatus', 'VIP');
		Test.startTest();
		CareServiceTypes.getTypes();
		Test.stopTest();
		List<CareServiceTypes.ServiceType> rv = (List<CareServiceTypes.ServiceType>) JSON.deserialize(RestContext.response.responseBody.toString(),
																									  List<CareServiceTypes.ServiceType>.class);
		System.debug('bengdebug: ' + rv);
		System.assertEquals(rv.size(), 3);
		System.assertEquals('AB No Workshop', rv[0].Name);
		System.assertEquals('Multiple Company', rv[1].Name);
		System.assertEquals('VIP ST', rv[2].Name);

	}
}