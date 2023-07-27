@isTest private class WhipWorkshop_Test {
	@TestSetup static void makeData() {
		List<Service_Quota__c> wsQ = TestFactory.genServiceQuota(2, true);
		List<String> types = new List<String>();
		for (Service_Quota__c q : wsQ) { types.add(q.Type__c); }
		Service_Slot__c ss = [SELECT Id, Workshop__c, Company__r.Name, Active_Date__c FROM Service_Slot__c WHERE Id = :wsQ[0].Service_Slot__c];
		update (new Workshop__c(Id = ss.Workshop__c, Service_Centre_Name__c = 'TEST CENTRE', AllowInWhip__c = true));
	
		List<Service_Quota__c> csaQ = TestFactory.genCSAServiceQuota(wsQ.size(), false);
		for (Integer i = 0; i < wsQ.size(); i++) {
		  csaQ[i].Type__c = wsQ[i].Type__c;
		}
		insert csaQ;
		update (new Employee_Shift__c(Id = csaQ[0].Employee_Shift__c, Workshop__c = ss.Workshop__c, Active_Date__c = ss.Active_Date__c));
	}

	@isTest static void getWorkshop_TestException() {
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		Test.startTest();
		WhipWorkshop.getWorkshop();
		Test.stopTest();
		WhipWorkshop.WorkshopResp resp = (WhipWorkshop.WorkshopResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipWorkshop.WorkshopResp.class);
		System.assertNotEquals(resp.err, null);
	}
	@isTest static void getWorkshop_TestType() {
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		String[] types = new List<String>();
		for (Service_Quota__c q : [SELECT Id, Type__c FROM Service_Quota__c]) { types.add(q.Type__c); }
		RestContext.request.params.put('type', types[0]);
		Test.startTest();
		WhipWorkshop.getWorkshop();
		Test.stopTest();
		WhipWorkshop.WorkshopResp resp = (WhipWorkshop.WorkshopResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipWorkshop.WorkshopResp.class);
		System.assertNotEquals(resp.workshopList.size(), null);
	}
}