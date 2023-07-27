@isTest
private class CareEnquiry_Test {

  @IsTest
  public static void testEnquiry() {
    List<Enquiry_Type__c> enqList = new List<Enquiry_Type__c>();
    Enquiry_Type__c actual = TestFactory.genEnquiryType('test1', false);
    enqList.add(actual);
    Enquiry_Type__c enqCmp = TestFactory.genEnquiryType('test2', false);
    enqCmp.Company__c = '03';
    enqList.add(enqCmp);
    Enquiry_Type__c enqActive = TestFactory.genEnquiryType('test3', false);
    enqActive.Active__c = false;
    enqList.add(enqActive);
    insert enqList;
    RestContext.response = new RestResponse();
    RestContext.request = new RestRequest();
    RestContext.request.params.put('cmp', '028');
    Test.startTest();
    CareEnquiry.getEnquiryTypes();
    Test.stopTest();
    List<CareEnquiry.Enq> rv = (List<CareEnquiry.Enq>) JSON.deserialize(RestContext.response.responseBody.toString(), List<CareEnquiry.Enq>.class);
    System.assertEquals(rv.size(), 1);
    System.assertEquals(rv[0].Name, 'test1');
  }
}