@isTest
public class CareLogin_Test {
	@TestSetup
	public static void setup() {
		List<Global_Trigger_Settings__c> trigList = new List<Global_Trigger_Settings__c>();
		Global_Trigger_Settings__c vehTrig = TestFactory.genTriggerSettings('Vehicle', false);
		vehTrig.Activated__c = false;
		trigList.add(vehTrig);
		trigList.add(TestFactory.genTriggerSettings('Vehicle Ownership', false));
		Global_Trigger_Settings__c accTrig = TestFactory.genTriggerSettings('Account', false);
		accTrig.Activated__c = false;
		trigList.add(accTrig);
		// Global_Trigger_Settings__c gdmsTrig = TestFactory.genTriggerSettings('GDMS Account Number', false);
		// gdmsTrig.Activated__c = false;
		// trigList.add(gdmsTrig);
		// trigList.add(TestFactory.genTriggerSettings('Vehicle Ownership_Link Vehicle Stock', false));
		Global_Trigger_Settings__c svcTrig = TestFactory.genTriggerSettings('Service Order', false);
		svcTrig.Activated__c = false;
		trigList.add(svcTrig);
		insert trigList;
		Test.startTest();
		Company__c ab = TestFactory.getCompany('028');
		Vehicle_Make__c vMake = TestFactory.genVehMake('B', true);
		List<Vehicle__c> vehList = TestFactory.genVehicle(2, false);
		for (Vehicle__c veh : vehList) {
			veh.Vehicle_Make__c = vMake.Id;
		}
		insert vehList;
		List<Account> accList = TestFactory.genAccount(1, true);

		List<Vehicle_Ownership__c> voList = TestFactory.genVO(2, false);
		voList[0].Customer__c = accList[0].Id;
		voList[0].Vehicle_Make__c = vMake.Id;
		voList[0].Vehicle__c = vehList[0].Id;
		voList[1].Customer__c = accList[0].Id;
		voList[1].Vehicle__c = vehList[1].Id;
		voList[1].Vehicle_Make__c = vMake.Id;

		insert voList;

		Service_Appointment__c sa = TestFactory.genSvcAppt(1, false)[0];
		sa.Vehicle_Ownership__c = voList[0].Id;
		sa.Account__c = accList[0].Id;
		update (new Workshop__c(Id = sa.Workshop__c, Service_Centre_Name__c = 'Test', Allow_Appt_External__c = true));

		insert sa;

		Account_Profile_with_Business_Unit__c apbu = TestFactory.genAPBU(1, false)[0];
		apbu.Account_Name__c = accList[0].Id;
		apbu.Category__c = 'Aftersales Related Matters';
		apbu.Account_Status__c = new List<String>(CareLogin.VIP_Status)[0];
		apbu.Company__c = ab.Id;
		insert apbu;
		Test.stopTest();

		/** M3 Tech WS setup */
		M3TechApiWrapper_Test.setup();
	}

	@IsTest
	public static void test2FAReg() {
		RestContext.response = new RestResponse();
		Account_Profile_with_Business_Unit__c apbu = [SELECT Id, Account_Name__c FROM Account_Profile_with_Business_Unit__c LIMIT 1];
		Vehicle_Ownership__c loginVO = [SELECT Id, Customer__r.Mobile_Country_Code_1__pc, Customer__r.Mobile_Preferred__pc, Registration_No__c FROM Vehicle_Ownership__c WHERE
										Customer__c = :apbu.Account_Name__c LIMIT 1];
		Test.startTest();
		CareLogin.login(loginVO.Customer__r.Mobile_Preferred__pc, loginVO.Registration_No__c, '028', null);
		Test.stopTest();
		CareToken.RegistrationResp resp = (CareToken.RegistrationResp) JSON.deserialize(RestContext.response.responseBody.toString(),
											CareToken.RegistrationResp.class);
		CareToken.AdditionalClaims claims = CareToken.parseToken(resp.token);
		System.assertEquals(claims.accountId, apbu.Account_Name__c);
	}

	@IsTest
	public static void test2FAVerify() {
		Test.setMock(WebServiceMock.class, new TestWSMock.M3TechAPI_Mock('success'));
		RestContext.response = new RestResponse();
		Account_Profile_with_Business_Unit__c apbu = [SELECT Id, Account_Name__c FROM Account_Profile_with_Business_Unit__c LIMIT 1];
		update new Account(Id = apbu.Account_Name__c, X2FA_Verified_List__c = '028');
		Vehicle_Ownership__c loginVO = [SELECT Id, Customer__r.Mobile_Country_Code_1__pc, Customer__r.Mobile_Preferred__pc, Registration_No__c FROM Vehicle_Ownership__c WHERE
										Customer__c = :apbu.Account_Name__c LIMIT 1];
		Test.startTest();
		CareLogin.login(loginVO.Customer__r.Mobile_Preferred__pc, loginVO.Registration_No__c, '028', null);
		Test.stopTest();
		system.debug('Resp body:');
		system.debug(RestContext.response.responseBody);
		CareToken.VerificationResp resp = (CareToken.VerificationResp) JSON.deserialize(RestContext.response.responseBody.toString(),
																		CareToken.VerificationResp.class);
		CareToken.AdditionalClaims claims = CareToken.parseToken(resp.token);
		System.assertEquals(claims.accountId, apbu.Account_Name__c);
		System.assertEquals(claims.mobile, loginVO.Customer__r.Mobile_Preferred__pc);
	}

	@isTest
	public static void testLogin() {
		RestContext.response = new RestResponse();
		Account_Profile_with_Business_Unit__c apbu = [SELECT Id, Account_Name__c FROM Account_Profile_with_Business_Unit__c LIMIT 1];
		update new Account(Id = apbu.Account_Name__c, Skip_2FA_ACP__c = true);
		Vehicle_Ownership__c loginVO = [SELECT Id, Customer__r.Mobile_Country_Code_1__pc, Customer__r.Mobile_Preferred__pc, Registration_No__c FROM Vehicle_Ownership__c WHERE
										Customer__c = :apbu.Account_Name__c LIMIT 1];
		CareLogin.login(loginVO.Customer__r.Mobile_Preferred__pc, loginVO.Registration_No__c, '028', null);
		CareLogin.LoginResp resp = (CareLogin.LoginResp) JSON.deserialize(RestContext.response.responseBody.toString(), CareLogin.LoginResp.class);
		System.assert(resp.user != null);
		CareToken.AdditionalClaims claims = CareToken.parseToken(resp.token);
		System.assert(claims.isVerified);
		System.assertEquals(resp.user.accId, apbu.Account_Name__c);
		System.assertEquals(resp.user.vehicles.size(), 2);
		System.assertEquals(resp.user.apptList.size(), 1);
		System.assertEquals(resp.user.serviceList.size(), 0);
		System.assertEquals(resp.user.acctStatus, 'VIP');
	}
}