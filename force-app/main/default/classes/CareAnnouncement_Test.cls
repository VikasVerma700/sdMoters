@isTest
private class CareAnnouncement_Test {

  @isTest
  public static void testAnnouncement() {
    List<ACP_Announcement__c> annList = TestFactory.genAnnouncement(1, false);
    annList[0].Active__c = true;
    annList[0].Company__c = '028';
    insert annList;
    RestRequest req = new RestRequest();
    req.params.put('cmp', '028');
    RestContext.request = req;
    RestContext.response = new RestResponse();
    Test.startTest();
    CareAnnouncement.getAnnouncement();
    List<String> rv = (List<String>) JSON.deserialize(RestContext.response.responseBody.toString(), List<String>.class);
    System.assertEquals(rv.size(), 1);
    Test.stopTest();
  }
}