public class CaseMail
{
	private static Map<String,Map<String,EmailTemplate>> company2CaseAction2EmailTemplate;

	private static List<String> bccAddressList = new List<String>{
		'harsh_c@iconresources.com','rx0ug.sfdc@gmail.com'
	};

	/** Provide shorthand for CaseCommon.pref. */
	public static object pref(Case c, string key) { return CaseCommon.pref(c, key); }

	/**
	 * Creates a new case-related email.
	 *
	 * @param   c        relevant case
	 * @param   addr     list of emails
	 * @param   t        email template to be used
	 */
	private static Messaging.SingleEmailMessage create(Case c, List<string> addr, EmailTemplate t) {
		System.debug(t);
		if (addr == null || /*addr.size() == 0 ||*/ t == null || addr.size() == 0) { return null; }

		List<string> addrs = new List<string>();
		// for (string a : addr) { addrs.add(u.sbx() ? (a + '.sbx') : a); }
		for (string a : addr) { addrs.add(a); }

		Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
		m.setSenderDisplayName(Envir.isSandbox ? 'Salesforce Sandbox' : 'Salesforce');
		m.setToAddresses(addrs);
		m.setBccAddresses(bccAddressList);
		m.setSubject(replace(c, t.Subject));
		m.whatId= c.Id;
		m.setSaveAsActivity(true);

		if (t.TemplateType != 'text') {
			if(t.TemplateType == 'visualforce'){
				Id templateId = t.Id;
				Id whatId = c.Id;
				Messaging.SingleEmailMessage sem = Messaging.renderStoredEmailTemplate(templateId, null, whatId);
	
				m.setSubject(sem.getSubject());
				m.setHtmlBody(sem.getHtmlBody());
				m.setSaveAsActivity(true);
			}
			else{
				m.setHtmlBody(replace(c, t.HtmlValue));
			}
		}
		else{
			m.setPlainTextBody(replace(c, t.Body));
		}
		
		return m;
	}

	/**
	 * Performs mail-merge for the template string.
	 *
	 * @return          mail-merged string
	 * @param   c       relevant case
	 * @param   addr    list of emails
	 * @param   t       email template to be used
	 */
	private static string replace(Case c, string text) {
		if (c == null || text == null) { return text; }

		text = z.caseReplace(c, text);
		Pattern p = Pattern.compile('\\{!Case\\.([^]\\}]+)\\}');
		Matcher m = p.matcher(text);
		while (m.find()) {
			string key = m.group(0), field = m.group(1);
			string val = z.caseReplaceKey(c, key, field);

			if (val != null) { /* use value */ }
			//else if (field == 'Letterhead__c') { val = (string) pref(c, 'letterhead'); }
			// else if (field == 'All_Case_Comments__c') { val = ((string) u.def(c.All_Case_Comments__c, '')).replace('\n', '<br>\n'); }
			else if (field == 'Account') { val = (string) u.defs(u.acct(c.AccountId), 'Name', ''); }
			else if (field == 'ContactMobile') { val = (string) u.defs(u.contact(c.ContactId), 'MobilePhone', ''); }
			else if (field == 'ContactEmail') { val = (string) u.defs(u.contact(c.ContactId), 'Email', ''); }
			else if (field == 'CreatedBy') { val = (string) u.defs(u.usr(c.CreatedById), 'Name', ''); }
			else if (field == 'CreatedDate') { val = u.str(c.CreatedDate); }
			else if (field == 'Description') { val = ((string) u.def(c.Description, '')).replace('\n', '<br>\n'); }
			else if (field == 'Link') { val = (URL.getSalesforceBaseUrl().toExternalForm() + '/' + c.Id); }
			else {
				try { val = string.valueOf(u.defs(c, key.mid(7, key.length() - 8), '')); }
				catch (System.SObjectException e) { val = '<Error: field ' + field + ' not found>'; }
			}
			text = text.replace(key, (string) u.def(val, ''));
			m = p.matcher(text);
		}
		System.debug(text);
		return text;
	}

