public class CtrlDev {
	public string error { get; private set; }
	public string status { get; private set; }

	public PageReference createJob() {
		Id hour = system.schedule('Scheduler - M00', '0 0 * * * ? *', new Scheduler());
		Id half = system.schedule('Scheduler - M30', '0 30 * * * ? *', new Scheduler());
		error = ''; status = 'Created jobs with ID ' + hour + ', ' + half + '.';
		return null;
	}

	public PageReference deleteJob() {
		List<Id> ids = new List<Id>();
		for (CronTrigger ct : [select CronExpression from CronTrigger]) {
			if (new Set<string>{'0 0 * * * ? *', '0 30 * * * ? *'}.contains(ct.CronExpression))
			{ system.abortJob(ct.id); ids.add(ct.id); }
		}

		error = '';
		if (ids.size() > 0) { status = 'Deleted jobs with ID ' + string.join(ids, ', ') + '.'; }
		else { status = 'No jobs to delete.'; }
		return null;
	}

	public PageReference scheduler() {
		datetime now = datetime.now();
		CaseCommon.schedule(now);
		error = ''; status = 'Last executed at ' + now.format('yyyy-MM-dd HH:mm:ss.SSS.');
		return null;
	}
}