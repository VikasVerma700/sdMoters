@IsTest
public class CustAppInsurance_Test {
	@TestSetup
	static void setup() {
		TestFactory.getCompany('028');
		TestFactory.genTriggerSettings('Vehicle Model', true);
		TestFactory.genTriggerSettings('Vehicle', true);
		List<Customer_External_Account__c> extAcc = TestFactory.genCustExtAcc(1, true);
		Vehicle_Ownership__c vo = TestFactory.genVO(1, false)[0];
		vo.Customer__c = extAcc[0].Account__c;
		insert vo;
		Insurance_Policy__c pol = TestFactory.genInsurancePolicy(1, false)[0];
		pol.Policy_Holder__c = vo.Customer__c;
		pol.Vehicle_Ownership__c = vo.Id;
		insert pol;
		Attachment att = TestFactory.genAttachment(1)[0];
		att.Name = 'Policy Schedule';
		att.ParentId = pol.Id;
		insert att;
	}

	@IsTest
	static void testIns() {
		Insurance_Policy__c policy = [SELECT Id, Policy_Holder__c, Vehicle_Ownership__c, Vehicle_Ownership__r.Customer__c, Created_From__c FROM Insurance_Policy__c LIMIT 1];
		System.debug('testIns(): ' + JSON.serialize(policy));
		Test.startTest();
		Map<Id, List<CustAppInsurance.InsuranceCls>> res = CustAppInsurance.retrieveInsurance(policy.Policy_Holder__c, '028');
		Test.stopTest();
		System.assertEquals(res.values()[0][0].id, policy.Id);
	}

	@IsTest
	static void testAddInsCallback() {
		List<Customer_External_Account__c> extAcc = [SELECT Id, Account__c, UUID__c FROM Customer_External_Account__c];
		Set<Id> accId = new Set<Id>();
		for (Customer_External_Account__c e : extAcc) { accId.add(e.Account__c); }
		Vehicle_Ownership__c vo = [SELECT Id, Vehicle__c, Vehicle__r.Name FROM Vehicle_Ownership__c WHERE Customer__c IN :accId LIMIT 1];
		CustAppInsurance.AddInsurancePayload payloadBody = new CustAppInsurance.AddInsurancePayload();
		CustAppInsurance.AddInsuranceReq req = new CustAppInsurance.AddInsuranceReq();
		req.insurance = new CustAppInsurance.AddInsuranceCls();
		req.insurance.underwriterName = 'TestIns';
		req.insurance.startDate = Date.today();
		req.insurance.endDate = Date.today().addYears(1);
		req.insurance.id = 'TEST123456';
		req.insurance.policyNumber = 'INS1234';
		req.insurance.excess = new CustAppAPI.CurrencyCls(500);
		req.insurance.premium = new CustAppAPI.CurrencyCls(1500);
		req.vehicle = new CustAppInsurance.VehOwnerCls();
		req.vehicle.accountUuid = extAcc[0].UUID__c;
		req.vehicle.identificationNumber = vo.Vehicle__r.Name;
		payloadbody.payload = req;
		payloadBody.event = CustAppInsurance.ADD_EVENT;
		RestContext.request = new RestRequest();
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(payloadBody));
		Test.startTest();
		CustAppInsurance.processAddCallback();
		Test.stopTest();
		List<Insurance_Policy__c> checkPolicy = [SELECT Id FROM Insurance_Policy__c WHERE Policy_Number__c = :req.insurance.policyNumber AND
												Ext_Underwriter__c = :req.insurance.underwriterName];
		System.assert(checkPolicy.size() > 0);
	}

	@IsTest
	static void testRemInsCallback() {
		List<Customer_External_Account__c> extAcc = [SELECT Id, Account__c, UUID__c, Type__c FROM Customer_External_Account__c];
		Insurance_Policy__c policy = [SELECT Id, Policy_Holder__c FROM Insurance_Policy__c LIMIT 1];
		policy.Created_From__c = extAcc[0].Type__c;
		policy.Ext_UUID__c = 'test';
		update policy;
		CustAppInsurance.RemInsurancePayload payloadBody = new CustAppInsurance.RemInsurancePayload();
		CustAppInsurance.RemInsuranceCls req = new CustAppInsurance.RemInsuranceCls();
		req.insuranceId = policy.Ext_UUID__c;
		req.vehicle = new CustAppInsurance.VehOwnerCls();
		req.vehicle.accountUuid = extAcc[0].UUID__c;
		payloadbody.payload = req;
		payloadBody.event = CustAppInsurance.REM_EVENT;
		RestContext.request = new RestRequest();
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(payloadBody));
		Test.startTest();
		CustAppInsurance.processRemoveCallback();
		Test.stopTest();
		List<Insurance_Policy__c> checkPolicy = [SELECT Id, User_Deleted__c FROM Insurance_Policy__c WHERE Id = :policy.Id];
		System.assert(checkPolicy[0].User_Deleted__c);
	}
}