	public static List<String> getEscalationEmails(Case cs){
		System.debug('control was here to get escalation emails');
		String companyName = cs.Company__r.Name;
		if(companyName == null){
			companyName = '028';
		}
		List<String> emailList = new List<String>();
		if(cs.Priority != null && cs.EscalationStage__c != null){
			Map<Integer,List<String>> stage2TitleList = CaseStageMdt.getStageTitles(cs.priority);
			List<String> titleList = stage2TitleList.get(Integer.valueOf(cs.EscalationStage__c));

			System.debug(cs.EscalationStage__c);
			System.debug(titleList);
			if(titleList != null){
				for(String recipientTitle: titleList){
					CompanyEmailMdt.Title title = CompanyEmailMdt.Title.valueOf(recipientTitle);
					List<String> titleEmailList;
					try{
						if(String.isNotBlank(cs.Incident_Location__c)){
							String branchCode = CaseBranchCodeMdt.getBranchCodeMap().get(companyName).get(cs.Incident_Location__c);
							titleEmailList = CompanyEmailMdt.branchRecipientData.get(companyName).get(branchCode).get(title);
							if(titleEmailList != null){
								emailList.addAll(titleEmailList);
							}
						}
					}
					catch(NullPointerException npException){
					}
	
					try{
						emailList.addAll(CompanyEmailMdt.companyRecipientData.get(companyName).get(title));
					}
					catch(NullPointerException npException){
					}
	
					try{
						emailList.addAll(CompanyEmailMdt.recipientData.get(title));
					}
					catch(NullPointerException npException){
					}
				}
			}
		}
		System.debug(emailList);
		return emailList;
	}

	public static Set<Id> teamMemberRecipients(Set<Id> teams){
		Set<Id> recipientIdSet = new Set<Id>();
		if(teams!=null){
			Map<Id,List<Id>> memberIdMap = CaseCommon.getTeamTemplateMemberMap();
			for(Id teamId:teams){
				if(memberIdMap.get(teamId) != null){
					for(Id memberId:memberIdMap.get(teamId)){
						recipientIdSet.add(memberId);
					}
				}
			}
		}
		System.debug(recipientIdSet);
		return recipientIdSet;
	}

