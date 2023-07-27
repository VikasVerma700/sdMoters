public with sharing class UserDepotAccessRepository {

    public static final String ACCESS_TYPE_BOOKING = 'Booking';
    public static final String ACCESS_TYPE_SETUP = 'Setup';
    public static List<UserDepotAccess__c> getUserDepotAccess(String type, boolean writeAccessOnly, Id userId){
        String query ='SELECT ';
        query += 'Workshop__r.Name,Company__r.name,Company__r.Description__c,Company__c,IsReadOnly__c,Id,Workshop__r.IsActive__c,Workshop__r.Short_Address__c ';
        query += 'FROM ';
        query += 'UserDepotAccess__c ';
        query += 'WHERE ';
        query += writeAccessOnly ? 'IsReadOnly__c = false AND ' : '';
        query += 'User__c = \''+ userId+'\' ';
        query += 'AND Type__c = \''+type+'\' ';
        query += 'ORDER BY Workshop__r.Name ASC ';

        List<UserDepotAccess__c> userDepotAccessList =(List<UserDepotAccess__c>) Database.query(query);
        return userDepotAccessList;
    }

    public static List<String> getAccessibleWorkhopNames(String type,boolean writeAccessOnly, Id userId){

        List<UserDepotAccess__c> userDepotAccessList = getUserDepotAccess(type, writeAccessOnly, userId);
        List<String> workshopNames = new List<String>();
        for(UserDepotAccess__c userDepotAccess : userDepotAccessList){
            String workshopName = userDepotAccess.workshop__r.Name;
            if(String.isNotBlank(workshopName)){
                workshopNames.add(workshopName.trim());
            }
        }
        return workshopNames;
    }

    public static List<String> getAccessibleWorkhopNames(String type, boolean writeAccessOnly){
        return getAccessibleWorkhopNames(type, writeAccessOnly, UserInfo.getUserId());
    }

    public static List<String> getAccessibleWorkhopNames(String type){
        return getAccessibleWorkhopNames(type, false);
    }

    public static List<UserDepotAccess__c> getUserDepotAccess(String type, boolean writeAccessOnly){
        return getUserDepotAccess(type, writeAccessOnly, UserInfo.getUserId());
    }
}