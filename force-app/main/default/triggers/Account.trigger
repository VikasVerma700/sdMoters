Trigger Account on Account (after insert, after update, before insert, before update, before delete, after delete) {
	TriggerRun.run(new AccountHandler());
	//Query from custom settings
/*	Global_Trigger_Settings__c csSettings = Global_Trigger_Settings__c.getValues('Account');
	if (csSettings == null || !csSettings.Activated__c) return;

	if (TriggerHelper.currentUserInfo == null) {
		TriggerHelper.currentUserInfo = [SELECT Id, Company__c, ProfileId, Profile.Name, UserRoleId, UserRole.Name, Email
										 FROM User WHERE Id = :Userinfo.getUserId() LIMIT 1];
	}

	if (Trigger.isBefore) {
		if (Trigger.isDelete) {
			AccountHandler.checkExistOppOrTD(trigger.old);
		} else {
			if (TriggerHelper.bTriggerRun == null) {
				AccountHandler.updateModelInterest(trigger.new, trigger.old);
				AccountHandler.Account_CheckMobilePreferredDup(trigger.new);
				AccountHandler.accOwnerAssignment(trigger.new);
				TriggerHelper.bTriggerRun = true;
			}
		}
	} else {
		if (!System.isFuture() && !System.isQueueable() && !System.isBatch() && TriggerHelper.bFutureCallRun == null) {
			if (Trigger.isInsert) {
				if (Limits.getLimitQueueableJobs() > Limits.getQueueableJobs() && !Test.isRunningTest()) {
					System.enqueueJob(new SalesContactCheck_Queue(Trigger.new));
				}
			}
			AccountHandler.CreateGDMSAccountNo_and_Opp(Trigger.new, TriggerHelper.currentUserInfo);
			TriggerHelper.bFutureCallRun = true;
		}
	}*/
}