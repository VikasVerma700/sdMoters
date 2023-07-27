public with sharing class ApplicationLogTriggerHandler extends TriggerBase{
    public static final String TRIG_SETTING = 'Application Log';
    public ApplicationLogTriggerHandler() {
        super(TRIG_SETTING);
    }

    public override void afterInsert(Map<Id, SObject> triggerNew) {
        sendImmediateLogAlert((List<ApplicationLog__c>) triggerNew.values());
	}

    public static void sendImmediateLogAlert(List<ApplicationLog__c> appLogList){
        List<Id> immediateAppLogIdList = new List<Id>();
        for(ApplicationLog__c appLog :appLogList){
            if(ApplicationLogUtility.IMMEDIATE_PRIORITY_LIST.contains(appLog.Priority__c )){
                immediateAppLogIdList.add(appLog.Id);
            }
        }

        ApplicationLogUtility.sendLogAlert(immediateAppLogIdList);
    }
}