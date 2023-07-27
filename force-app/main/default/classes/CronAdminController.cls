public class CronAdminController {

/** Internal class. */
	public class LogColumns implements Comparable {
		public Datetime	logDateTime	{ get; private set; }
		public string	logDate		{ get; private set; }
		public string	logTime		{ get; private set; }
		public string	logMessage	{ get; private set; }
		public LogColumns(string message) {
			this.logDateTime	= Datetime.now();
			this.logDate 		= this.logDateTime.format('yyyy-MM-dd');
			this.logTime 		= this.logDateTime.format('HH:mm:ss', 'GMT+8');
			this.logMessage		= message;
		}
		public Integer compareTo(Object compareTo) {
			LogColumns lc = (LogColumns)compareTo;
			Datetime src = logDateTime;
			Datetime dst = lc.logDateTime;
			if (src == dst) return 0;
			if (src > dst) return -1;
			return 1;
		}
	}
	public class CronTriggerColumns {
		public Id 		id				{ get; private set; }
		public string	name			{ get; private set; }
		public Datetime	nextFireTime	{ get; private set; }
		public Datetime	prevFireTime	{ get; private set; }
		public string	state			{ get; private set; }
		public string	cronExpression	{ get; private set; }
		public integer	timesTriggered	{ get; private set; }
		public CronTriggerColumns(Id id, string name, Datetime next, Datetime prev, string state, string cron, integer times) {
			this.id				= id;		this.name			= name;
			this.nextFireTime	= next;		this.prevFireTime	= prev;
			this.state			= state;	this.cronExpression	= cron;
			this.timesTriggered	= times;
		}
	}
	private class CronConstruct {
		public string   			Render	{ get; private set; }
		public string   			Html	{ get; private set; }
		public CronTriggerColumns[]	Ctc		{ get; private set; }
		public CronConstruct() { this.Render = ''; this.Html   = ''; this.Ctc = new List<CronTriggerColumns>(); }
	}
	

/** Controller Properties. */
	/** Private properties. */
	private string conSoTqSms;
	private string jobName;

	/** Public properties. */
	public string selectedTab	{ get; set; }
	public CronTrigger[] cts	{ get; private set; }
	public LogColumns[] logs	{ get; private set; }

	/** Job scheduling. */
	public Date dateFrom		{ get; set; }
	public Date dateTo			{ get; set; }
	public string regNo			{ get; set; }

/** Tab specific properties. */
	/** Service Order Thank You SMS properties. */
	public integer countSoTqSms	{ get; private set; }
	public string htmlSoTqSms	{ get; private set; }
	public string renderSoTqSms	{ get; private set; }
	public CronTriggerColumns[] ctcSoTqSms	{ get; private set; }

/** Constructor, Initialisers. */
	public CronAdminController() {
		conSoTqSms			= 'Thank You SMS';
		if (Test.isRunningTest()) {
			conSoTqSms			= '[Test] ' + conSoTqSms;
		}
		/** Initialise CronTrigger & module counts, LogColumns. */
		cts = getCronTrigger();
		logs = new List<LogColumns>();

		CronConstruct cc;
		/** Initialise Service Order Thank You SMS scheduler. */
		cc = initCron(conSoTqSms, countSoTqSms);
		renderSoTqSms = cc.Render; htmlSoTqSms = cc.Html; ctcSoTqSms = cc.Ctc;
	}
	private CronConstruct initCron(string jobName, integer counter) {
		CronConstruct cc = new CronConstruct();
		if (counter == 0) {
			cc.Render	= 'Create';
			cc.Html		= 'No running scheduler.<br />';
		} else {
			cc.Render	= 'Delete';
			cc.Html		= '';
			for (CronTrigger ct :cts) {
				if (ct.CronJobDetail.Name.contains(jobName)) {
					cc.Ctc.add(new CronTriggerColumns(ct.Id, ct.CronJobDetail.Name,
						ct.NextFireTime, ct.PreviousFireTime, ct.State, ct.CronExpression,
						ct.TimesTriggered));
				}
			}
		}
		return cc;
	}

/** Service Order Thank You SMS scheduler */
	public Pagereference createSoTqSms() { this.jobName = this.conSoTqSms; schCreate(this.jobName); return null; }
	public Pagereference deleteSoTqSms() { this.jobName = this.conSoTqSms; schDelete(this.jobName); return null; }
	public Pagereference executeSoTqSms() {
		ServiceOrderThankYouSms a	= new ServiceOrderThankYouSms();
		string jobId				= Database.executeBatch(a, ServiceOrderThankYouSms.scopeSize);

		logText('Execute Thank You SMS ({0}).',
				new object[] { jobId });

		return null;
	}

/** Create, Delete schedulers and multi-purpose methods. */
	public void schCreate(string cjdName) {
		Id id;
		string totalJobs = '';
		CronConstruct cc;
		/** Schedule Case Common - daily, every 30 mins. */
		if (cjdName.contains(this.conSoTqSms)) {
			id = system.schedule(cjdName, '0 0 10 * * ?', new ServiceOrderThankYouSms());
			totalJobs += string.format('+ {0} ({1}).\n', new string[] { cjdName, id });

			cts = getCronTrigger();
			cc = initCron(conSoTqSms, countSoTqSms);
			renderSoTqSms = cc.Render; htmlSoTqSms = cc.Html; ctcSoTqSms = cc.Ctc;
		}
		logText('Job(s) scheduled:\n{0}', new string [] { totalJobs });
	}
	public void schDelete(string cjdName) {
		string totalJobs = '';
		CronConstruct cc;

		/** Loop through CronTrigger and remove scheduled jobs. */
		for (CronTrigger ct :cts) {
			if (ct.CronJobDetail.Name.contains(cjdName)) {
				try {
					system.abortJob(ct.id);
					totalJobs += string.format('- {0} ({1}).\n',
								new string[] { ct.CronJobDetail.Name, ct.Id });
				} catch (Exception e) {
					totalJobs += string.format(' -{0} ({1}).\n',
								new string[] { ct.CronJobDetail.Name, ct.Id });
				}
			}
		}
		/** Get latest Cron Trigger listing. */
		cts = getCronTrigger();

		/** Delete Case Common scheduler. */
		if (cjdName.contains(this.conSoTqSms)) {
			cc = initCron(conSoTqSms, countSoTqSms);
			renderSoTqSms = cc.Render; htmlSoTqSms = cc.Html; ctcSoTqSms = cc.Ctc;
		}
		logText('Job(s) deleted:\n{0}', new string[] { totalJobs });
	}
/** Miscellaneous methods. */
	private void logText(string s, string p) { logText(s, new object[] { p }); }
	private void logText(string s, Object[] args) {
		string[] szArgs = new List<String>();
		for (Object o: args) szArgs.add(String.valueOf(o));
		logText(string.format(s, szArgs));
	}
	private void logText(string message) { logTextHtml(message.replace('\n', '<br />')); }
	private void logTextHtml(string message) {
		if (logs == null) logs = new List<LogColumns>();
		logs.add(new LogColumns(message));
		/** sort logs by date/time desc. */
		logs.sort();
	}
	private CronTrigger[] getCronTrigger() {
		/** Reset count. */
		countSoTqSms 		= 0;

		CronTrigger[] cts = [
			SELECT Id, CronJobDetail.Name, CronJobDetail.JobType, NextFireTime,
					PreviousFireTime, State, StartTime, EndTime, CronExpression,
					TimeZoneSidKey, OwnerId, LastModifiedById, CreatedById,
					CreatedDate, TimesTriggered
			FROM CronTrigger
		];
		for (CronTrigger ct :cts) {
			if (ct.CronJobDetail.Name.contains(this.conSoTqSms))				countSoTqSms++;
		}
		return cts;
	}
}