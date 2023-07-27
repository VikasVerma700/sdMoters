trigger ServiceOrderTrigger on ServiceOrder__c (before insert /*, before update */) {
	// Set<string> co = new Set<string>();	// company
	// Set<string> ws = new Set<string>();	// workshop
	// Set<string> ve = new Set<string>();	// vehicle
	// Set<string> rn = new Set<string>(); // reg. no.

	// for (ServiceOrder__c so: Trigger.new) {
	// 	if (String.isNotBlank(so.CompanyCode__c))		{ co.add(so.CompanyCode__c); }
	// 	if (String.isNotBlank(so.WorkshopCode__c))		{ ws.add(so.WorkshopCode__c); }
	// 	if (String.isNotBlank(so.ChassisNo__c))			{ ve.add(so.ChassisNo__c); }
	// 	if (String.isNotBlank(so.RegistrationNo__c))	{ rn.add(so.RegistrationNo__c); }
	// }

	// /** CompanyCode__c => Company__c.Id */
	// Map<string, Id> mco = new Map<string, Id>();
	// Company__c[] cos = [SELECT Id, Name FROM Company__c WHERE Name IN :co];
	// for (Company__c c :cos) { mco.put(c.Name, c.Id); }

	// /** WorkshopCode__c => Workshop__c.Id */
	// Map<string, Id> mws = new Map<string, Id>();
	// Workshop__c[] wss = [SELECT Id, Name, Company__r.Name FROM Workshop__c WHERE Name IN :ws And Company__r.Name IN :co];
	// for (Workshop__c w: wss) { mws.put(string.format('{0}|{1}', new string[] { w.Company__r.Name, w.Name }), w.Id); }

	// /** ChassisNo__c => Vehicle__c.Id */
	// Map<string, Id> mve = new Map<string, Id>();
	// Vehicle__c[] ves = [SELECT Id, Name FROM Vehicle__c WHERE Name IN :ve];
	// for (Vehicle__c v :ves) { mve.put(v.Name, v.Id); }

	// /** ChassisNo__c => Vehicle__c => VehicleOwnership */
	// Map<string, Vehicle_Ownership__c> mvo = new Map<string, Vehicle_Ownership__c>();
	// Vehicle_Ownership__c[] vos = [
	// 	SELECT
	// 		Id, Chassis_No__c, Registration_No__c, Customer__r.Id
	// 	FROM Vehicle_Ownership__c
	// 	WHERE Chassis_No__c IN :ve
	// 	AND Registration_No__c IN :rn
	// 	AND Status__c = 'Active'
	// ];
	// for (Vehicle_Ownership__c vo :vos) {
	// 	string voKey = String.format('{0}_{1}', new string[] { vo.Chassis_No__c, vo.Registration_No__c });
	// 	mvo.put(voKey, vo);
	// }

	// /** Update record with reference id's. */
	// string regex = '[^0-9]';
	// for (ServiceOrder__c so :Trigger.new) {
	// 	so.Name = so.WorkshopCode__c + ' ' + so.RepairOrderNo__c;

	// 	string cows = string.format('{0}|{1}', new string[] { so.CompanyCode__c, so.WorkshopCode__c });
	// 	if (mco.containsKey(so.CompanyCode__c))	{ so.Company__c = mco.get(so.CompanyCode__c); }
	// 	if (mws.containsKey(cows))				{ so.Workshop__c = mws.get(cows); }
	// 	if (mve.containsKey(so.ChassisNo__c))	{ so.Vehicle__c = mve.get(so.ChassisNo__c); }
	// 	string soKey = String.format('{0}_{1}', new string[] { so.ChassisNo__c, so.RegistrationNo__c });
	// 	if (mvo.containsKey(soKey)) {
	// 		Vehicle_Ownership__c vo = mvo.get(soKey);
	// 		so.VehicleOwnership__c = vo.Id;
	// 		so.Account__c = vo.Customer__r.Id;
	// 	}

	// 	/** PhoneNumber__c => ContactPhone__c */
	// 	try { so.ContactPhone__c = so.PhoneNumber__c.replaceAll(regex, ''); }
	// 	catch (Exception e) {}
	// }
}