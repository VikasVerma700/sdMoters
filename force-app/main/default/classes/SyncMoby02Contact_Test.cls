@isTest
public class SyncMoby02Contact_Test {

	@TestSetup
	public static void makeData(){
		SyncMobyApiBase_Test.makeData();

		// SyncMoby01User_Test.testPull();
		SyncMoby01User.MobyUserRes res = SyncMoby01User_Test.createObj();
		SyncMoby01User job = new SyncMoby01User();
		job.upsertUser(res);
	}

	@isTest
	public static SyncMoby02Contact.MobyContactRes createObj() {
		SyncMoby02Contact.MobyContactRes response = new SyncMoby02Contact.MobyContactRes();
		response.contacts = new SyncMoby02Contact.MobyContact[]{};

		SyncMoby02Contact.MobyContact contact;
		SyncMoby02Contact.MobyHobby hobby;
		
		contact = new SyncMoby02Contact.MobyContact();
		contact.id = 1362;
		contact.companyId = 1;
		contact.companyCode = 'SDAB';
		contact.companyName = 'SD Auto Bavaria';
		contact.branchId = 5;
		contact.branchCode = 'ABKL';
		contact.branchName = 'SDAB KL';
		contact.title = '';
		contact.gender = '';
		contact.contactName = 'Munirah Bt Abdullah @ Looi Mei Leng';
		contact.nickname = null;
		contact.birthday = null;
		contact.unit = null;
		contact.address = '7, jalan raja muda musa kampung barhlu 50300 kl w persekutuan';
		contact.postCode = null;
		contact.city = null;
		contact.state = null;
		contact.email = 'munirahlooi@gmail.com';
		contact.mobileNo = '0122881289';
		contact.documentType = null;
		contact.icNo = '591015105700';
		contact.licenseNo = '03314011';
		contact.maritalStatus = 30;
		contact.maritalStatusName = 'Single';
		contact.maritalStatusDescription = 'Single definitely available.';
		contact.incomeGroup = 44;
		contact.incomeGroupName = '10,001 - 15,000';
		contact.incomeGroupDescription = 'Perhaps 2 cars!';
		contact.interests = '';
		contact.contactCompanyName = null;
		contact.source = null;
		contact.extContactUid = null;
		contact.isActive = true;
		contact.insertDate = Datetime.valueOf('2019-02-01 10:27:39.77+08:00');
		contact.insertUserId = 67;
		contact.updateDate = Datetime.valueOf('2019-03-11 10:18:45.51+08:00');
		contact.updateUserId = 68;
		contact.hobbies = new SyncMoby02Contact.MobyHobby[]{};
		hobby = new SyncMoby02Contact.MobyHobby();
		hobby.hobbyName = 'Golf';
		hobby.hobbyCode = 'GOLF';
		hobby.hobbyType = 'Sport';
		hobby.isActive = true;
		contact.hobbies.add(hobby);
		response.contacts.add(contact);

		contact = new SyncMoby02Contact.MobyContact();
		contact.id = 1363;
		contact.companyId = 1;
		contact.companyCode = 'SDAB';
		contact.companyName = 'SD Auto Bavaria';
		contact.branchId = 5;
		contact.branchCode = 'ABKL';
		contact.branchName = 'SDAB KL';
		contact.title = '';
		contact.gender = '';
		contact.contactName = 'Justice Timberleg';
		contact.nickname = null;
		contact.birthday = null;
		contact.unit = null;
		contact.address = '';
		contact.postCode = null;
		contact.city = null;
		contact.state = null;
		contact.email = '';
		contact.mobileNo = '015455555552';
		contact.documentType = null;
		contact.icNo = '';
		contact.licenseNo = '';
		contact.maritalStatus = null;
		contact.incomeGroup = null;
		contact.interests = '';
		contact.contactCompanyName = null;
		contact.source = 'Email';
		contact.extContactUid = null;
		contact.isActive = true;
		contact.insertDate = Datetime.valueOf('2019-02-01 10:30:42.733+08:00');
		contact.insertUserId = 67;
		contact.updateDate = Datetime.valueOf('2019-03-11 10:18:45.51+08:00');
		contact.updateUserId = 68;
		response.contacts.add(contact);

		contact = new SyncMoby02Contact.MobyContact();
		contact.id = 1364;
		contact.companyId = 1;
		contact.companyCode = 'SDAB';
		contact.companyName = 'SD Auto Bavaria';
		contact.branchId = 3;
		contact.branchCode = 'ABAD';
		contact.branchName = 'SDAB Ara Damansara';
		contact.title = '';
		contact.gender = '';
		contact.contactName = 'Zambri Bin Mat';
		contact.nickname = null;
		contact.birthday = null;
		contact.unit = null;
		contact.address = 'No 114 Darul Aman Height, Darul Aman Golf 06000 Jitra Kedah';
		contact.postCode = null;
		contact.city = null;
		contact.state = null;
		contact.email = 'zambrimat@yahoo.com';
		contact.mobileNo = '0104016929';
		contact.documentType = null;
		contact.icNo = '790922025933';
		contact.licenseNo = '';
		contact.maritalStatus = null;
		contact.incomeGroup = null;
		contact.interests = '';
		contact.contactCompanyName = null;
		contact.source = 'Showroom';
		contact.extContactUid = null;
		contact.isActive = true;
		contact.insertDate = Datetime.valueOf('2019-02-01 10:30:42.75+08:00');
		contact.insertUserId = 67;
		contact.updateDate = Datetime.valueOf('2019-03-11 10:18:45.51+08:00');
		contact.updateUserId = 68;
		response.contacts.add(contact);

		response.lastKey = 1364;

		return response;
	}

