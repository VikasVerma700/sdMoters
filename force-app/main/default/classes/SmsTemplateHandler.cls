public without sharing class SmsTemplateHandler extends TriggerBase {
	public class SmsTemplateException extends Exception {}
	public static boolean SQL_UPDATE = false;
	public static final string TRIG_SETTING = 'SMS Template';

    public SmsTemplateHandler() { super(TRIG_SETTING, 2); }

	public override void beforeInsert(List<SObject> triggerNew) {
		SmsTemplateHandler.genUniqueKey((List<SmsTemplate__c>) triggerNew);
	}

	public override void beforeUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
		SmsTemplateHandler.genUniqueKey((List<SmsTemplate__c>) triggerNew.values());
	}

	public static void genUniqueKey(List<SmsTemplate__c> triggerNew) {
		Map<Id, Company__c> mapComp = new Map<Id, Company__c>([SELECT Id, Name FROM Company__c]);
		Map<Id, Workshop__c> mapWork = new Map<Id, Workshop__c>([SELECT Id, Name FROM Workshop__c]);

		for (SmsTemplate__c st :triggerNew) {
			/** Key: Company__r.Name _ Workshop__r.Name _ Type__c */
			string key = string.format('{0}_{1}_{2}'
				, new string[] { 
					mapComp.get(st.Company__c).Name
					, mapWork.get(st.Workshop__c).Name
					, st.Type__c
				}
			);
			system.debug('Key: ' + key);
			st.Key__c = key;
		}
	}
}