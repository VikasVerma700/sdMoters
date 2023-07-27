@isTest
public class SQL_API_Wty_Sched_Test {

	@TestSetup
	static void setup() {
		SQL_API_Base_Test.makeData();
		// TestFactory.genVehType('NC', true);
		// SQL_WtyPkg_Queue_Test.createWtyPkg();
		// SQL_VehWty_Queue_Test.createVeh();
	}

	@isTest static void testSched() {
		Test.startTest();
		String jobId = SQL_API_Wty_Sched.scheduleJob();
		Test.stopTest();
		List<CronTrigger> ctList = [SELECT Id, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
		System.assertEquals(ctList.size(), 1);
	}

}