public class SyncMobySched implements Schedulable {
	private static final string JOB_NAME = 'SyncMobySched';
	public static final Integer INTERVAL = SyncMobyApiBase.INTERVAL;

	public static void scheduleJob() {
		/** Start from 00th minute */
		for (Integer i = 0; i < 60; i += INTERVAL) {
			string jobName = 'SQL API (' + JOB_NAME + ')';
			string cronExp = '0 0 * * * ?';

			SyncMobySched schedulable = new SyncMobySched();
			if (Test.isRunningTest()) { jobName += '_Test'; }

			System.schedule(jobName, cronExp, schedulable);
		}
	}
	
	public void execute(SchedulableContext sc) {
		SyncMoby01User queueable = new SyncMoby01User();
		queueable.dateTo = Datetime.now();
		queueable.followOnToNext = true;
		if (!Test.isRunningTest()) { System.enqueueJob(queueable); }
	}
}