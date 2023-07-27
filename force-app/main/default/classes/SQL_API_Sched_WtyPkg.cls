/** Deprecated */
global class SQL_API_Sched_WtyPkg implements Schedulable, Database.AllowsCallouts {
	global void execute(SchedulableContext sc) {
		System.enqueueJob(new SQL_WtyPkg_Queue());
	}
}