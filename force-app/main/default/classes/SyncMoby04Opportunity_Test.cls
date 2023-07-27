@isTest
public class SyncMoby04Opportunity_Test {

	@TestSetup
	public static void makeData(){
		SyncMobyApiBase_Test.makeData();

		// SyncMoby01User_Test.testPull();
		SyncMoby01User.MobyUserRes resUser = SyncMoby01User_Test.createObj();
		SyncMoby01User jobUser = new SyncMoby01User();
		jobUser.upsertUser(resUser);

		SyncMoby02Contact.MobyContactRes resCont = SyncMoby02Contact_Test.createObj();
		SyncMoby02Contact jobCont = new SyncMoby02Contact();
		jobCont.upsertContact(resCont);

		// remove Showroom__c records
		delete [SELECT Id FROM Showroom__c];
	}
	
	@isTest
	public static SyncMoby04Opportunity.MobyOpportunityRes createObj() {
		SyncMoby04Opportunity.MobyOpportunityRes response = new SyncMoby04Opportunity.MobyOpportunityRes();
		response.opportunities = new SyncMoby04Opportunity.MobyOpportunity[]{};

		SyncMoby04Opportunity.MobyOpportunity oppo;
		SyncMoby04Opportunity.MobyModel mi;

		oppo = new SyncMoby04Opportunity.MobyOpportunity();
		oppo.id = 757;
		oppo.leadId = null;
		oppo.opportunityType = 'SELL';
		oppo.userId = 418;
		oppo.companyId = 1;
		oppo.companyCode = 'SDAB';
		oppo.companyName = 'SD Auto Bavaria';
		oppo.branchId = 4;
		oppo.branchCode = 'ABSB';
		oppo.branchName = 'SDAB Sg Besi';
		oppo.externalId = '2dfec865-776d-474e-83b5-a74461cb37b2';
		oppo.extDealerUid = null;
		oppo.makeId = 1;
		oppo.makeCode = 'BMW';
		oppo.makeName = 'BMW';
		oppo.extMakeId = 174640000;
		oppo.salescycleId = 702;
		oppo.contactId = 1362;
		oppo.sourceId = 7;
		oppo.sourceCode = 'Showroom Walk-in';
		oppo.sourceName = 'Showroom Walk-in';
		oppo.eventId = null;
		oppo.eventCode = null;
		oppo.eventName = null;
		oppo.extUid = null;
		oppo.carTypeId = 14;
		oppo.carTypeCode = 'NEW';
		oppo.carTypeName = 'New Car';
		oppo.statusId = 12;
		oppo.statusCode = 'WON';
		oppo.statusName = 'Won';
		oppo.stage = 'Car Delivered';
		oppo.extStatusId = '174640005';
		oppo.extStateId = '1';
		oppo.extResponseId = null;
		oppo.extReasoncodeId = 'AC6EA159-07BB-E611-80DD-005056AC3EC8';
		oppo.extLostReasonNo = null;
		oppo.prospectDocId = 1238;
		oppo.deferredDate = null;
		oppo.warmth = 100;
		oppo.leadStatusId = 25;
		oppo.variantText = null;
		oppo.remarks = null;
		oppo.statusReason = null;
		oppo.sourceUserid = null;
		oppo.transferUserId = null;
		oppo.extLeadUid = null;
		oppo.extOpportunityUid = null;
		oppo.extCustomerUid = null;
		oppo.insertDate = Datetime.valueOf('2019-02-08 15:44:00.247+08:00');
		oppo.updateDate = Datetime.valueOf('2019-02-08 15:44:00.247+08:00');
		oppo.insertUserId = 67;
		oppo.updateUserId = 67;
		oppo.modelInterests = new SyncMoby04Opportunity.MobyModel[]{};
		mi = new SyncMoby04Opportunity.MobyModel();
		mi.id = 1866;
		mi.headerId = 757;
		mi.variantCode = 'DA3KRAB';
		mi.variantName = 'FORD FIESTA SEDAN 1.5L';
		mi.variantAssemblyCode = null;
		mi.variantBodyType = null;
		mi.variantCylinder = null;
		mi.variantDisplacement = '1498 cc';
		mi.extVariantUid = null;
		mi.variantFuelType = 'Petrol';
		mi.variantModelId = 350;
		mi.modelCode = 'FEST';
		mi.modelName = '(FOR) Fiesta';
		mi.modelAssemblyCode = null;
		mi.modelBodyType = null;
		mi.modelCylinder = null;
		mi.modelDisplacement = null;
		mi.modelFuelType = null;
		mi.makeId = 213;
		mi.makeCode = 'ASELECT';
		mi.makeName = 'Auto Selection';
		mi.variantSystem = 'Manual';
		mi.isActive = true;
		oppo.modelInterests.add(mi);
		response.opportunities.add(oppo);

		oppo = new SyncMoby04Opportunity.MobyOpportunity();
		oppo.id = 737;
		oppo.leadId = null;
		oppo.opportunityType = 'SELL';
		oppo.userId = 239;
		oppo.companyId = 1;
		oppo.companyCode = 'SDAB';
		oppo.companyName = 'SD Auto Bavaria';
		oppo.branchId = 5;
		oppo.branchCode = 'ABKL';
		oppo.branchName = 'SDAB KL';
		oppo.externalId = '3dfec865-776d-474e-83b5-a74461cb37b3';
		oppo.extDealerUid = '82b58118-6681-e511-80d3-00505684373b';
		oppo.makeId = 1;
		oppo.makeCode = 'BMW';
		oppo.makeName = 'BMW';
		oppo.extMakeId = 174640000;
		oppo.salescycleId = 683;
		oppo.contactId = 1363;
		oppo.sourceId = 7;
		oppo.sourceCode = 'Showroom Walk-in';
		oppo.sourceName = 'Showroom Walk-in';
		oppo.eventId = null;
		oppo.eventCode = null;
		oppo.eventName = null;
		oppo.extUid = null;
		oppo.carTypeId = 14;
		oppo.carTypeCode = 'NEW';
		oppo.carTypeName = 'New Car';
		oppo.statusId = 22;
		oppo.statusCode = 'DEFERRED';
		oppo.statusName = 'Deferred';
		oppo.stage = 'Test Drive';
		oppo.extStatusId = '174640009';
		oppo.extStateId = '0';
		oppo.extResponseId = null;
		oppo.extReasoncodeId = null;
		oppo.extLostReasonNo = null;
		oppo.prospectDocId = 1238;
		oppo.deferredDate = Datetime.valueOf('2019-10-01 00:00:00+08:00');
		oppo.warmth = 51;
		oppo.leadStatusId = 24;
		oppo.variantText = null;
		oppo.remarks = 'Interested with G20 330i';
		oppo.statusReason = null;
		oppo.sourceUserid = null;
		oppo.transferUserId = null;
		oppo.extLeadUid = null;
		oppo.extOpportunityUid = null;
		oppo.extCustomerUid = null;
		oppo.insertDate = Datetime.valueOf('2019-02-04 13:18:18.663+08:00');
		oppo.updateDate = Datetime.valueOf('2019-07-24 08:42:20.72+08:00');
		oppo.insertUserId = 68;
		oppo.updateUserId = 68;
		oppo.modelInterests = null;
		response.opportunities.add(oppo);

		oppo = new SyncMoby04Opportunity.MobyOpportunity();
		oppo.id = 725;
		oppo.leadId = null;
		oppo.opportunityType = 'SELL';
		oppo.userId = 161;
		oppo.companyId = 1;
		oppo.companyCode = 'SDAB';
		oppo.companyName = 'SD Auto Bavaria';
		oppo.branchId = 3;
		oppo.branchCode = 'ABAD';
		oppo.branchName = 'SDAB Ara Damansara';
		oppo.externalId = '7dfec865-776d-474e-83b5-a74461cb37b8';
		oppo.extDealerUid = '77b58118-6681-e511-80d3-00505684373b';
		oppo.makeId = 1;
		oppo.makeCode = 'BMW';
		oppo.makeName = 'BMW';
		oppo.extMakeId = 174640000;
		oppo.salescycleId = 671;
		oppo.contactId = 1364;
		oppo.sourceId = null;
		oppo.sourceCode = null;
		oppo.sourceName = null;
		oppo.eventId = null;
		oppo.eventCode = null;
		oppo.eventName = null;
		oppo.extUid = null;
		oppo.carTypeId = null;
		oppo.carTypeCode = null;
		oppo.carTypeName = null;
		oppo.statusId = 11;
		oppo.statusCode = 'OPEN';
		oppo.statusName = 'Open';
		oppo.stage = 'Prospecting';
		oppo.extStatusId = '174640000';
		oppo.extStateId = '0';
		oppo.extResponseId = null;
		oppo.extReasoncodeId = null;
		oppo.extLostReasonNo = null;
		oppo.prospectDocId = 1238;
		oppo.deferredDate = null;
		oppo.warmth = 0;
		oppo.leadStatusId = 23;
		oppo.variantText = '["BMW 520i Luxury"]';
		oppo.remarks = null;
		oppo.statusReason = null;
		oppo.sourceUserid = null;
		oppo.transferUserId = null;
		oppo.extLeadUid = null;
		oppo.extOpportunityUid = null;
		oppo.extCustomerUid = null;
		oppo.insertDate = Datetime.valueOf('2019-02-02 16:16:05.693+08:00');
		oppo.updateDate = Datetime.valueOf('2019-02-02 16:16:05.693+08:00');
		oppo.insertUserId = 67;
		oppo.updateUserId = 67;
		oppo.modelInterests = null;
		response.opportunities.add(oppo);

		response.lastKey = 757;

		return response;
	}

