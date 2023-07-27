@isTest
public with sharing class CaseMailTest {
    @TestSetup
	static void makeData() {
		TestFactory.genTriggerSettings('Case', true);
        Company__c C028 = new Company__c(Name = '028');
        insert C028;
	}

    static Datetime nowDateTime;

    static List<Id> prepareCase(List<String> priorityList, List<Integer> dayList){
        List<Case> caseList = new List<Case>();
        for(Integer i=0; i<dayList.size();i+=1){
            Case cs = CaseTest.createValid();
            cs.Priority = priorityList.get(i);
            cs.Type = 'Complaint';
            caseList.add(cs);
        }

        insert caseList;
        List<Id> caseIdList = new List<Id>();

        for(Integer i=0;i<dayList.size();i++){
            Id caseId = caseList.get(i).Id;
            Test.setCreatedDate(caseId, nowDateTime.addDays(-1 * dayList.get(i)));
            System.debug(i);
            System.debug(nowDateTime.addDays(-1 * dayList.get(i)));
            caseIdList.add(caseId);
        }
        return caseIdList;

    }

    static List<Id> prepareCase(String priority, List<Integer> dayList){
        List<String> priorityList = new List<String>();
        for(Integer i=0; i< dayList.size();i++){
            priorityList.add(priority);
        }
        return prepareCase(priorityList, dayList);
    }

    @isTest
    static void testKeepInView(){
        nowDateTime = Datetime.now();
        String priority = CaseCommon.PRIORITY_KEEP_IN_VIEW;
        List<Integer> dayList = new List<Integer>{1,2,3,4,5,6,7};
        List<Id> caseIdList = prepareCase(priority, dayList);
        test.startTest();
        CaseBatch batchJob = new CaseBatch(CaseBatch.BatchType.TYPE_A,Datetime.now());
        Database.executeBatch(batchJob);
        test.stopTest();
        String query = 'SELECT '+ CaseCommon.getAllFields()+' FROM Case';
        query += ' WHERE Id IN :caseIdList';
        List<Case> caseList = Database.query(query);
    }
}