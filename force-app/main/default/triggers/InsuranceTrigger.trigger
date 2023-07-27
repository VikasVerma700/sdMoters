trigger InsuranceTrigger on Insurance_Policy__c (after update, before insert, after insert, before update) {
	Global_Trigger_Settings__c csSettings = Global_Trigger_Settings__c.getValues('Insurance Policy');
	if (csSettings == null || !csSettings.Activated__c) { return; }
	if (Trigger.isBefore) {
		if (Trigger.isUpdate && TriggerHelper.bBeforeUpdateRun != true) {
			InsuranceHandler.updateVO(Trigger.new);
			InsuranceHandler.assignUnderwriter(Trigger.new);
			TriggerHelper.bBeforeUpdateRun = true;
		}
	} else {
		if (Trigger.isInsert) {
			InsuranceHandler.createNewTransaction(Trigger.new);
			InsuranceHandler.createNewUWTask(Trigger.new);
			if ((TriggerHelper.bFutureCallRun == null || !TriggerHelper.bFutureCallRun) && !System.isFuture()) {
				// call the AXA API for auto submission
				//AXA_API.futureSubmit(new List<Id>(Trigger.newMap.keySet()));
				TriggerHelper.bFutureCallRun = true;
			}
		}
		if (Trigger.isUpdate) {
			InsuranceHandler.createPolicyReceivedTask(Trigger.new);
		}
	}
}