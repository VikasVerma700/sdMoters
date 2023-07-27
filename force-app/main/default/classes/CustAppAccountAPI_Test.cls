@IsTest
public class CustAppAccountAPI_Test {
	@TestSetup
	static void setup() {
		TestFactory.genApiSetup();
		// TestFactory.genTriggerSettings('Customer App Callback', true);
		TestFactory.genTriggerSettings('Vehicle', true);
		TestFactory.genTriggerSettings('Vehicle Model', true);
		Company__c cmp = TestFactory.getCompany('028');
		cmp.AbAppCompany__c = 'Sime Darby Auto Bavaria';
		update cmp;
		PDPA_Test.makeData();

		Vehicle_Ownership__c vo = TestFactory.genVO(1, true)[0];
		Insurance_Policy__c insP = TestFactory.genInsurancePolicy(1, false)[0];
		insP.Vehicle_Ownership__c = vo.Id;
		insP.Policy_Holder__c = vo.Customer__c;
		insert insP;

		Service_Appointment__c appt = TestFactory.genSvcAppt(1, false)[0];
		appt.Account__c = vo.Customer__c;
		appt.Vehicle_Ownership__c = vo.Id;
		insert appt;
		Set<String> ws = CustAppAppt.ALLOWED_WS.get('028');
		update new Workshop__c(Id = appt.Workshop__c, Name = new List<String>(ws)[0]);
		System.debug([SELECT Id, Company__r.Name, Workshop__r.Name, Account__c FROM Service_Appointment__c WHERE Id = :appt.Id]);

		ServiceOrder__c ro = TestFactory.genRepairOrder(1, false)[0];
		ro.Account__c = vo.Customer__c;
		ro.VehicleOwnership__c = vo.Id;
		ro.Vehicle__c = vo.Vehicle__c;
		ro.Workshop__c = appt.Workshop__c;
		insert ro;
		System.debug([SELECT Id, Company__r.Name, Workshop__r.Name, Service_Order_Date__c, Account__c FROM ServiceOrder__c WHERE Id = :ro.Id]);

		List<Alternative_Driver__c> altDList = TestFactory.genAltDriver(2, false);
		altDList[0].Vehicle_Ownership__c = vo.Id;
		altDList[1].Account__c = vo.Customer__c;
		insert altDList;

		Test_Drive__c td = TestFactory.genTestDrive(1, false)[0];
		update new Opportunity(AccountId = vo.Customer__c, Id = td.Opportunity__c);
		td.Account__c = vo.Customer__c;
		insert td;

		Vehicle_Model__c model = TestFactory.genVehModel(1, false)[0];
		model.Series_Picklist__c = '1er';
		model.Fuel__c = 'Petrol';
		insert model;
		update new Vehicle_Make__c(Id = model.Vehicle_Make__c, Description__c = 'BMW');

		Company__c ppsl = TestFactory.getCompany('05');
		ppsl.AbAppCompany__c = 'Sime Darby Auto Selection Sdn. Bhd.';
		update ppsl;
		Vehicle_Type__c uc = TestFactory.genVehType('UC', false);
		uc.Company__c = ppsl.Id;
		insert uc;

		List<Vehicle__c> vehList = [SELECT Id FROM Vehicle__c];
		for (Vehicle__c v : vehList) {
			v.Vehicle_Model__c = model.Id;
			v.Vehicle_Type__c = uc.Id;
		}
		update vehList;
	}

	@IsTest
	static void testResync() {
		Test_Drive__c td = [SELECT Id, Account__c FROM Test_Drive__c LIMIT 1];
		Customer_External_Account__c extAcc = TestFactory.genCustExtAcc(1, false)[0];
		extAcc.Account__c = td.Account__c;
		insert extAcc;

		/* 1st: Call Moby API for test drive retrieval */
		// Test.setMock(HttpCalloutMock.class, new TestWSMock.MobyApiBase_Mock(200));
		/* 2nd: Call WHIP webhook */
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		String errMsg = CustAppAccountAPI.resyncAccountToApp(td.Account__c);
		System.debug('errMsg: ' + errMsg);
		Test.stopTest();
		// System.assert(String.isBlank(errMsg));
		// check debug logs
	}

