global class CommonMethodsLibrary {
	public class CommonException extends Exception{}
	global static Map<String, Company__c> CMP_MAP;

	public static User USER_ADMIN = Envir.USER_ADMIN;
	public final static Map<SObjectType, List<String>> ERR_DETAIL_MAP = new Map<SObjectType, List<String>> {
		Account.SObjectType => new List<String> { 'Customer_Number__c', 'Dms_Number__c', 'IsPersonAccount' },
		Vehicle__c.SObjectType => new List<String> { 'Vehicle_Number__c' },
		Vehicle_Ownership__c.SObjectType => new List<String> { 'Vehicle_Ownership_Number__c' },
		Alternative_Driver__c.SObjectType => new List<String> { 'Id', 'Name', 'Status__c', 'Created_From__c', 'Account__c', 'Vehicle_Ownership__c' }
	};

	/**
	 * we sort SC alphabetically and use the Lead_Counter__c as a flag to determine if they have been assigned a lead
	 * once all SC have been marked, we reset everything back to zero again
	 * @param  userList [the specific list of users to iterate thru]
	 * @param  num      [the number of SCs we need to allocate]
	 * @return [list of Id of SC that will be assigned to this new opp/lead]
	 */
	public static List<Id> assignSC(List<User_Config__c> userList, Integer num) {
		List<Id> retIds = new List<Id>();
		if (userList.size() <= 0) { throw new CommonException('No Users to assign to. Please contact an administrator.'); }
		while (retIds.size() < num) {
			for (User_Config__c curUser : userList) {
				if (!curUser.Lead_Mark__c) { // we assign if its false
					retIds.add(curUser.User__c == null ? curUser.Employee_Master__c : curUser.User__c);
					curUser.Lead_Mark__c = true;
				}

				if (retIds.size() >= num) {
					break;
				}
			}

			if (retIds.size() < num) {
				// we reset everything so we can assign SCs again
				for (User_Config__c u : userList) {
					u.Lead_Mark__c = false;
				}
			}
		}

		SavePoint sp = Database.setSavePoint();
		try {
			update userList;
		} catch (DmlException e) {
			Database.rollback(sp);
			throw new CommonException('Error resetting SC Lead_Counter:' + e.getMessage());
		}
		return retIds;
	}




	// /** Copied from AssistantAPI:12 */
	public static Boolean setEmail(Account a, String email) {
		Boolean isChanged = (a.Id == null && !String.isBlank(email)) || (a.Id != null && a.Default_Email__c != email);
		if (!isChanged) { return isChanged; }
		if (String.isBlank(email)) { // remove active email and then make another one the default
			if (a.Active_Work__c) {
				a.Office_Email__c = '';
				a.Active_Work__c = false;
			}
			if (a.Active_Home__c) {
				a.Home_Email__c = '';
				a.Active_Home__c = false;
			}
			if (a.Active_Other__c) {
				a.Other_Email__c = '';
				a.Active_Other__c = false;
			}
			if (!String.isBlank(a.Office_Email__c)) {
				a.Active_Work__c = true;
			}
			else if (!String.isBlank(a.Home_Email__c)) {
				a.Active_Home__c = true;
			}
			else if (!String.isBlank(a.Other_Email__c)) {
				a.Active_Other__c = true;
			}
			else {
				// no more emails
			}
		}
		else {
			if (a.Office_Email__c != email && a.Other_Email__c != email && a.Home_Email__c != email) { // find a space to put the new email
				if (String.isBlank(a.Home_Email__c)) {
					a.Home_Email__c = email;
				}
				else if (String.isBlank(a.Office_Email__c)) {
					a.Office_Email__c = email;
				}
				else {
					a.Other_Email__c = email;
				}
			}
			// a.Active_Work__c = (a.Office_Email__c == email);
			// a.Active_Home__c = (a.Home_Email__c == email);
			// a.Active_Other__c = (a.Other_Email__c == email);
			if (a.Office_Email__c == email) { a.Active_Work__c = true; a.Active_Home__c = a.Active_Other__c = false; }
			else if (a.Home_Email__c == email) { a.Active_Home__c = true; a.Active_Work__c = a.Active_Other__c = false; }
			else if (a.Other_Email__c == email) { a.Active_Other__c = true; a.Active_Work__c = a.Active_Home__c = false; }
		}
		return isChanged;
	}





































































































































































































































































































































































































































































































































































	/*
	Methos to send email with just email addressess
	First send to a dummy contact, then we revert the sending and copy the html body of the generated email from template
	*/
// 	public static List<Messaging.SingleEmailMessage> sendEmail (List<String> toList, List<String> ccList, String templateName, String orgName, String relatedId, Boolean send){
// 		OrgWideEmailAddress orgEmail;
// 		try {
// 			orgEmail = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName =: orgName LIMIT 1];
// 		} catch (Exception e) {
// 			System.debug('@@@ No Org Email provided');
// 		}
// 		EmailTemplate eTemplate = [SELECT Id, Body FROM EmailTemplate WHERE Name =: templateName];
// 		List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
// 		List<Messaging.SingleEmailMessage> msgList = new List<Messaging.SingleEmailMessage>();
// 		Messaging.SingleEmailMessage cur = new Messaging.SingleEmailMessage();

// 		cur = Messaging.renderStoredEmailTemplate(eTemplate.Id, '', relatedId);
// 		if(ccList != null && !ccList.isEmpty()) { cur.setCcAddresses(ccList); }
// 		if(orgEmail != null) { cur.setOrgWideEmailAddressId(orgEmail.Id); }
// 		cur.setToAddresses(toList);
// 		cur.setUseSignature(false);
// 		cur.setBccSender(false);
// /*		cur.setSubject(cur.getSubject());
// 		cur.setHTMLBody(cur.getHTMLBody());
// 		cur.setPlainTextBody(cur.getPlainTextBody());*/
// 		Boolean saveAsActivity = false;
// 		if (!String.isBlank(relatedId)) {
// 			saveAsActivity = ((Id) relatedId).getSObjectType() != User.sObjectType;
// 		}
// 		cur.setSaveAsActivity(saveAsActivity); // prevent error when sending to user
// 		msgList.add(cur);

// 		if (send && !Test.isRunningTest()) { Messaging.sendEmail(msgList, true); }
// 		return msgList;
// 	}

	public static List<Messaging.SingleEmailMessage> sendErrorEmail(List<User> sendTo, String body) {
		return sendErrorEmail(sendTo, body, true, Envir.subject);
	}
	public static List<Messaging.SingleEmailMessage> sendErrorEmail(List<User> sendTo, String body, Boolean send) {
		return sendErrorEmail(sendTo, body, send, Envir.subject);
	}
	/**
	 * generic function to send email to internal staff
	 * note that Ids should be UserIDs, since those will not be counted email limits
	 * @param  sendTo [list of USER ids to send to]
	 * @param  body   [email body, HTML format]
	 */
	public static List<Messaging.SingleEmailMessage> sendErrorEmail(List<User> sendTo, String body, Boolean send, String subject) {
		String REPLY_TO = Envir.USER_CUR.Email;
		String NAME = Envir.USER_CUR.Name;
		Set<User> sendSet = new Set<User>();
		Set<String> seen = new Set<String>();
		// we try to unique-fy by emails if possible
		try {
			for (User u : sendTo) {
			  if (!seen.contains(u.Email)) {
				sendSet.add(u);
				seen.add(u.Email);
			  }
			}
		} catch (SObjectException e) {
			sendSet.addAll(sendTo);
		}

		// we use single email messages here since we cannot setHTMLBody for mass
		List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
		Messaging.SingleEmailMessage cur;
		for (User u : sendSet)
		{
			cur = new Messaging.SingleEmailMessage();
			cur.setTargetObjectId(u.Id);
			cur.setReplyTo(REPLY_TO);
			cur.setSenderDisplayName(NAME);
			cur.setSubject(subject);
			cur.setBccSender(false);
			cur.setUseSignature(false);
			cur.setHtmlBody(body);
			cur.setSaveAsActivity(false); // prevent error when sending to user
			mails.add(cur);
		}

		if (Test.isRunningTest() || !send) {
			System.debug('Email not sent due to test environment.');
			System.debug(mails);
		} else {
			// note that no secondary error handling will occur here,
			// we do not check email result
			Messaging.sendEmail(mails, false);
		}

		return mails;
	}

	/**
	 * generic function to send emails to Contact/Lead objects
	 * normally used for EXTERNAL parties
	 * @param  targetIds      [the list of account/leads to send to]
	 * @param  templateId     [which email template to use]
	 * @param  orgWideEmailId [org wide email id to send from]
	 * @param  relatedId      [the one object other you can merge template with]
	 * @return                [list of sent email messages]
	 */
	public static List<Messaging.SingleEmailMessage> sendEmail(List<String> targetIds, String templateId, String orgWideEmailId, String relatedId, Boolean send) {
		// we use single email messages here since we cannot setHTMLBody for mass
		List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
		Messaging.SingleEmailMessage cur;
		for (Id targetId : targetIds) {
			cur = new Messaging.SingleEmailMessage();
			cur.setTargetObjectId(targetId);
			if (!String.isBlank(orgWideEmailId)) {
				cur.setOrgWideEmailAddressId(orgWideEmailId);
			}
			cur.setTemplateID(templateId);
			cur.setBccSender(false);
			cur.setUseSignature(false);
			if (!String.isBlank(targetId)) {
				if (((Id)targetId).getSObjectType() == User.SObjectType) {
					cur.setSaveAsActivity(false);
				}
			}
			if (!String.isBlank(relatedId)) {
				cur.setWhatId(relatedId);
				if (((Id)relatedId).getSObjectType() == CampaignMember.SObjectType) {
					cur.setSaveAsActivity(false);
				}
			}
			mails.add(cur);
		}

		if (Test.isRunningTest() || !send) {
			System.debug('Email not sent due to test environment.');
			System.debug(mails);
		} else {
			Messaging.SendEmailResult [] r = Messaging.sendEmail(mails, false);
			for(Messaging.SendEmailResult rr:r){
				if(!rr.IsSuccess())
				{
				 System.debug('@@@ Common Send Email Failure : ' + rr.getErrors());
				}
			}

		}

		return mails;
	}

	// helper function to send a single email message
	public static List<Messaging.SingleEmailMessage> sendEmail(String targetId, String templateId, String orgWideEmailId, String relatedId, Boolean send) {
		return sendEmail(new List<String> { targetId }, templateId, orgWideEmailId, relatedId, send);
	}

	/**
	 * defaults to send = true, i.e. email will be sent immediately
	 */
	//public static List<Messaging.SingleEmailMessage> sendEmail(String targetId, String templateId, String orgWideEmailId, String relatedId) {
	//    return sendEmail(new List<String> { targetId }, templateId, orgWideEmailId, relatedId, true);
	//}
    public static String constructErrEmail(String header, String footer, String error){
        String boldMessage = '<strong>An error has encountered:</strong>';
        return constructErrEmail(header,footer,error ,boldMessage);
    }

	/**
	 * helper method to convert error messages to an html email format
	 * @param  header [optional header to include in the start of the email]
	 * @param  footer [optional footer to include at the bottom of the email (usually add stack trace here)]
	 * @param  error  [actual error message]
	 * @return        [overall email body]
	 */
	public static String constructErrEmail(String header, String footer, String error, String boldMessage) {
		//String errHTML = '<strong>An error has encountered:</strong>';
        String errHTML = boldMessage;
		errHTML += (header != null && header != '') ? '<br/><br/>' + header : '';
		errHTML += (error != null && error != '') ? '<br/><br/>' + error : '';
		errHTML += (footer != null && footer != '') ? '<br/><br/>' + footer : '';
		// performing cleanup on the given strings
		errHTML = errHTML.replace('\n', '<br/>');
		return errHTML;
	}

	/**
	 * helper method to replace any custom fields on an email template
	 * note that this will replace ALL references of a given keyword
	 * @param  origBody [the original string in the email template]
	 * @param  keywords [map of given keywords and the string to replace them to]
	 * @return          [the new body string]
	 */
	// public static String replaceEmailKeywords(String origBody, Map<String, String> keywords) {
	// 	String newBody = origBody.substring(0); // get copy of string
	// 	for (String k : keywords.keyset()) {
	// 		newBody = newBody.replace(k, keywords.get(k));
	// 	}
	// 	return newBody;
	// }




































































































































	






























































































	/**
	 * @param  strCompanyCode [Code of the Company]
	 * @return               [Company]
	 */

	// public static Company__c getCompanyByCode(String strCompanyCode) {
	// 	if (Test.isRunningTest()) { TestFactory.getCompany(strCompanyCode); }
	// 	if (String.isBlank(strCompanyCode)) { throw new CommonException('Empty Company Code'); }
	// 	if (CMP_MAP == null || !CMP_MAP.containsKey(strCompanyCode)) {
	// 		CMP_MAP = new Map<String, Company__c>();
	// 		for (Company__c cmp : [SELECT Id, Name FROM Company__c]) { CMP_MAP.put(cmp.Name, cmp); }
	// 	}
	// 	return CMP_MAP.get(strCompanyCode);
	// }

	// public static Company__c getCompanyById(Id cmpId) {
	// 	if (String.isBlank(cmpId)) { throw new CommonException('Empty Company Id'); }
	// 	if (CMP_MAP == null) {
	// 		CMP_MAP = new Map<String, Company__c>();
	// 		for (Company__c cmp : [SELECT Id, Name FROM Company__c]) { CMP_MAP.put(cmp.Name, cmp); }
	// 	}
	// 	for (Company__c cmp : CMP_MAP.values()) {
	// 		if (cmp.Id == cmpId) {
	// 			return cmp;
	// 		}
	// 	}
	// 	return null;
	// }

	/**
	 * helper method to get User record
	 * @param  userId       [ID of the user]
	 * @return               [User]
	 */
	// public static User getCompanyFromUser(String userId)
	// {
	// 	User userRec = new User();

	// 	if(userId != '')
	// 	{
	// 		userRec = [SELECT Id, Company__c FROM User WHERE Id =: userId];
	// 	}
	// 	return userRec;
	// }



























	/**
	 * helper function to check for existing opp with leads
	 * note that order is preserved since lead and sc is
	 * needed to find existing opp
	 * @param  leads   [list of leads]
	 * @param  scIds   [corresponding list of sc]
	 * @param  cmpId   [company to search under, one company only]
	 * @param  cmpName [company name due to business dependent rules]
	 * @return         [list of opp associated with lead and sc. Note that list size is
	 *                  guaranteed to be the same as initial]
	 * NOTE TO CHECK FOR NULL ON RET VAL
	 */
	// public static List<Opportunity> checkForExistingOpportunity(List<Lead> leads, List<Id> scIds, Id cmpId, String cmpName, String valModelInt) {
	// 	if (leads.size() != scIds.size()) throw new CommonException('checkForExistingOpp: Lists must have same size.');
	// 	List<Id> checkId = new List<Id>();
	// 	for (Lead l : leads) {
	// 		checkId.add(l.Id);
	// 	}

	// 	String query = 'SELECT AccountId, Lead__c, Lead__r.Id, OwnerId, Model_Interest__c, Sales_Rep_Name__c, Id, CampaignId, CampaignMemberId__c, ';
	// 	query += 'Remarks__c, Channel__c, Description, RecordTypeId, Planned_Purchase_Date__c, Purchase_Vehicle_Intention__c, CreatedDate, ';
	// 	query += 'Vehicle_Model_Interest__c, Vehicle_Model_Interest_Code__c ';
	// 	query += 'FROM Opportunity WHERE (Lead__c = :checkId) AND Sales_Rep_Name__c = :scIds AND Company__c = :cmpId AND isClosed = false ';
	// 	if (cmpName == '02' || cmpName == '888' || cmpName == '03' || cmpName == '05') {
	// 		query += 'AND (Type = \'Vehicle Sales\' OR Type = \'Vehicle Sales (Company)\' OR Type = \'Vehicle Sales (Priority)\')';
	// 		if (cmpName == '03' && !String.isBlank(valModelInt)) {
	// 			query += ' AND Model_Interest_Make__c = :valModelInt';
	// 		}
	// 	} else if (cmpName == '13') {
	// 		query += 'AND Type = \'Vehicle Lease\'';
	// 	}
	// 	List<Opportunity> opptList = Database.query(query);
	// 	return checkExistingHelper(opptList, checkId, scIds, 'Lead__c');
	// }

	// public static Opportunity checkForExistingOpportunity(Lead ld, Id scId, Id cmpId, String cmpName) {
	// 	return checkForExistingOpportunity(new List<Lead>{ ld }, new List<Id>{ scId }, cmpId, cmpName)[0];
	// }

	// public static List<Opportunity> checkForExistingOpportunity(List<Lead> leads, List<Id> scIds, Id cmpId, String cmpName) {
	// 	return checkForExistingOpportunity(leads, scIds, cmpId, cmpName, '');
	// }

	/**
	 * helper function to check for existing opp with acc
	 * note that order is preserved since acc and sc is
	 * needed to find existing opp
	 * @param  acc     [list of acc]
	 * @param  scIds   [corresponding list of sc]
	 * @param  cmpId   [company to search under, one company only]
	 * @param  cmpName [company name due to business dependent rules]
	 * @return         [list of opp associated with acc and sc. Note that list size is
	 *                  guaranteed to be the same as initial]
	 * NOTE TO CHECK FOR NULL ON RET VAL
	 */
	// public static List<Opportunity> checkForExistingOpportunity(List<Account> acc, List<Id> scIds, Id cmpId, String cmpName, String valModelInt) {
	// 	if (acc.size() != scIds.size()) throw new CommonException('checkForExistingOpp: Lists must have same size.');
	// 	List<Id> checkId = new List<Id>();
	// 	for (Account a : acc) {
	// 		checkId.add(a.Id);
	// 	}

	// 	String query = 'SELECT AccountId, Lead__c, Lead__r.Id, Model_Interest__c, Business_Contact__c, OwnerId, Sales_Rep_Name__c, Id, CampaignId, ';
	// 	query += 'CampaignMemberId__c, Channel__c, Remarks__c, Description, RecordTypeId, Planned_Purchase_Date__c, Purchase_Vehicle_Intention__c, CreatedDate, ';
	// 	query += 'Vehicle_Model_Interest__c, Vehicle_Model_Interest_Code__c ';
	// 	query += 'FROM Opportunity WHERE (AccountId = :checkId) AND Sales_Rep_Name__c = :scIds AND Company__c = :cmpId AND isClosed = false ';
	// 	if (cmpName == '02' || cmpName == '888' || cmpName == '03' || cmpName == '05') {
	// 		query += 'AND (Type = \'Vehicle Sales\' OR Type = \'Vehicle Sales (Company)\' OR Type = \'Vehicle Sales (Priority)\')';
	// 		if (cmpName == '03' && !String.isBlank(valModelInt)) {
	// 			query += ' AND Model_Interest_Make__c = :valModelInt';
	// 		}
	// 	} else if (cmpName == '13') {
	// 		query += 'AND Type = \'Vehicle Lease\'';
	// 	}
	// 	List<Opportunity> opptList = Database.query(query);
	// 	return checkExistingHelper(opptList, checkId, scIds, 'AccountId');
	// }

	// public static Opportunity checkForExistingOpportunity(Account acc, Id scId, Id cmpId, String cmpName) {
	// 	return checkForExistingOpportunity(new List<Account>{ acc }, new List<Id>{ scId }, cmpId, cmpName)[0];
	// }

	// public static List<Opportunity> checkForExistingOpportunity(List<Account> acc, List<Id> scIds, Id cmpId, String cmpName) {
	// 	return checkForExistingOpportunity(acc, scIds, cmpId, cmpName, '');
	// }

	// public static Opportunity checkForExistingOpportunity(Id tagId, Id scId, Id cmpId, String cmpName) {
	// 	Schema.SObjectType curType = tagId.getSObjectType();
	// 	if (curType == Schema.Account.getSObjectType()) {
	// 		return checkForExistingOpportunity(new Account(Id = tagId), scId, cmpId, cmpName);
	// 	} else {
	// 		return checkForExistingOpportunity(new Lead(Id = tagId), scId, cmpId, cmpName);
	// 	}
	// }

	// private static List<Opportunity> checkExistingHelper(List<Opportunity> opptList, List<Id> checkId, List<Id> scIds, String fieldName) {
	// 	// we consolidate based on acc Id
	// 	Map<Id, Map<Id, Opportunity>> idToScAndOpp = new Map<Id, Map<Id, Opportunity>>();
	// 	Map<Id, Opportunity> oMap;
	// 	for (Opportunity o : opptList) {
	// 		oMap = idToScAndOpp.get((Id) o.get(fieldName));
	// 		oMap = (oMap == null) ? new Map<Id, Opportunity>() : oMap;
	// 		// oMap.put(o.Sales_Rep_Name__c, o);
	// 		idToScAndOpp.put((Id) o.get(fieldName), oMap);
	// 	}

	// 	List<Opportunity> checkedOpp = new List<Opportunity>();
	// 	Map<Id, Opportunity> scToOpp;
	// 	for (Integer i = 0; i < checkId.size(); i++) {
	// 		if (idToScAndOpp.containsKey(checkId[i])) {
	// 			scToOpp = idToScAndOpp.get(checkId[i]);
	// 			checkedOpp.add(scToOpp.get(scIds[i])); // null is added if not available
	// 		} else {
	// 			checkedOpp.add(null);
	// 		}
	// 	}
	// 	return checkedOpp;
	// }

	///**
	// * helper method to get existing Account record based on Mobile Number
	// * @param  strMobile       [Mobile Number]
	// * @return                 [Account]
	// */
	// public static List<Account> checkforExistingAccount(String strMobile, String strDocNum)
	// {
	// 	//Account existAcc = new Account();
	// 	List<Account> existAcc = new List<Account>();

	// 	String queryString = 'SELECT Id, Name, Mobile_Preferred__pc, NRIC_Number__c FROM Account WHERE Mobile_Preferred__pc = \'' + strMobile + '\' ';
	// 	if(strDocNum != '' && strDocNum != null){
	// 		queryString += ' OR NRIC_Number__c = \'' + strDocNum + '\'';
	// 	}
	// 	//queryString += ' LIMIT 1';

	// 	if(strMobile != '')
	// 	{
	// 		//existAcc = [Select Id, Name from Account where Mobile_Preferred__pc =: strMobile limit 1];
	// 		existAcc = Database.query(queryString);
	// 	}
	// 	return existAcc;
	// }

	///**
	// * helper method to create Campaign Member record
	// * @param  leadId       [Lead ID]
	// * @param  campaignId   [Campaign ID]
	// * @return              [CampaignMember]
	// */
	// public static CampaignMember createCampaignMember(String contactId, String leadId, String campaignId)
	// {
	// 	CampaignMember camMember = new CampaignMember ();
	// 	if(contactId != '' && contactId != null)
	// 	{
	// 		camMember.ContactId = contactId;
	// 	}
	// 	if(leadId != '' && leadId != null)
	// 	{
	// 		camMember.LeadId = leadId;
	// 	}
	// 	camMember.CampaignId = campaignId;

	// 	return camMember;
	// }

	public static Task createTask(String contactId, String oppId, String ownerId, String taskType, String activityType, String crmIndication, String taskPriority, String subject, Boolean setReminder, Integer reminderTimeHours)
	{
		System.debug('task type: ' + taskType);
		Id taskRecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByName().get(taskType).getRecordTypeId();
		System.debug('task type2 : ' + taskType);

		Task newTask = new Task();
		newTask.Priority = taskPriority;
		newTask.isReminderSet = setReminder;
		newTask.ReminderDateTime = (setReminder) ? System.now().addHours(4) : null;
		newTask.Status = 'Not Started';
		newTask.Subject = subject;
		newTask.OwnerId = ownerId;
		newTask.RecordTypeId = taskRecordTypeId;
		newTask.WhatId = oppId;
		newTask.WhoId = (contactId != '') ? contactId : null;
		newTask.Type = activityType;

		return newTask;
	}




































	// public static Opportunity createOpp(String accId, String leadId, String oppRT, String oppType, String ownerId, String companyId, String leadTrafficId, String modelInterest, String strSource, String strExplanation, String strStage, String strStageName, String strRemarks, String strCampaignId)
	// {
	// 	String oppId = '';
	// 	Opportunity newOpp = new Opportunity();
	// 	//-> PML oppty record type
	// 	Id oppRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get(oppRT).getRecordTypeId();

	// 	if(accId != '' && accId != null)
	// 	{
	// 		newOpp.AccountId = accId;
	// 	}
	// 	if(leadId != '' && leadId != null)
	// 	{
	// 		// newOpp.Lead__c = leadId;
	// 	}
	// 	if(strCampaignId != '' && strCampaignId != null)
	// 	{
	// 		newOpp.CampaignId = strCampaignId;
	// 	}

	// 	if(leadTrafficId != '' && leadTrafficId != null)
	// 	{
	// 		// newOpp.Lead_Traffic__c = leadTrafficId;
	// 	}
	// 	// newOpp.RecordTypeId = oppRecordTypeId;
	// 	newOpp.Type = oppType;
	// 	// newOpp.Source__c = strSource;
	// 	// newOpp.Source_Explanation__c = strSource;
	// 	newOpp.OwnerId = ownerId;
	// 	// newOpp.Sales_Rep_Name__c = ownerId;
	// 	// newOpp.Company__c = companyId;
	// 	newOpp.StageName = strStageName;
	// 	// newOpp.Opportunity_Stage__c = strStage;
	// 	newOpp.CloseDate = date.today() + 30;
	// 	// newOpp.Model_Interest__c = modelInterest;
	// 	// newOpp.Remarks__c = strRemarks;
	// 	newOpp.Name = 'name';



	// 	//return oppId;
	// 	return newOpp;
	// }











































































	public static String emailResultFailure(List<Database.DeleteResult> srResult, List<SObject> objList, String funcName, String className, List<User> emailTo) {
		return emailResultFailure(srResult, objList, funcName, className, emailTo, true);
	}
	public static String emailResultFailure(List<Database.DeleteResult> srResult, List<SObject> objList, String funcName, String className, List<User> emailTo, Boolean toSend) {
		Map<Id, List<Database.Error>> mapIdError = new Map<Id, List<Database.Error>>();
		for (Integer i = 0; i < objList.size(); i++) {
			if (!srResult.get(i).isSuccess()) {
				mapIdError.put(objList.get(i).Id, srResult.get(i).getErrors());
			}
		}

		return emailResultFailureHelper(objList, mapIdError, funcName, className, emailTo, toSend);
	}

	public static String emailResultFailure(List<Database.SaveResult> srResult, List<SObject> objList, String funcName, String className, List<User> emailTo) {
		return emailResultFailure(srResult, objList, funcName, className, emailTo, true);
	}
	public static String emailResultFailure(List<Database.SaveResult> srResult, List<SObject> objList, String funcName, String className, List<User> emailTo, Boolean toSend) {
		Map<Id, List<Database.Error>> mapIdError = new Map<Id, List<Database.Error>>();
		for (Integer i = 0; i < objList.size(); i++) {
			if (!srResult.get(i).isSuccess()) {
				mapIdError.put(objList.get(i).Id, srResult.get(i).getErrors());
			}
		}

		return emailResultFailureHelper(objList, mapIdError, funcName, className, emailTo, toSend);
	}

	public static String emailResultFailure(List<Database.UpsertResult> srResult, List<SObject> objList, String funcName, String className, List<User> emailTo) {
		return emailResultFailure(srResult, objList, funcName, className, emailTo, true);
	}
	public static String emailResultFailure(List<Database.UpsertResult> srResult, List<SObject> objList, String funcName, String className, List<User> emailTo, Boolean toSend) {
		Map<Id, List<Database.Error>> mapIdError = new Map<Id, List<Database.Error>>();
		for (Integer i = 0; i < objList.size(); i++) {
			if (!srResult.get(i).isSuccess()) {
				mapIdError.put(objList.get(i).Id, srResult.get(i).getErrors());
			}
		}
		return emailResultFailureHelper(objList, mapIdError, funcName, className, emailTo, toSend);
	}

	public static String errorGenerating(SObject obj, List<Database.Error> errList) {
		String singleError = '';
		String objURL = obj.Id != null ? '<a href="' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + obj.Id + '">' + obj.Id + '</a>' :
										 'Error Before Insert (No ID on Object), Insert Failed';
		singleError += 'ID of failed record: ' + objURL + '<br>Error Record:<br/>' + JSON.serialize(obj) + '<br/>Error Message: <br/>';
		for (Database.Error error : errList) {
			singleError += error.getStatusCode() + ': ' + error.getMessage() +
						   (error.getFields().isEmpty() ? '<br/>' : '<br/>At following Field(s): <br/>');
			for (String fields : error.getFields()) {
				singleError += fields + '<br/>';
			}
		}
		return singleError;
	}

	private static String emailResultFailureHelper (List<SObject> objList, Map<Id, List<Database.Error>> mapIdError, String funcName, String className, List<User> emailTo, Boolean toSend) {
		String errorString = '', objURL;
		Integer numOfFailed = 0;
		for (SObject obj : objList) {
			if (mapIdError.containsKey(obj.Id)) {
				numOfFailed++;
				errorString += errorGenerating(obj, mapIdError.get(obj.Id));
				errorString += '<br/>________________________________________<br/><br/>';
			}
		}
		if (numOfFailed > 0) {
			errorString = '<strong>Class: ' + className +
						  '</br>Function: ' + funcName +
						  '</br>Number of Failed Records: ' + numOfFailed +
						  '</br></br></strong> The following error has occurred: </br></br>' + errorString;
			if (toSend) sendErrorEmail(emailTo, errorString);
			return errorString;
		}
		return 'No Error';
	}


	







	
































































































































































}