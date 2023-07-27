@IsTest
private class TriggerHelper_Test {

	@TestSetup
	static void makeData(){
		Force_com_Site_URL__c[] sites = new Force_com_Site_URL__c[]{};
		sites.add(new Force_com_Site_URL__c(Name = 'Sandbox'));
		sites.add(new Force_com_Site_URL__c(Name = 'Production'));
		insert sites;
	}

	@IsTest
	static void testProperties() {
		Boolean bool = false;
		TriggerHelper.bTriggerRun = bool;
		bool = !TriggerHelper.bTriggerRun;
		TriggerHelper.bBeforeTriggerRun = bool;
		bool = !TriggerHelper.bBeforeTriggerRun;
		TriggerHelper.bBeforeInsertRun = bool;
		bool = !TriggerHelper.bBeforeInsertRun;
		TriggerHelper.bAfterInsertRun = bool;
		bool = !TriggerHelper.bAfterInsertRun;
		TriggerHelper.bBeforeUpdateRun = bool;
		bool = !TriggerHelper.bBeforeUpdateRun;
		TriggerHelper.bAfterTriggerRun = bool;
		bool = !TriggerHelper.bAfterTriggerRun;
		TriggerHelper.bafterUpdateRun = bool;
		bool = !TriggerHelper.bafterUpdateRun;
		TriggerHelper.bAfterDeleteRun = bool;
		bool = !TriggerHelper.bAfterDeleteRun;
		TriggerHelper.bAfterUndeleteRun = bool;
		bool = !TriggerHelper.bAfterUndeleteRun;
		TriggerHelper.bFutureCallRun = bool;
		bool = !TriggerHelper.bFutureCallRun;
		TriggerHelper.bFutureCallVORun = bool;
		bool = !TriggerHelper.bFutureCallVORun;
	}

	@IsTest
	static void testGetForceSiteURLSandbox() {
		string site;
		Test.startTest();
		site = TriggerHelper.getForceSiteURL(false);
		Test.stopTest();
	}

	@IsTest
	static void testGetForceSiteURLProd() {
		string site;
		Test.startTest();
		site = TriggerHelper.getForceSiteURL(false);
		Test.stopTest();
	}

}