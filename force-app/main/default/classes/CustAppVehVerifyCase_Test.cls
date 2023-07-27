@IsTest
public class CustAppVehVerifyCase_Test {
	@TestSetup
	static void setup() {
		TestFactory.genTriggerSettings('Vehicle', true);
		TestFactory.genVO(1, true);
	}
	@IsTest
	static void testCase() {
		Vehicle_Ownership__c vo = [SELECT Id, Customer__c FROM Vehicle_Ownership__c LIMIT 1];
		CustAppVehicle.LtaVehCls veh = CustAppVehicle_Test.createVehCls('964D');
		CustAppVehVerifyCase caseCreator = new CustAppVehVerifyCase(vo.Id, veh, '028');
		Test.startTest();
		caseCreator.execute(null);
		Test.stopTest();
		List<Case> caseCheck = [SELECT Id FROM Case WHERE AccountId = :vo.Customer__c];
		System.assert(caseCheck.size() > 0);
	}
}