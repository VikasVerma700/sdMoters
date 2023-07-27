global class SQL_API_Wty_Sched implements Schedulable, Database.AllowsCallouts {
	public static string scheduleJob() {
		string name = 'SQL API (SQL_WtyPkg_Queue)';
		string jobName = (Test.isRunningTest() ? '[Test] ' + name: name);
		return System.schedule(jobName, '0 0 3 ? * * *', new SQL_API_Wty_Sched());
	}

	global void execute(SchedulableContext sc) {
		SQL_WtyPkg_Queue q = new SQL_WtyPkg_Queue();
		q.dateTo = Datetime.now();
		q.followOnToVehWty = true;
		System.enqueueJob(q);
	}
}