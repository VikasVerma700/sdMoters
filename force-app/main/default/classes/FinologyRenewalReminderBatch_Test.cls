@isTest
public without sharing class FinologyRenewalReminderBatch_Test {
    @isTest 
    static void test() {
        Vehicle_Ownership__c ownership = TestFactory.genVO(1, false)[0];
        insert ownership;
       // Insurance_Policy__c policy = TestFactory.genInsurancePolicy(1, false)[0];
        Insurance_Policy__c plc = new Insurance_Policy__c();
        plc.Vehicle_Ownership__c = ownership.Id;
        plc.Active__c =true;
        plc.Policy_Expiry_Date__c = system.today();
        insert plc;
        
       // policy.Ext_Underwriter__c = null;
        //insert policy;
        Test.startTest();
        FinologyRenewalReminderBatch renewal = new FinologyRenewalReminderBatch('IC', '47400');
        Id batchId = Database.executeBatch(renewal);
        Test.stopTest();        
       // System.assert(!renewal.successRecordsId.IsEmpty(), 'Batch run Successfully.');
    }
}