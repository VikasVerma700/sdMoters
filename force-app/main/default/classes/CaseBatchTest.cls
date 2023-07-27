@isTest
public with sharing class CaseBatchTest {
    @TestSetup
    static void makeData(){
        TestFactory.genTriggerSettings('Case', true);
        Company__c C028 = new Company__c(Name = '028');
        insert C028;
    }

    @isTest
    static void testTypeA(){
        
        CaseBatch.withinBusinessRange = true;
        List<Case> caseList = new List<Case>();
        Case cs = CaseTest.createValid();
		cs.Draft_Mode__c = true;
        caseList.add(cs);
        cs = CaseTest.createValid();
		cs.Draft_Mode__c = false;
        cs.Hold_Notification_Email__c = true;
        caseList.add(cs);
        insert caseList;
        test.startTest();
        System.debug(CaseBatch.withinBusinessRange);
        CaseBatch batchJobA = new CaseBatch(CaseBatch.BatchType.TYPE_A, Datetime.now());
        Database.executeBatch(batchJobA);
        test.stopTest();
    }

    @isTest
    static void testTypeB(){
        
        CaseBatch.withinBusinessRange = true;
        List<Case> caseList = new List<Case>();
        Case cs = CaseTest.createValid();
		cs.Draft_Mode__c = true;
        cs.Stop_Escalation__c = true;
        cs.Stop_Escalation_Till_Date__c = Date.today().addDays(-1);
        cs.Stop_Escalation_Remarks__c = 'Test setup';
        caseList.add(cs);
        insert caseList;
        test.startTest();
        System.debug(CaseBatch.withinBusinessRange);
        CaseBatch batchJobB = new CaseBatch(CaseBatch.BatchType.TYPE_B, Datetime.now());
        Database.executeBatch(batchJobB);
        test.stopTest();
    }

    @isTest
    static void testTypeC(){
        CaseBatch.withinBusinessRange = true;
        List<Case> caseList = new List<Case>();
        Case cs = CaseTest.createValid();
		cs.Type = CaseCommon.TYPE_GENERAL_ENQUIRY;
        cs.Priority = CaseCommon.PRIORITY_LOW;
        cs.Department__c = String.join(CaseCommon.getDepartments(), ';');
        caseList.add(cs);
        insert caseList;
        Id csId = cs.Id;
        Test.setCreatedDate(cs.Id, Datetime.now().addDays(-3));
        String query = 'SELECT '+ CaseCommon.getAllFields();
        query += ' FROM Case WHERE Id = :csId';
        cs = Database.query(query);
        cs.EscalationStage__c = CaseStage.initial(cs);
        cs.NextEscalation__c = CaseStage.next(cs, Datetime.now());
        update cs;
        test.startTest();
        CaseBatch batchJobC = new CaseBatch(CaseBatch.BatchType.TYPE_C, Datetime.now());
        Database.executeBatch(batchJobC);
        test.stopTest();
    }

    @isTest
    static void testBatchChaining(){
        CaseBatch batchJobA = new CaseBatch(CaseBatch.BatchType.TYPE_A, Datetime.now(), true);
        Database.executeBatch(batchJobA);
    }
}