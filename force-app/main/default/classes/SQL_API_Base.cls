public with sharing class SQL_API_Base {
	public static final string[] COMPANY_CODE;
	public static final User[] USER_ADMINS;
	public static final User USER_ADMIN;
	public static final User USER_CUR;
	public static final Organization ORG;
	public static final Boolean ISSANDBOX;
	public static final string SBSUFFIX;
	public static final String USERNAME;
	public static final String PASSWORD;
	public static final String ENDPOINT;
	public static final String QRCODEEP;
	public static final Integer TIMEZONE = 8;
	public static final Integer INTERVAL = 15; // interval between scheduler job
	// if there is a queueable job still processing that was created < RETRY LIMIT, then new job will not run
	public static DateTime RETRY_LIMIT = DateTime.now().addMinutes(INTERVAL * -1);

	public static final string QUEUE_EMPL;
	public static final string QUEUE_ACCO;
	public static final string QUEUE_VEHI;
	public static final string QUEUE_VOWN;
	public static final string QUEUE_APPT;
	public static final string QUEUE_RORD;
	public static final string QUEUE_INVO;
	public static final string QUEUE_FILE;
	public static final string QUEUE_PAYM;
	public static final string QUEUE_PKGE;
	public static final string QUEUE_WRTY;
    public static final string QUEUE_ESA;

    public static final Map<String,List<String>> gdmsSource2CompanyCodeList;

	static {
		COMPANY_CODE = getCareCompanyCode();
		USER_ADMINS = Envir.USER_ADMINS;
		USER_ADMIN = Envir.USER_ADMIN;
		USER_CUR = Envir.USER_CUR;
		ORG = Envir.org;
		ISSANDBOX = Envir.isSandbox;
		SBSUFFIX = Envir.sbSuffix;
		USERNAME = (IsSandbox) ? API_Setup__c.getInstance('Sync Care Dev Username').Value__c : API_Setup__c.getInstance('Sync Care Prd Username').Value__c;
		PASSWORD = (IsSandbox) ? API_Setup__c.getInstance('Sync Care Dev Password').Value__c : API_Setup__c.getInstance('Sync Care Prd Password').Value__c;
		ENDPOINT = (IsSandbox) ? API_Setup__c.getInstance('Sync Care Dev Endpoint').Value__c : API_Setup__c.getInstance('Sync Care Prd Endpoint').Value__c;
		QRCODEEP = (IsSandbox) ? API_Setup__c.getInstance('Sync Care Dev QR Endpoint').Value__c : API_Setup__c.getInstance('Sync Care Prd QR Endpoint').Value__c;
		QUEUE_ACCO = 'SQL_Acc_Queue';
		QUEUE_VEHI = 'SQL_Veh_Queue';
		QUEUE_VOWN = 'SQL_VO_Queue';
		QUEUE_APPT = 'SQL_Appt_Queue';
		QUEUE_RORD = 'SQL_RO_Queue';
		QUEUE_INVO = 'SQL_SvcInv_Queue';
		QUEUE_FILE = 'SQL_File_Queue';
		QUEUE_PAYM = 'SQL_Payment_Queue';
		QUEUE_PKGE = 'SQL_WtyPkg_Queue';
		QUEUE_WRTY = 'SQL_VehWty_Queue';
        QUEUE_ESA  = 'SQL_ExternalSystemAccount_Queue';

        gdmsSource2CompanyCodeList = new Map<String,List<String>>{
            'GdmsInternal' => new List<String>{'028','038','088','168','099'},
            'GdmsExternal' => new List<String>{'138','128'}
        };
	}

	public static Service_Run__c getRun(string queueName) {
		Service_Run__c serviceRun = Service_Run__c.getInstance(queueName);
		if(serviceRun == null){
			insert new Service_Run__c(Name = queueName, Last_Run__c = Datetime.newInstance(1900,01,01));
			serviceRun = Service_Run__c.getInstance(queueName);
		}
		return serviceRun;
	}
	public static DateTime getRunTime(string queueName) { return getRunTime(getRun(queueName)); }
	public static DateTime getRunTime(Service_Run__c run) { return (run != null && run.Last_Run__c != null) ? run.Last_Run__c : DateTime.now(); }
	public static void updateRun(string queueName, DateTime dtTo) { updateRun(getRun(queueName), dtTo); }
	public static void updateRun(Service_Run__c run, DateTime dtTo) {
		if (run == null) { return; }
		DateTime lastRun = run.Last_Run__c;
		lastRun = (dtTo == null) ? lastRun : dtTo;
		lastRun = (lastRun != null && lastRun > DateTime.now()) ? DateTime.now() : lastRun;
		run.Last_Run__c = lastRun;
		update run;
	}

	private static string[] getCareCompanyCode() {
		Set<string> uniqueCareCompanyCode = new Set<string>();
		for (Company__c cmp :Envir.cmps) {
			if (String.isNotBlank(cmp.Name)) {
				uniqueCareCompanyCode.add(cmp.Name);
			}
		}
		string[] ret = new string[]{};
		ret.addAll(uniqueCareCompanyCode);
		return ret;
	}

	public virtual class CareReq {
		public string Username;
		public string Password;
		public string DateFrom;
		public string DateTo;
		public string[] Company;
		public long RowCount;
	}

	public class ErrorTracking {
		public Object objFrom;
		public SObject objTo;
		public string message;
		public ErrorTracking(Object obj, string message) { this(obj, null, message); }
		public ErrorTracking(Object obj, SObject sobj, string message) {
			this.objFrom = obj;
			this.objTo = sobj;
			this.message = message;
		}
	}

	public class RowTracking {
		public Integer Added { get; private set; }
        public Integer Updated { get; private set; }
        public Integer Matched { get; private set; }
		public Integer Skipped {get; private set;}
        public Integer Total { get; private set; }
	    public RowTracking() {
	        Added = Updated = Matched = Skipped = Total = 0;
	    }
		public void AddOne() { Added++; Total++; }
		public void UpdateOne() { Updated++; Total++; }
		public void MatchOne() { Matched++; Total++; }
		public void SkipOne() { SKipped++; Total++; }
		public void AddTo(Integer count) { Added += count; Total += count; }
		public void UpdateTo(Integer count) { Updated += count; Total += count; }
		public void MatchTo(Integer count) { Matched += count; Total += count; }
		public void SkipTo(Integer count) { Skipped += count; Total += count; }
	}

	public class API_DEBUG {
		public string Method { get; private set; }
		public string Endpoint { get; private set; }
		public Map<string, string> Headers { get; private set; }
		public string RequestBody { get; private set; }
		public string Request { get {
			string ret = '';
			if (String.isNotBlank(Method) && String.isNotBlank(Endpoint)) {
				ret += Method + ' ' + Endpoint + '\n';
			}
			for (string key :Headers.keySet()) {
				ret += key + ': ' + Headers.get(key) + '\n';
			}
			if (String.isNotBlank(RequestBody)) { ret += '\n' + RequestBody + '\n'; }
			return ret;
		}}
		public Integer StatusCode { get; private set; }
		public string Status { get; private set; }
		public string ResponseBody { get; private set; }
		public Integer Rows { get; private set; }
		public string Response { get {
			string ret = '';
			if (StatusCode != null && String.isNotBlank(Status)) {
				ret += 'HTTP/1.1 ' + String.valueOf(StatusCode) + ' ' + Status + '\n';
			}
			if (String.isNotBlank(ResponseBody)) { ret += 'Size: ' + ResponseBody.length() + '\n'; }
			if (Rows != null) { ret += 'Rows: ' + String.valueOf(Rows) + '\n'; }
			if (String.isNotBlank(ResponseBody)) { ret += '\n' + ResponseBody + '\n'; }
			return ret;
		}}

		public API_DEBUG() { Headers = new Map<string, string>(); }
		public void parse(HttpRequest req) {
			if (req != null) {
				if (String.isNotBlank(req.getMethod()))		{ this.Method = req.getMethod(); }
				if (String.isNotBlank(req.getEndpoint()))	{ this.Endpoint = req.getEndpoint(); }
				if (String.isNotBlank(req.getBody()))		{ this.RequestBody = req.getBody(); }
				/** Reset headers */
				this.Headers = new Map<string, string>();
			}
		}
		public void parse(HttpRequest req, string[] headerKeys) {
			parse(req);
			if (headerKeys != null && headerKeys.size() > 0) {
				for (string key :headerKeys) {
					if (req.getHeader(key) != null) {
						setHeader(key, req.getHeader(key));
					}
				}
			}
		}
		public void parse(HttpResponse res) {
			if (res != null) {
				if (res.getStatusCode() != null)			{ this.StatusCode = res.getStatusCode(); }
				if (String.isNotBlank(res.getStatus()))		{ this.Status = res.getStatus(); }
				if (String.isNotBlank(res.getBody()))		{ this.ResponseBody = res.getBody(); }
			}
		}
		public void parse(Object[] objs) {
			if (objs != null) { Rows = objs.size(); }
		}
		public void setHeader(string key, string value) {
			this.Headers.put(key, value);
		}
		public void setRows(Integer rows) { this.Rows = rows; }
		public override string toString() {
			return 	(String.isNotBlank(Request) ? Request : '') + 
					(String.isNotBlank(Response) ? '\n' + Response.left(5242880) : '');
		}
	}

}