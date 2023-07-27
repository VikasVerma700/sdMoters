trigger UserDepotAccess on UserDepotAccess__c (before insert,before update) {

    TriggerRun.run(new UserDepotAccessTriggerHandler());
}