@isTest
public with sharing class UserDepotAccessRepository_Test {
    static Company__c getCompany(String companyName){
        List<Company__c> companyList = [
            SELECT Id,Name
            FROM Company__c 
            WHERE Name = :companyName
        ];
        if(companyList.size()>0){
            return companyList[0];
        }

        return null;
    }

    static User getUser(String alias){
        List<User> userList = [
            SELECT Id,alias, Name
            FROM User
            WHERE alias = :alias
        ];
        if(userList.size()>0){
            return userList[0];
        }
        return null;
    }

    static Workshop__c getWorkshop(String workshopName){
        List<Workshop__c> workshopList = [
            SELECT Id,Name
            FROM Workshop__c 
            WHERE Name = :workshopName
        ];

        if(workshopList.size()>0){
            return workshopList[0];
        }

        return null;
    }

    @TestSetup
    static void makeData(){
        //create custom setting record necessary to run trigger
        TestFactory.genTriggerSettings(UserDepotAccessTriggerHandler.TRIG_SETTING,true);
        
        List<Company__c> companyList = TestFactory.genCompany(2, false);
        companyList[0].name = 'companyA';
        companyList[1].name = 'companyB';
        insert companyList;

        List<WorkShop__c> workshopList = TestFactory.genWorkshop(2, false);
        workshopList[0].name = 'W1A';
        workshopList[0].Company__c = companyList[0].Id;
        workshopList[1].name = 'W1B';
        workshopList[1].Company__c = companyList[1].Id;
        insert workshopList;

        List<User> userList = TestFactory.genUser(2,false);
        userList[0].alias = 'userA';
        userList[1].alias = 'userB';
        insert userList;
        System.debug(getCompany('companyA'));
        System.debug(getUser('userA'));
        System.debug(getWorkshop('W1A'));
        UserDepotAccess__c userDepotAccess = new UserDepotAccess__c(
            Company__c = getCompany('companyA').Id,
            User__c = getUser('userA').Id,
            Workshop__c = getWorkshop('W1A').Id,
            Type__c = 'Booking',
            IsReadOnly__c = true
        );
        insert userDepotAccess;
    }

    @isTest
    static void getCurrentUserAccess(){
        List<UserDepotAccess__c> currentUserAccessList = UserDepotAccessRepository.getUserDepotAccess(UserDepotAccessRepository.ACCESS_TYPE_BOOKING,false);
        System.assert(currentUserAccessList.isEmpty());

        List<String> currentUserWorkshopNames = UserDepotAccessRepository.getAccessibleWorkhopNames(UserDepotAccessRepository.ACCESS_TYPE_BOOKING);
        System.assert(currentUserWorkshopNames.isEmpty());
    }

    @isTest
    static void testuserA(){
        List<String> userAWorkshopNamesList = UserDepotAccessRepository.getAccessibleWorkhopNames(UserDepotAccessRepository.ACCESS_TYPE_BOOKING,true,getUser('userA').Id);
        System.assert(userAWorkshopNamesList.isEmpty());//no write access yet

        List<UserDepotAccess__c> userAccessList = UserDepotAccessRepository.getUserDepotAccess(UserDepotAccessRepository.ACCESS_TYPE_BOOKING,false,getUser('userA').Id);
        System.assertEquals(1,userAccessList.size());//read access already provided
        userAccessList.get(0).IsReadOnly__c = false;
        update userAccessList;

        userAWorkshopNamesList = UserDepotAccessRepository.getAccessibleWorkhopNames(UserDepotAccessRepository.ACCESS_TYPE_BOOKING,true,getUser('userA').Id);
        System.assert(userAWorkshopNamesList.contains('W1A'));//write access provided
    }
}