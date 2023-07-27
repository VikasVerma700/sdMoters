@IsTest
public class MOBY_API_TestDrive_Test {

	@TestSetup
	public static void makeData() {
		MOBY_API_Base_Test.makeData();
		Customer_External_Account__c extAcc = TestFactory.genCustExtAcc(1, true)[0];
	}

	@IsTest
	public static void testProcessCallback() {
		Customer_External_Account__c cea = [SELECT Id, Name, UUID__c FROM Customer_External_Account__c LIMIT 1];
		CustAppTD.TDReqCallback tdrc = new CustAppTD.TDReqCallback();
		tdrc.event = 'SEND_TEST_DRIVE_REQUEST';
		tdrc.payload = new CustAppTD.TDReqPayload();
		CustAppTD.TDRequest tdr = new CustAppTD.TDRequest();
		tdr.selectedSlots = new List<DateTime>{ Datetime.now() };
		tdr.companyId = '028';
		tdr.referenceNumber = 'ref';
		tdr.type = 'type';
		tdr.accountUuid = cea.UUID__c;
		tdr.answers = new List<CustAppTD.AnsCls>();
		tdr.location = new CustAppLocation.LocationCls('No1', 'B1', 'address', 0.00, 1.00);
		tdr.branch = new CustAppLocation.BranchCls();
		tdr.remark = 'remark';
		tdr.unit = new CustAppTD.ModelReqCls();
		tdrc.payload.testDrive = tdr;

		Test.setMock(HttpCalloutMock.class, new TestWSMock.MOBY_API_Mock(200));
		Test.startTest();

		RestRequest req = new RestRequest();
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(JSON.serialize(tdrc));
		RestContext.request = req;

		MOBY_API_TestDrive.processCallback();

		Test.stopTest();
	}

	@IsTest
	public static void testProcessCallbackUuidNotFound() {
		Customer_External_Account__c cea = [SELECT Id, Name, UUID__c FROM Customer_External_Account__c LIMIT 1];
		CustAppTD.TDReqCallback tdrc = new CustAppTD.TDReqCallback();
		tdrc.event = 'SEND_TEST_DRIVE_REQUEST';
		tdrc.payload = new CustAppTD.TDReqPayload();
		CustAppTD.TDRequest tdr = new CustAppTD.TDRequest();
		tdr.selectedSlots = new List<DateTime>{ Datetime.now() };
		tdr.companyId = '028';
		tdr.referenceNumber = 'ref';
		tdr.type = 'type';
		tdr.accountUuid = cea.UUID__c + '1';
		CustAppTD.AnsCls qna = new CustAppTD.AnsCls();
		qna.question = 'q'; qna.answer = 'a';
		tdr.answers = new List<CustAppTD.AnsCls>{ qna };
		tdr.location = new CustAppLocation.LocationCls('No1', 'B1', 'address', 0.00, 1.00);
		tdr.branch = new CustAppLocation.BranchCls();
		tdr.remark = 'remark';
		tdr.unit = new CustAppTD.ModelReqCls();
		tdrc.payload.testDrive = tdr;

		Test.setMock(HttpCalloutMock.class, new TestWSMock.MOBY_API_Mock(400));
		Test.startTest();

		RestRequest req = new RestRequest();
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(JSON.serialize(tdrc));
		RestContext.request = req;
		
		System.Exception ee;
		try { MOBY_API_TestDrive.processCallback(); }
		catch (Exception e) { ee = e; }
		Test.stopTest();
		System.AssertNotEquals(null, ee, 'Exception not raised.');
	}

	@IsTest
	public static void testSendwebhook() {
		MOBY_API_TestDrive.TDReqCallback tdrc = new MOBY_API_TestDrive.TDReqCallback();
		tdrc.event = 'RETURN_TEST_DRIVE_REQUEST';
		MOBY_API_TestDrive.MobyTestDrive mtd = new MOBY_API_TestDrive.MobyTestDrive();
		mtd.Id = 'id';
		mtd.ReferenceNumber = 'ref';
		mtd.Company = '028';
		MOBY_API_TestDrive.MobySalesperson sa = new MOBY_API_TestDrive.MobySalesperson();
		sa.Fullname = 'salesperson fullname';
		sa.MobileNo = '+60123456789';
		sa.Email = 'sales@email.com';
		mtd.SalesAdvisor = sa;
		MOBY_API_TestDrive.MobyVehicle ve = new MOBY_API_TestDrive.MobyVehicle();
		ve.TradePlate = 'tradeplate';
		ve.PlateNo = 'plateno';
		ve.ChassisNo = 'chassisno';
		ve.InVehicleUnit = 'ivu';
		ve.Make = 'make';
		ve.Model = 'model';
		ve.Variant = 'variant';
		ve.Display = 'display';
		ve.BodyStyle = 'bodystyle';
		ve.ExteriorColour = 'ext color';
		ve.InteriorColour = 'int color';
		mtd.Vehicle = ve;
		mtd.Location = new MOBY_API_TestDrive.MobyLocationRequest('No1', 'B1', 'address', 0, 1);
		mtd.PlannedStart = mtd.PlannedEnd = Datetime.now();
		mtd.ActualStart = mtd.ActualEnd = Datetime.now();
		MOBY_API_TestDrive.MobyFile file = new MOBY_API_TestDrive.MobyFile();
		file.ContentType = 'content';
		file.Name = 'name';
		file.Url = 'url';
		mtd.Documents = new List<MOBY_API_TestDrive.MobyFile>{ file };
		mtd.status = 'NEW';
		mtd.Type = 'type';
		mtd.AccountId = 'accId';
		mtd.AccountUuid = 'uuid';
		tdrc.payload = mtd;

		Test.setMock(HttpCalloutMock.class, new TestWSMock.MOBY_API_Mock(200));
		Test.startTest();

		RestRequest req = new RestRequest();
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(JSON.serialize(tdrc));
		RestContext.request = req;

		MOBY_API_TestDrive.sendWebhook();

		Test.stopTest();
	}

	@IsTest
	public static void testRetrieveTD() {
		Customer_External_Account__c cea = [SELECT Id, Name, UUID__c FROM Customer_External_Account__c LIMIT 1];
		
		Test.setMock(HttpCalloutMock.class, new TestWSMock.MOBY_API_Mock(200));
		Test.startTest();
		MOBY_API_TestDrive.retrieveTD(cea.UUID__c, '028');
		Test.stopTest();
	}
}