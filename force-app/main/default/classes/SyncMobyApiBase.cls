public with sharing class SyncMobyApiBase {
	public static final string[] COMPANY_CODE;
	public static final User[] USER_ADMINS;
	public static final User USER_ADMIN;
	public static final User USER_CUR;
	public static final Organization org;
	public static final Boolean isSandbox;
	public static final string sbSuffix;
	public static final String USERNAME;
	public static final String PASSWORD;
	public static final String ENDPOINT;
	public static final Integer TIMEZONE = 8;
	public static final Integer INTERVAL = 60;

	public static final string SYNC01USER;
	public static final string SYNC02CONT;
	public static final string SYNC03LEAD;
	public static final string SYNC04OPPO;
	public static final string SYNC05TDRV;
	public static final string SYNC06BOOK;
	public static final string SYNC08SORD;

	static {
		COMPANY_CODE = getMobyCompanyCode();
		USER_ADMINS = Envir.USER_ADMINS;
		USER_ADMIN = Envir.USER_ADMIN;
		USER_CUR = Envir.USER_CUR;
		org = Envir.org;
		isSandbox = Envir.isSandbox;
		sbSuffix = Envir.sbSuffix;
		USERNAME = (IsSandbox) ? Api_Setup__c.getInstance('Sync Moby Dev Username')?.Value__c : Api_Setup__c.getInstance('Sync Moby Prd Username')?.Value__c;
		PASSWORD = (IsSandbox) ? Api_Setup__c.getInstance('Sync Moby Dev Password')?.Value__c : Api_Setup__c.getInstance('Sync Moby Prd Password')?.Value__c;
		ENDPOINT = (IsSandbox) ? Api_Setup__c.getInstance('Sync Moby Dev Endpoint')?.Value__c : Api_Setup__c.getInstance('Sync Moby Prd Endpoint')?.Value__c;
		SYNC01USER = 'SyncMoby01User';
		SYNC02CONT = 'SyncMoby02Contact';
		SYNC03LEAD = 'SyncMoby03Lead';
		SYNC04OPPO = 'SyncMoby04Opportunity';
		SYNC05TDRV = 'SyncMoby05TestDrive';
		SYNC06BOOK = 'SyncMoby06Booking';
		SYNC08SORD = 'SyncMoby08SalesOrder';
	}

	private static string[] getMobyCompanyCode() {
		Set<string> uniqueMobyCompanyCode = new Set<string>();
		for (Company__c cmp :Envir.cmps) {
			if (String.isNotBlank(cmp.MobyCompanyCode__c)) {
				uniqueMobyCompanyCode.add(cmp.MobyCompanyCode__c);
			}
		}
		string[] ret = new string[]{};
		ret.addAll(uniqueMobyCompanyCode);
		return ret;
	}

	public virtual class MobyReq {
		public string[] companyCode;
		public long[] id;
		public Datetime dateFrom;
		public Datetime dateTo;
		public long lastKey;
		public long rowCount;
	}
}