	@IsTest
	static void testSync() {
		Account[] acs = [SELECT Id, Name, Default_Email__c, Mobile_Preferred__pc, PersonMobilePhone FROM Account];
		Test_Drive__c td = [SELECT Id, Account__c, Account__r.Mobile_Preferred__pc, Account__r.LastName FROM Test_Drive__c LIMIT 1];
		CustAppAccount.AccountReq req = new CustAppAccount.AccountReq();
		req.company = 'Sime Darby Auto Bavaria';
		req.email = 'test@example.com';
		req.uuid = 'testuuid';
		req.phone = new CustAppAccount.PhoneCls(td.Account__r.Mobile_Preferred__pc);
		req.identity = new CustAppAccount.IdentityCls();
		req.identity.fullName = td.Account__r.LastName;
		req.identity.salutation = 'MR';
		CustAppAccount.AgreementCls pdpa = new CustAppAccount.AgreementCls();
		pdpa.type = 'USER_REGISTRATION';
		pdpa.referenceId = 'PDPA Consent T&C for Existing Customers_V2';
		CustAppAccount.ClauseCls dataClause = new CustAppAccount.ClauseCls('Data Storage Privacy and Policy', 'DATA_CONSENT', true, true);
		CustAppAccount.ClauseCls mktgClause = new CustAppAccount.ClauseCls('Marketing', 'MARKETING', false, false);
		pdpa.clauses = new List<CustAppAccount.ClauseCls>{ dataClause, mktgClause };
		req.agreement = new List<CustAppAccount.AgreementCls>{ pdpa }[0];
		CustAppAccount.DeviceCls device = new CustAppAccount.DeviceCls();
		device.advertisingId = 'abc';
		device.appVersion = '1.0.0';
		device.os = 'test';
		req.devices = new List<CustAppAccount.DeviceCls>{ device };
		RestContext.request = new RestRequest();
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
		RestContext.response = new RestResponse();
		Test.startTest();
		CustAppAccountAPI.CustomerSync sync = CustAppAccountAPI.getAccount();
		Test.stopTest();
		List<Customer_External_Account__c> extAcc = [SELECT Id, Name, Account__c, Account__r.Default_Email__c, Account__r.Mobile_Preferred__pc FROM Customer_External_Account__c WHERE UUID__c = :req.uuid];
		System.debug('acs: ' + JSON.serialize(acs));
		System.debug('req: ' + JSON.serialize(req));
		System.debug('extAcc: ' + JSON.serialize(extAcc));
		System.assert(extAcc.size() > 0);
		System.assertEquals(extAcc[0].Account__c, td.Account__c);
	}

	@IsTest
	static void testInvite() {
		Test_Drive__c td = [SELECT Id, Account__c, Account__r.Default_Email__c FROM Test_Drive__c LIMIT 1];
		List<Vehicle_Ownership__c> voList = [SELECT Id FROM Vehicle_Ownership__c WHERE Customer__c = :td.Account__c];
		CustAppAccountAPI.InviteResp resp = new CustAppAccountAPI.InviteResp();
		resp.httpStatus = 200;
		resp.response = new CustAppAccountAPI.InviteBody();
		resp.response.data = new CustAppAccountAPI.InviteData();
		resp.response.data.account = new CustAppAccountAPI.InviteAcc();
		resp.response.data.account.uuid = 'testuuid';
		resp.response.data.account.email = td.Account__r.Default_Email__c;
		resp.response.data.account.vehicles = new CustAppAccountAPI.InviteVehCnt();
		resp.response.data.account.vehicles.confirmed = voList.size();
		resp.response.data.account.isEmailDispatched = true;
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppInvite(resp));
		Test.startTest();
		CustAppAccountAPI.inviteAcc(new Account(Id = td.Account__c), '028');
		Test.stopTest();
		List<Customer_External_Account__c> extAcc = [SELECT Id, Account__c FROM Customer_External_Account__c WHERE UUID__c = :resp.response.data.account.uuid];
		System.assert(extAcc.size() > 0);
		System.assertEquals(extAcc[0].Account__c, td.Account__c);
	}
}