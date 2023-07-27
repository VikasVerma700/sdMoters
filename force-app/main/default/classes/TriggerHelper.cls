public without sharing class TriggerHelper 
{
	public static Boolean bTriggerRun {get;set;}	
	public static Boolean bBeforeTriggerRun {get;set;}
	public static Boolean bBeforeInsertRun {get;set;}	
	public static Boolean bAfterInsertRun {get;set;}	
	public static Boolean bBeforeUpdateRun {get;set;}	
	public static Boolean bAfterTriggerRun {get;set;}
	public static Boolean bAfterUpdateRun {get;set;}
	public static Boolean bAfterDeleteRun {get;set;}
	public static Boolean bAfterUndeleteRun {get;set;}
	public static Boolean bFutureCallRun {get;set;}
	public static Boolean bFutureCallVORun {get;set;}
	public static Map<Id, RecordType> mapRecordTypes {get;set;}
	public static Map<String, Company__c> mapCompany {get;set;} 
	public static User currentUserInfo {get;set;}
	
	public static String getForceSiteURL(Boolean isSandbox)
	{
		String strSiteURL = '';
		
		Map<String, Force_com_Site_URL__c> mapForceSite = Force_com_Site_URL__c.getAll();
		
		system.debug('##mapForceSite: ' + mapForceSite);
		strSiteURL = mapForceSite.get('Production').URL__c;
		system.debug('##strSiteURL: ' + strSiteURL);
		system.debug('##isSandbox: ' + isSandbox);
		if(isSandbox)
		{
			strSiteURL = mapForceSite.get('Sandbox').URL__c;
		}
		return strSiteURL;
	}
}