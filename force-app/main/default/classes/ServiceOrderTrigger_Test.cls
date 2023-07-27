@isTest
public class ServiceOrderTrigger_Test {
    
	private static testMethod void test01() {
		Company__c[] cos = TestFactory.genCompany(1, true);
		cos = [Select Id, Name From Company__c];
		Workshop__c[] wos = TestFactory.genWorkshop(1, true);
		wos = [Select Id, Name From Workshop__c];
		Vehicle_Ownership__c[] vos = TestFactory.genVO(1, true);
		vos = [Select Id, Name, Chassis_No__c From Vehicle_Ownership__c];
		Account[] acs = [Select Id, Name From Account];
		Vehicle__c[] ves = [Select Id, Name From Vehicle__c];
		/** Update Lookup fields */
		for (Company__c c :cos) {
			for (Workshop__c w :wos) {
				w.Company__c = c.Id;
			}
		}
		update wos;

		ServiceOrder__c[] sos = new List<ServiceOrder__c>();
		for (Company__c c :cos) {
			for (Workshop__c w :wos) {
				for (Vehicle_Ownership__c vo :vos) {
					ServiceOrder__c so = new ServiceOrder__c();
					so.Name = 'A';
					so.CompanyCode__c = c.Name;
					so.WorkshopCode__c = w.Name;
					so.ChassisNo__c = vo.Chassis_No__c;
					so.ContactName__c = 'Apex Test User';
					so.ContactPhone__c = '+60192651650';
					sos.add(so);
				}
			}
		}
		insert sos;
	}
}