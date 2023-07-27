@IsTest
public class CustAppUser_Test {
	@IsTest
	static void testUser() {
		User testUser = Database.query('SELECT ' + String.join(CustAppUser.USER_FIELDS, ',') + ' FROM User WHERE IsActive = TRUE LIMIT 1');
		Test.startTest();
		CustAppUser.UserCls u = new CustAppUser.UserCls(testUser);
		Test.stopTest();
		System.assertEquals(u.name, testUser.Name);
	}

	@IsTest
	static void testEmployeeMaster() {
		TestFactory.genEmpMaster(1, true);
		Employee_Master__c em = Database.query('SELECT ' + String.join(CustAppUser.EMPMASTER_FIELDS, ',') + ' FROM Employee_Master__c LIMIT 1');
		Test.startTest();
		CustAppUser.UserCls u = new CustAppUser.UserCls(em);
		Test.stopTest();
		System.assertEquals(u.Name, em.Name);
	}
}