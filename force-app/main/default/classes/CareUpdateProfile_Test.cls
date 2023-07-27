@isTest
private class CareUpdateProfile_Test {
  @isTest
  public static void testUpdProfile() {
    List<Account> accList = TestFactory.genAccount(2, false);
    accList[0].Active_Home__c = true;
    accList[0].Home_Email__c = 'test@example.com';
    accList[0].Office_Email__c = 'test1@example.com';
    insert accList;
    RestContext.response = new RestResponse();
System.debug(JSON.serialize(accList));
    Test.startTest();
    CareUpdateProfile.updateProfile(accList[1].Mobile_Preferred__pc, 'test1@example.com', accList[0].Id);
     
    Map<Id, Account> checkAcc = new Map<Id, Account>([SELECT Id, Default_Email__c, Active_Work__c, Mobile_Preferred__pc FROM Account WHERE Id IN :accList]);
      System.debug('checkAcc : '+checkAcc.values());
      System.debug('checkAcc.get(accList[0].Id).Mobile_Preferred__pc : '+checkAcc.get(accList[0].Id).Mobile_Preferred__pc);
      System.debug('checkAcc.get(accList[1].Id).Mobile_Preferred__pc : '+checkAcc.get(accList[1].Id).Mobile_Preferred__pc);

    System.assertEquals(checkAcc.get(accList[0].Id).Mobile_Preferred__pc, accList[1].Mobile_Preferred__pc);
    System.assert(checkAcc.get(accList[0].Id).Active_Work__c);
    System.assertEquals(checkAcc.get(accList[1].Id).Mobile_Preferred__pc, 'CRM');
  }

  @isTest
  public static void testUpdEmail() {
    List<Account> accList = TestFactory.genAccount(1, false);
    accList[0].Active_Home__c = true;
    accList[0].Home_Email__c = 'test@example.com';
    accList[0].Office_Email__c = 'test1@example.com';
    insert accList;
    RestContext.response = new RestResponse();

    Test.startTest();
    CareUpdateProfile.updateProfile(accList[0].Mobile_Preferred__pc, 'test2@example.com', accList[0].Id);
    Account checkAcc = [SELECT Id, Default_Email__c, Mobile_Preferred__pc FROM Account WHERE Id = :accList[0].Id];
    System.assertEquals(checkAcc.Default_Email__c, 'test2@example.com');
  }

  @isTest
  public static void testUpdEmailOther() {
    List<Account> accList = TestFactory.genAccount(1, false);
    accList[0].Active_Other__c = true;
    accList[0].Other_Email__c = 'test@example.com';
    insert accList;
    RestContext.response = new RestResponse();

    Test.startTest();
    CareUpdateProfile.updateProfile(accList[0].Mobile_Preferred__pc, 'test2@example.com', accList[0].Id);
    Account checkAcc = [SELECT Id, Default_Email__c, Mobile_Preferred__pc FROM Account WHERE Id = :accList[0].Id];
    System.assertEquals(checkAcc.Default_Email__c, 'test2@example.com');
  }
}