@isTest
public with sharing class UserDepotAccessTriggerHandler_Test {

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
            Type__c = 'Booking'
        );
        insert userDepotAccess;
    }

    @isTest
    static void testDuplicateCreation(){
        UserDepotAccess__c userDepotAccess = new UserDepotAccess__c(
            Company__c = getCompany('companyA').Id,
            User__c = getUser('userA').Id,
            Workshop__c = getWorkshop('W1A').Id,
            Type__c = 'Booking'
        );
        Test.startTest();
        try{
            insert userDepotAccess;
            System.assert(false, 'Duplicate Access Assignment');
        }
        catch (DmlException insertException){
            System.debug(insertException);
            System.assert(insertException.getDmlMessage(0).contains(UserDepotAccessTriggerHandler.DUPLICATE_ACCESS));
        }
    }

    @isTest
    static void testDuplicateUpdate(){
        UserDepotAccess__c userDepotAccess = new UserDepotAccess__c(
            Company__c = getCompany('companyA').Id,
            User__c = getUser('userB').Id,
            Workshop__c = getWorkshop('W1A').Id,
            Type__c = 'Booking'
        );
        Test.startTest();
        try{
            insert userDepotAccess;
            userDepotAccess.User__c = getUser('userA').Id;
            update userDepotAccess;
            System.assert(false, 'Duplicate Access Assignment');
        }
        catch (DmlException updateException){
            System.debug(updateException);
            System.assert(updateException.getDmlMessage(0).contains(UserDepotAccessTriggerHandler.DUPLICATE_ACCESS));
        }
    }

    @isTest
    static void testUpdateNoDuplicate(){
        List<UserDepotAccess__c> userDepotAccessList = [
            SELECT Id,IsReadOnly__c
            FROM UserDepotAccess__c
            LIMIT 1
        ];
        userDepotAccessList[0].IsReadOnly__c = true;
        update userDepotAccessList;
        System.assert(true,userDepotAccessList[0].IsReadOnly__c);
    }

    @isTest
    static void testInsertSimultaneousDuplicate(){
        List<UserDepotAccess__c> userDepotAccessList = new List<UserDepotAccess__c>();
        userDepotAccessList.add(new UserDepotAccess__c(
            Company__c = getCompany('companyA').Id,
            User__c = getUser('userA').Id,
            Workshop__c = getWorkshop('W1A').Id,
            Type__c = 'Booking'
        ));
        userDepotAccessList.add(new UserDepotAccess__c(
            Company__c = getCompany('companyA').Id,
            User__c = getUser('userA').Id,
            Workshop__c = getWorkshop('W1A').Id,
            Type__c = 'Booking'
        ));
        Test.startTest();
        try{
            insert userDepotAccessList;
            System.assert(false, 'Duplicate Access Assignment');
        }
        catch (DmlException insertException){
            System.debug(insertException);
            System.assert(insertException.getDmlMessage(0).contains(UserDepotAccessTriggerHandler.DUPLICATE_ACCESS));
        }
    }
}