@isTest
public with sharing class ReportAlerts_Test {
    @isTest(SeeAllData='true')
    static void testAlerts(){
        ReportAlerts reportAlert = new ReportAlerts();
        reportAlert.execute(null);
    }

}