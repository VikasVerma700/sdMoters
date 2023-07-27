@isTest
public class SQL_WtyPkg_Queue_Test {

	@TestSetup
	static void setup() {
		SQL_API_Base_Test.makeData();
	}
	
	@isTest
	public static Integer createWtyPkg() {
		Company__c cmp = [SELECT Id FROM Company__c LIMIT 1];
		WarrantyPackage__c[] wps = new List<WarrantyPackage__c>();
		wps.add(new WarrantyPackage__c(
			Name = 'CODE1'
			, Company__c = cmp.Id
			, CompanyCode__c = '028'
			, Description__c = 'Code Name 1'
			, ExternalId__c = '028-CODE1'
		));
		wps.add(new WarrantyPackage__c(
			Name = 'CODE2'
			, CompanyCode__c = '028'
			, Description__c = 'Code Name 22'
			, ExternalId__c = '028-CODE2'
		));
		insert wps;
		return wps.size();
	}

	@isTest
	static void testPullInsert() {
		Integer count = createWtyPkg();
		WarrantyPackage__c[] wps = [
			SELECT
				Id, Name, CompanyCode__c, Description__c
			FROM WarrantyPackage__c
		];
		SQL_WtyPkg_Queue.CareWtyPkgRes[] res = new SQL_WtyPkg_Queue.CareWtyPkgRes[]{};
		for (WarrantyPackage__c wp :wps) {
			SQL_WtyPkg_Queue.CareWtyPkgRes wres = new SQL_WtyPkg_Queue.CareWtyPkgRes();
			wres.CompanyCode = wp.CompanyCode__c;
			wres.CompanyId = 1;
			wres.CompanyName = null;
			wres.ContractCode = wp.Name;
			wres.ContractName = wp.Description__c;
			wres.ExternalId = wres.CompanyCode + '-' + wres.ContractCode;
			wres.Id = 1;
			wres.Region = null;
			res.add(wres);
		}
		/** Delete 1 record to simulate add */
		Database.delete(wps);
		SQL_WtyPkg_Queue job = new SQL_WtyPkg_Queue();
		// job.upsertWtyPkg(res);

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		job.followOnToVehWty = true;
		job.sendCompletionEmail = true;
        System.enqueueJob(job);
		Test.stopTest();
		System.assertEquals(res.size(), [SELECT Id FROM WarrantyPackage__c].size());
	}

	@isTest
	static void testPullUpdate() {
		Integer count = createWtyPkg();
		WarrantyPackage__c[] wps = [
			SELECT
				Id, Name, CompanyCode__c, Description__c
			FROM WarrantyPackage__c
		];
		SQL_WtyPkg_Queue.CareWtyPkgRes[] res = new SQL_WtyPkg_Queue.CareWtyPkgRes[]{};
		for (WarrantyPackage__c wp :wps) {
			SQL_WtyPkg_Queue.CareWtyPkgRes wres = new SQL_WtyPkg_Queue.CareWtyPkgRes();
			wres.CompanyCode = wp.CompanyCode__c;
			wres.CompanyId = 1;
			wres.CompanyName = null;
			wres.ContractCode = wp.Name;
			wres.ContractName = wp.Description__c;
			if (wp.Name == 'CODE2') { wres.ContractName += 'x'; }
			wres.ExternalId = wres.CompanyCode + '-' + wres.ContractCode;
			wres.Id = 1;
			wres.Region = null;
			res.add(wres);
		}

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_WtyPkg_Queue job = new SQL_WtyPkg_Queue();
		job.followOnToVehWty = true;
		job.sendCompletionEmail = true;
        System.enqueueJob(job);
		Test.stopTest();
		System.assertEquals(res.size(), [SELECT Id FROM WarrantyPackage__c].size());
	}

	@isTest static void testPullNoRow() {
		SQL_WtyPkg_Queue.CareWtyPkgRes[] res = new SQL_WtyPkg_Queue.CareWtyPkgRes[]{};

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SQL_WtyPkg_Queue job = new SQL_WtyPkg_Queue();
		job.dateFrom = null;
		job.dateTo = null;
        job.followOnToVehWty = true;
		job.sendCompletionEmail = true;
        System.enqueueJob(job);
        Test.stopTest();
		System.assertEquals(0, [SELECT Id FROM WarrantyPackage__c].size());		
	}

	@isTest static void testPullStatusNotOK() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SQL_WtyPkg_Queue job = new SQL_WtyPkg_Queue();
        job.followOnToVehWty = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPull_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SQL_WtyPkg_Queue job = new SQL_WtyPkg_Queue();
		job.followOnToVehWty = true;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPull_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_WtyPkg_Queue job = new SQL_WtyPkg_Queue();
		job.followOnToVehWty = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPull_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_WtyPkg_Queue job = new SQL_WtyPkg_Queue();
		job.followOnToVehWty = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}

}