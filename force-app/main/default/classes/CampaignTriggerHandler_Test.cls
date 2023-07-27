@isTest
public with sharing class CampaignTriggerHandler_Test {

    @TestSetup
    static void makeData(){
        TestFactory.genCampaign(1, true);
        TestFactory.genTriggerSettings(CampaignTriggerHandler.TRIG_SETTING, true);
    }

    @isTest
    static void testInsert() {
        Test.startTest();
        Campaign cmpg = TestFactory.genCampaign(1, true)[0];
        Test.stopTest();
        System.assert(cmpg.CheckInUrl__c != '');
        System.assert(cmpg.NominationUrl__c != '');
    }

    @isTest
    static void testUpdate() {
        Test.startTest();
        Campaign cmpg = [SELECT Id, Name, Description, CheckInUrl__c, NominationUrl__c FROM Campaign LIMIT 1];
        cmpg.Description = 'perform update';
		cmpg.CheckInUrl__c = '';
		cmpg.NominationUrl__c = '';
        update cmpg;
        Test.stopTest();
        Campaign cmpg2 = [SELECT Id, Name, Description, CheckInUrl__c, NominationUrl__c FROM Campaign WHERE Id = :cmpg.Id LIMIT 1];
        System.assert(cmpg2.CheckInUrl__c != '');
        System.assert(cmpg2.NominationUrl__c != '');
    }
}