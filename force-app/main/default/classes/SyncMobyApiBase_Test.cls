@IsTest
public class SyncMobyApiBase_Test {

	@TestSetup
	public static void makeData(){
		Company__c[] cmps = TestFactory.genCompany(1, true);
		TestFactory.genApiSetup();
	}
	
	@IsTest
	static void testProperties() {
		string[] COMPANY = SyncMobyApiBase.COMPANY_CODE;
		User[] admins = SyncMobyApiBase.USER_ADMINS;
		User admin = SyncMobyApiBase.USER_ADMIN;
		User curUser = SyncMobyApiBase.USER_CUR;
		Organization org = SyncMobyApiBase.org;
		Boolean isSandbox = SyncMobyApiBase.isSandbox;
		string sbSuffix = SyncMobyApiBase.sbSuffix;
		string USERNAME = SyncMobyApiBase.USERNAME;
		string PASSWORD = SyncMobyApiBase.PASSWORD;
		string ENDPOINT = SyncMobyApiBase.ENDPOINT;
		string SYNC01USER = SyncMobyApiBase.SYNC01USER;
		string SYNC02CONT = SyncMobyApiBase.SYNC02CONT;
		string SYNC03LEAD = SyncMobyApiBase.SYNC03LEAD;
		string SYNC04OPPO = SyncMobyApiBase.SYNC04OPPO;
		string SYNC05TDRV = SyncMobyApiBase.SYNC05TDRV;
		string SYNC06BOOK = SyncMobyApiBase.SYNC06BOOK;
	}

	@isTest
	static string[] getServices() {
		 string[] services = new string[] { 
			'SyncMoby01User', 'SyncMoby02Contact', 'SyncMoby03Lead'
			, 'SyncMoby04Opportunity', 'SyncMoby05TestDrive', 'SyncMoby06Booking'
		};
		return services;
	}


}