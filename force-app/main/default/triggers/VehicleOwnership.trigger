trigger VehicleOwnership on Vehicle_Ownership__c ( after update) {
    TriggerRun.run(new VehicleOwnershipHandler());
}