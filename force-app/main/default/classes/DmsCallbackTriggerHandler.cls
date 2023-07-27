public with sharing class DmsCallbackTriggerHandler{
    public static Map<String, Map<String, List<String>>> entityWithRecordIdMap = new Map<String, Map<String, List<String>>>();
    public static String entity;
    public static String companyCode;

    public DmsCallbackTriggerHandler(String action, Map<String, Map<String, List<String>>> recordIdMap) {
        entity = action;
        entityWithRecordIdMap = recordIdMap;
    }

    public static void afterInsert(List<DmsCallBack__e> eventList) {
        DMSCallbackQueue.enqueue(eventList); 
	}

    public void publishEvent() {
        try {
            if(entityWithRecordIdMap.isEmpty()){ return ;}
            List<DmsCallBack__e> dmsCallbackList = new List<DmsCallBack__e>(); 
            if(entityWithRecordIdMap.containsKey(entity)){
                Map<String, List<String>> companyCodeWithRecordIdListMap = entityWithRecordIdMap.get(entity);
                for(String compCode : companyCodeWithRecordIdListMap.keySet() ){
                    if(companyCodeWithRecordIdListMap.containsKey(compCode)){
                        for(String str : companyCodeWithRecordIdListMap.get(compCode)){
                            DmsCallBack__e dmsCallback = new DmsCallBack__e( Event__c = entity, Id__c = str, CompanyCode__c = compCode);
                            dmsCallbackList.add(dmsCallback);
                        }
                    } 
                } 
            }
            if(!dmsCallbackList.isEmpty()){ 
				List<Database.SaveResult> results = EventBus.publish(dmsCallbackList);
				for (Database.SaveResult sr : results) {
					if (sr.isSuccess()) {
						System.debug('Successfully published event.');
					} else {
						for(Database.Error err : sr.getErrors()) {
							System.debug('Error returned: ' + err.getStatusCode() );
						}
					}
				} 
			}
        } catch(Exception e) {
            DmsCallbackTriggerHandler handler = new DmsCallbackTriggerHandler('', new Map<String, Map<String, List<String>>>());
            ApplicationLogUtility.insertApexErrorLog(handler, e, ApplicationLogUtility.PRIORITY_HIGH, false);
			ApplicationLogUtility.insertLogs();
        }     
	}
}