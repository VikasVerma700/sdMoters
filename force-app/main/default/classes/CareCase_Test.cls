@isTest
private class CareCase_Test {
  @TestSetup
  public static void setup() {
    Test.startTest();
    List<Global_Trigger_Settings__c> trigList = new List<Global_Trigger_Settings__c>();
    Global_Trigger_Settings__c vehTrig = TestFactory.genTriggerSettings('Vehicle', false);
    vehTrig.Activated__c = false;
    trigList.add(vehTrig);
    trigList.add(TestFactory.genTriggerSettings('Vehicle Ownership', false));
    insert trigList;
    Test.stopTest();
  }

  @isTest
  public static void testCase() {
    Vehicle_Ownership__c vo = TestFactory.genVO(1, true)[0];
    RestRequest req = new RestRequest();
    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    CareCase.newCase(vo.Id, 'Test', '028');
    Test.stopTest();
    List<Case> check = [SELECT Id, Type FROM Case WHERE AccountId = :vo.Customer__c AND Enquiry_Type__c = 'Test'];
    System.assertEquals(1, check.size());
    System.assertEquals(check[0].Type, 'Aftersales App');
  }
}