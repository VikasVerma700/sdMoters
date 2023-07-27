@isTest
public with sharing class ProcessAppLogs_Test {

    private static void insertCalloutErrorLog(String className,String recordId, String companycode){
        CalloutException calloutExc = new CalloutException();
        calloutExc.setMessage('Error sending '+recordId+' '+companycode);
        ApplicationLogUtility.insertCalloutErrorLog(className, calloutExc, ApplicationLogUtility.PRIORITY_HIGH, false);
    }

    private static void insertApexErrorLog(String className, String recordId, String companycode){
        Exception apexExc = new NullPointerException();
        apexExc.setMessage('Exception : '+recordId+' '+companycode);
        ApplicationLogUtility.insertApexErrorLog(className, apexExc, ApplicationLogUtility.PRIORITY_HIGH, false);
    }
    @isTest
    private static void testEsaLogCapture(){
        ExternalSystemAccount__c esa = new ExternalSystemAccount__c();
        insert esa;
        insertApexErrorLog('DmsEsaAccount', String.valueOf(esa.Id), CompanyRepository.C099);
        insertCalloutErrorLog('DmsEsaAccount', String.valueOf(esa.Id), CompanyRepository.C099);
        ApplicationLogUtility.insertLogs();
        Test.startTest();
        ProcessAppLogs.startJobs(ProcessAppLogs.BatchType.TYPE_ESA,0);
        Test.stopTest();
    }

    @isTest
    private static void testInvalidLogCapture(){
        ExternalSystemAccount__c esa = new ExternalSystemAccount__c();
        insert esa;
        String esaId = String.valueOf(esa.Id);
        if(esaId.substring(esaId.length()-1, esaId.length()) != 'A'){
            esaId = esaId.substring(0,esaId.length()-1) + 'A';
        }
        else{
            esaId = esaId.substring(0,esaId.length()-1) + 'B';
        }
        insertApexErrorLog('DmsEsaAccount', esaId, CompanyRepository.C099);
        insertCalloutErrorLog('DmsEsaAccount', esaId, CompanyRepository.C099);
        ApplicationLogUtility.insertLogs();
        Test.startTest();
        ProcessAppLogs.startJobs(ProcessAppLogs.BatchType.TYPE_ESA,0);
        Test.stopTest();
    }
}