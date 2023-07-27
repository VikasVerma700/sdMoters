@isTest
private class TriggerRun_Test {
	private static testMethod void testResetRun() {
		TriggerRun.resetRun('test');
		Map<TriggerRun.Process, Integer> rv = TriggerRun.CUR_RUN.get('test');
		for (TriggerRun.Process p : rv.keySet()) { rv.put(p, 1); }
		TriggerRun.resetAll();
		rv = TriggerRun.CUR_RUN.get('test');
		for (TriggerRun.Process p : rv.keySet()) {
			System.assertEquals(rv.get(p), 0);
		}
	}

	private static testMethod void testSetMaxRun() {
		TriggerRun.setMaxRun('test', 5);
		System.assertEquals(TriggerRun.MAX_RUN.get('test'), 5);
	}

	private static testMethod void testShouldRun() {
		TriggerRun.setMaxRun('test', 1);
		TriggerRun.resetRun('test');
		TestFactory.genTriggerSettings('test', true);
		System.assert(TriggerRun.shouldRun('test', TriggerRun.CUR_RUN.get('test'), TriggerRun.Process.B_INS));
	}

	private static testMethod void testRun() {
		SQL_API_Base_Test.makeData();
		TestFactory.genTriggerSettings(ServiceAppointmentHandler.TRIG_SETTING, true);
		Service_Appointment__c o = TestFactory.genSvcAppt(1, false)[0];
		Test.startTest();
		insert o;
		update o;
		Test.stopTest();
		Map<TriggerRun.Process, Integer> rv = TriggerRun.CUR_RUN.get(ServiceAppointmentHandler.TRIG_SETTING);
		for (TriggerRun.Process p : rv.keySet()) {
			System.debug(rv.get(p) + ' <= ' + TriggerBase.DEF_RUN + ', ' + p);
			System.assert(rv.get(p) <= TriggerBase.DEF_RUN, p);
		}
	}
}