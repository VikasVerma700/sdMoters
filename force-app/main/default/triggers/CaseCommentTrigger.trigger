trigger CaseCommentTrigger on CaseComment (after insert, after update) {
	if (u.trig('i')) {
		List<Id> cids = new List<Id>();
		for (CaseComment cc : Trigger.new) { cids.add(cc.ParentId); }
		string query = 'SELECT ' + String.join(CaseCommon.fields(), ',') + ' FROM Case WHERE Id IN :cids';
		Map<Id, Case> cs = new Map<Id, Case>((List<Case>)Database.query(query));

		/** Prevent Case Comment on Closed Case */
		for (CaseComment cc :Trigger.new) {
			Case cse = cs.get(cc.ParentId);
			if (cse != null && cse.IsClosed) {
				cc.addError('Closed Case cannot be commented upon.');
			}
			
            try { update cse; }
			catch (System.DmlException e) { cc.addError(e.getDmlMessage(0)); }
		}

		Set<Case> caseUpdates = new Set<Case>();
		List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
		
		// save to case

		// for (CaseComment cc : Trigger.new) {
		// 	Case c = cs.get(cc.ParentId);
		// 	c.Last_Case_Comment__c = cc.CommentBody;
		// 	if (c.All_Case_Comments__c == null) { c.All_Case_Comments__c = ''; }
		// 	else { c.All_Case_Comments__c += '\n' + '*'.repeat(32) + '\n'; }
		// 	c.All_Case_Comments__c += cc.CreatedDate.format('yyyy-MM-dd HH:mm') + ' (' + u.usr().Name +'):';
		// 	if (cc.CommentBody.contains('\n')) { c.All_Case_Comments__c += '\n'; }
		// 	c.All_Case_Comments__c += cc.CommentBody;

		// 	try { update c; }
		// 	catch (System.DmlException e) { cc.addError(e.getDmlMessage(0)); }
		// }

		// check if is MD comment & if case higher than MD level

		for (CaseComment cc : Trigger.new) {
			Case c = cs.get(cc.ParentId);
			if (c.EscalationStage__c < 3) { continue; }
			User md = (User) CaseCommon.pref(c, 'managing_director');
			if (u.usr().Id == md.Id){
				u.add(emails, CaseMail.prepareCaseMail(c, CaseActionMdt.CaseAction.new_md_comment, null));
			}
		}

		Messaging.sendEmail(emails);
	}
}