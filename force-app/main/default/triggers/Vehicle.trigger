trigger Vehicle on Vehicle__c (before update,after insert, after update) {
    TriggerRun.run(new VehicleTriggerHandler());
}