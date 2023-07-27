global class InsuranceBatchSched  implements Database.Batchable<sObject>, Schedulable {
	private final static Organization ORG = [SELECT Id, IsSandbox FROM Organization LIMIT 1];
	private final static Set<String> ERR_EMAIL = (Test.isRunningTest() || ORG.IsSandbox) ? new Set<String> { 'pml@simedarby.com.sg' } : new Set<String>();
	private static List<User> ERR_USER;
	public static String DEF_FIELDS = 'SELECT Vehicle__c, Policy_Classification__c, Company__c, Underwriter_Code__c, Underwriter__c, Insurance_Product__c,' +
										'Registration_Number__c, Policy_Received_Date__c, Policy_Expiry_Date__c, Name, Document_Number__c, Days_To_Lapse__c,'+
										'Policy_Holder__c,Policy_Holder__r.Id, Policy_Holder__r.Name, Sales_Rep_Name__c FROM Insurance_Policy__c';
	// we add in those policies that are due soon to trigger the opp update of the stage using process builder
	private static String DEF_Q = DEF_FIELDS + ' WHERE Policy_Expiry_Date__c = NEXT_N_MONTHS:3 OR (Policy_Expiry_Date__c <= NEXT_90_DAYS AND ' +
												'Policy_Expiry_Date__c >= LAST_N_DAYS:15)';
	public class InsBatchException extends Exception {}

	static {
		String profileName = (Test.isRunningTest() || ORG.IsSandbox) ? '' : 'Contego Managers';
		// List<User> userList = [SELECT Id, Email FROM User WHERE (Profile.Name = :profileName OR Email IN :ERR_EMAIL) AND IsActive = TRUE];
		// Set<String> seenEmail = new Set<String>();
		// ERR_USER = new List<User>();
		// for (User u : userList) {
		// 	if (seenEmail.contains(u.Email)) { continue; }
		// 	ERR_USER.add(u);
		// 	seenEmail.add(u.Email);
		// }
		ERR_USER = TriggerBase.ERR_USER;
	}

	/////////////////////////////////////////////////////////////////////////////
	// Batch Job ////////////////////////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////

	global String query;
	public InsuranceBatchSched(String query) { this.query = query; }
	public InsuranceBatchSched() { this(DEF_Q); }

	global void execute(SchedulableContext sc) { Database.executeBatch(this, 1); }

	global Database.QueryLocator start(Database.BatchableContext cont) { return Database.getQueryLocator(query); }

	global void execute(Database.BatchableContext cont, List<Insurance_Policy__c> scope) {
		try {
			Map<Id, Opportunity> existingOppty = getExistingOppty(scope);
			renewOpp(scope, existingOppty);
			triggerOppStageUpd(existingOppty.values());
		} catch (Exception e) {
			String body = CommonMethodsLibrary.constructErrEmail('InsuranceBatch Scheduler', e.getStackTraceString(), e.getMessage());
			CommonMethodsLibrary.sendErrorEmail(ERR_USER, body);
		}
	}

	global void finish(Database.BatchableContext BC) {}

	public void renewOpp(List<Insurance_Policy__c> insPolicy, Map<Id, Opportunity> insMap) {
		// User defUser = defUserId();
		User defUser = Envir.USER_CUR;
		Set<Id> activeUserId = filterActiveUser(insPolicy);
		Id rtId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Opportunity RT').getRecordTypeId();
		List<Opportunity> listOpp = new List<Opportunity>();
		for (Insurance_Policy__c p : insPolicy) {
			if (insMap.containsKey(p.Id)) { continue; }
			Opportunity newOpp = new Opportunity();
			newOpp.Type = 'Vehicle Insurance';
			newOpp.Opportunity_Stage__c = 'Open for Renewal';
			newOpp.RecordTypeId = rtId;
			newOpp.StageName = 'Open for Renewal';
			newOpp.Company__c = p.Company__c;
			newOpp.CloseDate = p.Policy_Expiry_Date__c;
			newOpp.Insurance__c = p.Id;
			newOpp.AccountId = p.Policy_Holder__r.Id;
			newOpp.Name = p.Policy_Holder__r.Name;
			newOpp.CreatedFrom__c = 'INS Scheduler';
			newOpp.Insurance_Product__c = p.Insurance_Product__c;
			newOpp.Policy_Classification__c = p.Policy_Classification__c;
			newOpp.Underwriter_Code__c = p.Underwriter_Code__c;
			newOpp.OwnerId = (activeUserId.contains(p.Sales_Rep_Name__c)) ? p.Sales_Rep_Name__c : defUser.Id;
			newOpp.Sales_Rep_Name__c = newOpp.OwnerId;
			newOpp.Chassis__c = p.Vehicle__c;
			listOpp.add(newOpp);
		}
		List<Database.SaveResult> srList = Database.insert(listOpp, false);
		CommonMethodsLibrary.emailResultFailure(srList, listOpp, 'renewOpp', 'InsuranceBatchSched', ERR_USER);
	}

	/////////////////////////////////////////////////////////////////////////////
	// Private Helpers //////////////////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////

	private Map<Id, Opportunity> getExistingOppty(List<Insurance_Policy__c> insPolicy) {
		List<Opportunity> oppList = [SELECT Id, Insurance__c, IsClosed FROM Opportunity WHERE Insurance__c IN :insPolicy];
		Map<Id, Opportunity> insToOpp = new Map<Id, Opportunity>();
		for (Opportunity o : oppList) { insToOpp.put(o.Insurance__c, o); }
		return insToOpp;
	}

	private void triggerOppStageUpd(List<Opportunity> oppList) {
		if (oppList.size() <= 0) { return; }
		List<Opportunity> ignoreClosed = new List<Opportunity>();
		for (Opportunity o : oppList) {
			if (!o.IsClosed) { ignoreClosed.add(o); }
		}
		List<Database.SaveResult> srList = Database.update(ignoreClosed, false);
		CommonMethodsLibrary.emailResultFailure(srList, ignoreClosed, 'triggerOppStageUpd', 'InsuranceBatchSched', ERR_USER);
	}

	private Set<Id> filterActiveUser(List<Insurance_Policy__c> insPolicy) {
		Set<Id> userIds = new Set<Id>();
		for (Insurance_Policy__c p : insPolicy) { userIds.add(p.Sales_Rep_Name__c); }
		Map<Id, User> userMap = new Map<Id, User>([SELECT Id FROM User WHERE IsActive = TRUE AND Id = :userIds]);
		return userMap.keySet();
	}

	// private User defUserId() {
	// 	List<GroupMember> members = [SELECT Id, UserOrGroupId FROM GroupMember WHERE Group.Name = 'Contego Default Oppty Owner'];
	// 	Set<Id> memberIds = new Set<Id>();
	// 	Schema.SObjectType userType = Schema.User.getSObjectType();
	// 	for (GroupMember m : members) {
	// 		if (m.UserOrGroupId.getSObjectType() == userType) { memberIds.add(m.UserOrGroupId); }
	// 	}
	// 	return [SELECT Id, Email FROM User WHERE Id = :memberIds AND IsActive = TRUE LIMIT 1];
	// }
}