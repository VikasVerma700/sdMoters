public virtual class TriggerBase {
	public static List<User> ERR_USER;
	public static User CUR_USER;
    public static User admin;
	public class TriggerException extends Exception {}
	@TestVisible private static final Integer DEF_RUN = 1;
	private String triggerName;
	public TriggerBase(String triggerName, Integer maxRun) {
		this.triggerName = triggerName;
		TriggerRun.setMaxRun(triggerName, maxRun);
	}
	public TriggerBase(String triggerName) { this(triggerName, DEF_RUN); }

	public final static Map<String, Company__c> CMP_MAP;
	static {
		List<User> userList = [SELECT Id, Email, Company__c, Profile.Name, IsActive,Alias FROM User WHERE Alias = 'godlike' OR Id = :UserInfo.getUserId()];
		ERR_USER = new List<User>();
		Boolean hasAdmin = false;
		for (User u : userList) {
			if (u.Id == UserInfo.getUserId()) {
				ERR_USER.add(u);
				CUR_USER = u;
			} else {
				if (!hasAdmin) {
					ERR_USER.add(u);
					hasAdmin = true;
				}
			}
            if(u.alias == 'godLike' && u.IsActive){
                admin = u;
            }
		}
		CMP_MAP = new Map<String, Company__c>();
		for (Company__c cmp : [SELECT Id, Name, Description__c FROM Company__c]) { CMP_MAP.put(cmp.Name, cmp); }
	}

	public String getTriggerName() { return this.triggerName; }
	public virtual void beforeInsert(List<SObject> triggerNew) { return; }
	public virtual void beforeUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) { return; }
	public virtual void beforeDelete(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) { return; }
	public virtual void afterInsert(Map<Id, SObject> triggerNew) { return; }
	public virtual void afterUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) { return; }
	public virtual void afterDelete(Map<Id, SObject> triggerOld) { return; }
	public virtual void afterUndelete(Map<Id, SObject> triggerOld) { return; }
}