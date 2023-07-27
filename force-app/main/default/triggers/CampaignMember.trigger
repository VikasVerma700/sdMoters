trigger CampaignMember on CampaignMember (before insert, before update, before delete, after insert, after update, after delete) {
	TriggerRun.run(new CampaignMemberTriggerHandler());
}