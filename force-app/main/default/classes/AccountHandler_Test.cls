@isTest
public class AccountHandler_Test {

	@TestSetup
	public static void makeData() {
		TestFactory.genTriggerSettings(AccountHandler.TRIG_SETTING, true);
		SyncMoby02Contact_Test.makeData();
	}

	@isTest
	public static SyncMoby02Contact.MobyContactRes createObj() {
		SyncMoby02Contact.MobyContactRes response = SyncMoby02Contact_Test.createObj();

		return response;
	}

	@isTest
	public static void testNewLeadsNotFromSharktank() {
		SyncMoby02Contact.MobyContactRes res = createObj();

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);

		Test.startTest();
		SyncMoby02Contact job = new SyncMoby02Contact();
		job.upsertContact(res);

		Account[] accs = [SELECT Id, Name, AccountSource, Customer_Number__c, MobyContactNumber__c, MobySyncToMc__c, SyncToMc__c FROM Account LIMIT 5];
		for (Account acc :accs) {
			string msg = string.format('testNewLeadsNotFromSharktank(): Account: {0} with source: {1} with SyncToMc: {2} failed trigger update.', new string[] { acc.Name, acc.AccountSource, String.valueOf(acc.SyncToMc__c) });
			System.assert(acc.MobySyncToMc__c == true, msg);
		}
		Test.stopTest();
	}

	@isTest
	public static void testNewLeadsFromSharktank() {
		SyncMoby02Contact.MobyContactRes res = createObj();
		for (SyncMoby02Contact.MobyContact mobycon :res.contacts) {
			mobycon.source = 'Sharktank';
		}

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);

		Test.startTest();
		SyncMoby02Contact job = new SyncMoby02Contact();
		job.upsertContact(res);

		Account[] accs = [SELECT Id, Name, AccountSource, Customer_Number__c, MobyContactNumber__c, MobySyncToMc__c, SyncToMc__c FROM Account LIMIT 5];
		for (Account acc :accs) {
			string msg = string.format('testNewLeadsFromSharktank(): Account: {0} with source: {1} with SyncToMc: {2} failed trigger update.', new string[] { acc.Name, acc.AccountSource, String.valueOf(acc.SyncToMc__c) });
			System.assert(acc.MobySyncToMc__c == false, msg);
		}
		Test.stopTest();
	}

	@isTest
	public static void testDeleteAccount() {
		SyncMoby02Contact.MobyContactRes res = createObj();
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);

		Test.startTest();
		SyncMoby02Contact job = new SyncMoby02Contact();
		job.upsertContact(res);

		Account[] accs = [SELECT Id, Name, AccountSource, Customer_Number__c, MobyContactNumber__c, MobySyncToMc__c, SyncToMc__c FROM Account LIMIT 5];
		Account master;
		Account[] slaves = new Account[]{};
		
		for (Integer row = 0; row < accs.size(); row++) {
			if (row == 0) { master = accs[row]; }
			else { slaves.add(accs[row]); }
		}

		Database.MergeResult[] mrs = Database.merge(master, slaves, false);
		System.debug(JSON.serialize(mrs));

		Test.stopTest();
	}

	// @isTest
	// public static void testCheckPhone() {
	// 	SyncMoby02Contact.MobyContactRes res = createObj();

	// 	TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
	// 	Test.setMock(HttpCalloutMock.class, mock);

	// 	Test.startTest();
	// 	SyncMoby02Contact job = new SyncMoby02Contact();
	// 	job.upsertContact(res);

	// 	Account[] acs = [SELECT Id, PersonMobilePhone, Phone FROM Account];	
	// 	System.debug(JSON.serialize(acs));
	// 	AccountHandler.checkPhone(acs);
	// }

}