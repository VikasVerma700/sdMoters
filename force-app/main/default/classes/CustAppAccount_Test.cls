@IsTest
public class CustAppAccount_Test {
	@TestSetup
	public static void setup() {
		TestFactory.genApiSetup();
		TestFactory.genTriggerSettings('Customer App Callback', true);
		TestFactory.genCustExtAcc(1, true);
		Company__c cmp = TestFactory.getCompany('028');
		cmp.AbAppCompany__c = 'Sime Darby Auto Bavaria';
		update cmp;
		PDPA_Test.makeData();
	}

	@IsTest
	public static void testSendWebhook() {
		Customer_External_Account__c extAcc = [SELECT Id, Account__c FROM Customer_External_Account__c LIMIT 1];
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = extAcc.Account__c);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppAccount.sendWebHook(callback);
		Test.stopTest();
		// refer to debug logs if there are any errors, no return value
	}

	@IsTest
	public static void testGetAccount() {
		Customer_External_Account__c extAcc = [SELECT Id, Account__c FROM Customer_External_Account__c LIMIT 1];
		Test.startTest();
		List<Customer_External_Account__c> extAccTest = CustAppAccount.getExtAccounts(extAcc.Account__c, CustAppAccount.REV_TYPE.keySet());
		Test.stopTest();
		System.assertEquals(extAccTest.size(), 1);
		System.assertEquals(extAccTest[0].Id, extAcc.Id);
	}

	@IsTest
	public static void testGetQR() {
		Account acc = [SELECT Id FROM Account LIMIT 1];
		Test.startTest();
		String qrStr = CustAppAccount.getAccQR(acc.Id, '028');
		Test.stopTest();
		System.assert(qrStr.startsWith(ServiceApptBooking.QR_SRC));
	}

	@isTest
	public static void testPushToAbApp() {
		Account ac = [SELECT Id FROM Account LIMIT 1];
		Test.startTest();
		CustAppAccount.pushToAbApp(ac.Id);
		Test.stopTest();
	}
	@IsTest
	public static void testProcessCallbackMatch() {
		RestContext.request = new RestRequest();
		Account acc = [SELECT Id, Mobile_Country_Code_1__pc, Mobile_Preferred__pc, Salutation, LastName FROM Account LIMIT 1];
		acc.Verified_with_NRIC__c = true;
		update acc;
		CustAppAccount.AccountCallback req = new CustAppAccount.AccountCallback();
		req.event = CustAppAccount.EVENT_NAME;
		req.payload = new CustAppAccount.AccountReq();
		req.payload.company = 'Sime Darby Auto Bavaria';
		req.payload.email = 'test@example.com';
		req.payload.uuid = 'testuuid';
		req.payload.phone = new CustAppAccount.PhoneCls(acc.Mobile_Preferred__pc);
		req.payload.identity = new CustAppAccount.IdentityCls();
		req.payload.identity.fullName = acc.LastName + 'abc';
		req.payload.identity.salutation = 'MR';
		CustAppAccount.AgreementCls pdpa = new CustAppAccount.AgreementCls();
		pdpa.type = 'USER_REGISTRATION';
		pdpa.referenceId = 'PDPA Consent T&C for Existing Customers_V2';
		CustAppAccount.ClauseCls dataClause = new CustAppAccount.ClauseCls('Data Storage Privacy and Policy', 'DATA_CONSENT', true, true);
		CustAppAccount.ClauseCls mktgClause = new CustAppAccount.ClauseCls('Marketing', 'MARKETING', false, false);
		pdpa.clauses = new List<CustAppAccount.ClauseCls>{ dataClause, mktgClause };
		req.payload.agreement = new List<CustAppAccount.AgreementCls>{ pdpa }[0];
		CustAppAccount.DeviceCls device = new CustAppAccount.DeviceCls();
		device.advertisingId = 'abc';
		device.appVersion = '1.0.0';
		device.os = 'test';
		req.payload.devices = new List<CustAppAccount.DeviceCls>{ device };
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
		Test.startTest();
		CustAppAccount.processCallback();
		Test.stopTest();
		List<Customer_External_Account__c> extAcc = [SELECT Id, Account__c, Name__c, Account__r.Default_Email__c FROM Customer_External_Account__c WHERE
													UUID__c = :req.payload.uuid];
		System.assert(extAcc.size() > 0);
		System.assertEquals(extAcc[0].Account__c, acc.Id);
		System.assertEquals(extAcc[0].Account__r.Default_Email__c, req.payload.email);
		System.assertEquals(extAcc[0].Name__c, req.payload.identity.fullName);
		List<Local_Legislation__c> leg = [SELECT Id FROM Local_Legislation__c WHERE Account_Name__c = :acc.Id];
		System.assert(leg.size() > 0);
		List<User_Message_Token__c> deviceToken = [SELECT Id FROM User_Message_Token__c WHERE Account__c = :acc.Id];
		System.assert(deviceToken.size() > 0);
	}

	@IsTest
	public static void testProcessCallback() {
		RestContext.request = new RestRequest();
		CustAppAccount.AccountCallback req = new CustAppAccount.AccountCallback();
		req.event = CustAppAccount.EVENT_NAME;
		req.payload = new CustAppAccount.AccountReq();
		req.payload.company = 'Sime Darby Auto Bavaria';
		req.payload.email = 'test@example.com';
		req.payload.uuid = 'testuuid';
		req.payload.phone = new CustAppAccount.PhoneCls('91234567');
		req.payload.identity = new CustAppAccount.IdentityCls();
		req.payload.identity.fullName = 'Test test';
		req.payload.identity.salutation = 'MS';
		req.payload.document = new CustAppAccount.DocCls();
		req.payload.document.id = '123A';
		req.payload.document.type = 'FOREIGN_PASSPORT';
		CustAppAccount.AgreementCls pdpa = new CustAppAccount.AgreementCls();
		pdpa.type = 'USER_REGISTRATION';
		pdpa.referenceId = 'PDPA Consent T&C for Existing Customers_V2';
		CustAppAccount.ClauseCls dataClause = new CustAppAccount.ClauseCls('Data Storage Privacy and Policy', 'DATA_CONSENT', true, true);
		CustAppAccount.ClauseCls mktgClause = new CustAppAccount.ClauseCls('Marketing', 'MARKETING', false, false);
		pdpa.clauses = new List<CustAppAccount.ClauseCls>{ dataClause, mktgClause };
		req.payload.agreement = new List<CustAppAccount.AgreementCls>{ pdpa }[0];
		CustAppAccount.DeviceCls device = new CustAppAccount.DeviceCls();
		device.advertisingId = 'abc';
		device.appVersion = '1.0.0';
		device.os = 'test';
		req.payload.devices = new List<CustAppAccount.DeviceCls>{ device };
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
		User apiUser = [SELECT Id FROM User WHERE Alias = 'fireapi' AND IsActive = TRUE LIMIT 1];
		Test.startTest();
		System.runAs(apiUser) {
			CustAppAccount.processCallback();
		}
		String docType = CustAppAccount.mapDocType(req.payload.document.type);
		Test.stopTest();
		List<Customer_External_Account__c> extAcc = [SELECT Id, Account__c, Account__r.Default_Email__c, Account__r.Doc_Type__c FROM
													Customer_External_Account__c WHERE UUID__c = :req.payload.uuid];
		System.assert(extAcc.size() > 0);
		System.assertEquals(extAcc[0].Account__r.Default_Email__c, req.payload.email);
		System.assertEquals(extAcc[0].Account__r.Doc_Type__c, docType);
		List<Local_Legislation__c> leg = [SELECT Id FROM Local_Legislation__c WHERE Account_Name__c = :extAcc[0].Account__c];
		System.assert(leg.size() > 0);
		List<User_Message_Token__c> deviceToken = [SELECT Id FROM User_Message_Token__c WHERE Account__c = :extAcc[0].Account__c];
		System.assert(deviceToken.size() > 0);
	}

	@IsTest
	public static void testProcessV1Callback() {
		RestContext.request = new RestRequest();
		CustAppAccount.AccountV1Callback req = new CustAppAccount.AccountV1Callback();
		req.event = CustAppAccount.EVENT_NAME;
		req.payload = new CustAppAccount.AccountV1Req();
		req.payload.company = 'Sime Darby Auto Bavaria';
		req.payload.email = 'test@example.com';
		req.payload.uuid = 'testuuid';
		req.payload.phone = new CustAppAccount.PhoneCls('91234567');
		req.payload.identity = new CustAppAccount.IdentityCls();
		req.payload.identity.fullName = 'Test test';
		req.payload.identity.salutation = 'DATO';
		req.payload.document = new CustAppAccount.DocCls();
		req.payload.document.id = '123A';
		req.payload.document.type = 'MALAYSIA_NRIC';
		CustAppAccount.AgreementClsV1 pdpa = new CustAppAccount.AgreementClsV1();
		pdpa.type = 'USER_REGISTRATION';
		pdpa.referenceId = 'PDPA Consent T&C for Existing Customers_V2';
		CustAppAccount.ClauseV1Cls dataClause = new CustAppAccount.ClauseV1Cls('DATA_CONSENT', true, true);
		CustAppAccount.ClauseV1Cls mktgClause = new CustAppAccount.ClauseV1Cls('MARKETING', false, false);
		pdpa.clauses = new List<CustAppAccount.ClauseV1Cls>{ dataClause, mktgClause };
		req.payload.agreements = new List<CustAppAccount.AgreementClsV1>{ pdpa };
		CustAppAccount.DeviceCls device = new CustAppAccount.DeviceCls();
		device.advertisingId = 'abc';
		device.appVersion = '1.0.0';
		device.os = 'test';
		req.payload.devices = new List<CustAppAccount.DeviceCls>{ device };
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
		User apiUser = [SELECT Id FROM User WHERE Alias = 'fireapi' AND IsActive = TRUE LIMIT 1];
		Test.startTest();
		System.runAs(apiUser) {
			CustAppAccount.processV1Callback();
		}
		String docType = CustAppAccount.mapDocType(req.payload.document.type);
		Test.stopTest();
		List<Customer_External_Account__c> extAcc = [SELECT Id, Account__c, Account__r.Default_Email__c, Account__r.Doc_Type__c FROM
													Customer_External_Account__c WHERE UUID__c = :req.payload.uuid];
		System.assert(extAcc.size() > 0);
		System.assertEquals(extAcc[0].Account__r.Default_Email__c, req.payload.email);
		System.assertEquals(extAcc[0].Account__r.Doc_Type__c, docType);
		List<Local_Legislation__c> leg = [SELECT Id FROM Local_Legislation__c WHERE Account_Name__c = :extAcc[0].Account__c];
		System.assert(leg.size() > 0);
		List<User_Message_Token__c> deviceToken = [SELECT Id FROM User_Message_Token__c WHERE Account__c = :extAcc[0].Account__c];
		System.assert(deviceToken.size() > 0);
	}

	// @IsTest
	// public static void testProcessCallback3() {
	// 	Account ac = [SELECT Id, Name, Mobile_Preferred__pc FROM Account LIMIT 1];
	// 	RestContext.request = new RestRequest();
	// 	CustAppAccount.AccountCallback req = new CustAppAccount.AccountCallback();
	// 	req.event = CustAppAccount.EVENT_NAME;
	// 	req.payload = new CustAppAccount.AccountReq();
	// 	req.payload.company = 'Sime Darby Auto Bavaria';
	// 	req.payload.email = 'test@example.com';
	// 	req.payload.uuid = 'testuuid';
	// 	req.payload.phone = new CustAppAccount.PhoneCls(ac.Mobile_Preferred__pc);
	// 	req.payload.identity = new CustAppAccount.IdentityCls();
	// 	req.payload.identity.fullName = 'Test test';
	// 	req.payload.identity.salutation = 'DATO';
	// 	req.payload.document = new CustAppAccount.DocCls();
	// 	req.payload.document.id = '123A';
	// 	req.payload.document.type = 'BUSINESS';
	// 	CustAppAccount.AgreementCls pdpa = new CustAppAccount.AgreementCls();
	// 	pdpa.type = 'USER_REGISTRATION';
	// 	pdpa.referenceId = 'PDPA Consent T&C for Existing Customers_V2';
	// 	CustAppAccount.ClauseCls dataClause = new CustAppAccount.ClauseCls('DATA_CONSENT', true, true);
	// 	CustAppAccount.ClauseCls mktgClause = new CustAppAccount.ClauseCls('MARKETING', false, false);
	// 	pdpa.clauses = new List<CustAppAccount.ClauseCls>{ dataClause, mktgClause };
	// 	req.payload.agreements = new List<CustAppAccount.AgreementCls>{ pdpa };
	// 	CustAppAccount.DeviceCls device = new CustAppAccount.DeviceCls();
	// 	device.advertisingId = 'abc';
	// 	device.appVersion = '1.0.0';
	// 	device.os = 'test';
	// 	req.payload.devices = new List<CustAppAccount.DeviceCls>{ device };
	// 	RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
	// 	User apiUser = [SELECT Id FROM User WHERE Alias = 'fireapi' AND IsActive = TRUE LIMIT 1];
	// 	Test.startTest();
	// 	System.runAs(apiUser) {
	// 		CustAppAccount.processCallback();
	// 	}
	// 	String docType = CustAppAccount.mapDocType(req.payload.document.type);
	// 	Test.stopTest();
	// 	List<Customer_External_Account__c> extAcc = [SELECT Id, Account__c, Account__r.Default_Email__c, Account__r.Doc_Type__c FROM
	// 												Customer_External_Account__c WHERE UUID__c = :req.payload.uuid];
	// 	System.assert(extAcc.size() > 0);
	// 	System.assertEquals(extAcc[0].Account__r.Default_Email__c, req.payload.email);
	// 	System.assertEquals(extAcc[0].Account__r.Doc_Type__c, docType);
	// 	List<Local_Legislation__c> leg = [SELECT Id FROM Local_Legislation__c WHERE Account_Name__c = :extAcc[0].Account__c];
	// 	System.assert(leg.size() > 0);
	// 	List<User_Message_Token__c> deviceToken = [SELECT Id FROM User_Message_Token__c WHERE Account__c = :extAcc[0].Account__c];
	// 	System.assert(deviceToken.size() > 0);
	// }
}