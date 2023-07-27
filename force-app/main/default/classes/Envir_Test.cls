@IsTest
public class Envir_Test {

	@TestSetup
	static void makeData(){
		Company__c[] cmp = TestFactory.genCompany(1, true);
	}

	@IsTest
	static void testOrganization() {
		boolean isSandbox = Envir.isSandbox;
		string sbSuffix = Envir.sbSuffix;
	}

	@IsTest
	static void testUsers() {
		User userCurr = Envir.USER_CUR;
		System.assertEquals(UserInfo.getUserId(), userCurr?.Id, 'Current user is invalid.');
		User[] userAdmins = [SELECT Id, Name FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true ORDER BY CreatedDate];
		System.assertEquals(userAdmins.size(), Envir.USER_ADMINS.size(), 'Profile: System Administrator users count doesn\'t match.');
		System.assertEquals(userAdmins[0].Id, Envir.USER_ADMIN.Id, 'First System Administrator user don\'t match.');
	}

	@isTest
	static void testRecordTypeList() {
		Map<Id, RecordType> id2RecordType = Envir.recordTypeById;
		Map<string, RecordType> name2RecordType = Envir.recordTypeByName;
		Map<string, RecordType> devName2RecordType = Envir.recordTypeByDevName;
		Map<string, RecordType[]> sObject2RecordType = Envir.recordTypeBySobjectType;

	}

	@isTest
	static void testSiteDetailList() {
		Map<string, SiteDetail> siteName2Detail = Envir.siteDetailList;
	}
}