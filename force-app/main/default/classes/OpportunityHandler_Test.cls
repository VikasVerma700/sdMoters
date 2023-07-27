@isTest
public class OpportunityHandler_Test {

	@TestSetup
	public static void makeData() {
		TestFactory.genTriggerSettings(AccountHandler.TRIG_SETTING, true);
		TestFactory.genTriggerSettings(OpportunityHandler.TRIG_SETTING, true);
		SyncMoby04Opportunity_Test.makeData();
	}

	@isTest
	public static SyncMoby04Opportunity.MobyOpportunityRes createObj() {
		SyncMoby04Opportunity.MobyOpportunityRes response = SyncMoby04Opportunity_Test.createObj();

		// for (SyncMoby04Opportunity.MobyOpportunity mobyopp :response.opportunities) {
		// 	mobyopp.recordSource = 'Sharktank';
		// }

		return response;
	}

	@isTest
	public static void testNewOppoLeadsNotFromSharktank() {
		SyncMoby04Opportunity.MobyOpportunityRes res = createObj();
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);

		Test.startTest();
		SyncMoby04Opportunity job = new SyncMoby04Opportunity();
		job.upsertOppo(res);

		Opportunity[] oppos = [SELECT Id, Name, MobyRecordSource__c, AccountId, Account.Name, Account.AccountSource, Account.MobySyncToMc__c, Account.SyncToMc__c FROM Opportunity];
		for (Opportunity oppo :oppos) {
			System.debug(JSON.serialize(oppo));
			string msg = string.format('testNewOppoLeadsNotFromSharktank(): Opportunity: {0} with source: {1} with MobySyncToMc: {2} failed trigger update.', new string[] { oppo.Name, oppo.MobyRecordSource__c, String.valueOf(oppo.Account.MobySyncToMc__c) });
			System.assert(oppo.Account.MobySyncToMc__c == true, msg);
		}
		Test.stopTest();
	}

	@isTest
	public static void testNewOppoLeadsFromSharktank() {
		/** Update accounts to be Sharktank Leads */
		Account[] accs = [SELECT Id, AccountSource FROM Account];
		for (Account acc :accs) { acc.AccountSource = 'Sharktank'; }
		update accs;
		
		SyncMoby04Opportunity.MobyOpportunityRes res = createObj();
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);

		Test.startTest();
		SyncMoby04Opportunity job = new SyncMoby04Opportunity();
		job.upsertOppo(res);

		Opportunity[] oppos = [SELECT Id, Name, MobyRecordSource__c, Account.AccountSource, Account.MobySyncToMc__c FROM Opportunity];
		System.debug('oppo: ' + JSON.serialize(oppos));
		for (Opportunity oppo :oppos) {
			string msg = string.format('testNewOppoLeadsFromSharktank(): Opportunity: {0} with source: {1} with MobySyncToMc: {2} failed trigger update.', new string[] { oppo.Name, oppo.MobyRecordSource__c, String.valueOf(oppo.Account.MobySyncToMc__c) });
			System.assert(oppo.Account.MobySyncToMc__c == true, msg);
		}
		Test.stopTest();
	}

	@isTest
	public static void testNewSharktankOppoLeadsNotFromSharktank() {
		SyncMoby04Opportunity.MobyOpportunityRes res = createObj();
		
		Map<Long, Boolean> expected = new Map<Long, Boolean>();
		Datetime now = Datetime.now();
		for (Integer i = 0; i < res.opportunities.size(); i++) {
			res.opportunities[i].recordSource = 'Sharktank';
			if (i == 0) {
				/** Open, insertDate < 5-day ago */
				Datetime dtInsert = now.addDays(-3);
				res.opportunities[i].insertDate = Datetime.newInstance(dtInsert.year(), dtInsert.month(), dtInsert.day(), dtInsert.hour(), dtInsert.minute(), dtInsert.second());
				res.opportunities[i].updateDate = Datetime.newInstance(now.year(), now.month(), now.day(), now.hour(), now.minute(), now.second());
				res.opportunities[i].stage = 'Prospecting';
				res.opportunities[i].statusCode = 'OPEN';
				res.opportunities[i].statusName = 'Open';
				expected.put(res.opportunities[i].id, true);
			}
			if (i == 1) {
				/** Open, insertDate > 5-day ago */
				Datetime dtInsert = now.addDays(-8);
				res.opportunities[i].insertDate = Datetime.newInstance(dtInsert.year(), dtInsert.month(), dtInsert.day(), dtInsert.hour(), dtInsert.minute(), dtInsert.second());
				res.opportunities[i].updateDate = Datetime.newInstance(now.year(), now.month(), now.day(), now.hour(), now.minute(), now.second());
				res.opportunities[i].stage = 'Prospecting';
				res.opportunities[i].statusCode = 'OPEN';
				res.opportunities[i].statusName = 'Open';
				expected.put(res.opportunities[i].id, true);
			}
			if (i == 2) {
				/** Lost, within 5-day */
				Datetime dtInsert = now.addDays(-3);
				res.opportunities[i].insertDate = Datetime.newInstance(dtInsert.year(), dtInsert.month(), dtInsert.day(), dtInsert.hour(), dtInsert.minute(), dtInsert.second());
				res.opportunities[i].updateDate = Datetime.newInstance(now.year(), now.month(), now.day(), now.hour(), now.minute(), now.second());
				res.opportunities[i].stage = 'Closed Lost';
				res.opportunities[i].statusCode = 'LOST';
				res.opportunities[i].statusName = 'Lost';
				expected.put(res.opportunities[i].id, true);
			}
		}

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);

		Test.startTest();
		SyncMoby04Opportunity job = new SyncMoby04Opportunity();
		job.upsertOppo(res);

		Opportunity[] oppos = [SELECT Id, Name, MobyRecordSource__c, MobyOpportunityNumber__c, AccountId, Account.Name, Account.AccountSource, Account.MobySyncToMc__c, Account.SyncToMc__c FROM Opportunity];
		for (Opportunity oppo :oppos) {
			System.debug(JSON.serialize(oppo));
			string msg = string.format('testNewSharktankOppoLeadsNotFromSharktank(): Opportunity: {0} with source: {1} with MobySyncToMc: {2} failed trigger update.', new string[] { oppo.Name, oppo.MobyRecordSource__c, String.valueOf(oppo.Account.MobySyncToMc__c) });
			// System.assert(oppo.Account.MobySyncToMc__c == false, msg);
			System.assertEquals(expected.get(oppo.MobyOpportunityNumber__c.longValue()), oppo.Account.MobySyncToMc__c, msg);
		}
		Test.stopTest();
	}

	@isTest
	public static void testNewSharktankOppoLeadsFromSharktank() {
		/** Update accounts to be Sharktank Leads */
		Account[] accs = [SELECT Id, AccountSource FROM Account];
		for (Account acc :accs) {
			acc.AccountSource = 'Sharktank';
			acc.MobySyncToMc__c = false;
		}
		update accs;
		
		accs = [SELECT Id, AccountSource, Customer_Number__c, MobyContactNumber__c, MobySyncToMc__c FROM Account];
		System.debug('Accs: ' + JSON.serialize(accs));

		SyncMoby04Opportunity.MobyOpportunityRes res = createObj();

		Map<Long, Boolean> expected = new Map<Long, Boolean>();
		Datetime now = Datetime.now();
		for (Integer i = 0; i < res.opportunities.size(); i++) {
			res.opportunities[i].recordSource = 'Sharktank';
			if (i == 0) {
				/** Open, insertDate < 5-day ago */
				Datetime dtInsert = now.addDays(-3);
				res.opportunities[i].insertDate = Datetime.newInstance(dtInsert.year(), dtInsert.month(), dtInsert.day(), dtInsert.hour(), dtInsert.minute(), dtInsert.second());
				res.opportunities[i].updateDate = Datetime.newInstance(now.year(), now.month(), now.day(), now.hour(), now.minute(), now.second());
				res.opportunities[i].stage = 'Prospecting';
				res.opportunities[i].statusCode = 'OPEN';
				res.opportunities[i].statusName = 'Open';
				expected.put(res.opportunities[i].id, false);
			}
			if (i == 1) {
				/** Open, insertDate > 5-day ago */
				Datetime dtInsert = now.addDays(-8);
				res.opportunities[i].insertDate = Datetime.newInstance(dtInsert.year(), dtInsert.month(), dtInsert.day(), dtInsert.hour(), dtInsert.minute(), dtInsert.second());
				res.opportunities[i].updateDate = Datetime.newInstance(now.year(), now.month(), now.day(), now.hour(), now.minute(), now.second());
				res.opportunities[i].stage = 'Prospecting';
				res.opportunities[i].statusCode = 'OPEN';
				res.opportunities[i].statusName = 'Open';
				expected.put(res.opportunities[i].id, true);
			}
			if (i == 2) {
				/** Lost, within 5-day */
				Datetime dtInsert = now.addDays(-3);
				res.opportunities[i].insertDate = Datetime.newInstance(dtInsert.year(), dtInsert.month(), dtInsert.day(), dtInsert.hour(), dtInsert.minute(), dtInsert.second());
				res.opportunities[i].updateDate = Datetime.newInstance(now.year(), now.month(), now.day(), now.hour(), now.minute(), now.second());
				res.opportunities[i].stage = 'Closed Lost';
				res.opportunities[i].statusCode = 'LOST';
				res.opportunities[i].statusName = 'Lost';
				expected.put(res.opportunities[i].id, false);
			}
		}

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);

		Test.startTest();
		SyncMoby04Opportunity job = new SyncMoby04Opportunity();
		job.upsertOppo(res);

		Opportunity[] oppos = [SELECT Id, Name, MobyRecordSource__c, MobyOpportunityNumber__c, Account.MobySyncToMc__c FROM Opportunity];
		for (Opportunity oppo :oppos) {
			string msg = string.format('testNewSharktankOppoLeadsFromSharktank(): Opportunity: {0} with source: {1} with MobySyncToMc: {2} failed trigger update.', new string[] { oppo.Name, oppo.MobyRecordSource__c, String.valueOf(oppo.Account.MobySyncToMc__c) });
			// System.assert(oppo.Account.MobySyncToMc__c == false, msg);
			System.assertEquals(expected.get(oppo.MobyOpportunityNumber__c.longValue()), oppo.Account.MobySyncToMc__c, msg);
		}
		Test.stopTest();
	}

	@isTest
	public static void testNewOpposOneLeadFromSharktank() {
		/** Update accounts to be Sharktank Leads */
		Long contactId;
		Account[] accs = [SELECT Id, AccountSource, MobyContactNumber__c FROM Account];
		for (Account acc :accs) {
			acc.AccountSource = 'Sharktank';
			contactId = acc.MobyContactNumber__c.longValue();
		}
		update accs;
		
		SyncMoby04Opportunity.MobyOpportunityRes res = createObj();

		Map<Long, Boolean> expected = new Map<Long, Boolean>();
		Datetime now = Datetime.now();
		for (Integer i = 0; i < res.opportunities.size(); i++) {
			if (i == 0) {
				/** Open, insertDate < 5-day ago */
				Datetime dtInsert = now.addDays(-3);
				// res.opportunities[i].recordSource = 'Sharktank';
				res.opportunities[i].contactId = contactId;
				res.opportunities[i].insertDate = Datetime.newInstance(dtInsert.year(), dtInsert.month(), dtInsert.day(), dtInsert.hour(), dtInsert.minute(), dtInsert.second());
				res.opportunities[i].updateDate = Datetime.newInstance(now.year(), now.month(), now.day(), now.hour(), now.minute(), now.second());
				res.opportunities[i].stage = 'Prospecting';
				res.opportunities[i].statusCode = 'OPEN';
				res.opportunities[i].statusName = 'Open';
				expected.put(res.opportunities[i].id, true);
			}
			if (i == 1) {
				/** Open, insertDate > 5-day ago */
				Datetime dtInsert = now.addDays(-8);
				res.opportunities[i].recordSource = 'Sharktank';
				res.opportunities[i].contactId = contactId;
				res.opportunities[i].insertDate = Datetime.newInstance(dtInsert.year(), dtInsert.month(), dtInsert.day(), dtInsert.hour(), dtInsert.minute(), dtInsert.second());
				res.opportunities[i].updateDate = Datetime.newInstance(now.year(), now.month(), now.day(), now.hour(), now.minute(), now.second());
				res.opportunities[i].stage = 'Prospecting';
				res.opportunities[i].statusCode = 'OPEN';
				res.opportunities[i].statusName = 'Open';
				expected.put(res.opportunities[i].id, true);
			}
			if (i == 2) {
				/** Lost, within 5-day */
				Datetime dtInsert = now.addDays(-3);
				// res.opportunities[i].recordSource = 'Sharktank';
				res.opportunities[i].contactId = contactId;
				res.opportunities[i].insertDate = Datetime.newInstance(dtInsert.year(), dtInsert.month(), dtInsert.day(), dtInsert.hour(), dtInsert.minute(), dtInsert.second());
				res.opportunities[i].updateDate = Datetime.newInstance(now.year(), now.month(), now.day(), now.hour(), now.minute(), now.second());
				res.opportunities[i].stage = 'Closed Lost';
				res.opportunities[i].statusCode = 'LOST';
				res.opportunities[i].statusName = 'Lost';
				expected.put(res.opportunities[i].id, true);
			}
		}

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);

		Test.startTest();
		SyncMoby04Opportunity job = new SyncMoby04Opportunity();
		job.upsertOppo(res);

		Opportunity[] oppos = [SELECT Id, Name, MobyRecordSource__c, MobyOpportunityNumber__c, Account.MobySyncToMc__c FROM Opportunity];
		for (Opportunity oppo :oppos) {
			string msg = string.format('testNewOpposOneLeadFromSharktank(): Opportunity: {0} with source: {1} with MobySyncToMc: {2} failed trigger update.', new string[] { oppo.Name, oppo.MobyRecordSource__c, String.valueOf(oppo.Account.MobySyncToMc__c) });
			// System.assert(oppo.Account.MobySyncToMc__c == false, msg);
			System.assertEquals(expected.get(oppo.MobyOpportunityNumber__c.longValue()), oppo.Account.MobySyncToMc__c, msg);
		}
		Test.stopTest();
	}
}