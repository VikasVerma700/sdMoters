@isTest
private class CarePDPA_Test {
  @TestSetup
  public static void setup() {
    PDPA_Test.makeData();

    List<Force_com_Site_URL__c> sites = new List<Force_com_Site_URL__c>();
    sites.add(TestFactory.genForceSite('Sandbox', false));
    sites.add(TestFactory.genForceSite('Production', false));
    insert sites;
  }

  @isTest
  public static void testGetTC() {
    RestContext.response = new RestResponse();
    RestContext.request = new RestRequest();
    RestContext.request.params.put('cmp', '028');
    Test.startTest();
    CarePDPA.getTerms();
	Test.stopTest();
    CarePDPA.PDPATerms rv = (CarePDPA.PDPATerms) JSON.deserialize(RestContext.response.responseBody.toString(), CarePDPA.PDPATerms.class);
    System.assert(rv.terms != null);
  }

  @isTest
  public static void testPDPA() {
    Account acc = TestFactory.genAccount(1, false)[0];
    acc.Home_Email__c = 'test@example.com';
    acc.Active_Home__c = true;
    insert acc;

    RestContext.response = new RestResponse();
    Test.startTest();
    CarePDPA.updatePDPA(acc.Id,  '028', true, true, true, DateTime.now(), 'SFDC999');
    Test.stopTest();
    List<Local_Legislation__c> leg = [SELECT Id FROM Local_Legislation__c WHERE Account_Name__c = :acc.Id];
    System.assertEquals(leg.size(), 1);
    // check debug log for email queue
  }
  @isTest
  public static void testPDPANoEmail() {
    Account acc = TestFactory.genAccount(1, false)[0];
    acc.Home_Email__c = 'test@example.com';
    acc.Active_Home__c = false;
    insert acc;

    RestContext.response = new RestResponse();
    Test.startTest();
    CarePDPA.updatePDPA(acc.Id,  '028', true, true, true, DateTime.now(), 'SFDC999');
    Test.stopTest();
    List<Local_Legislation__c> leg = [SELECT Id FROM Local_Legislation__c WHERE Account_Name__c = :acc.Id];
    System.assertEquals(leg.size(), 1);
    // check debug log for email queue
  }
}