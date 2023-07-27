trigger SmsTemplate on SmsTemplate__c (before insert, before update) {
	TriggerRun.run(new SmsTemplateHandler());
}