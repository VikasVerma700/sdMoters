@isTest
public with sharing class ApplicationLogAlerts_Test {
	@TestSetup
	public static void makeData() {
        TestFactory.genTriggerSettings(ApplicationLogTriggerHandler.TRIG_SETTING,true);
    }
    @isTest
    static void testScheduledBatches(){
        Test.startTest();
        ApplicationLogAlerts scheduleApplicationLogAlerts = new ApplicationLogAlerts();
        scheduleApplicationLogAlerts.execute(null);
        Test.stopTest();
        System.assertEquals(1,scheduleApplicationLogAlerts.jobIdList.size());

    }
}