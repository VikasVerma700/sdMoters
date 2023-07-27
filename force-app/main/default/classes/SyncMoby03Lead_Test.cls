@isTest
public class SyncMoby03Lead_Test {

	@TestSetup
	public static void makeData(){
		SyncMobyApiBase_Test.makeData();

		// SyncMoby01User_Test.testPull();
		SyncMoby01User.MobyUserRes res = SyncMoby01User_Test.createObj();
		SyncMoby01User job = new SyncMoby01User();
		job.upsertUser(res);

		// remove Showroom__c records
		delete [SELECT Id FROM Showroom__c];
	}

	@isTest
	static SyncMoby03Lead.MobyLeadRes createObj() {
		SyncMoby03Lead.MobyLeadRes response = new SyncMoby03Lead.MobyLeadRes();
		response.leads = new SyncMoby03Lead.MobyLead[]{};

		SyncMoby03Lead.MobyLead lead;
		SyncMoby03Lead.MobyModel mi;
		
		lead = new SyncMoby03Lead.MobyLead();
		lead.id = 94;
		lead.companyId = 1;
		lead.companyCode = 'SDAB';
		lead.companyName = 'SD Auto Bavaria';
		lead.makeId = 1;
		lead.makeCode = 'BMW';
		lead.makeName = 'BMW';
		lead.branchId = 3;
		lead.branchCode = 'ABAD';
		lead.branchName = 'SDAB Ara Damansara';
		lead.contactId = null;
		lead.title = 'Mr';
		lead.contactName = 'Azhar Hasnan';
		lead.mobileCountry = '60';
		lead.mobileNo = '107060007';
		lead.email = '';
		lead.location = 'Ara';
		lead.remarks = '';
		lead.source = 'Referral';
		lead.variantText = '["BMW 530i M Sport"]';
		lead.branchAssignDate = Datetime.valueOf('2020-08-05 14:50:21+08:00');
		lead.lastEmailDate = null;
		lead.referenceText = null;
		lead.sforceParam = null;
		lead.extOpportunityUid = null;
		lead.opportunityId = null;
		lead.insertRemark = null;
		lead.type = 'SALES';
		lead.insertDate = Datetime.valueOf('2020-08-05 14:13:01.88+08:00');
		lead.insertUserId = 67;
		lead.updateDate = Datetime.valueOf('2020-08-05 14:13:01.88+08:00');
		lead.updateUserId = 68;
		lead.isDeleted = false;
		lead.leadStatus = 'OPEN';
		lead.modelInterests = new SyncMoby03Lead.MobyModel[]{};
		mi = new SyncMoby03Lead.MobyModel();
		mi.id = 3;
		mi.headerId = 94;
		mi.variantCode = 'KT08A7';
		mi.variantName = 'BMW X5 xDrive40e M Sport (F15)';
		mi.variantAssemblyCode = 'CKD';
		mi.variantBodyType = 'SAV';
		mi.variantCylinder = 'In-Line 4';
		mi.variantDisplacement = '1,997';
		mi.extVariantUid = 'aafe48a0-f9b9-e611-80de-005056ac629c';
		mi.variantFuelType = 'Petrol + Electric';
		mi.variantModelId = 29;
		mi.modelCode = 'F15';
		mi.modelName = 'BMW X5 F15';
		mi.modelAssemblyCode = 'CKD';
		mi.modelBodyType = 'SAV';
		mi.modelCylinder = 'In-Line 4';
		mi.modelDisplacement = '1,997 cc';
		mi.modelFuelType = 'Petrol + Electric Motor';
		mi.makeId = 1;
		mi.makeCode = 'BMW';
		mi.makeName = 'BMW';
		mi.variantSystem = 'Manual';
		mi.isActive = true;
		lead.modelInterests.add(mi);
		response.leads.add(lead);

		lead = new SyncMoby03Lead.MobyLead();
		lead.id = 95;
		lead.companyId = 1;
		lead.companyCode = 'SDAB';
		lead.companyName = 'SD Auto Bavaria';
		lead.makeId = 1;
		lead.makeCode = 'BMW';
		lead.makeName = 'BMW';
		lead.branchId = 4;
		lead.branchCode = 'ABSB';
		lead.branchName = 'SDAB Sg. Besi';
		lead.contactId = null;
		lead.title = 'Ms';
		lead.contactName = 'Cheryl Yoong';
		lead.mobileCountry = '60';
		lead.mobileNo = '173680110';
		lead.email = '';
		lead.location = 'Ara Damansara ';
		lead.remarks = '';
		lead.source = 'Referral';
		lead.variantText = '["BMW 520i Luxury"]';
		lead.branchAssignDate = Datetime.valueOf('2020-08-05 17:31:16.893+08:00');
		lead.lastEmailDate = null;
		lead.referenceText = null;
		lead.sforceParam = null;
		lead.extOpportunityUid = null;
		lead.opportunityId = null;
		lead.insertRemark = null;
		lead.type = 'TRADEIN';
		lead.insertDate = Datetime.valueOf('2020-08-05 17:30:49.47+08:00');
		lead.insertUserId = 67;
		lead.updateDate = Datetime.valueOf('2020-08-05 17:30:49.47+08:00');
		lead.updateUserId = 68;
		lead.isDeleted = false;
		lead.leadStatus = 'OPEN';
		lead.modelInterests = new SyncMoby03Lead.MobyModel[]{};
		mi = new SyncMoby03Lead.MobyModel();
		mi.id = 4;
		mi.headerId = 95;
		mi.variantCode = '5Z18A7';
		mi.variantName = 'BMW 320i Sport 2020 (G20)';
		mi.variantAssemblyCode = null;
		mi.variantBodyType = null;
		mi.variantCylinder = 'In-Line/4';
		mi.variantDisplacement = '1,998';
		mi.extVariantUid = 'af4300df-6933-ea11-a813-000d3a851c27';
		mi.variantFuelType = null;
		mi.variantModelId = 130;
		mi.modelCode = 'G20';
		mi.modelName = 'BMW 3 Series G20';
		mi.modelAssemblyCode = 'CBU';
		mi.modelBodyType = 'Sedan';
		mi.modelCylinder = 'In-Line 4';
		mi.modelDisplacement = '1,998 cc';
		mi.modelFuelType = 'Petrol';
		mi.makeId = 1;
		mi.makeCode = 'BMW';
		mi.makeName = 'BMW';
		mi.variantSystem = null;
		mi.isActive = true;
		lead.modelInterests.add(mi);
		response.leads.add(lead);

		lead = new SyncMoby03Lead.MobyLead();
		lead.id = 96;
		lead.companyId = 1;
		lead.companyCode = 'SDAB';
		lead.companyName = 'SD Auto Bavaria';
		lead.makeId = 1;
		lead.makeCode = 'BMW';
		lead.makeName = 'BMW';
		lead.branchId = null;
		lead.branchCode = null;
		lead.branchName = null;
		lead.contactId = null;
		lead.title = 'Datin\' Seri';
		lead.contactName = 'Adriana Syaira';
		lead.mobileCountry = '60';
		lead.mobileNo = '122477481';
		lead.email = '';
		lead.location = 'Ara';
		lead.remarks = '';
		lead.source = 'Referral';
		lead.variantText = null;
		lead.branchAssignDate = null;
		lead.lastEmailDate = null;
		lead.referenceText = null;
		lead.sforceParam = null;
		lead.extOpportunityUid = null;
		lead.opportunityId = null;
		lead.insertRemark = null;
		lead.type = null;
		lead.insertDate = Datetime.valueOf('2020-08-06 09:56:41.38+08:00');
		lead.insertUserId = 67;
		lead.updateDate = Datetime.valueOf('2020-08-06 09:56:41.38+08:00');
		lead.updateUserId = 68;
		lead.isDeleted = false;
		lead.leadStatus = 'OPEN';
		lead.modelInterests = new SyncMoby03Lead.MobyModel[]{};
		mi = new SyncMoby03Lead.MobyModel();
		mi.id = 5;
		mi.headerId = 96;
		mi.variantCode = '4S32';
		mi.variantName = 'BMW 420i Coupe Sport (F32)';
		mi.variantAssemblyCode = 'CBU';
		mi.variantBodyType = 'Coupe';
		mi.variantCylinder = 'In-Line 4';
		mi.variantDisplacement = '1,998';
		mi.extVariantUid = null;
		mi.variantFuelType = 'Petrol';
		mi.variantModelId = 33;
		mi.modelCode = 'F32';
		mi.modelName = 'BMW 4 Series F32';
		mi.modelAssemblyCode = 'CBU';
		mi.modelBodyType = 'Coupe';
		mi.modelCylinder = 'In-Line 4';
		mi.modelDisplacement = '1,998 cc';
		mi.modelFuelType = 'Petrol';
		mi.makeId = 1;
		mi.makeCode = 'BMW';
		mi.makeName = 'BMW';
		mi.variantSystem = 'Manual';
		mi.isActive = true;
		lead.modelInterests.add(mi);
		response.leads.add(lead);

		response.lastKey = 96;

		return response;
	}

