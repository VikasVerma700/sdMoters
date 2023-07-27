trigger Campaign on Campaign (before insert, before update, before delete, after insert, after update, after delete) {
	TriggerRun.run(new CampaignTriggerHandler());
}