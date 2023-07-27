public class TriggerRun {
	@TestVisible private static Map<String, Integer> MAX_RUN = new Map<String, Integer>();
	@TestVisible private static Map<String, Map<Process, Integer>> CUR_RUN = new Map<String, Map<Process, Integer>>();
	public static void setMaxRun(String name, Integer max) { MAX_RUN.put(name, max); }

	@TestVisible enum Process { B_INS, B_UPD, B_DEL, A_INS, A_UPD, A_DEL, A_UNDEL }

	public static void run(TriggerBase trig) {
		String triggerName = trig.getTriggerName();
		if (!isEnabled(triggerName)) { return; }
		Map<Process, Integer> cur = CUR_RUN.get(triggerName);
		if (cur == null) {
			cur = initCurRun();
			CUR_RUN.put(triggerName, cur);
		}
		if (Trigger.isBefore) {
			if (Trigger.isInsert) {
				if (shouldRun(triggerName, cur, Process.B_INS)) {
					trig.beforeInsert(Trigger.new);
					incrementCurRun(cur, Process.B_INS);
				}
			} else if (Trigger.isUpdate) {
				if (shouldRun(triggerName, cur, Process.B_UPD)) {
					trig.beforeUpdate(Trigger.newMap, Trigger.oldMap);
					incrementCurRun(cur, Process.B_UPD);
				}
			} else if (Trigger.isDelete) {
				if (shouldRun(triggerName, cur, Process.B_DEL)) {
					trig.beforeDelete(Trigger.newMap, Trigger.oldMap);
					incrementCurRun(cur, Process.B_DEL);
				}
			} else {
				throw new TriggerBase.TriggerException('Should not reach here!');
			}
		} else {
			if (Trigger.isInsert) {
				if (shouldRun(triggerName, cur, Process.A_INS)) {
					trig.afterInsert(Trigger.newMap);
					incrementCurRun(cur, Process.A_INS);
				}
			} else if (Trigger.isUpdate) {
				if (shouldRun(triggerName, cur, Process.A_UPD)) {
					trig.afterUpdate(Trigger.newMap, Trigger.oldMap);
					incrementCurRun(cur, Process.A_UPD);
				}
			} else if (Trigger.isDelete) {
				if (shouldRun(triggerName, cur, Process.A_DEL)) {
					trig.afterDelete(Trigger.oldMap);
					incrementCurRun(cur, Process.A_DEL);
				}
			} else if (Trigger.isUndelete) {
				if (shouldRun(triggerName, cur, Process.A_UNDEL)) {
					trig.afterUndelete(Trigger.oldMap);
					incrementCurRun(cur, Process.A_UNDEL);
				}
			} else {
				throw new TriggerBase.TriggerException('Should not reach here!');
			}
		}
		logLimits();
	}

	public static void resetAll() {
		for (String s : CUR_RUN.keySet()) { resetRun(s); }
	}
	public static void resetRun(String triggerName) { CUR_RUN.put(triggerName, initCurRun()); }

	private static Map<Process, Integer> initCurRun() {
		return new Map<Process, Integer> { Process.B_INS => 0, Process.B_UPD => 0, Process.B_DEL => 0, Process.A_INS => 0, Process.A_UPD => 0, Process.A_DEL => 0,
																			 Process.A_UNDEL => 0 };
	}

	// defaulted to only run once
	@TestVisible private static Boolean shouldRun(String triggerName, Map<Process, Integer> cur, Process curP) {
		Integer curInt = cur.get(curP);
		Integer maxInt = MAX_RUN.get(triggerName);
		return ((maxInt == null && curInt > 0) || curInt < maxInt) && isEnabled(triggerName);
	}

	@TestVisible private static void incrementCurRun(Map<Process, Integer> cur, Process curP) { cur.put(curP, cur.get(curP) + 1); }

	private static Boolean isEnabled(String triggerName) {
		Global_Trigger_Settings__c trigSettings = Global_Trigger_Settings__c.getValues(triggerName);
		return (trigSettings != null && trigSettings.Activated__c);
	}

	private static void logLimits() {
		System.debug('## Number of Queries used in this apex code so far: ' + Limits.getQueries() + ' out of ' + Limits.getLimitQueries());
		System.debug('## Number of Rows queried in this apex code so far: ' + Limits.getDmlRows() + ' out of ' + Limits.getLimitDmlRows());
		System.debug('## Number of DML statements used so far: ' +  Limits.getDmlStatements() + ' out of ' + Limits.getLimitDmlStatements());
	}
}