@IsTest
public class CustAppCallbackQueue_Test {
	@IsTest
	public static void testQueue() {
		Test.startTest();
		Id jobId = System.enqueueJob(new CustAppCallbackQueue(new List<Customer_App_Callback__e> { new Customer_App_Callback__e() }));
		Test.stopTest();
		List<AsyncApexJob> jobInfo = [SELECT Status,NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
		System.assert(jobInfo.size() > 0);
	}

	@IsTest
	public static void testProcessCallback() {
		List<String> events = new List<String> { 'UPDATE_ACCOUNT', 'RESYNC_ACCOUNT', 'UPSERT_VEHICLE', 'REMOVE_VEHICLE', 'REMOVE_VEHICLE_ALTERNATE_DRIVER',
												 'UPSERT_VEHICLE_APPOINTMENT', 'REMOVE_VEHICLE_APPOINTMENT', 'REMOVE_VEHICLE_REPAIR_ORDER',
												 'UPSERT_TEST_DRIVE', 'UPSERT_VEHICLE_WARRANTY' };
		Test.startTest();
		for (String s : events) {
			CustAppCallbackQueue.processCallback(new Customer_App_Callback__e(Event__c = s));
		}
		Test.stopTest();
		// check debug logs, there shld be errors since the rest of the body isnt included
	}

	@IsTest
	public static void testProcessCallbackException() {
		TestFactory.genTriggerSettings('Customer App Callback', true);
		string[] events = new string[] { 'INVALID_EVENT' };
		Test.startTest();
		Customer_App_Callback__e callback = new Customer_App_Callback__e();
		callback.Id__c =  'abcde';
		callback.Event__c = 'INVALID_EVENT';
		EventBus.publish(callback);
		Test.stopTest();
	}
}