	@isTest
	public static void testPull() {
		SyncMoby03Lead.MobyLeadRes res = createObj();

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby03Lead job = new SyncMoby03Lead();
		job.followOnToNext = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(3, [SELECT Id FROM Lead].size());
	}

	@isTest
	static void testPullUpdateByMobyId() {
		SyncMoby03Lead.MobyLeadRes res = createObj();

		SyncMoby03Lead job = new SyncMoby03Lead();
		job.upsertLead(res);

		/** Coverage:
		 * SyncMoby03Lead: 276
		 * 	Remove MobyBranchNumber__c */
		Showroom__c[] shows = [SELECT Id, Name, MobyBranchNumber__c, MobyBranchCode__c FROM Showroom__c];
		// for (Showroom__c show :shows) { show.MobyBranchNumber__c = null; }
		shows[1].MobyBranchNumber__c = null;
		update shows;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby03Lead kob = new SyncMoby03Lead();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(3, [SELECT Id FROM Lead].size());
	}


	@isTest
	static void testPullErrorEmail() {
		SyncMoby03Lead.MobyLeadRes res = createObj();
		Integer expected = res.leads.size();
		for (SyncMoby03Lead.MobyLead lead :res.leads) { lead.email += '.'; }

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby03Lead job = new SyncMoby03Lead();
		job.followOnToNext = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Lead].size());
	}

	@isTest
	static void testPullUpdateWithErrorEmail() {
		SyncMoby03Lead.MobyLeadRes res = createObj();
		Integer expected = res.leads.size();
		SyncMoby03Lead q = new SyncMoby03Lead();
		q.upsertLead(res);

		for (SyncMoby03Lead.MobyLead lead :res.leads) { lead.email += '.'; }

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby03Lead job = new SyncMoby03Lead();
		job.followOnToNext = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Lead].size());
	}


	@isTest static void testPullNoRow() {
		SyncMoby03Lead.MobyLeadRes res = new SyncMoby03Lead.MobyLeadRes();
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby03Lead job = new SyncMoby03Lead();
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
        SyncMoby03Lead job = new SyncMoby03Lead();
        job.followOnToNext = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPull_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SyncMoby03Lead job = new SyncMoby03Lead();
		job.followOnToNext = true;
		System.enqueueJob(job);
		Test.stopTest();

	}
	@isTest static void testPull_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SyncMoby03Lead job = new SyncMoby03Lead();
		job.followOnToNext = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPull_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SyncMoby03Lead job = new SyncMoby03Lead();
		job.followOnToNext = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}

}