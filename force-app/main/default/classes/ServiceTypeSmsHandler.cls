public without sharing class ServiceTypeSmsHandler extends TriggerBase {
	public class ServiceTypeSmsException extends Exception {}
	public static boolean SQL_UPDATE = false;
	public static final string TRIG_SETTING = 'Service Type SMS';

	public ServiceTypeSmsHandler() { 
		super(TRIG_SETTING, 2);
		system.debug('ServiceTypeSmsHandler()');
	}
	
	public override void beforeInsert(List<SObject> triggerNew) {
		system.debug('ServiceTypeSmsHandler: beforeInsert');
		ServiceTypeSmsHandler.checkUniqueServiceType((List<ServiceTypeSms__c>) triggerNew);
	}

	public override void beforeUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
		system.debug('ServiceTypeSmsHandler: beforeUpdate');
		ServiceTypeSmsHandler.checkUniqueServiceType((List<ServiceTypeSms__c>) triggerNew.values());
	}

	public static void checkUniqueServiceType(List<ServiceTypeSms__c> triggerNew) {
		Map<Id, Company__c> mapComp = new Map<Id, Company__c>([SELECT Id, Name FROM Company__c]);

		for (ServiceTypeSms__c sts :triggerNew) {
			string key = string.format('{0}_{1}', new string[] { mapComp.get(sts.Company__c).Name, sts.Name });
			system.debug('Key: ' + key);
			sts.Key__c = key;
		}
	}
}