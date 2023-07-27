@isTest
public class SQL_VO_Queue_Test {

	@TestSetup
	public static void makeData() {
		System.debug('SQL_VO_Queue_Test.makeData()');
		SQL_Veh_Queue_Test.makeData();

		SQL_Veh_Queue.CareVehicleRes[] vehs = SQL_Veh_Queue_Test.createObj();
		SQL_Veh_Queue r = new SQL_Veh_Queue();
		r.upsertVehicle(vehs);
	}

	@isTest
	public static SQL_VO_Queue.CareVehOwnRes[] createObj() {
		SQL_VO_Queue.CareVehOwnRes[] res = new SQL_VO_Queue.CareVehOwnRes[]{};
		SQL_VO_Queue.CareVehOwnRes vo;

		vo = new SQL_VO_Queue.CareVehOwnRes();
		vo.companyCode = '028';
		vo.source = 'Autoline';
		vo.vehOwnId = 75683;
		vo.vehNo = 23167;
		vo.vehChassisNo = 'PM1XG14060DV69340';
		vo.vehRegNo = 'BMW1002';
		vo.isBusiness = false;
		vo.custNo = 73811;
		vo.custDocNo = '590430016065';
		vo.drvNo = 61627;
		vo.drvDocNo = '791219025071';
		vo.voStartDate = Datetime.valueOf('2012-12-10 00:00:00');
		vo.voEndDate = null;
		res.add(vo);

		vo = new SQL_VO_Queue.CareVehOwnRes();
		vo.companyCode = '028';
		vo.source = 'Autoline';
		vo.vehOwnId = 124842;
		vo.vehNo = 98806;
		vo.vehChassisNo = 'WB40C0609KS801449';
		vo.vehRegNo = 'KER79';
		vo.isBusiness = false;
		vo.custNo = 61627;
		vo.custDocNo = '791219025071';
		vo.drvNo = 73811;
		vo.drvDocNo = '590430016065';
		vo.voStartDate = Datetime.valueOf('2021-09-01 00:00:00');
		vo.voEndDate = null;
		res.add(vo);

		vo = new SQL_VO_Queue.CareVehOwnRes();
		vo.companyCode = '028';
		vo.source = 'Autoline';
		vo.vehOwnId = 148903;
		vo.vehNo = 99162;
		vo.vehChassisNo = 'WB10A8107JR927694';
		vo.vehRegNo = 'BQB4744';
		vo.isBusiness = true;
		vo.custNo = 130849;
		vo.custDocNo = 'SA0219503X';
		vo.drvNo = 61627;
		vo.drvDocNo = '791219025071';
		vo.voStartDate = Datetime.valueOf('2019-11-13 00:00:00');
		vo.voEndDate = null;
		res.add(vo);

		vo = new SQL_VO_Queue.CareVehOwnRes();
		vo.companyCode = '028';
		vo.source = 'Autoline';
		vo.vehOwnId = 157225;
		vo.vehNo = 99884;
		vo.vehChassisNo = 'WB10J5406KR933675';
		vo.vehRegNo = 'KEU79';
		vo.isBusiness = false;
		vo.custNo = 61627;
		vo.custDocNo = '791219025071';
		vo.drvNo = null;
		vo.drvDocNo = null;
		vo.voStartDate = Datetime.valueOf('2019-12-18 00:00:00');
		vo.voEndDate = null;
		res.add(vo);

		vo = new SQL_VO_Queue.CareVehOwnRes();
		vo.companyCode = '028';
		vo.source = 'Autoline';
		vo.vehOwnId = 341499;
		vo.vehNo = 182080;
		vo.vehChassisNo = 'PM1JA180X0WG03286';
		vo.vehRegNo = 'VFG980';
		vo.isBusiness = false;
		vo.custNo = 132299;
		vo.custDocNo = '59195T';
		vo.drvNo = 61627;
		vo.drvDocNo = '791219025071';
		vo.voStartDate = Datetime.valueOf('2020-11-20 00:00:00');
		vo.voEndDate = Datetime.valueOf('2022-02-07 00:00:00');
		res.add(vo);

		return res;
	}

