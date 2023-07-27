@isTest
private class CareCalendar_Test {
  @isTest
  public static void testCSACalendar() {
    List<Service_Quota__c> curQ = TestFactory.genCSAServiceQuota(2, true);
    List<String> types = new List<String>();
    for (Service_Quota__c q : curQ) { types.add(q.Type__c); }
    Employee_Shift__c es = [SELECT Id, Workshop__c, Workshop__r.Id, Workshop__r.Name, Workshop__r.Appointment_Interval__c, Workshop__r.Auto_Assign_CSA__c,
                            Company__r.Name, Active_Date__c, Employee_Master__c FROM Employee_Shift__c WHERE Id = :curQ[0].Employee_Shift__c];
    ServiceApptBooking.APIBooking curBooking = new ServiceApptBooking.APIBooking();
    curBooking.csaId = es.Employee_Master__c;
    curBooking.cmp = es.Company__r.Name;
    curBooking.wsId = es.Workshop__c;
    curBooking.selectedTypes = types;
    CareCalendar.CalendarReq req = new CareCalendar.CalendarReq();
    req.booking = curBooking;
    req.startDate = es.Active_Date__c;
    req.endDate = es.Active_Date__c;
    RestContext.response = new RestResponse();
    RestContext.request = new RestRequest();
    RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
    Test.startTest();
    CareCalendar.calendar();
    Test.stopTest();
    Map<Date, CareCalendar.Cal> rv = (Map<Date, CareCalendar.Cal>) JSON.deserialize(RestContext.response.responseBody.toString(),
                                                                                    Map<Date, CareCalendar.Cal>.class);
    System.assertEquals(rv.size(), 1);
    CareCalendar.Cal cur;
    for (Date d : rv.keySet()) {
      cur = rv.get(d);
      System.assert(cur.slots.size() <= CareCalendar.BMW_MAX_SLOT);
    }
  }

  @isTest
  public static void testWSCalendar() {
    List<Service_Quota__c> curQ = TestFactory.genServiceQuota(2, true);
    List<String> types = new List<String>();
    for (Service_Quota__c q : curQ) { types.add(q.Type__c); }
    Service_Slot__c ss = [SELECT Id, Workshop__c, Workshop__r.Id, Workshop__r.Name, Workshop__r.Appointment_Interval__c, Workshop__r.Auto_Assign_CSA__c,
                          Company__r.Name, Active_Date__c FROM Service_Slot__c WHERE Id = :curQ[0].Service_Slot__c];
    ServiceApptBooking.APIBooking curBooking = new ServiceApptBooking.APIBooking();
    curBooking.cmp = ss.Company__r.Name;
    curBooking.wsId = ss.Workshop__c;
    curBooking.selectedTypes = types;
    CareCalendar.CalendarReq req = new CareCalendar.CalendarReq();
    req.booking = curBooking;
    req.startDate = ss.Active_Date__c;
    req.endDate = ss.Active_Date__c;
    RestContext.response = new RestResponse();
    RestContext.request = new RestRequest();
    RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
    Test.startTest();
    CareCalendar.calendar();
    Test.stopTest();
    Map<Date, CareCalendar.Cal> rv = (Map<Date, CareCalendar.Cal>) JSON.deserialize(RestContext.response.responseBody.toString(),
                                                                                    Map<Date, CareCalendar.Cal>.class);
    System.assertEquals(rv.size(), 1);
    CareCalendar.Cal cur;
    for (Date d : rv.keySet()) {
      cur = rv.get(d);
      System.assert(cur.slots.size() <= CareCalendar.BMW_MAX_SLOT);
    }
  }
}