	private static List<String> getEmailRecipients(Case cs, CaseActionMdt.CaseAction action, Set<Id> teamIdSet, Boolean draftModeChanged){
		Set<string> recipientSet = new Set<string>();
		Set<Id> userIdSet = new Set<Id>();

		if (action == CaseActionMdt.CaseAction.assign){//} || action == CaseActionMdt.CaseAction.escalate){
			userIdSet.addAll(teamMemberRecipients(teamIdSet));
		}
		if ((action == CaseActionMdt.CaseAction.close && cs.Type == 'Complaint')) {
			/*
			Integer priority = cs.Notification_Level__c == null ? 1 : cs.Notification_Level__c?.intValue();
			if (priority > 0){
				Set<Id> teamTemplateIdSet = CaseCommon.getCaseTeamTemplateIdSet(cs);
				userIdSet.addAll(teamMemberRecipients(teamTemplateIdSet));
			}
			if (priority >= 2){
				recipientSet.add(u.sandboxEmail('jeffrey.gan.cboon@simedarby.com'));
				recipientSet.add(u.sandboxEmail('peter.yew@simedarby.com.sg'));
				if (cs.Origin == 'Legal') { recipientSet.add(u.sandboxEmail('yasukochua@simedarby.com')); }
			}
			if (priority >= 3){
				recipientSet.add(u.sandboxEmail('andrew.basham@simedarby.com'));
			}
			*/
		}
		if (action == CaseActionMdt.CaseAction.notify){
			Integer stage = Integer.valueOf(cs.EscalationStage__c - 1);
			recipientSet.addAll(getEscalationEmails(cs));
			// add recipients from previous stages
			if(draftModeChanged){
				while(stage > 0){
					Case csClone = cs.clone(true,true,true,true);
					csClone.EscalationStage__c = stage;
					stage -= 1;
					recipientSet.addAll(getEscalationEmails(csClone));
				}
			}
		}
		if (action == CaseActionMdt.CaseAction.close){//} || action == CaseActionMdt.CaseAction.escalate) {
			//cached with caseteam member helper class
			userIdSet.addAll(CaseCommon.getTeamMembers(cs));
		}
		if (action == CaseActionMdt.CaseAction.no_md_comment){
			String companyName = cs.Company__r.Name;
			if(companyName == null){
				companyName = '028';
			}
			List<String> mdEmailList = CompanyEmailMdt.companyRecipientData.get(companyName).get(CompanyEmailMdt.Title.Md);
			if(mdEmailList != null){
				recipientSet.addAll(mdEmailList);
			}
			
		}
		//escalate action has been removed from recent enhancement
		if (action == CaseActionMdt.CaseAction.close || action == CaseActionMdt.CaseAction.new_md_comment) {
			if (cs.EscalationStage__c >= 2) {
				/*
				recipientSet.add(u.sandboxEmail('jeffrey.gan.cboon@simedarby.com'));
				recipientSet.add(u.sandboxEmail('peter.yew@simedarby.com.sg'));
				if (cs.Origin == 'Legal') { recipientSet.add(u.sandboxEmail('yasukochua@simedarby.com')); }
				*/
			}
			if (cs.EscalationStage__c >= 4) {
				//recipientSet.add(u.sandboxEmail('andrew.basham@simedarby.com'));
			}
		}
		List<CaseActionMdt.CaseAction> hodICActionList = new List<CaseActionMdt.CaseAction>{
			CaseActionMdt.CaseAction.draft,CaseActionMdt.CaseAction.hold,CaseActionMdt.CaseAction.close
		};
		/*
		if(hodIcActionList.contains(action)){
			recipientSet.add(u.sandboxEmail('sreedharan.kutty@autobavaria.com'));
		}
		*/
		if(action == CaseActionMdt.CaseAction.open){
			userIdSet.addAll(new Set<Id>(CaseCommon.getCaseOwners(cs.Operating_Unit__c)));
			userIdSet.add(cs.CreatedById);
		}

		if(action == CaseActionMdt.CaseAction.escalate){
			userIdSet.addAll(CaseCommon.getCaseOwners(cs.Operating_Unit__c));
			//teams for stage below the current stage
			Integer stage = Integer.valueOf(cs.EscalationStage__c - 1);
			while(stage > 0){
				Case csClone = cs.clone(true,true,true,true);
				csClone.EscalationStage__c = stage;
				stage -= 1;
				// add all users which are members for previous escalation stages
				userIdSet.addAll(teamMemberRecipients(CaseCommon.getCaseTeamTemplateIdSet(csClone)));
				// add recipients from previous stages
				recipientSet.addAll(getEscalationEmails(csClone));
			}
		}

		if(action == CaseActionMdt.CaseAction.assign_complaint || action == CaseActionMdt.CaseAction.assign_noncomplaint){
			if(teamIdSet == null){
				if(draftModeChanged){
					teamIdSet = CaseCommon.getCaseCumulativeTeamTemplateIdSet(cs);
				}
				else{
					teamIdSet = CaseCommon.getCaseTeamTemplateIdSet(cs);
				}
				userIdSet.addAll(teamMemberRecipients(teamIdSet));
			}
			else{
				if(draftModeChanged){
					teamIdSet.addAll(CaseCommon.getCaseCumulativeTeamTemplateIdSet(cs));
				}
				else{
					teamIdSet.addAll(CaseCommon.getCaseTeamTemplateIdSet(cs));
				}
				userIdSet.addAll(teamMemberRecipients(teamIdSet));
			}

		}
		for(Id userId: userIdSet){
			recipientSet.add(String.valueOf(userId));
		}
		return new List<String>(recipientSet);
	}

	public static Messaging.SingleEmailMessage prepareCaseMail(Case cs, CaseActionMdt.CaseAction action, Set<Id> teamIdSet){
		return prepareCaseMail(cs, action, teamIdSet, false);
	}

	public static Messaging.SingleEmailMessage prepareCaseMail(Case cs, CaseActionMdt.CaseAction action, Set<Id> teamIdSet, Boolean draftModeChanged){
		List<String> emailAddressList = getEmailRecipients(cs, action,teamIdSet, draftModeChanged);
		EmailTemplate caseEmailTemplate = CaseActionMdt.getCaseActionEmailTemplate(cs, action);
		return create(cs, emailAddressList, caseEmailTemplate);
	}

	public List<Messaging.SingleEmailMessage> emailMessageList;
    public CaseMail(){
        this.emailMessageList = new List<Messaging.SingleEmailMessage>();
    }

    public void addEmailMessage(Messaging.SingleEmailMessage message){
        if(message != null){
            this.emailMessageList.add(message);
        }
    }

    public void sendEmail(){
        if(!this.emailMessageList.isEmpty()){
            Messaging.sendEmail(this.emailMessageList);
        }
    }
}