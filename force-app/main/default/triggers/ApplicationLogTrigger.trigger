trigger ApplicationLogTrigger on ApplicationLog__c (after insert) {
    TriggerRun.run(new ApplicationLogTriggerHandler());
}