	@isTest
	public static void testPull() {
		SyncMoby02Contact.MobyContactRes res = createObj();
		Integer expected = res.contacts.size();

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact job = new SyncMoby02Contact();
		job.followOnToNext = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Account].size());
	}


	@isTest
	static void testPullUpdateEmails() {
		SyncMoby02Contact.MobyContactRes res = createObj();
		Integer expected = res.contacts.size();
		SyncMoby02Contact q = new SyncMoby02Contact();
		Account[] acs;
		q.upsertContact(res);
		acs = [SELECT Id, Name, DMS_Number__c, Active_Home__c, Home_Email__c, Active_Work__c, Office_Email__c, Active_Other__c, Other_Email__c FROM Account];
		System.debug('upsert 1: ' + JSON.serialize(acs));
		q.upsertContact(res);
		acs = [SELECT Id, Name, DMS_Number__c, Active_Home__c, Home_Email__c, Active_Work__c, Office_Email__c, Active_Other__c, Other_Email__c FROM Account];
		System.debug('upsert 2: ' + JSON.serialize(acs));

		/** Update 1: email */
		res.contacts[0].email += '.my';
		res.contacts[1].email += '.my';
		q.upsertContact(res);
		acs = [SELECT Id, Name, DMS_Number__c, Active_Home__c, Home_Email__c, Active_Work__c, Office_Email__c, Active_Other__c, Other_Email__c FROM Account];
		System.debug('upsert 3: ' + JSON.serialize(acs));
		q.upsertContact(res);
		acs = [SELECT Id, Name, DMS_Number__c, Active_Home__c, Home_Email__c, Active_Work__c, Office_Email__c, Active_Other__c, Other_Email__c FROM Account];
		System.debug('upsert 4: ' + JSON.serialize(acs));

		/** Update 1: email */
		res.contacts[0].email += '.sg';
		res.contacts[1].email += '.sg';
		q.upsertContact(res);
		acs = [SELECT Id, Name, DMS_Number__c, Active_Home__c, Home_Email__c, Active_Work__c, Office_Email__c, Active_Other__c, Other_Email__c FROM Account];
		System.debug('upsert 5: ' + JSON.serialize(acs));
		q.upsertContact(res);
		acs = [SELECT Id, Name, DMS_Number__c, Active_Home__c, Home_Email__c, Active_Work__c, Office_Email__c, Active_Other__c, Other_Email__c FROM Account];
		System.debug('upsert 6: ' + JSON.serialize(acs));

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact job = new SyncMoby02Contact();
		job.followOnToNext = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullErrorEmail() {
		SyncMoby02Contact.MobyContactRes res = createObj();
		Integer expected = res.contacts.size();
		for (SyncMoby02Contact.MobyContact con :res.contacts) { con.email += '.'; con.birthday = null; }

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact job = new SyncMoby02Contact();
		job.followOnToNext = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullUpdateWithErrorEmail() {
		SyncMoby02Contact.MobyContactRes res = createObj();
		Integer expected = res.contacts.size();
		SyncMoby02Contact q = new SyncMoby02Contact();
		q.upsertContact(res);

		for (SyncMoby02Contact.MobyContact con :res.contacts) { con.email += '.'; con.birthday = null; }

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact job = new SyncMoby02Contact();
		job.followOnToNext = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Account].size());
	}


	@isTest
	public static void testPullAsBusiness() {
		SyncMoby02Contact.MobyContactRes res = createObj();

		res.contacts[0].icNo = '123456A';

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact job = new SyncMoby02Contact();
		job.followOnToNext = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(3, [SELECT Id FROM Account].size());
	}


	@isTest
	static void testPullUpdateByMobyId() {
		SyncMoby02Contact.MobyContactRes res = createObj();

		SyncMoby02Contact job = new SyncMoby02Contact();
		job.upsertContact(res);

		/** Invalidate birthday */
		res.contacts[0].birthday = Date.valueOf('1200-01-01');

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact kob = new SyncMoby02Contact();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(3, [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullUpdateByMobyIdByOther() {
		SyncMoby02Contact.MobyContactRes res = createObj();

		SyncMoby02Contact job = new SyncMoby02Contact();
		job.upsertContact(res);

		Account[] acs = [SELECT Id, Created_From__c FROM Account];
		for (Account ac :acs) { ac.Created_From__c = 'Autoline'; }
		update acs;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact kob = new SyncMoby02Contact();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(3, [SELECT Id FROM Account].size());
	}


	@isTest
	static void testPullUpdateToBusinessByMobyId() {
		SyncMoby02Contact.MobyContactRes res = createObj();
		Integer expected = res.contacts.size();

		SyncMoby02Contact job = new SyncMoby02Contact();
		job.upsertContact(res);

		res.contacts[1].icNo = '123456A';
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact kob = new SyncMoby02Contact();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullUpdateToBusinessByMobyIdByOther() {
		SyncMoby02Contact.MobyContactRes res = createObj();
		Integer expected = res.contacts.size();

		SyncMoby02Contact job = new SyncMoby02Contact();
		job.upsertContact(res);

		Account[] acs = [SELECT Id, Created_From__c FROM Account];
		for (Account ac :acs) { ac.Created_From__c = 'Autoline'; }
		update acs;

		for (SyncMoby02Contact.MobyContact con :res.contacts) { con.icNo = '123456A'; }

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact kob = new SyncMoby02Contact();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullUpdateToPersonByMobyId() {
		SyncMoby02Contact.MobyContactRes res = createObj();
		Integer expected = res.contacts.size();

		SyncMoby02Contact job = new SyncMoby02Contact();
		res.contacts[1].icNo = '123456A';
		job.upsertContact(res);

		res.contacts[1].icNo = '810901105050';
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact kob = new SyncMoby02Contact();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Account].size());

	}

	@isTest
	static void testPullUpdateByNRIC() {
		SyncMoby02Contact.MobyContactRes res = createObj();

		SyncMoby02Contact job = new SyncMoby02Contact();
		job.upsertContact(res);
		/** Coverage:
		 * SyncMoby02Contact: 375
		 * 	Remove MobyContactNumber__c */
		Account[] accs = [SELECT Id, MobyContactNumber__c FROM Account];
		for (Account acc :accs) {
			acc.Doc_Type__c = '';
			acc.MobyContactNumber__c = null;
		}
		update accs;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact kob = new SyncMoby02Contact();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(3, [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullUpdateByNameMobileEmail() {
		SyncMoby02Contact.MobyContactRes res = createObj();

		SyncMoby02Contact job = new SyncMoby02Contact();
		job.upsertContact(res);
		/** Coverage:
		 * SyncMoby02Contact: 381
		 * 	Remove MobyContactNumber__c, NRIC_Number__c */
		Account[] accs = [SELECT Id, MobyContactNumber__c, NRIC_Number__c FROM Account];
		for (Account acc :accs) {
			acc.MobyContactNumber__c = null;
			acc.NRIC_Number__c = '';
		}
		update accs;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact kob = new SyncMoby02Contact();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(3, [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullUpdateByNameMobile() {
		SyncMoby02Contact.MobyContactRes res = createObj();

		SyncMoby02Contact job = new SyncMoby02Contact();
		job.upsertContact(res);
		/** Coverage:
		 * SyncMoby02Contact: 381
		 * 	Remove MobyContactNumber__c, NRIC_Number__c */
		Account[] accs = [SELECT Id, MobyContactNumber__c, NRIC_Number__c FROM Account];
		for (Account acc :accs) {
			acc.MobyContactNumber__c = null;
			acc.NRIC_Number__c = '';
			acc.Active_Home__c = acc.Active_Work__c = acc.Active_Other__c = false;
		}
		update accs;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact kob = new SyncMoby02Contact();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(3, [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullUpdateByMobileEmail() {
		SyncMoby02Contact.MobyContactRes res = createObj();

		SyncMoby02Contact job = new SyncMoby02Contact();
		job.upsertContact(res);

		/** Coverage:
		 * SyncMoby02Contact: 381
		 * 	Remove MobyContactNumber__c, NRIC_Number__c */
		Account[] accs = [SELECT Id, LastName, PersonMobilePhone, Default_Email__c, MobyContactNumber__c, NRIC_Number__c FROM Account];
		for (Account acc :accs) {
			acc.LastName += '(a)';
			if (String.isNotBlank(acc.Default_Email__c)) { acc.MobyContactNumber__c = null; }
			acc.NRIC_Number__c = '';
		}
		update accs;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact kob = new SyncMoby02Contact();
		kob.followOnToNext = true;
		System.enqueueJob(kob);
		// kob.execute(null);
		Test.stopTest();

		System.assertEquals(3, [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullUpdateLinkedAccount() {
		SyncMoby02Contact.MobyContactRes res = createObj();
		Integer expected = res.contacts.size();

		SyncMoby02Contact job = new SyncMoby02Contact();
		res.contacts[1].icNo = '123456X';
		job.upsertContact(res);
		/** Coverage:
		 * SyncMoby02Contact: 381
		 * 	Remove MobyContactNumber__c, NRIC_Number__c */
		Account[] accs = [SELECT Id, Customer_Number__c FROM Account];
		for (Integer i = 0; i < accs.size(); i++) { accs[i].Customer_Number__c = i + 1; }
		update accs;

		res.contacts[0].email += 'person@email.com';
		res.contacts[1].email += 'business@email.com';
		res.contacts[2].email += 'person2@email.com';

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact kob = new SyncMoby02Contact();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Account].size());
	}


	@isTest static void testPullNoRow() {
		SyncMoby02Contact.MobyContactRes res = new SyncMoby02Contact.MobyContactRes();
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby02Contact job = new SyncMoby02Contact();
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
        SyncMoby02Contact job = new SyncMoby02Contact();
        job.followOnToNext = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPull_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SyncMoby02Contact job = new SyncMoby02Contact();
		job.followOnToNext = true;
		System.enqueueJob(job);
		Test.stopTest();

	}
	@isTest static void testPull_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SyncMoby02Contact job = new SyncMoby02Contact();
		job.followOnToNext = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPull_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SyncMoby02Contact job = new SyncMoby02Contact();
		job.followOnToNext = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	// @isTest static void testRefresh() {
	// 	SyncMoby02Contact.MobyContactRes res = createObj();

	// 	SyncMoby02Contact job = new SyncMoby02Contact();
	// 	job.upsertContact(res);

	// 	TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
	// 	Test.setMock(HttpCalloutMock.class, mock);
	// 	Account[] accs = [SELECT Id FROM Account];
	// 	Test.startTest();
	// 	String ret = SyncMoby02Contact.refreshUser(accs[0].Id);
	// 	Test.stopTest();
	// 	System.assert(!ret.containsIgnoreCase('Error'));
	// }
}