@isTest
private class CareProviders_Test {
  @isTest
  public static void testProviders() {
    List<Service_Quota__c> wsQ = TestFactory.genServiceQuota(2, true);
    List<String> types = new List<String>();
    for (Service_Quota__c q : wsQ) { types.add(q.Type__c); }
    Service_Slot__c ss = [SELECT Id, Workshop__c, Company__r.Name, Active_Date__c FROM Service_Slot__c WHERE Id = :wsQ[0].Service_Slot__c];
    update (new Workshop__c(Id = ss.Workshop__c, Service_Centre_Name__c = 'TEST CENTRE', Allow_Appt_External__c = true));

    List<Service_Quota__c> csaQ = TestFactory.genCSAServiceQuota(wsQ.size(), false);
    for (Integer i = 0; i < wsQ.size(); i++) {
      csaQ[i].Type__c = wsQ[i].Type__c;
    }
    insert csaQ;
    update (new Employee_Shift__c(Id = csaQ[0].Employee_Shift__c, Workshop__c = ss.Workshop__c, Active_Date__c = ss.Active_Date__c));

    ServiceApptBooking.APIBooking booking = new ServiceApptBooking.APIBooking();
    booking.cmp = ss.Company__r.Name;
    booking.division = 'test';
    booking.selectedTypes = types;
    RestContext.request = new RestRequest();
    RestContext.response = new RestResponse();
    RestContext.request.requestBody = Blob.valueOf(JSON.serialize(booking));

    Test.startTest();
    CareProviders.providers();
    Test.stopTest();
    CareProviders.ProviderResp resp = (CareProviders.ProviderResp) JSON.deserialize(RestContext.response.responseBody.toString(),
                                                                                    CareProviders.ProviderResp.class);
    System.assertEquals(resp.wsList.size(), 1);
    System.assertEquals(resp.csaList.size(), 1);
  }
}