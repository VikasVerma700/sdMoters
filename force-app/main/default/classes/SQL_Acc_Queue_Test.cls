@isTest
public class SQL_Acc_Queue_Test {

	@TestSetup
	public static void makeData() {
		SQL_API_Base_Test.makeData();
	}
	
	@isTest
	public static SQL_Acc_Queue.CareContactRes[] createObj() {
		SQL_Acc_Queue.CareContactRes[] res = new SQL_Acc_Queue.CareContactRes[]{};
		SQL_Acc_Queue.CareContactRes con;
		
		con = new SQL_Acc_Queue.CareContactRes();
		con.contactIds = new long[] { 14812 };
		con.companyCode = '028';
		con.source = 'Autoline';
		con.custNo = 61627;
		con.dmsNo = '55928';
		con.isBusiness = false;
		con.salutation = 'Mr';
		con.fullName = 'Shahrul Nizam bin Abd Rahim';
		con.preferredName = 'Shahrul Nizam bin Abd Rahim';
		con.dateOfBirth = Datetime.valueOf('1979-12-19 00:00:00');
		con.docNum = '791219025071';
		con.docNumRaw = '791219025071';
		con.gender = 'M';
		con.prefix = '60';
		con.mobile = '129264594';
		con.phone1raw = '0129264594';
		con.prefix2 = null;
		con.mobile2 = null;
		con.phone2raw = null;
		con.prefix3 = null;
		con.mobile3 = null;
		con.phone3raw = null;
		con.email = 'shahrul_pb@yahoo.com.my';
		con.address1 = 'No 9, Long Branch Residence';
		con.address2 = 'Jalan Anggerik Disa 31/183B,';
		con.address3 = 'Alam Kemuning, Seksyen 31';
		con.postalCode = '40460';
		con.city = 'Alam Kemuning, Seksyen 31';
		con.state = 'Shah Alam';
		con.emailOptOut = false;
		con.letterOptOut = false;
		con.smsOptOut = false;
		res.add(con);

		con = new SQL_Acc_Queue.CareContactRes();
		con.contactIds = new long[] { 26996 };
		con.companyCode = '028';
		con.source = 'Autoline';
		con.custNo = 73811;
		con.dmsNo = '19455';
		con.isBusiness = false;
		con.salutation = 'Dato\'';
		con.fullName = 'Low Boon Hing';
		con.preferredName = 'Low Boon Hing';
		con.dateOfBirth = Datetime.valueOf('1959-04-30 00:00:00');
		con.docNum = '590430016065';
		con.docNumRaw = '590430016065';
		con.gender = 'M';
		con.prefix = null;
		con.mobile = null;
		con.phone1raw = null;
		con.prefix2 = '60';
		con.mobile2 = '122233088';
		con.phone2raw = '0122233088';
		con.prefix3 = null;
		con.mobile3 = null;
		con.phone3raw = null;
		con.email = 'jeffry@federalpoint.com.my';
		con.address1 = '4 Jln 5/2A';
		con.address2 = 'Taman TAR';
		con.address3 = 'Ampang Jaya';
		con.postalCode = '68000';
		con.city = 'Ampang Jaya';
		con.state = 'Ampang';
		con.emailOptOut = false;
		con.letterOptOut = false;
		con.smsOptOut = false;
		res.add(con);

		con = new SQL_Acc_Queue.CareContactRes();
		con.contactIds = new long[]{};
		con.companyCode = '028';
		con.source = 'Autoline';
		con.custNo = 130849;
		con.dmsNo = '16150';
		con.dmsNo = '16150|16151|16152|16153|16154|16155|16156|16157|16158|16159|16160|16161|16162|16163|16164|16165|16166|16167|16168|16169|16170|16171|16172|16173|16174|16175|16176|16177|16178|16179|16180|16181|16182|16183|16184|16185|16186|16187|16188|16189|16190|16191|16192|16193|16194|16195';
		con.isBusiness = true;
		con.salutation = null;
		con.fullName = 'Apple Galaxy Business Solutions';
		con.preferredName = null;
		con.dateOfBirth = null;
		con.docNum = 'SA0219503X';
		con.docNumRaw = 'SA0219503-X';
		con.gender = null;
		con.prefix = null;
		con.mobile = null;
		con.phone1raw = null;
		con.prefix2 = null;
		con.mobile2 = null;
		con.phone2raw = null;
		con.prefix3 = '60';
		con.mobile3 = '129264594';
		con.phone3raw = '012-9264594';
		con.email = 'apple@no.email.com';
		con.address1 = 'S-7-04 The Gamuda Biz Suites';
		con.address2 = 'Persiaran Anggerik';
		con.address3 = 'Villa Kota Kemuning';
		con.postalCode = '40460';
		con.city = 'Villa Kota Kemuning';
		con.state = 'Shah Alam';
		con.emailOptOut = false;
		con.letterOptOut = false;
		con.smsOptOut = false;

		res.add(con);
		
		return res;
	}

