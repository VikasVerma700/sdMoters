@IsTest
public class SQL_API_Sched_Test {
	@TestSetup
	public static void setup() {
		SQL_API_Base_Test.makeData();
	}

	@isTest static void testSched() {
		Test.startTest();
		SQL_API_Sched.scheduleJob();
		Test.stopTest();
	}
}