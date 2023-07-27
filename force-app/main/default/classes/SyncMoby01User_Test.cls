@isTest
public class SyncMoby01User_Test {

	@TestSetup
	public static void makeData(){
		SyncMobyApiBase_Test.makeData();
	}

	@isTest
	public static SyncMoby01User.MobyUserRes createObj() {
		SyncMoby01User.MobyUserRes response = new SyncMoby01User.MobyUserRes();
		response.users = new SyncMoby01User.MobyUser[]{};

		SyncMoby01User.MobyUser user;
		
		user = new SyncMoby01User.MobyUser();
		user.userId = 24;
		user.username = 'admin';
		user.displayName = 'Administrator';
		user.fullName = 'Administrator';
		user.extEmailAddress = null;
		user.extFullName = null;
		user.extGuid = null;
		user.email = 'mailbox.glenn@gmail.com';
		user.sapId = null;
		user.mobileNo = null;
		user.homePhoneNo = null;
		user.officePhoneNo = null;
		user.faxNo = null;
		user.source = 'SITE';
		user.companyId = 1;
		user.companyCode = 'SDAB';
		user.companyName = 'SD Auto Bavaria';
		user.branchId = null;
		user.branchCode = null;
		user.branchName = null;
		user.makeId = 1;
		user.makeCode = 'BMW';
		user.makeName = 'BMW';
		user.teamId = null;
		user.teamCode = null;
		user.teamName = null;
		user.domain = 'simedarby.com';
		user.businessRole = 'MANAGEMENT';
		user.lastDirectoryUpdate = null;
		user.timeZone = 'Singapore Standard Time';
		user.claimReward = false;
		user.countryCode = null;
		user.country = null;
		user.userCompanyName = null;
		user.department = null;
		user.title = null;
		user.isActive = true;
		user.insertDate = Datetime.valueOf('2018-07-05 22:23:20.65+08:00');
		user.insertUserId = 24;
		user.updateDate = Datetime.valueOf('2020-10-01 15:15:35.093+08:00');
		user.updateUserId = 24;
		response.users.add(user);

		user = new SyncMoby01User.MobyUser();
		user.userId = 67;
		user.username = 'dom';
		user.displayName = 'Dominique';
		user.fullName = 'Dominique';
		user.extEmailAddress = null;
		user.extFullName = 'Doms';
		user.extGuid = '380144ed-9959-ea11-a811-000d3aa3e77c';
		user.email = 'mailbox.dom@gmail.com';
		user.sapId = '00103279';
		user.mobileNo = '01126943168';
		user.homePhoneNo = null;
		user.officePhoneNo = null;
		user.faxNo = null;
		user.source = 'SITE';
		user.companyId = 1;
		user.companyCode = 'SDAB';
		user.companyName = 'SD Auto Bavaria';
		user.branchId = 3;
		user.branchCode = 'ABAD';
		user.branchName = 'SDAB Ara Damansara';
		user.makeId = 1;
		user.makeCode = 'BMW';
		user.makeName = 'BMW';
		user.teamId = 23;
		user.teamCode = 'CHAMP';
		user.teamName = 'Champion';
		user.domain = 'simedarby.com';
		user.businessRole = 'SALESPERSON';
		user.lastDirectoryUpdate = null;
		user.timeZone = 'Singapore Standard Time';
		user.claimReward = true;
		user.countryCode = null;
		user.country = null;
		user.userCompanyName = null;
		user.department = null;
		user.title = null;
		user.isActive = true;
		user.insertDate = Datetime.valueOf('2018-09-13 13:00:00.313+08:00');
		user.insertUserId = 24;
		user.updateDate = Datetime.valueOf('2021-09-13 18:51:57.033+08:00');
		user.updateUserId = 24;
		response.users.add(user);

		user = new SyncMoby01User.MobyUser();
		user.userId = 68;
		user.username = 'loo.chuan.wei';
		user.displayName = 'Loo PIC';
		user.fullName = 'Loo Chuan Wei';
		user.extEmailAddress = null;
		user.extFullName = null;
		user.extGuid = null;
		user.email = 'loo.chuan.wei@simedarby.com';
		user.sapId = '00000407';
		user.mobileNo = null;
		user.homePhoneNo = null;
		user.officePhoneNo = null;
		user.faxNo = null;
		user.source = 'AD';
		user.companyId = 1;
		user.companyCode = 'SDAB';
		user.companyName = 'SD Auto Bavaria';
		user.branchId = 4;
		user.branchCode = 'ABSB';
		user.branchName = 'SDAB Sg. Besi';
		user.makeId = 1;
		user.makeCode = 'BMW';
		user.makeName = 'BMW';
		user.teamId = null;
		user.teamCode = null;
		user.teamName = null;
		user.domain = 'simedarby.com';
		user.businessRole = 'MANAGEMENT';
		user.lastDirectoryUpdate = null;
		user.timeZone = 'Singapore Standard Time';
		user.claimReward = false;
		user.countryCode = null;
		user.country = null;
		user.userCompanyName = null;
		user.department = null;
		user.title = null;
		user.isActive = true;
		user.insertDate = Datetime.valueOf('2018-09-23 16:12:41.28+08:00');
		user.insertUserId = 24;
		user.updateDate = Datetime.valueOf('2020-07-15 13:47:14.093+08:00');
		user.updateUserId = 24;
		response.users.add(user);

		response.lastKey = 68;

		return response;
	}

