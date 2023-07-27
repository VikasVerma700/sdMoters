@IsTest
public class SyncMobySched_Test {
	@TestSetup
	static void makeData(){
		SyncMobyApiBase_Test.makeData();
	}

	@IsTest
	static void testSched() {
		Test.startTest();
		SyncMobySched.scheduleJob();
		Test.stopTest();
	}

	@IsTest
	static void testExecute() {
		Test.startTest();
		SyncMobySched q = new SyncMobySched();
		q.execute(null);
		Test.stopTest();
	}

	
}