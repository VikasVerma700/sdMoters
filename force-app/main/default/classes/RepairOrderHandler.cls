public class RepairOrderHandler extends TriggerBase {
	// private final static List<User> ADMIN_USER = [SELECT Id, Email FROM User WHERE Alias = 'godlike' LIMIT 1];
	// private final static String OPS_CODE = 'CSACOM';
	// private final static String DEFAULT_TEXT = 'CSA Comment';
	public static final String TRIG_SETTING = 'Repair Order';
	// public static final List<Employee_Master__c> BETA_CSA = [SELECT Id FROM Employee_Master__c WHERE Name IN ('Teh Jia Yit', 'Yeam Wei Hong',
																											//   'Jeffrey Koh Choon Wai', 'Lee Cheng Yang')];
	public RepairOrderHandler() { super(TRIG_SETTING, 3); }

	public override void afterInsert(Map<Id, SObject> triggerNew) {
		// CustAppRO.pushNotificationOnStatusChange((Map<Id, ServiceOrder__c>) triggerNew, new Map<Id, ServiceOrder__c>());
	}

	public override void afterUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
		// CustAppRO.pushNotificationOnStatusChange((Map<Id, ServiceOrder__c>) triggerNew, (Map<Id, ServiceOrder__c>) triggerOld);
	}
}