	@isTest static void testPull() {
		SQL_VO_Queue.CareVehOwnRes[] res = createObj();
		Integer expected = res.size();
		
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_VO_Queue job = new SQL_VO_Queue();
		job.followOnToAppt = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Vehicle_Ownership__c].size());
	}

	@isTest static void testPullUpdate() {
		SQL_VO_Queue.CareVehOwnRes[] res = createObj();
		Integer expected = res.size();
		
		SQL_VO_Queue q = new SQL_VO_Queue();
		q.upsertVO(res);
		q.upsertAltDrv(res);

		/** Duplicate all Alt D */
		Alternative_Driver__c[] ads = [SELECT Id, Account__c, Vehicle_Ownership__c, Status__c, Relationship_to_Owner__c, Created_From__c FROM Alternative_Driver__c];
		Alternative_Driver__c[] insertAds = new List<Alternative_Driver__c>();
		System.debug(JSON.serialize(ads));
		for (Alternative_Driver__c ad :ads) {
			Alternative_Driver__c newAd = new Alternative_Driver__c();
			newAd.Account__c = ad.Account__c;
			newAd.Vehicle_Ownership__c = ad.Vehicle_Ownership__c;
			newAd.Status__c = ad.Status__c;
			newAd.Relationship_to_Owner__c = ad.Relationship_to_Owner__c;
			newAd.Created_From__c = ad.Created_From__c;
			insertAds.add(newAd);
		}
		System.debug('insertAds: ' + JSON.serialize(insertAds));
		insert insertAds;

		/** remove reg. no. from source to seek reg. no. by Vno (Line: 552) */
		for (SQL_VO_Queue.CareVehOwnRes vo :res) { vo.vehRegNo = ''; }
		/** seek reg. no. by Vin (Line: 555) */
		res[1].vehNo = null;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_VO_Queue job = new SQL_VO_Queue();
		job.followOnToAppt = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();
		System.assertEquals(expected, [SELECT Id FROM Vehicle_Ownership__c].size());
	}

	@isTest static void testPullNoVoNumber() {
		SQL_VO_Queue.CareVehOwnRes[] res = new SQL_VO_Queue.CareVehOwnRes[]{};
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();

		/** Remove VO Number from Data first */
		Vehicle_Ownership__c[] vos = [SELECT Id, VehicleOwnershipNumber__c FROM Vehicle_Ownership__c];
		for (Vehicle_Ownership__c vo :vos) { vo.VehicleOwnershipNumber__c = null; }
		update vos;		

		SQL_VO_Queue job = new SQL_VO_Queue();
		System.enqueueJob(job);
		/** Let's run twice to do more coverage */
		// System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPullNoRow() {
		SQL_VO_Queue.CareVehOwnRes[] res = new SQL_VO_Queue.CareVehOwnRes[]{};
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_VO_Queue job = new SQL_VO_Queue();
		job.followOnToAppt = true;
		System.enqueueJob(job);
		job.dateFrom = job.dateTo = null;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPullStatusNotOK() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SQL_VO_Queue job = new SQL_VO_Queue();
        job.followOnToAppt = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPullRo_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SQL_VO_Queue job = new SQL_VO_Queue();
		job.followOnToAppt = true;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPullRo_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_VO_Queue job = new SQL_VO_Queue();
		job.followOnToAppt = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPullRo_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_VO_Queue job = new SQL_VO_Queue();
		job.followOnToAppt = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testRefreshVo() {
		SQL_VO_Queue.CareVehOwnRes[] res = createObj();
		Integer expected = res.size();
		SQL_VO_Queue q = new SQL_VO_Queue();
		q.upsertVO(res);

		Vehicle_Ownership__c[] vos = [SELECT Id FROM Vehicle_Ownership__c];

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		string ret = SQL_VO_Queue.refreshVO(vos[0].Id);
		Test.stopTest();
		System.assert(!ret.containsIgnoreCase('Error'));
	}

	@isTest static void testRefreshVoByVin() {
		SQL_VO_Queue.CareVehOwnRes[] res = createObj();
		Integer expected = res.size();
		SQL_VO_Queue q = new SQL_VO_Queue();
		q.upsertVO(res);

		Vehicle_Ownership__c[] vos = [SELECT Id, Chassis_No__c FROM Vehicle_Ownership__c];

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		string ret = SQL_VO_Queue.refreshVoByVin(vos[0].Chassis_No__c);
		Test.stopTest();
		System.assert(!ret.containsIgnoreCase('Error'));
	}

}