@isTest
	public class SQL_Veh_Queue_Test {

	@TestSetup
	public static void makeData() {
		SQL_Acc_Queue_Test.makeData();
		TestFactory.genVehType('NC', true);

		SQL_Acc_Queue.CareContactRes[] accs = SQL_Acc_Queue_Test.createObj();
		SQL_Acc_Queue q = new SQL_Acc_Queue();
		q.upsertAccount(accs);
	}

	@isTest
	public static SQL_Veh_Queue.CareVehicleRes[] createObj() {
		SQL_Veh_Queue.CareVehicleRes[] res = new SQL_Veh_Queue.CareVehicleRes[]{};
		SQL_Veh_Queue.CareVehicleRes veh;
		
		veh = new SQL_Veh_Queue.CareVehicleRes();
		veh.companyCode = '028';
		veh.company = 'Sime Darby Auto Bavaria Sdn Bhd';
		veh.source = 'Autoline';
		veh.vehNo = 23167;
		veh.dmsNo = '21161';
		veh.vehMakeCode = 'B';
		veh.vehMake = 'BMW';
		veh.vehModelRange = null;
		veh.vehModelCode = 'Generic';
		veh.vehModelDesc = 'BMW Generic Model';
		veh.vehModelYear = 2012;
		veh.vehColorCode = ' ';
		veh.vehColor = '300 alpinweiss 3';
		veh.vehTrimCode = '';
		veh.vehTrim = 'LCB8 Leather \'Dakota\'/terra';
		veh.vehVariantCode = 'Generic';
		veh.vehVariantDesc = 'BMW Generic Model';
		veh.chassis = 'PM1XG14060DV69340';
		veh.engineNum = 'A7980139';
		veh.engineCap = 0.0;
		veh.description = 'XG24A7 - F10/520i';
		veh.productionDate = Datetime.valueOf('1899-12-30 00:00:00');
		veh.productionMonth = '0';
		veh.productionYear = '2012';
		veh.bodyStyle = '';
		veh.vehType = 'U';
		veh.regDate = Datetime.valueOf('2012-12-10 00:00:00');
		veh.regNum = 'BMW1002';
		veh.mileage = 0;
		veh.nextServiceDate = null;
		veh.vsbRef = '0';
		veh.vsbRefCmp = 'A0';
		veh.sellingDealer = 'Auto Bavaria';
		veh.warrantyExDate = Datetime.valueOf('2014-12-10 00:00:00');
		veh.extendedWarrantyDate = Datetime.valueOf('1900-01-01 00:00:00');
		res.add(veh);
	
		veh = new SQL_Veh_Queue.CareVehicleRes();
		veh.companyCode = '028';
		veh.company = 'Sime Darby Auto Bavaria Sdn Bhd';
		veh.source = 'Autoline';
		veh.vehNo = 98806;
		veh.dmsNo = '99050';
		veh.vehMakeCode = 'C';
		veh.vehMake = 'Motorcycle';
		veh.vehModelRange = null;
		veh.vehModelCode = 'K08';
		veh.vehModelDesc = 'C 400 GT - K08';
		veh.vehModelYear = 2019;
		veh.vehColorCode = 'N2G';
		veh.vehColor = 'MOONWALK GREY METALLIC';
		veh.vehTrimCode = 'GEN';
		veh.vehTrim = 'Generic';
		veh.vehVariantCode = '0C06';
		veh.vehVariantDesc = 'C 400 GT - K08';
		veh.chassis = 'WB40C0609KS801449';
		veh.engineNum = '5018058K';
		veh.engineCap = 350.0;
		veh.description = 'C 400 GT - K08';
		veh.productionDate = Datetime.valueOf('1899-12-30 00:00:00');
		veh.productionMonth = '0';
		veh.productionYear = '2019';
		veh.bodyStyle = 'H';
		veh.vehType = 'N';
		veh.regDate = Datetime.valueOf('2019-10-05 00:00:00');
		veh.regNum = 'KER79';
		veh.mileage = 0;
		veh.nextServiceDate = null;
		veh.vsbRef = '11713';
		veh.vsbRefCmp = 'A1';
		veh.sellingDealer = 'A13';
		veh.warrantyExDate = Datetime.valueOf('2019-09-05 00:00:00');
		veh.extendedWarrantyDate = Datetime.valueOf('1900-01-01 00:00:00');
		res.add(veh);

		veh = new SQL_Veh_Queue.CareVehicleRes();
		veh.companyCode = '028';
		veh.company = 'Sime Darby Auto Bavaria Sdn Bhd';
		veh.source = 'Autoline';
		veh.vehNo = 99162;
		veh.dmsNo = '99439';
		veh.vehMakeCode = 'C';
		veh.vehMake = 'Motorcycle';
		veh.vehModelRange = null;
		veh.vehModelCode = 'K50 MU';
		veh.vehModelDesc = 'R 1200 GS - K50 MU';
		veh.vehModelYear = 2018;
		veh.vehColorCode = 'N1S';
		veh.vehColor = 'ICED CHOCOLATE METALLIC';
		veh.vehTrimCode = 'GEN';
		veh.vehTrim = 'Generic';
		veh.vehVariantCode = '0A81';
		veh.vehVariantDesc = 'R 1200 GS - K50 MU';
		veh.chassis = 'WB10A8107JR927694';
		veh.engineNum = '0218X012';
		veh.engineCap = 1170.0;
		veh.description = 'R 1200 GS - K50 MU';
		veh.productionDate = Datetime.valueOf('1899-12-30 00:00:00');
		veh.productionMonth = '0';
		veh.productionYear = '2018';
		veh.bodyStyle = 'H';
		veh.vehType = 'N';
		veh.regDate = Datetime.valueOf('2019-11-13 00:00:00');
		veh.regNum = 'BQB4744';
		veh.mileage = 0;
		veh.nextServiceDate = null;
		veh.vsbRef = '11813';
		veh.vsbRefCmp = 'A1';
		veh.sellingDealer = 'A13';
		veh.warrantyExDate = Datetime.valueOf('2019-12-11 00:00:00');
		veh.extendedWarrantyDate = Datetime.valueOf('1900-01-01 00:00:00');
		res.add(veh);

		veh = new SQL_Veh_Queue.CareVehicleRes();
		veh.companyCode = '028';
		veh.company = 'Sime Darby Auto Bavaria Sdn Bhd';
		veh.source = 'Autoline';
		veh.vehNo = 99884;
		veh.dmsNo = '100240';
		veh.vehMakeCode = 'C';
		veh.vehMake = 'Motorcycle';
		veh.vehModelRange = null;
		veh.vehModelCode = 'K51';
		veh.vehModelDesc = 'R 1200 GS Adv K51';
		veh.vehModelYear = 2019;
		veh.vehColorCode = 'N2H';
		veh.vehColor = 'Ice grey';
		veh.vehTrimCode = 'GEN';
		veh.vehTrim = 'Generic';
		veh.vehVariantCode = '0J54';
		veh.vehVariantDesc = 'R 1250 GS Adv - K51';
		veh.chassis = 'WB10J5406KR933675';
		veh.engineNum = '1419114T';
		veh.engineCap = 1254.0;
		veh.description = 'R 1250 GS Adv - K51';
		veh.productionDate = Datetime.valueOf('1899-12-30 00:00:00');
		veh.productionMonth = '0';
		veh.productionYear = '2019';
		veh.bodyStyle = 'H';
		veh.vehType = 'N';
		veh.regDate = Datetime.valueOf('2019-12-18 00:00:00');
		veh.regNum = 'KEU79';
		veh.mileage = 0;
		veh.nextServiceDate = null;
		veh.vsbRef = '12196';
		veh.vsbRefCmp = 'A1';
		veh.sellingDealer = 'A13';
		veh.warrantyExDate = Datetime.valueOf('2019-12-17 00:00:00');
		veh.extendedWarrantyDate = Datetime.valueOf('1900-01-01 00:00:00');
		res.add(veh);
	
		veh = new SQL_Veh_Queue.CareVehicleRes();
		veh.companyCode = '028';
		veh.company = 'Sime Darby Auto Bavaria Sdn Bhd';
		veh.source = 'Autoline';
		veh.vehNo = 182080;
		veh.dmsNo = '113115';
		veh.vehMakeCode = 'B';
		veh.vehMake = 'BMW';
		veh.vehModelRange = 'BMW 5 Series';
		veh.vehModelCode = 'G30';
		veh.vehModelDesc = 'BMW 5 Series G30';
		veh.vehModelYear = 2019;
		veh.vehColorCode = '300';
		veh.vehColor = 'Alpine White';
		veh.vehTrimCode = 'LCFK';
		veh.vehTrim = 'Leather Dakota Black Exclusive Stitching';
		veh.vehVariantCode = 'JA18A7';
		veh.vehVariantDesc = 'BMW 520i Luxury - CKD';
		veh.chassis = 'PM1JA180X0WG03286';
		veh.engineNum = '0143X063';
		veh.engineCap = 1998.0;
		veh.description = 'BMW 520i Luxury - CKD';
		veh.productionDate = Datetime.valueOf('1899-12-30 00:00:00');
		veh.productionMonth = '0';
		veh.productionYear = '2019';
		veh.bodyStyle = 'H';
		veh.vehType = 'U';
		veh.regDate = Datetime.valueOf('2020-11-20 00:00:00');
		veh.regNum = 'VFG980';
		veh.mileage = 0;
		veh.nextServiceDate = null;
		veh.vsbRef = '5130';
		veh.vsbRefCmp = 'A1';
		veh.sellingDealer = 'Auto Bavaria - Subang Jaya VDC';
		veh.warrantyExDate = Datetime.valueOf('2020-11-19 00:00:00');
		veh.extendedWarrantyDate = Datetime.valueOf('1900-01-01 00:00:00');
		res.add(veh);

		return res;
	}

	@isTest static void testPull() {
		SQL_Veh_Queue.CareVehicleRes[] res = createObj();
		Integer expected = res.size();
		
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Veh_Queue job = new SQL_Veh_Queue();
		job.followOnToVO = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Vehicle__c].size());
	}

	@isTest static void testUpdate() {
		SQL_Veh_Queue.CareVehicleRes[] res = createObj();
		Integer expected = res.size();
		SQL_Veh_Queue q = new SQL_Veh_Queue();
		q.upsertVehicle(res);

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Veh_Queue job = new SQL_Veh_Queue();
		job.followOnToVO = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Vehicle__c].size());
	}

	@isTest static void testUpdateByVin() {
		SQL_Veh_Queue.CareVehicleRes[] res = createObj();
		Integer expected = res.size();
		SQL_Veh_Queue q = new SQL_Veh_Queue();
		q.upsertVehicle(res);

		Vehicle__c[] vehs = [SELECT Id, Vehicle_Number__c FROM Vehicle__c];
		for (Vehicle__c veh :vehs) { veh.Vehicle_Number__c = null; }
		update vehs;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Veh_Queue job = new SQL_Veh_Queue();
		job.followOnToVO = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Vehicle__c].size());
	}

	@isTest static void testPullNoRow() {
		SQL_Veh_Queue.CareVehicleRes[] res = new SQL_Veh_Queue.CareVehicleRes[]{};
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_Veh_Queue job = new SQL_Veh_Queue();
		job.followOnToVO = true;
		System.enqueueJob(job);
		job.dateFrom = job.dateTo = null;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPullStatusNotOK() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SQL_Veh_Queue job = new SQL_Veh_Queue();
        job.followOnToVO = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPullVeh_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SQL_Veh_Queue job = new SQL_Veh_Queue();
		job.followOnToVO = true;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPullVeh_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_Veh_Queue job = new SQL_Veh_Queue();
		job.followOnToVO = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPullVeh_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_Veh_Queue job = new SQL_Veh_Queue();
		job.followOnToVO = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testRefreshVeh() {
		SQL_Veh_Queue.CareVehicleRes[] res = createObj();

		SQL_Veh_Queue job = new SQL_Veh_Queue();
		job.upsertVehicle(res);

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Vehicle__c veh = [SELECT Id FROM Vehicle__c LIMIT 1];
		Test.startTest();
		String ret = SQL_Veh_Queue.refreshVeh(veh.Id);
		Test.stopTest();
		System.assert(!ret.containsIgnoreCase('Error'));
	}
}