@isTest
private class InsuranceHandler_Test {

	@TestSetup
	private static void setup() {
		Global_Trigger_Settings__c voTrig = TestFactory.genTriggerSettings('Vehicle Ownership', false);
		voTrig.Activated__c = false;
		insert votrig; // dont let the trigger run again due to limits
		TestFactory.genTriggerSettings('Opportunity', true);
		TestFactory.genTriggerSettings('Vehicle Model', true);
		Global_Trigger_Settings__c vehTrig = TestFactory.genTriggerSettings('Vehicle', false);
		vehTrig.Activated__c = false;
		insert vehTrig; // dont let the trigger run again due to limits
		TestFactory.genTriggerSettings('Insurance Policy', true);
		TestFactory.getCompany('028');
		Sales_Order__c soPML = TestFactory.genSO(1, true)[0];

		Vehicle_Model__c vehModel = TestFactory.genVehModel(1, true)[0];
		Vehicle_Ownership__c vo = TestFactory.genVO(1, true)[0];
		Insurance_Policy__c policy = TestFactory.genInsurancePolicy(1, false)[0];

		System.debug('Oppo: ' + JSON.serialize([
			SELECT Id, Name, Company__r.Name, AccountId, StageName, CloseDate, Type,
			Sales_Order__r.Id, Sales_Order__r.Name FROM Opportunity])
		);

		Opportunity[] oppos = [SELECT Id FROM Opportunity];
		for (Opportunity opp :oppos) {
			opp.Sales_Order__c = soPML.Id;			
			opp.Type = 'Vehicle Insurance';
		}
		update oppos;
		System.debug('Oppo1: ' + JSON.serialize([
			SELECT Id, Name, Company__r.Name, AccountId, StageName, CloseDate, Type,
			Sales_Order__r.Id, Sales_Order__r.Name FROM Opportunity])
		);

		Opportunity insOpp = [SELECT Id FROM Opportunity WHERE Sales_Order__c = :soPML.Id AND Type = 'Vehicle Insurance'];
		policy.Sales_Order_PML__c = soPML.Id;
		policy.Opportunity__c = insOpp.Id;
		policy.Policy_Holder__c = vo.Customer__c;
		policy.Vehicle__c = vo.Vehicle__c;
		update (new Vehicle__c(Id = vo.Vehicle__c, Vehicle_Model__c = vehModel.Id, Vehicle_Make__c = vehModel.Vehicle_Make__c));

		Test.startTest();

		insert policy;
		policy.Policy_Number__c = 'ABC123';
		policy.Policy_Received_Date__c = Date.today();
		policy.Workshop_Type__c = 'Any';
		policy.Coverage__c = 'Comprehensive';
		update policy;

		Test.stopTest();
	}

	@isTest static void testCreateTxn() {
		Map<Id, Insurance_Policy__c> policyMap = new Map<Id, Insurance_Policy__c>([SELECT Id, Sales_Order_PML__c FROM Insurance_Policy__c]);
		List<Insurance_Transaction__c> txn = [SELECT Id, Insurance_Name_Id__c, Insurance_Transaction_Type_Id__c, Agency_Code__c FROM Insurance_Transaction__c
											WHERE Insurance_Name_ID__c IN :policyMap.keySet()];
		// System.assertEquals(txn.size(), policyMap.size());
		Insurance_Policy__c pol;
		for (Insurance_Transaction__c t : txn) {
		pol = policyMap.get(t.Insurance_Name_ID__c);
		System.assertNotEquals(pol, null);
		if (pol.Sales_Order_PML__c != null) {
			System.assertEquals(t.Insurance_Transaction_Type_Id__c, '(+) NEW WITH VSA RETAIL');
			// System.assertNotEquals(t.Agency_Code__c, null);
		} else {
			System.assertEquals(t.Insurance_Transaction_Type_Id__c, null);
		}
		}
	}

	@isTest static void testUWTask() {
		Map<Id, Insurance_Policy__c> policyMap = new Map<Id, Insurance_Policy__c>([SELECT Id FROM Insurance_Policy__c]);
		List<Task> taskList = [SELECT Id, WhatId, Status FROM Task WHERE Subject = 'UW Stages'];
		// System.assertEquals(policyMap.size(), taskList.size());
		for (Task t : taskList) {
			System.assert(policyMap.containsKey(t.WhatId));
		}
	}

	@isTest static void testPolicyReceived() {
		List<Insurance_Policy__c> policies = [SELECT Id FROM Insurance_Policy__c];
		List<Task> taskList = [SELECT Id FROM Task WHERE Subject = 'Policy received'];
		// System.assertEquals(policies.size(), taskList.size());
	}

	@isTest static void testUpdateVO() {
		Map<Id, Insurance_Policy__c> policyMap = new Map<Id, Insurance_Policy__c>([SELECT Id, Policy_Holder__c, Vehicle__c, Vehicle_Ownership__c
																				FROM Insurance_Policy__c]);
		List<Vehicle_Ownership__c> voList = [SELECT Id, Customer__c, Vehicle__c FROM Vehicle_Ownership__c WHERE With_Existing_Insurance_Policy__c = true];
		// System.assertEquals(voList.size(), policyMap.size());
		Boolean found;
		for (Insurance_Policy__c p : policyMap.values()) {
		found = false;
		for (Vehicle_Ownership__c vo : voList) {
			found = (vo.Customer__c == p.Policy_Holder__c) && (vo.Vehicle__c == p.Vehicle__c);
			if (found) { break; }
		}
		// System.assert(found);
		}
	}
}