	@isTest
	public static void testPull() {
		SyncMoby04Opportunity.MobyOpportunityRes res = createObj();

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby04Opportunity job = new SyncMoby04Opportunity();
		job.followOnToNext = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();

		System.debug(JSON.serialize([SELECT Id, Name FROM Opportunity]));
		System.assertEquals(3, [SELECT Id FROM Opportunity].size());
	}

	@isTest
	static void testPullUpdateByMobyId() {
		SyncMoby04Opportunity.MobyOpportunityRes res = createObj();
		Integer expected = res.opportunities.size();

		SyncMoby04Opportunity job = new SyncMoby04Opportunity();
		job.upsertOppo(res);

		/** Coverage:
		 * SyncMoby04Opportunity: 290
		 * 	Remove MobyBranchNumber__c */
		Showroom__c[] shows = [SELECT Id, Name, MobyBranchNumber__c, MobyBranchCode__c FROM Showroom__c];
		shows[1].MobyBranchNumber__c = null;
		update shows;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby04Opportunity kob = new SyncMoby04Opportunity();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Opportunity].size());
	}

	@isTest static void testPullNoRow() {
		SyncMoby04Opportunity.MobyOpportunityRes res = new SyncMoby04Opportunity.MobyOpportunityRes();
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby04Opportunity job = new SyncMoby04Opportunity();
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
        SyncMoby04Opportunity job = new SyncMoby04Opportunity();
        job.followOnToNext = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPull_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SyncMoby04Opportunity job = new SyncMoby04Opportunity();
		job.followOnToNext = true;
		System.enqueueJob(job);
		Test.stopTest();

	}
	@isTest static void testPull_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SyncMoby04Opportunity job = new SyncMoby04Opportunity();
		job.followOnToNext = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPull_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SyncMoby04Opportunity job = new SyncMoby04Opportunity();
		job.followOnToNext = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
}