Trigger Opportunity on Opportunity (after insert, after update, before insert, before update, before delete, after delete) {
	TriggerRun.run(new OpportunityHandler());
}