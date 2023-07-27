/**
 * Environment class
 * - Organization object
 * - Current User
 * - Admin User
 */
public class Envir {

	/** Organization - to determine if this is Sandbox */
	//public static Organization org = [Select Id, Name, InstanceName, IsSandbox From Organization Limit 1];
    public static Organization org{
        get{
            if(org == null){
                org = [
                    SELECT Id, Name, InstanceName, IsSandbox
                    FROM Organization
                    LIMIT 1
                ];
            }
            return org;
        }
        set;
    }
	public static Boolean isSandbox {
        get{
            return org.IsSandbox;
        } 
    }
	public static String sbSuffix { get {
			if (isSandbox) return UserInfo.getUserName().substringAfterLast('.');
			else return 'prod';
	}}

	/** Record Type - return list of record types */
	//private static RecordType[] rts = [SELECT Id, Name, IsActive, IsPersonType, Description, DeveloperName, NamespacePrefix, SobjectType, BusinessProcessId, CreatedById, CreatedDate, LastModifiedById, LastModifiedDate, SystemModstamp FROM RecordType];
    private static RecordType[] recordTypeList {
        get{
            if(recordTypeList == null){
                recordTypeList = [
                    SELECT Id, Name, IsActive, IsPersonType, Description, DeveloperName, NamespacePrefix,
                    SobjectType, BusinessProcessId, CreatedById, CreatedDate, LastModifiedById,
                    LastModifiedDate, SystemModstamp
                    FROM RecordType
                ];
            }
            return recordTypeList;
        }
        set;
    }
	public static Map<Id, RecordType> recordTypeById {
        get{
            if(recordTypeById == null){
                recordTypeById = new Map<Id,RecordType>();
                for (RecordType rt :recordTypeList) {
			        recordTypeById.put(rt.Id, rt);
                }
		    }
            return recordTypeById;
        }
        set;
    }

	public static Map<string, RecordType> recordTypeByName {
        get{
            if(recordTypeByName == null){
                recordTypeByName = new Map<string,RecordType>();
                for (RecordType rt :recordTypeList) {
			        recordTypeByName.put(rt.Name, rt);
                }
		    }
            return recordTypeByName;
        }
        set;
    }

	public static Map<string, RecordType> recordTypeByDevName {
        get{
            if(recordTypeByDevName == null){
                recordTypeByDevName = new Map<string,RecordType>();
                for (RecordType rt :recordTypeList) {
			        recordTypeByDevName.put(rt.DeveloperName, rt);
                }
		    }
            return recordTypeByDevName;
        }
        set;
    }

	public static Map<string, RecordType[]> recordTypeBySobjectType {
        get{
            if(recordTypeBySobjectType == null){
                recordTypeBySobjectType = new Map<string,RecordType[]>();
                for (RecordType rt :recordTypeList) {
			        RecordType[] recordTypeListBySobject = recordTypeBySobjectType.get(rt.SobjectType);
                    if(recordTypeListBySobject == null){
                        recordTypeListBySobject = new List<RecordType>();
                    }
                    recordTypeListBySobject.add(rt);
                    recordTypeBySobjectType.put(rt.SobjectType,recordTypeListBySobject);
                }
		    }
            return recordTypeBySobjectType;
        }
        set;
    }

	/** Site */
	public static Map<string, SiteDetail> siteDetailList {
		get {
			if (siteDetailList == null) {
				siteDetailList = new Map<string, SiteDetail>();

				Site[] sites = [SELECT Id, Name, MasterLabel, Subdomain, UrlPathPrefix FROM Site];
				Map<Id, Site> id2Site = new Map<Id, Site>();
				for (Site site :sites) {
					if (site?.Id == null) { continue; }
					id2Site.put(site.Id, site);
				}
				
				SiteDetail[] details = [SELECT Id, DurableId, SecureUrl FROM SiteDetail WHERE DurableId IN :id2Site.keySet()];
				for (SiteDetail detail :details) {
					if (detail?.Id == null || id2Site.get(detail.DurableId) == null) { continue; }
					siteDetailList.put(id2Site.get(detail.DurableId).MasterLabel, detail);
				}
			}
			return siteDetailList;
		}
		set;
	}

	/** User - return current/admin user object mainly for exception email */
	private static User[] userList = [SELECT Id, Name, Alias, Email, Company__c, IsActive, Profile.Name FROM User ORDER BY CreatedDate];
	public static User user_Cur;
	public static User[] USER_ADMINS;
	public static User USER_ADMIN;

	/** Company__c */
	public static Company__c[] cmps = [SELECT Id, Name, Description__c, MobyCompanyCode__c FROM Company__c];

	/** Email */
	public static final string subject;

	static {
        /*
		recordTypeByName = new Map<string, RecordType>();
		recordTypeByDevName = new Map<string, RecordType>();
		recordTypeBySobjectType = new Map<string, RecordType[]>();
		for (RecordType rt :recordTypeList) {
			recordTypeByName.put(rt.Name, rt);
			recordTypeByDevName.put(rt.DeveloperName, rt);
			if (recordTypeBySobjectType.containsKey(rt.SobjectType)) {
				RecordType[] lrts = recordTypeBySobjectType.get(rt.SobjectType);
				lrts.add(rt);
			}
			else {
				RecordType[] lrts = new RecordType[] { rt };
				recordTypeBySobjectType.put(rt.SobjectType, lrts);
			}
		}
        */
		USER_ADMINS = new User[]{};
		for (User usr :userList) {
			if (usr.Id == UserInfo.getUserId()) { USER_CUR = usr; }
			if (usr.Profile.Name == 'System Administrator' && usr.IsActive) { USER_ADMINS.add(usr); }
		}
		USER_ADMIN = (USER_ADMINS.size() > 0) ? USER_ADMINS[0] : null;
		subject = String.format('[Salesforce] {0} ({1}) [{2}]', new string[] { org.Name, org.Id, sbSuffix });
	}

}