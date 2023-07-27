@isTest private class CronAdminController_Test {
/** Service Order Thank You SMS. */
	@isTest static void SoTqSmsTest() {
		PageReference pr = Page.cronadmin;
		Test.setCurrentPage(pr);
		Test.startTest();

		CronAdminController ctl = new CronAdminController();

		/** Call methods. */
		ctl.createSoTqSms();
		ctl.deleteSoTqSms();
		ctl.executeSoTqSms();

		Test.stopTest();
	}
}