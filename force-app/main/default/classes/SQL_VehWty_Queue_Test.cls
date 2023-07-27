@isTest
public class SQL_VehWty_Queue_Test {

	@TestSetup
	static void setup() {
		
		SQL_API_Base_Test.makeData();
		// TestFactory.genVehType('NC', true);
		// createVeh();
		TestFactory.genVehicle(1, true);
		SQL_WtyPkg_Queue_Test.createWtyPkg();
	}

	@isTest static Integer createVehWty() {
		Vehicle__c v = [SELECT Id FROM Vehicle__c LIMIT 1];
		WarrantyPackage__c[] wps = [SELECT Id, Name, Description__c, CompanyCode__c, ExternalId__c FROM WarrantyPackage__c];
		Vehicle__c ve = [SELECT Id, Name FROM Vehicle__c LIMIT 1];

		VehicleWarranty__c[] vws = new VehicleWarranty__c[]{};
		VehicleWarranty__c vw1 = new VehicleWarranty__c();
		vw1.ChassisNo__c = ve.Name;
		vw1.ContractCode__c = wps[0].Name;
		vw1.Name = vw1.ChassisNo__c + '-' + vw1.ContractCode__c;
		vw1.CompanyCode__c = wps[0].CompanyCode__c;
		vw1.DateStart__c = Date.today();
		vw1.DateEnd__c = Date.today().addYears(1);
		vw1.Distance__c = 20000;
		vw1.Duration__c = 12;
		vw1.ExternalId__c = vw1.CompanyCode__c + '-' + vw1.ChassisNo__c + '-' + vw1.ContractCode__c + '-' + String.valueOf(Date.today()).replace('-', '');
		vw1.WarrantyPackage__c = wps[0].Id;
		vw1.Vehicle__c = v.Id;
		vws.add(vw1);
		VehicleWarranty__c vw2 = new VehicleWarranty__c();
		vw2.ChassisNo__c = ve.Name;
		vw2.ContractCode__c = wps[1].Name;
		vw2.Name = vw2.ChassisNo__c + '-' + vw2.ContractCode__c;
		vw2.CompanyCode__c = wps[1].CompanyCode__c;
		vw2.DateStart__c = Date.today();
		vw2.DateEnd__c = Date.today().addYears(1);
		vw2.Distance__c = 40000;
		vw2.Duration__c = 24;
		vw2.ExternalId__c = vw2.CompanyCode__c + '-' + vw2.ChassisNo__c + '-' + vw2.ContractCode__c + '-' + String.valueOf(Date.today()).replace('-', '');
		vw2.WarrantyPackage__c = wps[1].Id;
		vw2.Vehicle__c = v.Id;
		vws.add(vw2);
		insert vws;

		return vws.size();
	}

	@isTest static void testPullInsert() {
		WarrantyPackage__c[] wps = [SELECT Id, Name, Description__c FROM WarrantyPackage__c];
		Integer count = createVehWty();
		VehicleWarranty__c[] vws = [
			SELECT 
				Id, Name, CompanyCode__c, Company__r.Name
				, ChassisNo__c, Vehicle__r.Name
				, ContractCode__c, WarrantyPackage__r.Description__c
				, DateStart__c, DateEnd__c, Distance__c, Duration__c
				, ExternalId__c
			FROM VehicleWarranty__c
		];
		SQL_VehWty_Queue.CareVehWtyRes[] res = new SQL_VehWty_Queue.CareVehWtyRes[]{};
		Integer index = 0;
		for (VehicleWarranty__c vw :vws) {
			SQL_VehWty_Queue.CareVehWtyRes wres = new SQL_VehWty_Queue.CareVehWtyRes();
			wres.ChassisNo = vw.ChassisNo__c;
			wres.CompanyCode = vw.CompanyCode__c;
			wres.CompanyId = 1;
			wres.CompanyName = vw.Company__r.Name;
			wres.ContractCode = wps[index].Name;
			wres.ContractId = null;
			wres.ContractName = null;
			wres.StartDate = vw.DateStart__c;
			wres.EndDate = vw.DateEnd__c;
			wres.Duration = Integer.valueOf(vw.Duration__c);
			wres.Distance = Integer.valueOf(vw.Distance__c);
			wres.ExternalId = wres.CompanyCode + '-' + wres.ChassisNo + '-' + wres.ContractCode + '-' + String.valueOf(wres.StartDate.date()).replace('-', '');
			wres.Id = 1;
			wres.Region = null;
			wres.Source = 'Autoline';
			res.add(wres);
			index++;
		}
		delete [SELECT Id FROM VehicleWarranty__c];

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_VehWty_Queue job = new SQL_VehWty_Queue();
		job.sendCompletionEmail = true;
        System.enqueueJob(job);
		Test.stopTest();
		System.assertEquals(res.size(), [SELECT Id FROM VehicleWarranty__c].size());
	}

