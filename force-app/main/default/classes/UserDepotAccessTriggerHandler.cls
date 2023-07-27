public with sharing class UserDepotAccessTriggerHandler extends TriggerBase{
    public static final String TRIG_SETTING = 'User Depot Access';
    public static final String DUPLICATE_ACCESS = 'Access already assigned';
    public UserDepotAccessTriggerHandler() {
        super(TRIG_SETTING);
    }

    public override void beforeInsert(List<SObject> triggerNew) {
        preventDuplicateDepotAccess((List<UserDepotAccess__c>) triggerNew);
    }

    public override void beforeUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld){
        preventDuplicateDepotAccess((List<UserDepotAccess__c> )triggerNew.values());
    }

    /**
	 * helper function to create a string by concatenating fields using '#' to create
     * a potentially unique string
	 * @param  userDepotAccess UserDepotAccess__c record whose fields are to be concatednated
	 * @return           concatenated unique string
	 */
    public static String getUniqueAccessString(UserDepotAccess__c userDepotAccess){
        String uniqueString = '';
        uniqueString += (userDepotAccess.User__c != null) ? userDepotAccess.User__c : '';
        uniqueString += '#';
        uniqueString += (userDepotAccess.Workshop__c != null) ? userDepotAccess.Workshop__c : '';
        uniqueString += '#';
        uniqueString += (userDepotAccess.Company__c != null) ? userDepotAccess.Company__c : '';
        uniqueString += '#';
        uniqueString += (userDepotAccess.Type__c != null) ? userDepotAccess.Type__c : '';
        return uniqueString;
    }

    /**
	 * static function to check if provided list of UserDepotAccess__c records 
     * do not have all  fields matching with any other record by creating a unique string
     * by concatenating all fields that are supposed to be unique
	 * @param  userDepotAccessList UserDepotAccess__c records which are either being inserted or updated
	 */
    public static void preventDuplicateDepotAccess(List<UserDepotAccess__c> userDepotAccessList){
        Set<Id> companyIdSet = new Set<Id>();
        Set<Id> userIdSet = new Set<Id>();
        Set<Id> workshopIdSet = new Set<Id>();
        Set<String> typeSet = new Set<String>();

        for(UserDepotAccess__c userDepotAccess : userDepotAccessList){
            companyIdSet.add(userDepotAccess.Company__c);
            userIdSet.add(userDepotAccess.User__c);
            workshopIdSet.add(userDepotAccess.Workshop__c);
            typeSet.add(userDepotAccess.Type__c);
        }

        List<UserDepotAccess__c> existingDepotAccessList = [
            SELECT Id, Workshop__c, Company__c, User__c, Type__c
            FROM UserDepotAccess__c
            WHERE Type__c IN :typeSet
                AND Workshop__c IN :workshopIdSet
                AND Company__c IN :companyIdSet
                AND User__c IN :userIdSet
        ];

        Map<String,Id> id2UniqueAccessString = new Map<String,Id>();

        for(UserDepotAccess__c userDepotAccess: existingDepotAccessList){
            id2UniqueAccessString.put(getUniqueAccessString(userDepotAccess),userDepotAccess.Id);
        }
        Map<String,List<UserDepotAccess__c>> uniqueString2accessList = new Map<String,List<UserDepotAccess__c>>();
        for(UserDepotAccess__c userDepotAccess: userDepotAccessList){
            String uniqueString = getUniqueAccessString(userDepotAccess);
            List<UserDepotAccess__c> uniqueKeyAccessList = uniqueString2accessList.get(uniqueString);
            if(uniqueKeyAccessList == null){
                uniqueKeyAccessList = new List<UserDepotAccess__c>();
            }
            uniqueKeyAccessList.add(userDepotAccess);
            uniqueString2accessList.put(uniqueString,uniqueKeyAccessList);
            if(id2UniqueAccessString.containsKey(uniqueString)){
                if(userDepotAccess.id == null){//insert check
                    userDepotAccess.addError(DUPLICATE_ACCESS + ' on '+String.valueOf(id2UniqueAccessString.get(uniqueString)));
                }
                else{//update check
                    if(id2UniqueAccessString.get(uniqueString)!= userDepotAccess.id){//only raise error if fields match with another record
                        userDepotAccess.addError(DUPLICATE_ACCESS + ' on '+String.valueOf(id2UniqueAccessString.get(uniqueString)));
                    }
                }
            }
        }

        for(String uniqueKey: uniqueString2accessList.keySet()){
            List<UserDepotAccess__c> uniqueKeyAccessList = uniqueString2accessList.get(uniqueKey);
            if(uniqueKeyAccessList.size()>1){
                for(Integer i=0;i<uniqueKeyAccessList.size()-1;i++){
                    uniqueKeyAccessList[i].addError(DUPLICATE_ACCESS);
                }
            }
        }
    }
}