Trigger ESATrigger on ExternalSystemAccount__c (before insert, before update, after update){
    TriggerRun.run(new ESATriggerHandler());
}