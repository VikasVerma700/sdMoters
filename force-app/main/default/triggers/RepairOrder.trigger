trigger RepairOrder on ServiceOrder__c (after delete, after insert, after update, before insert, before update) {
	TriggerRun.run(new RepairOrderHandler());
}