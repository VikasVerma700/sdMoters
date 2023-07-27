@isTest
public with sharing class SchedulerTest {
    @isTest
    static void testTwoJobs(){
        test.startTest();
        Scheduler sc = new Scheduler();
        SchedulableContext ctx = null;
        sc.execute(ctx);
        ApplicationLogAlerts appLogSchedulable = new ApplicationLogAlerts();
		appLogSchedulable.execute(null);
        test.stopTest();
    }

    @isTest
    static void testError(){
        CompanyRepositoryTest.makeData();
		SQL_API_Base_Test.makeData();
        test.startTest();
        Scheduler sc = new Scheduler();
        sc.execute(null);
        test.stopTest();
        String query = 'SELECT '+String.join(new List<String>(schema.SObjectType.ApplicationLog__c.fields.getMap().keySet()),',');
        query += ' FROM ApplicationLog__c ';
        
        List<ApplicationLog__c> appLogList = Database.query(query);
        for(ApplicationLog__c appLog:appLogList){
            System.debug(appLog);
        }
        System.assertEquals(0, appLogList.size());
    }
}