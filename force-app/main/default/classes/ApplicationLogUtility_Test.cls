@isTest
public with sharing class ApplicationLogUtility_Test {
    @isTest
    static void testInsertCalloutSuccessLog(){
        ApplicationLogUtility.insertCalloutSuccessLog('_Test','Callout Request','Callout Response',Request.getCurrent().getRequestId(),false);
        System.assertEquals(1, ApplicationLogUtility.appLogList.size());
    }

    @isTest
    static void testInsertApexErrorLog(){
        Account accRecord = new Account(Name = 'Test Account');
        insert accRecord;
        try{
            insert accRecord;
            System.assert(false);
        }
        catch(Exception e){
            ApplicationLogUtility.insertApexErrorLog(new ApplicationLogUtility(), e, ApplicationLogUtility.PRIORITY_HIGH,false);
            System.assertEquals(1, ApplicationLogUtility.appLogList.size());
        }
    }

    @isTest
    static void testInsertDatabaseErrorLog(){
        Account accRecord = new Account(Name = 'Test Account');
        insert accRecord;
        Database.SaveResult insertResult = Database.insert(accRecord,false);
        Database.Error dbError = insertResult.getErrors()[0];
        ApplicationLogUtility.insertApexErrorLog(new ApplicationLogUtility(), dbError, ApplicationLogUtility.PRIORITY_HIGH,false);
        System.assertEquals(1, ApplicationLogUtility.appLogList.size());

    }

    @isTest
    static void testLogUpsertFailure(){
        Account accRecord = new Account(Name = 'Test Account');
        insert accRecord;
        accRecord.Home_Email__c = '1234';
        List<Account> accList = new List<Account>{accRecord};
        List<Database.UpsertResult> upsertResultList = Database.Upsert(accList,false);
        ApplicationLogUtility.logUpsertFailure('ApplicationLogUtility', upsertResultList, ApplicationLogUtility.PRIORITY_HIGH,false);
        System.assertEquals(1, ApplicationLogUtility.appLogList.size());
        System.debug(ApplicationLogUtility.getLogHtml(ApplicationLogUtility.appLogList[0]));
        ApplicationLogUtility.insertLogs();
    }

    @isTest
    static void testImmediateAlerts(){
        Test.startTest();
        ApplicationLogUtility.insertApexErrorLog('ApplicationLogUtility', 'testApexErrorLog', 'ApplicationLogUtility\ntestImmediateAlerts');
        ApplicationLogUtility.insertCalloutErrorLog('ApplicationLogUtility', 'testCalloutErrorLog', 'ApplicationLogUtility\ntestImmediateAlerts');
        ApplicationLogUtility.insertCalloutFailLog('ApplicationLogUtility', 'testCalloutFailLog', 'ApplicationLogUtility\ntestImmediateAlerts',null);
        ApplicationLogUtility.insertCalloutSuccessLog('ApplicationLogUtility', 'testCalloutSuccessLog', 'ApplicationLogUtility\ntestImmediateAlerts',null);
        ApplicationLogUtility.insertApexCompletionLog('ApplicationLogUtility','test Apex Completion Log','test immediate alerts','ApplicationLogUtility.PRIORITY_HIGH',false);
        Test.stopTest();
    }
}