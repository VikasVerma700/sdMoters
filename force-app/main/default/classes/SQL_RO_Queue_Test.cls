@isTest
public with sharing class SQL_RO_Queue_Test {

	@TestSetup
	public static void makeData(){
		System.debug('SQL_RO_Queue_Test.makeData()');
        SQL_VO_Queue_Test.makeData();

		TestFactory.genWorkshop(1, true);
		TestFactory.genEmpMaster(1, true);

		SQL_VO_Queue.CareVehOwnRes[] vows = SQL_VO_Queue_Test.createObj();
		SQL_VO_Queue s = new SQL_VO_Queue();
		s.upsertVO(vows);
		s.upsertVO(vows);

		TestFactory.genSvcAppt(4, true);
		/** Patch Service Appoinments */
		Company__c[] cs = [SELECT Id FROM Company__c];
		Workshop__c[] ws = [SELECT Id, Company__c, Company__r.Name FROM Workshop__c];
		for (Workshop__c w :ws) { w.Company__c = cs[0].Id; }
		update ws;
		Service_Appointment__c[] sas = [SELECT Id, Name, Company__c, Company__r.Name, Workshop__c, Workshop__r.Name FROM Service_Appointment__c];
		for (Service_Appointment__c sa :sas) {
			sa.Company__c = cs[0].Id;
			sa.Workshop__c = ws[0].Id;
		}
		update sas;
	}
	@isTest static void testPull() {
		Service_Appointment__c[] sas = [
			SELECT
				Id, Name
				, Company__r.Name, Workshop__r.Name
				, Vehicle_Ownership__r.Customer__r.Name
				, Vehicle_Ownership__r.Customer__r.Customer_Number__c
				, Vehicle_Ownership__r.Customer__r.NRIC_Number__c
				, Vehicle_Ownership__r.Vehicle__r.Name
				, Vehicle_Ownership__r.Registration_No__c
			FROM Service_Appointment__c
		];

		SQL_RO_Queue.RepairOrderRes[] res = new SQL_RO_Queue.RepairOrderRes[]{};
		for (Service_Appointment__c sa :sas) {
			SQL_RO_Queue.RepairOrderRes ro = new SQL_RO_Queue.RepairOrderRes();
			ro.companyCode = sa.Company__r.Name; //  so.Company__r.Name;
			ro.branchCode = sa.Workshop__r.Name; // so.Workshop__r.Name;
			ro.wipNo = '12345'; // so.RepairOrderNo__c;
			ro.checkIn = Datetime.now(); //so.CheckIn__c;
			ro.checkOut = null; //so.CheckOut__c;
			ro.techCode = '';
			ro.status = '1'; //so.StatusNumber__c;
			ro.statusText = 'Memo'; //so.Status__c;
			ro.lastUpdate = Datetime.now(); //so.LastModifiedDate;
			ro.custAccNo = String.valueOf(sa.Vehicle_Ownership__r.Customer__r.Customer_Number__c); // String.valueOf(so.Account__r.Customer_Number__c);
			ro.custName = sa.Vehicle_Ownership__r.Customer__r.Name; // so.ContactName__c;
			ro.custDocNo = sa.Vehicle_Ownership__r.Customer__r.NRIC_Number__c; //  so.Account__r.NRIC_Number__c;
			ro.vehChassisNo = sa.Vehicle_Ownership__r.Vehicle__r.Name; // so.ChassisNo__c;
			ro.vehMakeModel = '';
			ro.vehModelCode = '';
			ro.vehRegNo = sa.Vehicle_Ownership__r.Registration_No__c; // so.VehicleOwnership__r.Registration_No__c;
			ro.mileage = 123; //so.Mileage__c;
			ro.wipKey = Datetime.now().format('yyyyMMdd') + ro.wipNo;
			ro.roKey = ro.wipKey + ro.branchCode;
			ro.externalId = String.format('{0}_{1}_{2}_{3}', new string[] { ro.companyCode, ro.branchCode, ro.wipNo, ro.vehChassisNo }); //so.ExternalId__c;
			res.add(ro);
		}
		SQL_RO_Queue job = new SQL_RO_Queue();
		job.upsertRo(res);
		res[0].checkOut = Datetime.now();
		res[0].statusText = 'Not Assigned';

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		job.followOnToSvcInv = false;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPullNoRow() {
		SQL_RO_Queue.RepairOrderRes[] res = new SQL_RO_Queue.RepairOrderRes[]{};
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_RO_Queue job = new SQL_RO_Queue();
		job.followOnToSvcInv = true;
		System.enqueueJob(job);
		job.dateFrom = job.dateTo = null;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPullStatusNotOK() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SQL_RO_Queue job = new SQL_RO_Queue();
        job.followOnToSvcInv = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPull_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SQL_RO_Queue job = new SQL_RO_Queue();
		job.followOnToSvcInv = true;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPull_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_RO_Queue job = new SQL_RO_Queue();
		job.followOnToSvcInv = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPull_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_RO_Queue job = new SQL_RO_Queue();
		job.followOnToSvcInv = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	
	@isTest static void testRefreshRo() {
		Service_Appointment__c sa = [
			SELECT
				Id, Name
				, Company__r.Name, Workshop__r.Name
				, Vehicle_Ownership__r.Customer__r.Name
				, Vehicle_Ownership__r.Customer__r.Customer_Number__c
				, Vehicle_Ownership__r.Customer__r.NRIC_Number__c
				, Vehicle_Ownership__r.Vehicle__r.Name
				, Vehicle_Ownership__r.Registration_No__c
			FROM Service_Appointment__c
			LIMIT 1
		];

		SQL_RO_Queue.RepairOrderRes[] res = new SQL_RO_Queue.RepairOrderRes[]{};
		SQL_RO_Queue.RepairOrderRes ro = new SQL_RO_Queue.RepairOrderRes();
		ro.companyCode = sa.Company__r.Name; //  so.Company__r.Name;
		ro.branchCode = sa.Workshop__r.Name; // so.Workshop__r.Name;
		ro.wipNo = '12345'; // so.RepairOrderNo__c;
		ro.checkIn = Datetime.now(); //so.CheckIn__c;
		ro.checkOut = null; //so.CheckOut__c;
		ro.techCode = '';
		ro.status = '1'; //so.StatusNumber__c;
		ro.statusText = 'Memo'; //so.Status__c;
		ro.lastUpdate = Datetime.now(); //so.LastModifiedDate;
		ro.custAccNo = String.valueOf(sa.Vehicle_Ownership__r.Customer__r.Customer_Number__c); // String.valueOf(so.Account__r.Customer_Number__c);
		ro.custName = sa.Vehicle_Ownership__r.Customer__r.Name; // so.ContactName__c;
		ro.custDocNo = sa.Vehicle_Ownership__r.Customer__r.NRIC_Number__c; //  so.Account__r.NRIC_Number__c;
		ro.vehChassisNo = sa.Vehicle_Ownership__r.Vehicle__r.Name; // so.ChassisNo__c;
		ro.vehMakeModel = '';
		ro.vehModelCode = '';
		ro.vehRegNo = sa.Vehicle_Ownership__r.Registration_No__c; // so.VehicleOwnership__r.Registration_No__c;
		ro.mileage = 123; //so.Mileage__c;
		ro.wipKey = Datetime.now().format('yyyyMMdd') + ro.wipNo;
		ro.roKey = ro.wipKey + ro.branchCode;
		ro.externalId = String.format('{0}_{1}_{2}_{3}', new string[] { ro.companyCode, ro.branchCode, ro.wipNo, ro.vehChassisNo }); //so.ExternalId__c;
		res.add(ro);

		SQL_RO_Queue job = new SQL_RO_Queue();
		job.upsertRo(res);
		res[0].statusText = 'Not Assigned';

		ServiceOrder__c so = [SELECT Id FROM ServiceOrder__c];

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		string ret = SQL_RO_Queue.refreshRo(so.Id);
		Test.stopTest();
		System.assert(!ret.containsIgnoreCase('Error'));
	}
	@isTest static void testRefreshRoByVin() {
		Service_Appointment__c sa = [
			SELECT
				Id, Name
				, Company__r.Name, Workshop__r.Name
				, Vehicle_Ownership__r.Customer__r.Name
				, Vehicle_Ownership__r.Customer__r.Customer_Number__c
				, Vehicle_Ownership__r.Customer__r.NRIC_Number__c
				, Vehicle_Ownership__r.Vehicle__r.Name
				, Vehicle_Ownership__r.Registration_No__c
			FROM Service_Appointment__c
			LIMIT 1
		];

		SQL_RO_Queue.RepairOrderRes[] res = new SQL_RO_Queue.RepairOrderRes[]{};
		SQL_RO_Queue.RepairOrderRes ro = new SQL_RO_Queue.RepairOrderRes();
		ro.companyCode = sa.Company__r.Name; //  so.Company__r.Name;
		ro.branchCode = sa.Workshop__r.Name; // so.Workshop__r.Name;
		ro.wipNo = '12345'; // so.RepairOrderNo__c;
		ro.checkIn = Datetime.now(); //so.CheckIn__c;
		ro.checkOut = null; //so.CheckOut__c;
		ro.techCode = '';
		ro.status = '1'; //so.StatusNumber__c;
		ro.statusText = 'Memo'; //so.Status__c;
		ro.lastUpdate = Datetime.now(); //so.LastModifiedDate;
		ro.custAccNo = String.valueOf(sa.Vehicle_Ownership__r.Customer__r.Customer_Number__c); // String.valueOf(so.Account__r.Customer_Number__c);
		ro.custName = sa.Vehicle_Ownership__r.Customer__r.Name; // so.ContactName__c;
		ro.custDocNo = sa.Vehicle_Ownership__r.Customer__r.NRIC_Number__c; //  so.Account__r.NRIC_Number__c;
		ro.vehChassisNo = sa.Vehicle_Ownership__r.Vehicle__r.Name; // so.ChassisNo__c;
		ro.vehMakeModel = '';
		ro.vehModelCode = '';
		ro.vehRegNo = sa.Vehicle_Ownership__r.Registration_No__c; // so.VehicleOwnership__r.Registration_No__c;
		ro.mileage = 123; //so.Mileage__c;
		ro.wipKey = Datetime.now().format('yyyyMMdd') + ro.wipNo;
		ro.roKey = ro.wipKey + ro.branchCode;
		ro.externalId = String.format('{0}_{1}_{2}_{3}', new string[] { ro.companyCode, ro.branchCode, ro.wipNo, ro.vehChassisNo }); //so.ExternalId__c;
		res.add(ro);

		SQL_RO_Queue job = new SQL_RO_Queue();
		job.upsertRo(res);
		res[0].statusText = 'Not Assigned';

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		string ret = SQL_RO_Queue.refreshRoByVin(res[0].vehChassisNo);
		Test.stopTest();
		System.assert(!ret.containsIgnoreCase('Error'));
	}
}