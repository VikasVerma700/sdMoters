@IsTest public with sharing class MobyApiTestDrive_Test {

	@TestSetup static void makeData(){
		MobyApiBase_Test.makeData();
		Account ac = TestFactory.genAccount(1, true)[0];
		Customer_External_Account__c extAcc = TestFactory.genCustExtAcc(1, false)[0];
		extAcc.Account__c = ac.Id;
		insert extAcc;
	}

/** Test MobyApiTestDrive.processWhipCallback() */
	@IsTest public static void testProcessWhipCallbackLocation() {
		Customer_External_Account__c cea = [SELECT Id, Name, UUID__c FROM Customer_External_Account__c LIMIT 1];
		CustAppTD.TDReqCallback tdrc = new CustAppTD.TDReqCallback();
		tdrc.event = 'SEND_TEST_DRIVE_REQUEST';
		tdrc.payload = new CustAppTD.TDReqPayload();
		CustAppTD.TDRequest tdr = new CustAppTD.TDRequest();
		tdr.selectedSlots = new List<DateTime>{ Datetime.now() };
		tdr.companyId = '028';
		tdr.referenceNumber = 'ref';
		tdr.type = 'LOCATION';
		tdr.accountUuid = cea.UUID__c;
		tdr.answers = new List<CustAppTD.AnsCls>();
		tdr.location = new CustAppLocation.LocationCls('No1', 'B1', 'address', 0.00, 1.00);
		tdr.branch = new CustAppLocation.BranchCls();
		tdr.remark = 'remark';
		tdr.unit = new CustAppTD.ModelReqCls();
		tdrc.payload.testDrive = tdr;

		Test.setMock(HttpCalloutMock.class, new TestWSMock.MobyApiBase_Mock(200));
		Test.startTest();

		RestRequest req = new RestRequest();
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(JSON.serialize(tdrc));
		RestContext.request = req;

		MobyApiTestDrive.processWhipCallback();

		Test.stopTest();
	}
	@IsTest public static void testProcessWhipCallbackShowroom() {
		Customer_External_Account__c cea = [SELECT Id, Name, UUID__c FROM Customer_External_Account__c LIMIT 1];
		CustAppTD.TDReqCallback tdrc = new CustAppTD.TDReqCallback();
		tdrc.event = 'SEND_TEST_DRIVE_REQUEST';
		tdrc.payload = new CustAppTD.TDReqPayload();
		CustAppTD.TDRequest tdr = new CustAppTD.TDRequest();
		tdr.selectedSlots = new List<DateTime>{ Datetime.now() };
		tdr.companyId = '028';
		tdr.referenceNumber = 'ref';
		tdr.type = 'SHOW_ROOM';
		tdr.accountUuid = cea.UUID__c;
		tdr.answers = new List<CustAppTD.AnsCls>();
		tdr.location = new CustAppLocation.LocationCls('No1', 'B1', 'address', 0.00, 1.00);
		tdr.branch = new CustAppLocation.BranchCls();
		tdr.remark = 'remark';
		tdr.unit = new CustAppTD.ModelReqCls();
		tdrc.payload.testDrive = tdr;

		Test.setMock(HttpCalloutMock.class, new TestWSMock.MobyApiBase_Mock(200));
		Test.startTest();

		RestRequest req = new RestRequest();
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(JSON.serialize(tdrc));
		RestContext.request = req;

		MobyApiTestDrive.processWhipCallback();

		Test.stopTest();
	}
	@IsTest public static void testProcessWhipCallbackEmptyPayload() {
		CustAppTD.TDReqCallback tdrc = new CustAppTD.TDReqCallback();
		tdrc.event = 'SEND_TEST_DRIVE_REQUEST';
		tdrc.payload = new CustAppTD.TDReqPayload();

		Test.setMock(HttpCalloutMock.class, new TestWSMock.MobyApiBase_Mock(200));
		Test.startTest();

		RestRequest req = new RestRequest();
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(JSON.serialize(tdrc));
		RestContext.request = req;

		try { MobyApiTestDrive.processWhipCallback(); }
		catch (Exception e) { System.assertEquals('Empty payload.', e.getMessage()); }

		Test.stopTest();
	}
	@IsTest public static void testProcessWhipCallbackUuidNotFound() {
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

		Test.setMock(HttpCalloutMock.class, new TestWSMock.MobyApiBase_Mock(400));
		Test.startTest();

		RestRequest req = new RestRequest();
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(JSON.serialize(tdrc));
		RestContext.request = req;
		
		System.Exception ee;
		try { MobyApiTestDrive.processWhipCallback(); }
		catch (Exception e) { ee = e; }
		Test.stopTest();
		System.AssertNotEquals(null, ee, 'Exception not raised.');
	}
	@IsTest public static void testProcessWhipCallbackStatus400() {
		Customer_External_Account__c cea = [SELECT Id, Name, UUID__c FROM Customer_External_Account__c LIMIT 1];
		CustAppTD.TDReqCallback tdrc = new CustAppTD.TDReqCallback();
		tdrc.event = 'SEND_TEST_DRIVE_REQUEST';
		tdrc.payload = new CustAppTD.TDReqPayload();
		CustAppTD.TDRequest tdr = new CustAppTD.TDRequest();
		tdr.selectedSlots = new List<DateTime>{ Datetime.now() };
		tdr.companyId = '028';
		tdr.referenceNumber = 'ref';
		tdr.type = 'SHOW_ROOM';
		tdr.accountUuid = cea.UUID__c;
		tdr.answers = new List<CustAppTD.AnsCls>();
		tdr.location = new CustAppLocation.LocationCls('No1', 'B1', 'address', 0.00, 1.00);
		tdr.branch = new CustAppLocation.BranchCls();
		tdr.remark = 'remark';
		tdr.unit = new CustAppTD.ModelReqCls();
		tdrc.payload.testDrive = tdr;

		Map<string, integer> mapping = new Map<string, integer>{
			'Testapi/v1.0/lead/set' => 400
		};
		Test.setMock(HttpCalloutMock.class, new TestWSMock.MobyApiBase_Mock(mapping));
		Test.startTest();

		RestRequest req = new RestRequest();
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(JSON.serialize(tdrc));
		RestContext.request = req;
		// RestResponse res = RestContext.Response();

		try { MobyApiTestDrive.processWhipCallback(); }
		catch (Exception e) { System.assert(e.getMessage().contains('Moby: Test Drive request failure.')); }

		Test.stopTest();
	}

/** Test MobyApiTestDrive.processMobyCallback() */
	@IsTest public static void testProcessMobyCallback() {
		string event = 'UPSERT_TEST_DRIVE';
		CustAppTD.TDPayload payload = new CustAppTD.TDPayload();
		payload.testDrive = new CustAppTD.TDSync();
		CustAppTD.TDWebhook hook = new CustAppTD.TDWebhook(event, payload);

		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();

		RestRequest req = new RestRequest();
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(JSON.serialize(hook));
		RestContext.request = req;
		MobyApiTestDrive.processMobyCallback();

		Test.stopTest();
	}
	@IsTest public static void testProcessMobyCallbackEmptyPayload() {
		string event = 'UPSERT_TEST_DRIVE';
		CustAppTD.TDPayload payload;
		CustAppTD.TDWebhook hook = new CustAppTD.TDWebhook(event, payload);

		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();

		RestRequest req = new RestRequest();
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(JSON.serialize(hook));
		RestContext.request = req;

		try { MobyApiTestDrive.processMobyCallback(); }
		catch (Exception e) { System.assert(e.getMessage().contains('Empty payload.')); }
		Test.stopTest();
	}

	// @IsTest public static void testSendwebhook() {
	// 	MobyApiTestDrive.TDReqCallback tdrc = new MobyApiTestDrive.TDReqCallback();
	// 	tdrc.event = 'RETURN_TEST_DRIVE_REQUEST';
	// 	MobyApiTestDrive.MobyTestDrive mtd = new MobyApiTestDrive.MobyTestDrive();
	// 	mtd.Id = 'id';
	// 	mtd.ReferenceNumber = 'ref';
	// 	mtd.Company = '028';
	// 	MobyApiTestDrive.MobySalesperson sa = new MobyApiTestDrive.MobySalesperson();
	// 	sa.Fullname = 'salesperson fullname';
	// 	sa.MobileNo = '+60123456789';
	// 	sa.Email = 'sales@email.com';
	// 	mtd.SalesAdvisor = sa;
	// 	MobyApiTestDrive.MobyVehicle ve = new MobyApiTestDrive.MobyVehicle();
	// 	ve.TradePlate = 'tradeplate';
	// 	ve.PlateNo = 'plateno';
	// 	ve.ChassisNo = 'chassisno';
	// 	ve.InVehicleUnit = 'ivu';
	// 	ve.Make = 'make';
	// 	ve.Model = 'model';
	// 	ve.Variant = 'variant';
	// 	ve.Display = 'display';
	// 	ve.BodyStyle = 'bodystyle';
	// 	ve.ExteriorColour = 'ext color';
	// 	ve.InteriorColour = 'int color';
	// 	mtd.Vehicle = ve;
	// 	mtd.Location = new MobyApiTestDrive.MobyLocationRequest('No1', 'B1', 'address', 0, 1);
	// 	mtd.PlannedStart = mtd.PlannedEnd = Datetime.now();
	// 	mtd.ActualStart = mtd.ActualEnd = Datetime.now();
	// 	MobyApiTestDrive.MobyFile file = new MobyApiTestDrive.MobyFile();
	// 	file.ContentType = 'content';
	// 	file.Name = 'name';
	// 	file.Url = 'url';
	// 	mtd.Documents = new List<MobyApiTestDrive.MobyFile>{ file };
	// 	mtd.status = 'NEW';
	// 	mtd.Type = 'type';
	// 	mtd.AccountId = 'accId';
	// 	mtd.AccountUuid = 'uuid';
	// 	tdrc.payload = mtd;

	// 	Test.setMock(HttpCalloutMock.class, new TestWSMock.MobyApiBase_Mock(200));
	// 	Test.startTest();

	// 	RestRequest req = new RestRequest();
	// 	req.httpMethod = 'POST';
	// 	req.requestBody = Blob.valueOf(JSON.serialize(tdrc));
	// 	RestContext.request = req;

	// 	MobyApiTestDrive.sendWebhook();

	// 	Test.stopTest();
	// }

	// @IsTest public static void testRetrieveTD() {
	// 	Customer_External_Account__c cea = [SELECT Id, Name, UUID__c FROM Customer_External_Account__c LIMIT 1];
		
	// 	Test.setMock(HttpCalloutMock.class, new TestWSMock.MobyApiBase_Mock(200));
	// 	Test.startTest();
	// 	MobyApiTestDrive.retrieveTD(cea.UUID__c, '028');
	// 	Test.stopTest();
	// }

/** Test MobyApiTestDrive.retrieveTD() */
	@IsTest public static void testRetrieveTD() {
		Customer_External_Account__c cae = [SELECT Id, UUID__c FROM Customer_External_Account__c LIMIT 1];

		Test.setMock(HttpCalloutMock.class, new TestWSMock.MobyApiBase_Mock(200));
		Test.startTest();
		CustAppTD.TDSync[] tds = MobyApiTestDrive.retrieveTD(cae.UUID__c, '028');
		Test.stopTest();
	}
	@IsTest public static void testRetrieveTD_E() {
		Customer_External_Account__c cae = [SELECT Id, UUID__c FROM Customer_External_Account__c LIMIT 1];

		Test.setMock(HttpCalloutMock.class, new TestWSMock.MobyApiBase_Mock(400));
		Test.startTest();
		try { CustAppTD.TDSync[] tds = MobyApiTestDrive.retrieveTD(cae.UUID__c, '028'); }
		catch (Exception e) {}
		Test.stopTest();
	}
}