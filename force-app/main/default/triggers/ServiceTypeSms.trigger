trigger ServiceTypeSms on ServiceTypeSms__c (before insert, before update) {
	TriggerRun.run(new ServiceTypeSmsHandler());
}