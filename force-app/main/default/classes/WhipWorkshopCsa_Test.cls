@isTest private class WhipWorkshopCsa_Test {
	@TestSetup static void makeData() {
		List<Service_Quota__c> wsQ = TestFactory.genServiceQuota(2, true);
		List<String> types = new List<String>();
		for (Service_Quota__c q : wsQ) { types.add(q.Type__c); }
		Service_Slot__c ss = [SELECT Id, Workshop__c, Company__r.Name, Active_Date__c FROM Service_Slot__c WHERE Id = :wsQ[0].Service_Slot__c];
		update (new Workshop__c(Id = ss.Workshop__c, Service_Centre_Name__c = 'TEST CENTRE', AllowInWhip__c = true));

		List<Service_Quota__c> csaQ = TestFactory.genCSAServiceQuota(wsQ.size(), false);
		for (Integer i = 0; i < wsQ.size(); i++) { csaQ[i].Type__c = wsQ[i].Type__c; }
		insert csaQ;
		update (new Employee_Shift__c(Id = csaQ[0].Employee_Shift__c, Workshop__c = ss.Workshop__c, Active_Date__c = ss.Active_Date__c));
	}

	@isTest static void getWorkshopCsa_TestException() {
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		Test.startTest();
		WhipWorkshopCsa.getWorkshopCsa();
		Test.stopTest();
		WhipWorkshopCsa.WorkshopCsaResp resp = (WhipWorkshopCsa.WorkshopCsaResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipWorkshopCsa.WorkshopCsaResp.class);
		System.assertNotEquals(resp.err, null);
	}

	@isTest static void getWorkshopCsa_TestType() {
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		String[] types = new List<String>();
		for (Service_Quota__c q : [SELECT Id, Type__c FROM Service_Quota__c]) { types.add(q.Type__c); }
		RestContext.request.params.put('type', types[0]);
		Test.startTest();
		WhipWorkshopCsa.getWorkshopCsa();
		Test.stopTest();
		WhipWorkshopCsa.WorkshopCsaResp resp = (WhipWorkshopCsa.WorkshopCsaResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipWorkshopCsa.WorkshopCsaResp.class);
		system.debug(resp);
		System.assertNotEquals(resp.csaList.size(), null);
	}

	@isTest static void getWorkshopCsa_Test() {
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		String[] types = new List<String>();
		for (Service_Quota__c q : [SELECT Id, Type__c FROM Service_Quota__c]) { types.add(q.Type__c); }
		RestContext.request.params.put('type', types[0]);
		String[] workshops = new List<String>();
		for (Workshop__c w :[SELECT Id, Name FROM Workshop__c]) { workshops.add(w.Name); }
		RestContext.request.params.put('workshop', workshops[0]);
		Test.startTest();
		WhipWorkshopCsa.getWorkshopCsa();
		Test.stopTest();
		WhipWorkshopCsa.WorkshopCsaResp resp = (WhipWorkshopCsa.WorkshopCsaResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipWorkshopCsa.WorkshopCsaResp.class);
		system.debug(resp);
		System.assertNotEquals(resp.csaList.size(), null);
	}
}