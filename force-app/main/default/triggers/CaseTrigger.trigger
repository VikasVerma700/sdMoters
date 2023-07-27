trigger CaseTrigger on Case (before insert, before update, after insert, after update) {
    Global_Trigger_Settings__c settings = Global_Trigger_Settings__c.getInstance('Case');
    if (settings == null || !settings.Activated__c) { return ; }
    datetime now = datetime.now();

    private static Map<String,Company__c> name2Company = new Map<String,Company__c>();
    for(Company__c company: [SELECT Id,Name,MobyCompanyCode__c FROM Company__c]){
        name2Company.put(company.Name, company);
    }
    if (Trigger.isBefore) {
        for (Case c : Trigger.new) {
            Case o;
            
            if (u.trig('u')) { o = Trigger.oldMap.get(c.Id); }

            // required to augment workflow field updates
            if ((u.trig('i') && c.Validated__c) || (u.trig('u') && u.chg('Validated__c', c, o))) { continue; }
            c.Validated__c = u.trig('i') ? true : !o.Validated__c;

        // validation //////////////////////////////////////////////////////////

            // constraint
            try{
				if (u.trig('u') && u.chg('Status', c, o) && c.Status != 'Closed') { c.Status.addError('The case status cannot be changed manually.'); }
				if (u.trig('u') && c.IsEscalated && u.chg('Priority', c, o)) { c.Priority.addError('The case severity cannot be changed as the case has been escalated.'); }
				if (u.trig('u') && u.chg('OwnerId', c, o) && Envir.User_Cur.Profile.Name != 'System Administrator') { c.addError('The case owner cannot be manually changed.'); }
				// prevent ou from changing
				if (u.trig('u') && u.chg('Operating_Unit__c', c, o) && Envir.User_Cur.Profile.Name != 'System Administrator') { c.addError('Operating Unit can not be changed'); }
			}
            catch(Exception e){
                System.debug(e.getStackTraceString());
            }
            // requirements

            // creation

            // draft
            if (c.Draft_Mode__c) {
                if (c.Priority == 'High' || c.Priority == 'Critical') { c.Priority.addError('Draft cases cannot have critical/high priority.'); }
                if (u.trig('u') && u.chg('Draft_Mode__c', c, o)) { c.Draft_Mode__c.addError('Cases cannot be put back into draft mode.'); }
            }

            // closing
            if (u.trig('u') && o.Status == 'Closed' && u.chg('Status', c, o)) { c.addError('Cases cannot be reopened.'); }
            if (c.Status == 'Closed') {
                // if (u.usr().Id != c.OwnerId && !u.usr().Allowed_to_Close_Case__c) { c.addError('Only the case owner or case team members can close this case.'); }
                if (u.trig('u') && o.Status == 'Draft') { c.addError('Please open the case by unchecking Draft Mode first.'); }
                if (u.trig('u') && !u.chg('Status', c, o) && Envir.User_Cur.Profile.Name != 'System Administrator') { c.addError('Closed cases cannot be modified or commented upon.'); }
                // if (u.trig('u') && o.All_Case_Comments__c == '') { c.addError('Cases without comments cannot be closed.'); }
            }

            // stop escalation
            if (c.Stop_Escalation__c) {
                if (c.Stop_Escalation_Till_Date__c == null || u.def(c.Stop_Escalation_Remarks__c, '') == '') { c.addError('Please ensure that the reason and end-date for stopping escalation has been filled in.'); }
                if (u.trig('u') && u.chg('Stop_Escalation__c', c, o) && c.Stop_Escalation_Count__c > 0) { c.addError('Escalation for this case has already been stopped once.'); }
                if (u.trig('u') && u.chg('Stop_Escalation_Till_Date__c', c, o)) {
                    if (c.Stop_Escalation_Till_Date__c < now.date()) { c.Stop_Escalation_Till_Date__c.addError('This cannot be set to an earlier date.'); }
                    if (now.date().daysBetween(c.Stop_Escalation_Till_Date__c) > 10) { c.Stop_Escalation_Till_Date__c.addError('This cannot be more than 10 days from today.'); }
                    if (u.chg('Stop_Escalation_Till_Date__c', c, o) && c.Stop_Escalation_Count__c > 0){ c.Stop_Escalation_Till_Date__c.addError('This date is fixed, no extension allowed!'); }
                    if (u.usr().Id != c.OwnerId && !u.usr().Is_CFM_Owner__c) { c.Stop_Escalation_Till_Date__c.addError('Please refer to the CCC team to change this date.'); }
                }
            }

            z.caseValidate(c, o, now);

        // field update ////////////////////////////////////////////////////////

            // defaults
            if (!c.Draft_Mode__c && !c.Assigned__c) {
                c.OwnerId = CaseCommon.getOwnerQueueId(c.Operating_Unit__c);
                c.Assigned__c = true;
            }
            if(u.trig('i') && c.Company__c == null && c.Operating_Unit__c != null){
                c.Company__c = name2Company.get(c.Operating_Unit__c).Id;
            }

            // draft
            if (c.Draft_Mode__c) { }
            if (!c.Draft_Mode__c && (u.trig('i') || u.chg('Draft_Mode__c', c, o))) { c.Draft_Mode_Unchecked_Date__c = now; }

            // stop escalation
            if (c.Stop_Escalation__c) {
                if (u.trig('u') && u.chg('Stop_Escalation__c', c, o)) { c.Stop_Escalation_Count__c += 1; }
            }

            // closed
            if (c.Status == 'Closed' && (u.trig('i') || u.chg('Status', c, o))) {
                c.Closed_Aged__c = u.days(CaseCommon.pref(c, 'hours'), c.CreatedDate.date(), now.date());
            }

            // status changes
            c.To_Escalate__c = CaseStage.valid(c) && !c.Stop_Escalation__c && c.Status != 'Closed';
            if (c.Status == 'Closed') { /* do nothing */ }
            else if (c.Stop_Escalation__c && c.Stop_Escalation_Till_Date__c > date.today()) { c.Status = 'On Hold'; }
            else if (c.IsEscalated) { c.Status = 'Escalated'; }
            else { c.Status = c.Draft_Mode__c ? 'Draft' : 'New'; }

            // record types
            if (c.Status == 'Closed') { c.RecordTypeId = ((Map<string, RecordType>) CaseCommon.pref(c, 'type')).get('closed').Id; }
            else if (c.Type == 'Complaint') { c.RecordTypeId = ((Map<string, RecordType>) CaseCommon.pref(c, 'type')).get(c.Draft_Mode__c ? 'draft' : 'complaint').Id; }
            else if (c.Type == 'Compliment') { c.RecordTypeId = ((Map<string, RecordType>) CaseCommon.pref(c, 'type')).get('compliment').Id; }
            else { c.RecordTypeId = ((Map<string, RecordType>) CaseCommon.pref(c, 'type')).get('enquiry').Id; }

            // notification priority
            if (u.trig('i') || (u.trig('u') && u.chg('Draft_Mode__c', c, o))) {
                //c.Hold_Notification_Email__c = (c.Priority == 'High' || c.Priority == 'Critical');

                if (c.Priority == 'Keep In View') { c.Notification_Level__c = 0; }
                else if (c.Priority == 'Low') { c.Notification_Level__c = 1; }
                else if (c.Priority == 'Medium') { c.Notification_Level__c = 2; }
                else if (c.Priority == 'High') { c.Notification_Level__c = 3; }
                else if (c.Priority == 'Critical') { c.Notification_Level__c = 4; }
                else { c.Notification_Level__c = 0; }
            }

            // staging
            boolean caseUndrafted = u.trig('u') && u.chg('Draft_Mode__c', c, o) && (c.Draft_Mode__c == false);
            boolean validForEscalation = CaseAssign.valid(c) || CaseStage.valid(c);

            if (((c.Status == 'New' && u.trig('i')) || (caseUndrafted)) && validForEscalation){
                c.EscalationStage__c = CaseStage.initial(c);
                c.NextEscalation__c = CaseStage.next(c, now);
            }
            //initial stage is same across priorities but next esalation can be diff + escalated cases can not have priotiy changed
            if(u.trig('u') && u.chg('Priority', c, o)){
                c.NextEscalation__c = CaseStage.next(c, now);
            }
            //if (c.To_Escalate__c) { c.NextEscalation__c = CaseStage.next(c, now); }

            // z.caseUpdate(c, o, now);		// defaults

			//	z.caseUpdate
			if (u.def(c.OriginIncidentLocation__c, 'N / A') == 'N / A') { c.OriginIncidentLocation__c = c.Incident_Location__c; }
			c.IncidentLocationLabel__c = Util.val(Case.Incident_Location__c, c.Incident_Location__c);
        }
    }
    else {
        List<CaseTeamMember> owners = new List<CaseTeamMember>();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<CaseTeamTemplateRecord> teamsAdd = new List<CaseTeamTemplateRecord>(), teamsDel = new List<CaseTeamTemplateRecord>();

        Map<Id, Map<Id, CaseTeamTemplateRecord>> caseteamrecords = new Map<Id, Map<Id, CaseTeamTemplateRecord>>();
        for (Id i : Trigger.newMap.keySet()) { caseteamrecords.put(i, new Map<Id, CaseTeamTemplateRecord>()); }
        for (CaseTeamTemplateRecord cttr :
            [select TeamTemplateId, ParentId from CaseTeamTemplateRecord
            where ParentId in :Trigger.newMap.keySet()])
        { caseteamrecords.get(cttr.ParentId).put(cttr.TeamTemplateId, cttr); }

        for (Case c : Trigger.new) {
            Case o;
            if (u.trig('u')) { o = Trigger.oldMap.get(c.Id); }

            // create new case

            if (u.trig('i')) {
                // add case creator to case team
                owners.add(new CaseTeamMember(
                    ParentId = c.Id,
                    MemberId = u.usr().Id,
                    TeamRoleId = (Id) CaseCommon.pref(c, 'creator_role')));
            }

            // open new case

            /*
            if (!c.Draft_Mode__c && (u.trig('i') || u.chg('Draft_Mode__c', c, o))) {
                u.add(emails, CaseMail.prepareCaseMail(c, CaseActionMdt.CaseAction.open, null));
            }
            */
            if(u.trig('i')){
                u.add(emails, CaseMail.prepareCaseMail(c, CaseActionMdt.CaseAction.open, null));
            }

            // notification emails
            Boolean draftAction = false;
            CaseActionMdt.CaseAction action;
            if(c.Type == CaseCommon.TYPE_Complaint){
                action = CaseActionMdt.CaseAction.assign_complaint;
            }
            else{
                action = CaseActionMdt.CaseAction.assign_noncomplaint;
            }
            if (!c.Draft_Mode__c && !c.Hold_Notification_Email__c
                && (u.trig('i') || u.chg('Draft_Mode__c', c, o) || u.chg('Hold_Notification_Email__c', c, o))){
                    u.add(emails, CaseMail.prepareCaseMail(c, CaseActionMdt.CaseAction.notify, null, true));
                    draftAction = true;
            }

            // closed case

            if (c.Status == 'Closed' && (u.trig('i') || u.chg('Status', c, o)))
            { u.add(emails, CaseMail.prepareCaseMail(c, CaseActionMdt.CaseAction.close, null));}

            // assign case teams

            if (CaseAssign.valid(c) || CaseStage.valid(c)) {
                Set<Id> oldteams = CaseCommon.getCaseCumulativeTeamTemplateIdSet(o);
                for(Id caseTeamId: oldteams){
                    System.debug(caseTeamId);
                }
                //Set<Id> newteams = CaseAssign.ids(CaseAssign.names(c));
                Set<Id> newTeams = CaseCommon.getCaseCumulativeTeamTemplateIdSet(c);
                //Set<Id> cumulativeTeams = CaseCommon.getCaseCumulativeTeamTemplateIdSet(c);

                Set<Id> delteams = oldteams.clone(); delteams.removeAll(newTeams);
                System.debug(oldteams);
                //System.debug(cumulativeTeams);
                System.debug(delteams);
                for (Id t : delteams) {
                    u.add(teamsDel, caseteamrecords.get(c.Id).get(t));
                    System.debug(t + ' -> '+caseteamrecords.get(c.Id).get(t));
                }
                System.debug(teamsDel);

                Set<Id> addteams = new Set<Id>();
                for (Id t : newteams) {
                    if (caseteamrecords.get(c.Id).get(t) != null) { continue; }
                    teamsAdd.add(new CaseTeamTemplateRecord(TeamTemplateId = t, ParentId = c.Id));
                    addteams.add(t);
                }

                if(u.trig('u') && u.chg('Draft_Mode__c', c, o)){
                    //u.add(emails, CaseMail.prepareCaseMail(c, CaseActionMdt.CaseAction.notify, null, true));
                }

                //emails on escalation
                if (u.trig('u') && u.chg('EscalationStage__c', c, o)&& !(u.chg('Priority', c, o) || u.chg('Draft_Mode__c', c, o))){
                    u.add(emails, CaseMail.prepareCaseMail(c, CaseActionMdt.CaseAction.escalate, null, false));
                    u.add(emails, CaseMail.prepareCaseMail(c, CaseActionMdt.CaseAction.notify, null, false));
                    draftAction = false;
                    System.debug(newTeams);
                }

                //emails on department change
                else if (addteams.size() > 0){
                    u.add(emails, CaseMail.prepareCaseMail(c, action, addteams, draftAction));
                }
                else if(addteams.size() <= 0){
                    u.add(emails,CaseMail.prepareCaseMail(c, action, null, draftAction));
                }

                
                //emails on priority change
                if(u.trig('u') && u.chg('Priority', c, o)){
                    u.add(emails, CaseMail.prepareCaseMail(c, CaseActionMdt.CaseAction.open, null,false));
                    u.add(emails, CaseMail.prepareCaseMail(c, CaseActionMdt.CaseAction.notify, null, false));
                }
            }
        }

        try { insert owners; } catch (Exception ex) { }
        delete teamsDel;
        insert teamsAdd;
        System.debug(emails);
        Messaging.sendEmail(emails);
    }
}