	@isTest
	public static void testPull() {
		SyncMoby01User.MobyUserRes res = createObj();

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby01User job = new SyncMoby01User();
		job.followOnToNext = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(3, [SELECT Id FROM Employee_Master__c].size());
	}

	@isTest
	static void testPullUpdateByMobyId() {
		SyncMoby01User.MobyUserRes res = createObj();

		/** Coverage:
		 * SyncMoby01User: 180
		 * 	Remove MobyUserNumber__c */
		SyncMoby01User job = new SyncMoby01User();
		job.upsertUser(res);
		/** Update CreatedFrom to something else */
		Employee_Master__c[] ems = [SELECT Id, CreatedFrom__c FROM Employee_Master__c];
		for (Employee_Master__c em :ems) { em.CreatedFrom__c += '_bak'; }
		update ems;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby01User kob = new SyncMoby01User();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(3, [SELECT Id FROM Employee_Master__c].size());
	}

	@isTest
	static void testPullUpdateByUsername() {
		SyncMoby01User.MobyUserRes res = createObj();

		SyncMoby01User job = new SyncMoby01User();
		job.upsertUser(res);
		/** Coverage:
		 * SyncMoby01User: 189
		 * 	Remove MobyUserNumber__c */
		Employee_Master__c[] ems = [SELECT Id, MobyUserNumber__c FROM Employee_Master__c];
		for (Employee_Master__c em :ems) { em.MobyUserNumber__c = null; }
		update ems;

		/** Coverage:
		 * SyncMoby01User: 355
		 * 	Remove fullName */
		for (SyncMoby01User.MobyUser mu :res.users) { 
			mu.fullName = '';
			mu.displayName += '(a)';
			mu.branchId = null;
		}

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby01User kob = new SyncMoby01User();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(3, [SELECT Id FROM Employee_Master__c].size());
	}

	@isTest
	static void testPullUpdateBySapId() {
		SyncMoby01User.MobyUserRes res = createObj();

		SyncMoby01User job = new SyncMoby01User();
		job.upsertUser(res);
		/** Coverage:
		 * SyncMoby01User: 195
		 * 	Remove MobyUserNumber__c, ActiveDirectoryUsername__c */
		Employee_Master__c[] ems = [SELECT Id, MobyUserNumber__c, ActiveDirectoryUsername__c, Employee_Reference__c FROM Employee_Master__c];
		for (Employee_Master__c em :ems) {
			if (String.isNotBlank(em.Employee_Reference__c)) {
				em.MobyUserNumber__c = null;
				em.ActiveDirectoryUsername__c = '';
			}
		}
		update ems;
		System.debug('Test removed id: ' + JSON.serialize(ems));

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby01User kob = new SyncMoby01User();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(3, [SELECT Id FROM Employee_Master__c].size());
	}



	@isTest static void testPullNoRow() {
		SyncMoby01User.MobyUserRes res = new SyncMoby01User.MobyUserRes();
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby01User job = new SyncMoby01User();
		job.dateFrom = null;
		job.dateTo = null;
		job.followOnToNext = true;
		job.execute(null);
		Test.stopTest();
	}

	@isTest static void testPullStatusNotOK() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SyncMoby01User job = new SyncMoby01User();
        job.followOnToNext = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPull_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SyncMoby01User job = new SyncMoby01User();
		job.followOnToNext = true;
		System.enqueueJob(job);
		Test.stopTest();

	}
	@isTest static void testPull_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SyncMoby01User job = new SyncMoby01User();
		job.followOnToNext = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPull_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SyncMoby01User job = new SyncMoby01User();
		job.followOnToNext = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testRefresh() {
		SyncMoby01User.MobyUserRes res = createObj();

		SyncMoby01User job = new SyncMoby01User();
		job.upsertUser(res);

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Employee_Master__c[] ems = [SELECT Id FROM Employee_Master__c];
		Test.startTest();
		String ret = SyncMoby01User.refreshUser(ems[0].Id);
		Test.stopTest();
		System.assert(!ret.containsIgnoreCase('Error'));
	}
}