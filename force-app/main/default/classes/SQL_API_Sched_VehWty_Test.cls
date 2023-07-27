/** Deprecated */
@isTest
public class SQL_API_Sched_VehWty_Test {
	
	@TestSetup
	static void setup() {
		SQL_API_Base_Test.makeData();
		TestFactory.genVehType('NC', true);
		SQL_WtyPkg_Queue_Test.createWtyPkg();
		SQL_VehWty_Queue_Test.createVeh();
	}
	
	@isTest
	static void test_SQL_API_Sched_VehWty() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.SQL_SF_VehWty_API(200));
		Test.startTest();
		// SQL_API_Sched_VehWty.scheduleVehWty();
		string NAME = 'SQL API (SQL_Sched_VehWty)_Test1';
		string CRON_EXPR = '0 0 0 3 9 ? 2022';
		string jobId = System.schedule(NAME, CRON_EXPR, new SQL_API_Sched_VehWty());

		// s.execute(null);
		Test.stopTest();
	}
}