	@isTest
	static void testPull() {
		SQL_Acc_Queue.CareContactRes[] res = createObj();
		Integer expected = res.size();

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.followOnToVeh = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullUpdateEmails() {
		SQL_Acc_Queue.CareContactRes[] res = createObj();
		Integer expected = res.size();
		SQL_Acc_Queue q = new SQL_Acc_Queue();
		Account[] acs;
		q.upsertAccount(res);
		acs = [SELECT Id, Name, DMS_Number__c, Active_Home__c, Home_Email__c, Active_Work__c, Office_Email__c, Active_Other__c, Other_Email__c FROM Account];
		System.debug('upsert 1: ' + JSON.serialize(acs));
		q.upsertAccount(res);
		acs = [SELECT Id, Name, DMS_Number__c, Active_Home__c, Home_Email__c, Active_Work__c, Office_Email__c, Active_Other__c, Other_Email__c FROM Account];
		System.debug('upsert 2: ' + JSON.serialize(acs));

		/** Update 1: email */
		res[0].email += '.my';
		res[1].email += '.my';
		q.upsertAccount(res);
		acs = [SELECT Id, Name, DMS_Number__c, Active_Home__c, Home_Email__c, Active_Work__c, Office_Email__c, Active_Other__c, Other_Email__c FROM Account];
		System.debug('upsert 3: ' + JSON.serialize(acs));
		q.upsertAccount(res);
		acs = [SELECT Id, Name, DMS_Number__c, Active_Home__c, Home_Email__c, Active_Work__c, Office_Email__c, Active_Other__c, Other_Email__c FROM Account];
		System.debug('upsert 4: ' + JSON.serialize(acs));

		/** Update 1: email */
		res[0].email += '.sg';
		res[1].email += '.sg';
		q.upsertAccount(res);
		acs = [SELECT Id, Name, DMS_Number__c, Active_Home__c, Home_Email__c, Active_Work__c, Office_Email__c, Active_Other__c, Other_Email__c FROM Account];
		System.debug('upsert 5: ' + JSON.serialize(acs));
		q.upsertAccount(res);
		acs = [SELECT Id, Name, DMS_Number__c, Active_Home__c, Home_Email__c, Active_Work__c, Office_Email__c, Active_Other__c, Other_Email__c FROM Account];
		System.debug('upsert 6: ' + JSON.serialize(acs));

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.followOnToVeh = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullErrorEmail() {
		SQL_Acc_Queue.CareContactRes[] res = createObj();
		Integer expected = res.size();
		for (SQL_Acc_Queue.CareContactRes care :res) { care.email += '.'; care.dateOfBirth = null; }

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.followOnToVeh = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullUpdateWithErrorEmail() {
		SQL_Acc_Queue.CareContactRes[] res = createObj();
		Integer expected = res.size();
		SQL_Acc_Queue q = new SQL_Acc_Queue();
		q.upsertAccount(res);

		for (SQL_Acc_Queue.CareContactRes care :res) { care.email += '.'; care.dateOfBirth = null; }

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.followOnToVeh = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Account].size());
	}


	@isTest
	static void testPullKey2Update() {
		SQL_Acc_Queue.CareContactRes[] res = createObj();
		SQL_Acc_Queue q = new SQL_Acc_Queue();
		q.upsertAccount(res);

		/** Remove Customer_Number__c for NRIC key match (Key 2 & 3) */
		Account[] acs = [SELECT Id FROM Account];
		for (Account ac :acs) { ac.Customer_Number__c = null; }
		update acs;

		/** Change Response data for email update */
		res[0].email += '.my';
		res[1].email += '.my';
		res[0].dateOfBirth = Date.valueOf('1200-01-01');
		q.upsertAccount(res);

		/** Change Response data again for email update */
		res[0].email += '.sg';
		res[1].email += '.sg';
		q.upsertAccount(res);

		/** Change Response data again for email update */
		res[0].email += '.ph';
		res[1].email += '.ph';

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		System.assertEquals(acs.size(), [SELECT Id FROM Account].size());
	}

	/** Match Key 4 is disabled */
	@isTest
	static void testPullKey4Update() {
		SQL_Acc_Queue.CareContactRes[] res = createObj();
		SQL_Acc_Queue q = new SQL_Acc_Queue();
		q.upsertAccount(res);

		/** Remove Customer_Number__c, NRIC, DocumentNumberAlphaN__c for DMS key match (Key 4) */
		Account[] acs = [SELECT Id FROM Account];
		for (Account ac :acs) {
			ac.Customer_Number__c = null;
			ac.NRIC_Number__c = ac.DocumentNumberAlphaN__c = null;
		}
		update acs;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		// System.debug('after upsert: ' + tmpAcs.size() + ' / ' + JSON.serialize(tmpAcs));
		System.assertEquals(acs.size(), [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullKey5Update() {
		SQL_Acc_Queue.CareContactRes[] res = createObj();
		SQL_Acc_Queue q = new SQL_Acc_Queue();
		q.upsertAccount(res);

		/** Remove Customer_Number__c, NRIC, DocumentNumberAlphaN__c, DMS for Npe key match (Key 5) */
		Account[] acs = [SELECT Id FROM Account];
		for (Account ac :acs) {
			ac.Customer_Number__c = null;
			ac.NRIC_Number__c = ac.DocumentNumberAlphaN__c = null;
			ac.DMS_Number__c = null;
		}
		update acs;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		// System.debug('after upsert: ' + tmpAcs.size() + ' / ' + JSON.serialize(tmpAcs));
		System.assertEquals(acs.size(), [SELECT Id FROM Account].size());
	}

	@isTest
	static void testUpdateSubscription() {
		SQL_Acc_Queue.CareContactRes[] res = createObj();
		SQL_Acc_Queue q = new SQL_Acc_Queue();
		q.upsertAccount(res);
		Integer expected = res.size();

		for (SQL_Acc_Queue.CareContactRes aco :res) { aco.emailOptOut = aco.letterOptOut = aco.smsOptOut = true; }

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.followOnToVeh = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullPersonToBusiness() {
		SQL_Acc_Queue.CareContactRes[] res = createObj();
		SQL_Acc_Queue q = new SQL_Acc_Queue();
		q.upsertAccount(res);

		Account[] acs = [SELECT Id FROM Account];

		/** Change Response data for email update */
		res[0].docNum += '0219503X';
		res[0].docNumRaw += '0219503-X';
		res[0].isBusiness = true;
		res[1].docNum += '0219503Y';
		res[1].docNumRaw += '0219503-Y';
		res[1].isBusiness = true;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		System.assertEquals(acs.size(), [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullBusinessToPerson() {
		SQL_Acc_Queue.CareContactRes[] res = createObj();
		SQL_Acc_Queue q = new SQL_Acc_Queue();
		res[0].docNum = '0219503X';
		res[0].docNumRaw = '0219503-X';
		res[0].isBusiness = true;
		res[1].docNum = '0219503Y';
		res[1].docNumRaw = '0219503-Y';
		res[1].isBusiness = true;
		q.upsertAccount(res);

		System.debug('pre upsertAccount: ' + res.size() + ': ' + JSON.serialize(res));
		Account[] acs = [SELECT Id FROM Account];
		System.debug('post upsertAccount: ' + acs.size() + ': ' + JSON.serialize(acs));

		/** Change Response data for email update */
		res[0].docNum = '791219025071';
		res[0].docNumRaw = '791219-02-5071';
		res[0].isBusiness = false;
		res[1].docNum = '590430016065';
		res[1].docNumRaw = '590430-01-6065';
		res[0].isBusiness = false;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		System.assertEquals(acs.size(), [SELECT Id FROM Account].size());
	}

	@isTest
	static void testPullNoRow() {
		SQL_Acc_Queue.CareContactRes[] res = new SQL_Acc_Queue.CareContactRes[]{};
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.dateFrom = null;
		job.dateTo = null;
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
	}

	@isTest 
	static void testPullStatusNotOK() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SQL_Acc_Queue job = new SQL_Acc_Queue();
        job.followOnToVeh = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest
	static void testPull_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.followOnToVeh = true;
		System.enqueueJob(job);
		Test.stopTest();

	}
	@isTest
	static void testPull_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.followOnToVeh = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest
	static void testPull_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_Acc_Queue job = new SQL_Acc_Queue();
		job.followOnToVeh = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest
	static void testRefresh() {
		SQL_Acc_Queue.CareContactRes[] res = createObj();
		
		SQL_Acc_Queue q = new SQL_Acc_Queue();
		q.upsertAccount(res);

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Account[] acs = [SELECT Id FROM Account];
		Test.startTest();
		String ret = SQL_Acc_Queue.refreshAcc(acs[0].Id);
		Test.stopTest();
		System.assert(!ret.containsIgnoreCase('Error'));
	}

}