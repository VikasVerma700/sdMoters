@isTest
private class InsuranceBatchSched_Test {

	@TestSetup
	static void setup() {
		TestFactory.genTriggerSettings('Opportunity', true);
		TestFactory.genTriggerSettings('Vehicle', true);
		TestFactory.getCompany('828');
		// TestFactory.getCompany('02');
	}

	static testMethod void testSchedule() {
		Insurance_Policy__c policy = TestFactory.genInsurancePolicy(1, true)[0];
		Opportunity existingOpp = TestFactory.genOpportunity(1, false)[0];
		existingOpp.Insurance__c = policy.Id;
		insert existingOpp;
		Test.startTest();
		InsuranceBatchSched sched = new InsuranceBatchSched();
		String jobId = System.schedule('Sched Test', '0 0 0 * * ?', sched);
		sched.execute(null);
		CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered FROM CronTrigger WHERE id = :jobId];
		Test.stopTest();
		System.assertEquals(ct.TimesTriggered, 0);
		// check debuglog to ensure batch job ran
	}

	@isTest static void testRenewOpp() {
		Map<Id, Insurance_Policy__c> insPolicyMap = new Map<Id, Insurance_Policy__c>(TestFactory.genInsurancePolicy(2, true));
		Opportunity existingOpp = TestFactory.genOpportunity(1, true)[0];
		List<Insurance_Policy__c> existingPolicyList = insPolicyMap.values();
		Map<Id, Opportunity> existingInsOpp = new Map<Id, Opportunity> { existingPolicyList[0].Id => existingOpp };
		List<Insurance_Policy__c> policyList = Database.query(InsuranceBatchSched.DEF_FIELDS + ' WHERE Id IN (\'' + existingPolicyList[0].Id +
																													'\', \'' + existingPolicyList[1].Id + '\')');
		Test.startTest();
		InsuranceBatchSched sched = new InsuranceBatchSched();
		sched.renewOpp(policyList, existingInsOpp);
		Test.stopTest();
		Set<Id> insIds = new Set<Id>();
		for (Insurance_Policy__c insP : policyList) { insIds.add(insP.Id); }
		List<Opportunity> oppList = [SELECT Type, Id FROM Opportunity WHERE Insurance__c = :insIds];
		System.assertEquals(oppList.size(), 1);
		System.assertEquals(oppList[0].Type, 'Vehicle Insurance');
	}
}