@isTest private class WhipServiceType_Test {
	@TestSetup static void setup() {
		List<Service_Type__c> stList = new List<Service_Type__c>();
		// Should appear for PML W1 only
		Service_Type__c pmlWS = TestFactory.genServiceType('AB A1', false);
		pmlWS.Workshop__c = 'A1';
		pmlWS.AllowInWhip__c = true;
		stList.add(pmlWS);
		// Should appear if no workshop specified for PML
		Service_Type__c pmlEmpty = TestFactory.genServiceType('AB No Workshop', false);
		pmlEmpty.AllowInWhip__c = true;
		stList.add(pmlEmpty);
		// Should appear if no workshop specified for PML and should appear for all VAL
		Service_Type__c multiCmp = TestFactory.genServiceType('Multiple Company', false);
		multiCmp.Company__c = '028, 02';
		multiCmp.AllowInWhip__c = true;
		stList.add(multiCmp);
		// Should never appear for CareApp
		Service_Type__c noExternal = TestFactory.genServiceType('No External', false);
		noExternal.AllowInWhip__c = false;
		stList.add(noExternal);
		// Only valid for PML VIP
		Service_Type__c vipST = TestFactory.genServiceType('VIP ST', false);
		vipST.VIP__c = true;
		stList.add(vipST);
		insert stList;
	}

	@isTest static void WhipServiceType_Test() {
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		RestContext.request.params.put('cmp', '028');
		Test.startTest();
		WhipServiceType.getTypes();
		Test.stopTest();
		WhipServiceType.ServiceTypeResp resp = (WhipServiceType.ServiceTypeResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipServiceType.ServiceTypeResp.class);
		System.assertNotEquals(resp.typeList, null);
	}
}