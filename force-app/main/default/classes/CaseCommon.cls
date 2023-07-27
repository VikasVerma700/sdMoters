public class CaseCommon
{
	public class CaseException extends Exception { }

	//constants for priority/case severity picklist field
	public static final String PRIORITY_KEEP_IN_VIEW = 'Keep In View';
	public static final String PRIORITY_NA = 'N/A';
	public static final String PRIORITY_LOW = 'Low';
	public static final String PRIORITY_MEDIUM = 'Medium';
	public static final String PRIORITY_HIGH = 'High';
	public static final String PRIORITY_CRITICAL = 'Critical';

	//constants for Type picklist field
	public static final String TYPE_COMPLIMENT = 'Compliment';
	public static final String TYPE_COMPLAINT = 'Complaint';
	public static final String TYPE_GENERAL_ENQUIRY = 'General Enquiry';
	public static final String TYPE_GENERAL_FEEDBACK = 'General Feedback';

	//public static final String CASE_OWNER_QUEUE = 'CfmOwners';
	//public static final String CASE_OWNER_QUEUE = OU2OWNER_QUEUE.get(CompanyRepository.C028);
	public static final Map<String,String> OU2OWNER_QUEUE = new Map<String,String>{
		CompanyRepository.C028 => 'CfmOwnersSdab',
		CompanyRepository.C001 => 'CfmOwnersSdsa',
		CompanyRepository.C038 => 'CfmOwnersSdah',
		CompanyRepository.C088 => 'CfmOwnersSdac',
		CompanyRepository.C168 => 'CfmOwnersSdas',
		CompanyRepository.C099 => 'CfmOwnersSdba'
	};

	//Get string for querying all fields of Case object
	private static String allFields;
	public static String getAllFields(){
		if(allFields == null){
			allFields = String.join(new List<String>(schema.SObjectType.Case.fields.getMap().keySet()),',')+',Company__r.Name,Company__r.MobyCompanyCode__c';
		}
		return allFields;
	}

	//get a map of all team's Id to list of all members
	private static Map<Id,List<Id>> teamTemplateMemberMap;
	public static Map<Id,List<Id>> getTeamTemplateMemberMap(){
		if(teamTemplateMemberMap == null){
			teamTemplateMemberMap = new Map<Id,List<Id>>();
			for (CaseTeamTemplateMember teamTemplateMember : [select MemberId, TeamTemplateId from CaseTeamTemplateMember]) {
				List<Id> memberIdList = teamTemplateMemberMap.get(teamTemplateMember.TeamTemplateId);
				if(memberIdList == null){
					memberIdList = new List<Id>();
				}
				memberIdList.add(teamTemplateMember.MemberId);
				teamTemplateMemberMap.put(teamTemplateMember.TeamTemplateId,memberIdList);
			}
		}
		return teamTemplateMemberMap;
	}

	//get a list of department api names
	private static List<String> departmentList;
	public static final String DEFAULT_DEPARTMENT = 'Customer Care Center';
	public static List<String> getDepartments(){
		if(departmentList == null){
			departmentList = new List<String>();
			Schema.DescribeFieldResult deptDescription = Case.Department__c.getDescribe();
			List<Schema.PicklistEntry> deptEntries = deptDescription.getPicklistValues();
			for(Schema.PicklistEntry deptEntry: deptEntries){
				if(deptEntry.isActive()){
					departmentList.add(deptEntry.getValue());
				}
			}
		}
		return departmentList;
	}

	//list of patterns for arranging case fields into a team's name
	public static final List<String> patternList = new List<String>{
		'cbdms', 'cbds', 'cds', 'cbs', 'cs'//, 'cbdm', 'cbd','cd','cb'
	};

	//get branch code for case's branch using metadata helper class
	public static String getCaseBranchCode(Case cs){
		String companyName = cs.Operating_Unit__c != null ? cs.Operating_Unit__c : '028';
		Map<String,Map<String,String>> company2branch2code = CaseBranchCodeMdt.getBranchCodeMap();
		Map<String,String> branch2CodeMap = company2branch2code.get(companyName);
		String branchCode = branch2CodeMap.get(cs.Incident_Location__c);
		if(branchCode == null){
			return 'ABAD';
		}
		return branchCode;
	}

	//get a map for team's name to team
	private static Map<String,CaseTeamTemplate> name2TeamTeamplate;
	public static Map<String,CaseTeamTemplate> getTeamTemplateMap(){
		if(name2TeamTeamplate==null){
			name2TeamTeamplate = new Map<String,CaseTeamTemplate>();
			List<CaseTeamTemplate> templateList = [
				SELECT Id,Name
				FROM CaseTeamTemplate
			];
			for(CaseTeamTemplate template: templateList){
				name2TeamTeamplate.put(template.name,template);
			}
		}
		return name2TeamTeamplate;
	}

	//get userid for all the team member for a case
	public static Set<Id> getTeamMembers(Case cs){
		Set<Id> memberIdSet = new Set<Id>();
		List<CaseTeamMember> memberList= CaseTeamMemberHelper.get(cs.Id);
		if(memberList == null){
			for(CaseTeamMember member:[
				SELECT MemberId FROM CaseTeamMember WHERE ParentId = :cs.Id]){
				memberIdSet.add(member.MemberId);
			}
		}
		else{
			for(CaseTeamMember member: memberList){
				memberIdSet.add(member.Id);
			}
		}
		System.debug(memberIdSet);
		return memberIdSet;
	}
	/*
	private static Id ownerQueueId;
	public static Id getOwnerQueueId(){
		if(ownerQueueId == null){
			ownerQueueId = [
				SELECT Id 
				FROM GROUP 
				WHERE DeveloperName = :CASE_OWNER_QUEUE
					AND Type = 'Queue'
			][0].Id;
		}
		return ownerQueueId;
	}

	private static Set<Id> caseOwnerIdSet;
	public static Set<Id> getCaseOwners(){
		if(caseOwnerIdSet == null){
			Id queueId = getOwnerQueueId();
			caseOwnerIdSet = GroupRepository.getUsers(new List<Id>{queueId});
		}
		return caseOwnerIdSet;
	}
	*/
	private static Map <String,Id> ou2OwnerQueueId;
	public static Id getOwnerQueueId(String ou){
		if(ou2OwnerQueueId == null){
			ou2OwnerQueueId = new Map<String,Id>();
			for(Group ownerQueue: [SELECT Id,DeveloperName FROM GROUP WHERE DeveloperName IN :OU2OWNER_QUEUE.values() AND Type = 'Queue']){
				ou2OwnerQueueId.put(ownerQueue.DeveloperName,ownerQueue.Id);
			}
		}
		String ownerQueueName = OU2OWNER_QUEUE.get(ou);
		String ownerQueueId = ou2OwnerQueueId.get(ownerQueueName);
		if(ownerQueueId != null){
			return ownerQueueId;
		}
		return getOwnerQueueId();
	}

	public static Id getOwnerQueueId(){
		return getOwnerQueueId(CompanyRepository.C028);
	}

	private static Map<String,Set<Id>> ou2OwnerIdSet;
	public static Set<Id> getCaseOwners(String ou){
		ou2OwnerIdSet = new Map<String,Set<Id>>();
		if(ou2OwnerIdSet.get(ou) == null){
			Set<Id> ownerIdSet = new Set<Id>();
			Id ownerQueueId = getOwnerQueueId(ou);
			if(ownerQueueId != null){
				for(Id ownerId :GroupRepository.getUsers(new List<Id>{ownerQueueId})){
					ownerIdSet.add(ownerId);
				}
				ou2OwnerIdSet.put(ou,ownerIdSet);
			}
		}
		return ou2OwnerIdSet.get(ou);
	}

	public static Set<Id> getCaseOwners(){
		return getCaseOwners(CompanyRepository.C028);
	}

	//get businesshours id for defalult one
	private static Id defaultBusinessHoursId;
	public static Id getDefaultBusinessHours(){
		if(defaultBusinessHoursId == null){
			defaultBusinessHoursId = [
				SELECT Id
				FROM BusinessHours
				WHERE IsDefault = true
			].get(0).Id;
		}
		return defaultBusinessHoursId;
	}

	//get age of a case based on business hours
	public static Long getCaseAge(Case cs, DateTime now){
		Id businessHoursId = cs.BusinessHoursId;
		if(businessHoursId == null){
			businessHoursId = getDefaultBusinessHours();
		}

		DateTime createdDate = cs.CreatedDate;
		if(createdDate == null){
			createdDate = now;
		}

		return BusinessHours.diff(businessHoursId,createdDate,now);
	}

	public static Set<String> getCaseTeamTemplateNameSet(Set<String> departmentSet, String branchCode, String stageName, String companyName){
		Set<String> teamTemplateNameSet = new Set<String>();
		for(String dept :departmentSet){
			System.debug('Department: '+dept);
			for(String pattern :CaseCommon.patternList){
				System.debug(pattern);			
				List<String> namepartList = new List<String>();
				for (String patternUnit : pattern.split('')) {
					switch on patternUnit{
						when 'b'{
							namepartList.add(branchCode);
						}

						when 'd'{
							namepartList.add(dept);
						}

						when 's'{
							namepartList.add(stageName);
						}

						when 'c'{
							namepartList.add(companyName);
						}
					}
				}
				String teamTemplateName = String.join(namepartList, ' ');
				System.debug(teamTemplateName);
				if (CaseCommon.getTeamTemplateMap().containsKey(teamTemplateName)){
					teamTemplateNameSet.add(teamTemplateName);
					System.debug(teamTemplateName);
				}
			}
		}
		return teamTemplateNameSet;
	}

	public static Set<Id> getCaseTeamTemplateIdSet(Set<String> departmentSet, String branchCode, String stageName, String companyName){
		Set<String> teamTemplateNameSet = getCaseTeamTemplateNameSet(departmentSet, branchCode, StageName, companyName);
		Set<Id> teamTemplateIdSet = new Set<Id>();
		for(String teamTemplateName: teamTemplateNameSet){
			Id teamTemplateId = CaseCommon.getTeamTemplateMap().get(teamTemplateName).Id;
			if(teamTemplateId!=null){
				teamTemplateIdSet.add(teamTemplateId);
			}
		}

		return teamTemplateIdSet;
	}

	public static Set<Id> getCaseTeamTemplateIdSet(Case cs){
		Set<Id> teamTemplateIdSet = new Set<Id>();
		if(cs == null){
			return teamTemplateIdSet;
		}
		List<Schema.PicklistEntry> departmentPicklistEntryList = Schema.SObjectType.Case.fields.Department__c.getPicklistValues();
		Map<String,String> departmentApi2Label = new Map<String,String>();
		for(Schema.PicklistEntry departmentPicklistEntry: departmentPicklistEntryList){
			departmentApi2Label.put(departmentPicklistEntry.getValue(),departmentPicklistEntry.getLabel());
		}
		Set<String> caseDeptSet = new Set<String>();
		if(cs.Department__c == null){
			caseDeptSet.add(departmentApi2Label.get(CaseCommon.DEFAULT_DEPARTMENT));
		}
		else{
			List<String> caseDeptList = cs.Department__c.split(';');
			for(String caseDept: caseDeptList){
				if(!CaseCommon.getDepartments().contains(caseDept)){
					caseDept = CaseCommon.DEFAULT_DEPARTMENT;
				}
				caseDeptSet.add(departmentApi2Label.get(caseDept));
				if(caseDept.contains(' - ')){
					caseDeptSet.add(departmentApi2Label.get(caseDept.left(caseDept.lastIndexOf(' - '))));
				}
			}
		}

		
		String caseBranchCode = CaseCommon.getCaseBranchCode(cs);
		String stageName = CaseStage.getCaseStageName(cs);
		String companyName;
		try{
			companyName = cs.Company__r.MobyCompanyCode__c;
			if(String.isBlank(companyName)){
				companyName = 'SDAB';
			}
		}
		catch(NullPointerException nPException){
			companyName = 'SDAB';
		}
		
		teamTemplateIdSet = getCaseTeamTemplateIdSet(caseDeptSet, caseBranchCode, stageName, companyName);
		return teamTemplateIdSet;
	}

	public static set<Id> getCaseCumulativeTeamTemplateIdSet(Case cs){
		Set<Id> teamTemplateIdSet = new Set<Id>();
		if(cs != null && cs.EscalationStage__c != null && cs.EscalationStage__c > 0){
			Integer stage = Integer.valueOf(cs.EscalationStage__c);
			while(stage>0){
				Case csClone = cs.clone(true,true,true,true);
				csClone.EscalationStage__c = stage;
				teamTemplateIdSet.addAll(getCaseTeamTemplateIdSet(csClone));
				stage -= 1;
			}
		}
		
		for(Id templateId: teamTemplateIdSet){
			System.debug(templateId);
		}
		return teamTemplateIdSet;
	}

////// data ////////////////////////////////////////////////////////////////////

	public static object pref(Case c, String key) { return pr.ef('case', (c != null) ? z.casePrefix(c) : null, key); }
	/*
	@isTest static void prefTest() {
		pref(null, 'fields');
		pref(null, 'type');
		pref(null, 'owner');
		pref(null, 'creator_role');

		pref(null, 'template');

		pref(null, 'teams');
		pref(null, 'companies');

		pref(null, 'stages');
		pref(null, 'timing');
		pref(null, 'hours');
	}
	*/

	public static List<string> fields() { return (List<string>) pref(null, 'fields'); }

////// scheduler ///////////////////////////////////////////////////////////////

	/**
	 * Executes time-based workflows.
	 *
	 * @param   now      datetime of execution
	 */
	/*
	public static void schedule(datetime now) {
		// emails
		string query = 'select ' + string.join(fields(), ',') + ' from Case where IsClosed = false and (Draft_Mode__c = true or Hold_Notification_Email__c = true)';
		List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
		for (Case[] cs : Database.query(query))
		{
			for (Case c : cs) {
				if (!u.hrs((Id) pref(c, 'hours'), now)) { continue; }

				// notify CFM of draft cases after 4 hours
				if (c.Draft_Mode__c && now >= BusinessHours.add((Id) pref(c, 'hours'), c.CreatedDate, 4L * 60 * 60 * 1000))
				{ u.add(emails, CaseMail.create(c, CaseMail.emails(c, 'draft'), CaseMail.template(c).get('draft'))); }

				// notify CFM of high/critical case notification emails held after 4 hours
				else if (c.Hold_Notification_Email__c && now >= BusinessHours.add((Id) pref(c, 'hours'), c.Draft_Mode_Unchecked_Date__c, 4L * 60 * 60 * 1000))
				{ u.add(emails, CaseMail.create(c, CaseMail.emails(c, 'hold'), CaseMail.template(c).get('hold'))); }
			}
		}

		// resume case escalation after stop escalation expiry
		for (Case[] cs :
			[select Id, BusinessHoursId, Stop_Escalation__c from Case
			where IsClosed = false and Stop_Escalation__c = true and Stop_Escalation_Till_Date__c <= :now.date()])
		{
			List<Case> ch = new List<Case>();
			for (Case c : cs) {
				if (!u.hrs((Id) pref(c, 'hours'), now)) { continue; }
				c.Stop_Escalation__c = false;
				ch.add(c);
			}
			update ch;
		}

		// escalate due cases
		for (Case[] cs :
			Database.query('select ' + string.join(CaseCommon.fields(), ',') + ' from Case '
				+ 'where IsClosed = false and To_Escalate__c = true and NextEscalation__c <= :now'))
		{
			List<Case> ch = new List<Case>();
			List<Id> chid = new List<Id>();
			for (Case c : cs) {
				if (!u.hrs((Id) pref(c, 'hours'), now)) { continue; }
				integer stage = CaseStage.current(c, now);
				if (c.EscalationStage__c < stage) {
					c.IsEscalated = true;
					c.EscalationStage__c = stage;
					ch.add(c);
					chid.add(c.Id);
				}
			}
			update ch;

			Map<Id, Set<Id>> ccs = new Map<Id, Set<Id>>();
			for (CaseComment cc : [select ParentId, CreatedById from CaseComment where ParentId in :chid]) {
				if (!ccs.containsKey(cc.ParentId)) { ccs.put(cc.ParentId, new Set<Id>()); }
				ccs.get(cc.ParentId).add(cc.CreatedById);
			}
			for (Case c : Database.query('select ' + string.join(CaseCommon.fields(), ',') + ' from Case where Id in :chid')) {
				if (c.EscalationStage__c < 3) { continue; }
				User md = (User) CaseCommon.pref(c, 'managing_director');
				if (!ccs.containsKey(c.Id) || !ccs.get(c.Id).contains(md.Id)) {
					u.add(emails, CaseMail.create(c, CaseMail.emails(c, 'no_md_comment'), CaseMail.template(c).get('no_md_comment')));
				}
			}
		}

		Messaging.sendEmail(emails);
	}
	
	@isTest static void scheduleTest() {
		Case c = CaseTest.createValid();
		c.Priority = 'High';
		c.Type = 'Complaint';
		insert c;

		c = CaseTest.createValid();
		c.Priority = 'Low';
		c.Type = 'Complaint';
		c.Draft_Mode__c = true;
		insert c;

		schedule(BusinessHours.add((Id) pref(null, 'hours'), datetime.now(), 30L * 24 * 60 * 60 * 1000));
	}
	*/
}

// stage 3 - // team names stage 3// set 1 
/// stage 2 - // cujulatige team names swe 2