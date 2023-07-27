/** Deprecated */
global class SQL_API_Sched_VehWty implements Schedulable, Database.AllowsCallouts {
	global void execute(SchedulableContext sc) {
		System.enqueueJob(new SQL_VehWty_Queue());
	}
}