	@isTest static void testPullUpdate() {
		WarrantyPackage__c[] wps = [SELECT Id, Name, Description__c FROM WarrantyPackage__c];
		Integer count = createVehWty();
		VehicleWarranty__c[] vws = [
			SELECT 
				Id, Name, CompanyCode__c, Company__r.Name
				, ChassisNo__c, Vehicle__r.Name
				, ContractCode__c, WarrantyPackage__r.Description__c
				, DateStart__c, DateEnd__c, Distance__c, Duration__c
				, ExternalId__c
			FROM VehicleWarranty__c
		];
		System.debug('vws: ' + JSON.serialize(vws));

		SQL_VehWty_Queue.CareVehWtyRes[] res = new SQL_VehWty_Queue.CareVehWtyRes[]{};
		Integer index = 0;
		for (VehicleWarranty__c vw :vws) {
			SQL_VehWty_Queue.CareVehWtyRes wres = new SQL_VehWty_Queue.CareVehWtyRes();
			wres.ChassisNo = vw.ChassisNo__c;
			wres.CompanyCode = vw.CompanyCode__c;
			wres.CompanyId = 1;
			wres.CompanyName = vw.Company__r.Name;
			wres.ContractCode = wps[index].Name;
			wres.ContractId = null;
			wres.ContractName = null;

			wres.StartDate = vw.DateStart__c;
			wres.EndDate = vw.DateEnd__c;
			wres.Duration = Integer.valueOf(vw.Duration__c);
			wres.Distance = Integer.valueOf(vw.Distance__c);

			wres.ExternalId = wres.CompanyCode + '-' + wres.ChassisNo + '-' + wres.ContractCode + '-' + String.valueOf(wres.StartDate.date()).replace('-', '');
			wres.Id = 1;
			wres.Region = null;
			wres.Source = 'Autoline';
			if (index == 1) {
				wres.StartDate = vw.DateStart__c.addDays(1);
				wres.EndDate = vw.DateEnd__c.addDays(1);
				wres.Duration = Integer.valueOf(vw.Duration__c + 1);
				wres.Distance = Integer.valueOf(vw.Distance__c + 1);
			}
			res.add(wres);
			index++;
		}
		System.debug('res: ' + JSON.serialize(res));

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_VehWty_Queue job = new SQL_VehWty_Queue();
		job.sendCompletionEmail = true;
        System.enqueueJob(job);
		Test.stopTest();
		System.assertEquals(res.size(), [SELECT Id FROM VehicleWarranty__c].size());
	}

	@isTest static void testPullNoRow() {
		SQL_VehWty_Queue.CareVehWtyRes[] res = new SQL_VehWty_Queue.CareVehWtyRes[]{};

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SQL_VehWty_Queue job = new SQL_VehWty_Queue();
		job.dateFrom = null;
		job.dateTo = null;
		job.sendCompletionEmail = true;
        System.enqueueJob(job);
        Test.stopTest();
		System.assertEquals(0, [SELECT Id FROM VehicleWarranty__c].size());
	}

	@isTest static void testPullStatusNotOK() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SQL_VehWty_Queue job = new SQL_VehWty_Queue();
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPull_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SQL_VehWty_Queue job = new SQL_VehWty_Queue();
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPull_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_VehWty_Queue job = new SQL_VehWty_Queue();
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPull_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_VehWty_Queue job = new SQL_VehWty_Queue();
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}

}