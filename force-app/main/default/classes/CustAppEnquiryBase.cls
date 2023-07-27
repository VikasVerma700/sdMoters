global class CustAppEnquiryBase {
	public static List<Customer_External_Account__c> getCustAccList(String uuid) {
		return [SELECT Id, Type__c, Account__c, Account__r.Name, Account__r.LastName, Account__r.Account_Name__c, Account__r.Default_Email__c,
				Account__r.Mobile_Preferred__pc, Account__r.Doc_Type__c, Account__r.Partial_NRIC__c, Account__r.PersonContactId FROM
				Customer_External_Account__c WHERE UUID__c = :uuid AND IsActive__c = TRUE];
	}

	// public static Lead_Traffic__c createLeadTraffic(Company__c cmp, Account acc, User sc, String modelInt) {
	// 	Lead_Traffic__c leadT = CommonMethodsLibrary.createLeadTraffic(acc.Id, null, acc.LastName, acc.Account_Name__c, cmp.Id, acc.Default_Email__c,
	// 																	acc.Mobile_Preferred__pc, acc.Doc_Type__c, acc.Partial_NRIC__c, '', acc.LastName,
	// 																	sc.Id, 'Lead Traffic - Website', 'Websites or Social Media or APP', 'Demonstration',
	// 																	modelInt);
	// 	insert leadT;
	// 	return leadT;
	// }

	// public static Task createTask(Company__c cmp, Opportunity opp, Customer_External_Account__c acc) {
	// 	String rt;
	// 	switch on (cmp.Name) {
	// 		when '02', '888' { rt = 'PML Activities RT'; }
	// 		when '03' { rt = 'VAL General Task RT'; }
	// 		when '05' { rt = 'PPSL Sales Process Activities'; }
	// 		when '028' { rt = 'Automated Task'; }
	// 	}
	// 	String type = 'Follow Up';
	// 	String subject = acc.Type__c + ' Test Drive Request';
	// 	Task newTask = CommonMethodsLibrary.createTask(acc.Account__r.PersonContactId, opp.Id, opp.OwnerId, rt, type, '', 'Normal', subject, true, 4);
	// 	newTask.ReminderDateTime = DateTime.now();
	// 	newTask.ActivityDate = Date.today().addDays(1);
	// 	Database.DMLOptions dlo = new Database.DMLOptions();
	// 	dlo.EmailHeader.TriggerUserEmail = true;
	// 	Database.insert(newTask, dlo);
	// 	return newTask;
	// }

	// public static Opportunity findExistingOrCreateOpp(Customer_External_Account__c extAcc, Id leadTrafficId, User sc, Company__c cmp, String modelInt) {
	// 	Opportunity curOpp = CommonMethodsLibrary.checkForExistingOpportunity(extAcc.Account__c, sc.Id, cmp.Id, cmp.Name);
	// 	if (curOpp == null) {
	// 		String oppRT;
	// 		switch on (cmp.Name) {
	// 			when '02' { oppRT = 'Opportunity RT'; }
	// 			when '888' { oppRT = 'PMA Opportunity RT'; }
	// 			when '03' { oppRT = 'VAL Opportunity RT'; }
	// 			when '05' { oppRT = 'PPSL Opportunity RT'; }
	// 			when else { throw new CustAppAPI.CustAppException('Invalid record type mapping.'); }
	// 		}
	// 		curOpp = CommonMethodsLibrary.createOpp(extAcc.Account__c, null, oppRT, 'Vehicle Sales (Company)', sc.Id, cmp.Id, leadTrafficId,
	// 												modelInt, extAcc.Type__c, '', 'Prospecting', 'Prospecting', '', '');
	// 		curOpp.Created_From__c = extAcc.Type__c + ' Test Drive Request';
	// 	}
	// 	return curOpp;
	// }
}