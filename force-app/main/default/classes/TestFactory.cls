/*
	The following test helper has two main sections:

	1. TEST UTILITIES
	Any generic helper functions for classes should be included here.
	Try to keep the methods as generic as possible.

	2. DATA FACTORY FUNCTIONS
	Any data generation should be done here. Of course, given the scale of our SF instance,
	sometimes the objects are to complicated and we have to use SeeAllData. But if it is
	simple enough, then go ahead and try to create the object here instead.

	As much as possible, generation should occur in bulk

 */
@isTest
public class TestFactory {
	private static Integer UNIQUE_COUNT = 0;
	private static Integer MS_COUNT = 0;
	private static Map<String, Company__c> cmpMap = new Map<String, Company__c>();
	///////////////////////////////////////////////////////////////////////////
	// TEST UTILITIES /////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////////

	public static Profile getProfile(String profileName) {
		return [SELECT Id FROM Profile WHERE Name = :profileName];
	}

	public static UserRole getRole(String roleName) {
		return [SELECT Id FROM UserRole WHERE Name = :roleName];
	}

	public static Company__c getCompany(String companyCode) {
		/*
		Company__c cmp = cmpMap.get(companyCode);
		if (cmp != null) { return cmp; }
		try {
			cmp = [SELECT Id, Name, MobyCompanyCode__c FROM Company__c WHERE Name = :companyCode LIMIT 1];
		} catch (QueryException e) {
			cmp = genCompany(1, false)[0];
			cmp.Name = companyCode;
			insert cmp;
		}
		cmpMap.put(companyCode, cmp);
		*/

		Company__c cmp;
		try {
			cmp = CompanyRepository.name2Company.get(companyCode);
			if (cmp == null) {
				cmp = genCompany(1, false)[0];
				cmp.Name = companyCode;
				insert cmp;
			}
			System.debug(cmp);
		}
		catch (Exception e) {
			cmp = genCompany(1, false)[0];
			cmp.Name = companyCode;
			insert cmp;
			System.debug('cmp exception');
		}
		System.debug(CompanyRepository.name2Company.get(companyCode));
		// return CompanyRepository.name2Company.get(companyCode);
		return cmp;
	}

	public static String getUnique() {
		Integer getTime = Integer.valueOf(Math.mod(DateTime.now().getTime(), 100000));
		if (getTime != MS_COUNT) {
			UNIQUE_COUNT = 0;
			MS_COUNT = getTime;
		} else {
			UNIQUE_COUNT++;
		}
		return MS_COUNT + '' + UNIQUE_COUNT;
		/*String cnt = UNIQUE_COUNT.format();
		UNIQUE_COUNT++;
		return cnt;*/
	}

	///////////////////////////////////////////////////////////////////////////
	// DATA FACTORY ///////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////////

	/**
	 * generic helper function to create users
	 * @param  numCreate number of users to create
	 * @param  addtoDB    boolean on whether to commit to db
	 * @return           list of users created
	 */
	public static List<User> genUser(Integer numCreate, Boolean addtoDB) {
		List<User> users = new List<User>();
		User newUser;
		Id profId = getProfile('System Administrator').Id;
		for (Integer i = 0; i < numCreate; i++) {
			newUser = new User();
			newUser.IsActive = true;
			newUser.FirstName = 'Test' + getUnique();
			newUser.LastName = getUnique();
			newUser.Email = getUnique() + '@example.com';
			newUser.Company__c = '028';
			newUser.Username = getUnique() + '@pml.com';
			newUser.Alias = 'A' + getUnique();
			newUser.CommunityNickname = 'test' + getUnique();
			newUser.TimeZoneSidKey = 'Asia/Singapore';
			newUser.LocaleSidKey = 'en_SG';
			newUser.EmailEncodingKey = 'ISO-8859-1';
			newUser.LanguageLocaleKey = 'en_US';
			newUser.ProfileId = profId;
			users.add(newUser);
		}
		if (addtoDB) {
			insert users;
		}
		return users;
	}


	public static List<User_Config__c> genUserConfig(Integer numCreate, Boolean addtoDB) {
		List<User_Config__c> userConfigs = new List<User_Config__c>();
		List<User> users = genUser(numCreate, true);
		User_Config__c newUserConfig;
		for (Integer i = 0; i < numCreate; i++) {
			newUserConfig = new User_Config__c();
			newUserConfig.User__c = users[i].Id;
			userConfigs.add(newUserConfig);
		}
		if (addtoDB) {
			insert userConfigs;
		}
		return userConfigs;
	}


	public static List<Account> genAccount(Integer numCreate, Boolean addToDB) {
		User u = [SELECT Id FROM User WHERE Alias = 'godlike' LIMIT 1];
		List<Account> accList = new List<Account>();
		// List<User> users = genUser(numCreate, true);
		Account acc;
		for (Integer i = 0; i < numCreate; i++) {
			acc = new Account();
			acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
			acc.Salutation = 'Mr';
			acc.LastName = 'test ' + getUnique();
			acc.OwnerId = u.Id;
			acc.Country__c = 'United States';
			acc.Doc_Type__c = 'Foreign Document/Passport';
			acc.NRIC_Number__c = 'PSFDC999' + getUnique();
			acc.Partial_NRIC__c = acc.NRIC_Number__c.right(4);
			acc.Gender__pc = 'Male';
			acc.Race__pc = 'Chinese';
			acc.Mobile_Country_Code_1__pc = 60;
			string phone = String.valueOf(acc.Mobile_Country_Code_1__pc) + ('12' + getUnique()).left(12);
			UtilPhone up = new UtilPhone(phone);
			acc.Mobile_Preferred__pc = up.toNoPrefixNumber();
			// acc.PersonMobilePhone = UtilPhone.toE164(String.valueOf(acc.Mobile_Country_Code_1__pc) + acc.Mobile_Preferred__pc);
			acc.PersonMobilePhone = up.toE164();
			acc.Model_Interest__c = '1 Series';
			acc.Customer_Number__c = Long.valueOf('1234' + i);
			accList.add(acc);
		}

		if (addToDB) {
			System.debug('accList: ' + JSON.serialize(accList));
			insert accList;
		}
		return accList;
	}
	public static List<Account> genBusinessAccount(Integer numCreate, Boolean addToDB) {
		List<Account> accList = new List<Account>();
		List<User> users = genUser(numCreate, true);
		Account acc;
		for (Integer i = 0; i < numCreate; i++) {
			acc = new Account();
			acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business Account').getRecordTypeId();
			acc.Name = 'test ' + getUnique();
			acc.OwnerId = users.get(i).Id;
			acc.Country__c = 'United States';
			acc.Doc_Type__c = ' Company (e.g. 198912345K)';
			acc.NRIC_Number__c = 'A198912345' + getUnique();
			acc.Model_Interest__c = '1 series';
			accList.add(acc);
		}

		if (addToDB) {
			insert accList;
		}
		return accList;
	}

	public static List<Vehicle_Ownership__c> genVO(Integer numCreate, Boolean addToDB) {
		List<Account> dummyAcc = [SELECT Id FROM Account WHERE Name = 'Pls key into Salesforce updated owner details'];
		if (dummyAcc.size() <= 0) { genVODummy(true); }
		List<Vehicle_Ownership__c> voList = new List<Vehicle_Ownership__c>();
		Vehicle_Ownership__c vo;
		List<Vehicle__c> vehList = genVehicle(numCreate, true);
		List<Account> accList = genAccount(numCreate, true);
		for (Integer i = 0; i < numCreate; i++) {
			vo = new Vehicle_Ownership__c();
			vo.Start_Date__c = Date.today();
			vo.Vehicle__c = vehList[i].Id;
			vo.Customer__c = accList[i].Id;
			vo.Registration_No__c = vehList[i].Registration_Number__c;
			vo.VehicleOwnershipNumber__c = Long.valueOf('1234' + i);
			voList.add(vo);
		}
		if (addToDB) {
			insert voList;
		}
		return voList;
	}

	public static List<Service_Appointment__c> genSvcAppt(Integer numCreate, Boolean addToDB) {
		List<Service_Appointment__c> saList = new List<Service_Appointment__c>();
		Service_Appointment__c sa;
		List<Employee_Shift__c> esList = TestFactory.genEmpShift(numCreate, true);
		List<Account> acc = genAccount(numCreate, true);
		List<Vehicle_Ownership__c> voList = genVO(numCreate, true);
		Id cmpId = getCompany('028').Id;
		Time apptTime = Time.newInstance(12, 12, 12, 12);
		for (Integer i = 0; i < numCreate; i++) {
			sa = new Service_Appointment__c();
			sa.Account__c = acc.get(i).Id;
			sa.Apppointment_Status__c = 'ACTIVE';
			sa.Appt_Type__c = 'Service Appointment';
			sa.Company__c = cmpId;
			sa.Appointment_Date__c = DateTime.newInstance(esList[i].Active_Date__c, apptTime);
			sa.Employee_Master__c = esList[i].Employee_Master__c;
			sa.Workshop__c = esList[i].Workshop__c;
			sa.System_Control__c = true;
			sa.Vehicle_Ownership__c = voList[i].Id;
			saList.add(sa);
		}

		if (addToDB) {
			insert saList;
		}

		return saList;
	}

	public static List<Account_Profile_With_Business_Unit__c> genAPBU(Integer numCreate, Boolean addToDB) {
		List<Account_Profile_With_Business_Unit__c> apbuList =  new List<Account_Profile_With_Business_Unit__c>();
		Account_Profile_With_Business_Unit__c apbu;
		List<Account> acc = genAccount(numCreate, true);
		List<User> userList = genUser(numCreate, true);
		Id cmpId = getCompany('028').Id;
		for (Integer i = 0; i < numCreate; i++) {
			apbu = new Account_Profile_With_Business_Unit__c();
			apbu.Company__c = cmpId;
			apbu.Account_Name__c = acc.get(i).Id;
			apbu.Assigned_Representative__c = userList[i].Id;
			apbuList.add(apbu);
		}

		if (addToDB) {
			insert apbuList;
		}

		return apbuList;
	}

	public static List<Company__c> genCompany(Integer numCreate, Boolean addToDB) {
		List<Company__c> cList = new List<Company__c>();
		Company__c c;
		for(Integer i = 0; i < numCreate; i++) {
			c = new Company__c();
			c.Name = '028';
			c.Description__c = '028-Auto Bavaria';
			c.MobyCompanyCode__c = 'SDAB';
			cList.add(c);
		}
		if (addToDB) {
			insert cList;
		}
		return cList;
	}

	public static List<Workshop__c> genWorkshop(Integer numCreate, Boolean addTODB) {
		List<Workshop__c> wList = new List<Workshop__c>();
		Workshop__c w;
		for(Integer i = 0; i < numCreate; i++) {
			w = new Workshop__c();
			w.Name = 'W1'+getUnique();
			w.Appointment_Interval__c = 20;
			w.IsActive__c = true;
			wList.add(w);
		}
		if (addTODB) {
			insert wList;
		}
		return wList;
	}

	public static List<CampaignMember> genCampaignMember(Integer numCreate, Boolean addToDB) {
		Campaign cmpg = genCampaign(1, true)[0];
		List<CampaignMember> cmList = new List<CampaignMember>();
		CampaignMember cm;
		List<Account> accList = genAccount(numCreate, true);
		List<Id> accIds = new List<Id>();
		for (Integer i = 0; i < numCreate; i++) {
			accIds.add(accList[i].Id);
		}
		accList = [SELECT Id, PersonContactId FROM Account WHERE Id = :accIds];

		for (Integer i = 0; i < numCreate; i++) {
			cm = new CampaignMember();
			cm.ContactId = accList[i].PersonContactId;
			cm.Status = 'Responded';
			cm.RSVP_Status__c = 'Arrived';
			cm.Account_Name__c = accList[i].Id;
			cm.CampaignId = cmpg.Id;
			cmList.add(cm);
		}

		if (addToDB) {
			insert cmList;
		}

		return cmList;
	}

	public static List<Vehicle_Stock_Master__c> genVehicleStockMaster(Integer numCreate, Boolean addToDB) {
		List<Vehicle_Stock_Master__c> vehStockList = new List<Vehicle_Stock_Master__c>();
		Vehicle_Stock_Master__c v;
		List<Vehicle__c> vehList = genVehicle(numCreate, true);
		Id pmlId = getCompany('028').Id;
		// Exclusive for vehicle stock master requires 05 company
		Id ppslId = getCompany('05').Id;
		for (Integer i = 0; i < numCreate; i++) {
			v = new Vehicle_Stock_Master__c();
			v.Chassis__c = vehList[i].Id;
			v.Name = '999' + getUnique();
			v.Company__c = pmlId;
			// v.Workshop_Vehicle__c = true;
			vehStockList.add(v);
		}

		if (addTODB) {
			insert vehStockList;
		}

		return vehStockList;
	}

	public static List<Vehicle__c> genVehicle(Integer numCreate, Boolean addToDB) {
		List<Vehicle__c> vehList = new List<Vehicle__c>();
		Vehicle__c v;
		for (Integer i = 0; i < numCreate; i++) {
			v = new Vehicle__c();
			v.Name = i + getUnique().rightPad(16, '0').left(16);
			v.Full_Chassis__c = i + getUnique().rightPad(16, '0').left(16);
			v.Registration_Number__c = i + getUnique().right(8);
			v.Registration_Date__c = Date.today();
			v.Vehicle_Number__c = Long.valueOf('1234' + i);
			vehList.add(v);
		}

		if (addTODB) {
			insert vehList;
		}

		return vehList;
	}

	/**
	 * note that since attachments must be tagged to a particular object, the addToDB option is removed
	 * @param  numCreate [number of attachments to create]
	 * @return           [attachment list]
	 */
	public static List<Attachment> genAttachment(Integer numCreate) {
		List<Attachment> attList = new List<Attachment>();
		Attachment att;
		for (Integer i = 0; i < numCreate; i++) {
			att = new Attachment();
			att.Name = 'att ' + getUnique();
			att.Body = Blob.valueOf('Content ' + getUnique());
			attList.add(att);
		}

		return attList;
	}

	public static List<Campaign> genCampaign(Integer numCreate, Boolean addToDB) {
		List<Campaign> camList = new List<Campaign>();
		Campaign c;
		Id cmpId = getCompany('028').Id;
		for (Integer i = 0; i < numCreate; i++) {
			c = new Campaign();
			c.Name = 'Test Campaign ' + getUnique();
			c.Company__c = cmpId;
			c.IsActive = true;
			// c.EventStartDate__c = Datetime.now();
			// c.EventEndDate__c = Datetime.now();
			// c.Auto_Create_Opportunity__c = true;
			// c.Auto_Schedule_Campaign_Follow_Up_Task__c = true;
			// c.Trigger_Time_for_Auto_Creation__c = 'Immediate';
			// c.Auto_Creation_Opportunity_Base_On__c = 'Arrival_Date_Time__c';
			// c.Trigger_Date_for_No_Show__c = date.today();
			// (REMOVED FIELD) c.Opportunity_Record_Type_ID__c = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Opportunity RT').getRecordTypeId();
			// c.Opportunity_Close_Date__c = date.today();
			// c.Opportunity_Type__c = 'Vehicle Sales';
			// c.Model_Interest__c = '7 Series';
			// c.Sales_Offer_Reference__c = 'PL7SNOV2015';
			// c.Team__c = 'BMW';
			// c.RecordTypeId = Schema.SObjectType.Campaign.getRecordTypeInfosByName().get('BMW - Campaigns').getRecordTypeId();
			camList.add(c);
		}

		if (addTODB) {
			insert camList;
		}

		return camList;
	}

	public static List<Opportunity> genOpportunity(Integer numCreate, Boolean addToDB) {
		List<Opportunity> oppList = new List<Opportunity>();
		List<Account> accList = genAccount(numCreate, true);
		List<User> userList = genUser(numCreate, true);
		Opportunity newOpp;
		Id cmpId = getCompany('028').Id;
		for (Integer i = 0; i < numCreate; i++) {
			newOpp = new Opportunity();
			newOpp.AccountId = accList[i].Id;
			newOpp.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Opportunity RT').getRecordTypeId();
			newOpp.Type = 'Vehicle Sales';
			newOpp.OwnerId = userList[i].Id;
			newOpp.Sales_Rep_Name__c = userList[i].Id;
			newOpp.Company__c = cmpId;
			newOpp.StageName = 'Prospecting';
			newOpp.Opportunity_Stage__c = 'Prospecting';
			newOpp.CloseDate = Date.today() + 30;
			newOpp.Planned_Purchase_Date__c = Date.today() + 30;
			newOpp.Name = 'test'; // filled up by workflow
			newOpp.Previous_Stage__c = 'Prospecting';
			newOpp.Sales_Offer_Reference__c = 'Test';
			oppList.add(newOpp);
		}

		if (addToDB) {
			insert oppList;
		}

		return oppList;
	}

	public static List<Sales_Order__c> genSO(Integer numCreate, Boolean addToDB){
		List<Sales_Order__c> soList = new List<Sales_Order__c>();
		Sales_Order__c newSO = new Sales_Order__c();
		List<Opportunity> oppList = genOpportunity(numCreate,true);
		Id cmpId = getCompany('028').Id;
		for (Integer i = 0; i < numCreate; i++) {
			newSO = new Sales_Order__c();
			soList.add(newSO);
			newSO.Opportunity__c = oppList[i].Id;
			newSO.Account__c = oppList[i].AccountId;
			newSO.Company__c = cmpId;
			newSO.eVSA_Status__c = 'DRAFT';
		}

		if (addToDB) {
			insert soList;
		}

		return soList;
	}
	public static List<Vehicle_Model__c> genVehModel(Integer numCreate, Boolean addToDB) {
		List<Vehicle_Model__c> vModelList = new List<Vehicle_Model__c>();
		Vehicle_Model__c vM;
		Vehicle_Type__c vType = genVehType('NC', true);
		Vehicle_Make__c vMake = genVehMake('BMW', true);
		Id cmpId = getCompany('028').Id;
		for (Integer i = 0; i < numCreate; i++) {
			vM = new Vehicle_Model__c();
			vM.Name = 'Model ' + getUnique();
			vM.Short_Description__c = vM.Name;
			// vM.Available_for_Selection_Reception__c = true;
			vM.Company__c = cmpId;
			vM.Vehicle_Make__c = vMake.Id;
			vM.Vehicle_Type__c = vType.Id;
			vM.Description__c = 'Test' + getUnique();
			// vM.Vehicle_Model_Brochure__c = 'test';
			// vM.Engine_Power__c = 100;
			vModelList.add(vM);
		}

		if (addToDB) {
			insert vModelList;
		}

		return vModelList;
	}

	public static List<Employee_Master__c> genEmpMaster(Integer numCreate, Boolean addToDB) {
		List<Employee_Master__c> emList = new List<Employee_Master__c>();
		Id cmpId = getCompany('028').Id;
		Employee_Master__c em;
		List<Workshop__c> w = genWorkshop(numCreate, true);
		for (Integer i = 0; i < numCreate; i++) {
			em = new Employee_Master__c();
			em.Name = 'test' + getUnique();
			em.Allow_Appt_External__c = true;
			em.Allow_Appt_Internal__c = true;
			em.Employee_Status_Code__c = 'CA';
			em.IsActive__c = true;
			em.Company__c = cmpId;
			em.Employee_Reference__c = '1234';
			em.Workshop__c = w[i].Id;
			emList.add(em);
		}

		if (addToDB) {
			insert emList;
		}

		return emList;
	}

	// public static List<Employees_Shift_Maintenance__c> genEmpShftMaint(Integer numCreate, Boolean addToDB) { return genEmpShiftMaint(numCreate, addToDB); }
	// public static List<Employees_Shift_Maintenance__c> genEmpShiftMaint(Integer numCreate, Boolean addToDB) {
	// 	List<Employees_Shift_Maintenance__c> esmList = new List<Employees_Shift_Maintenance__c>();
	// 	List<Employee_Master__c> em = genEmpMaster(numCreate, true);
	// 	Employees_Shift_Maintenance__c esm;
	// 	List<Workshop__c> w = genWorkshop(numCreate, true);
	// 	for (Integer i = 0; i < numCreate; i++) {
	// 		esm = new Employees_Shift_Maintenance__c();
	// 		esm.Employee_Name__c = em[i].Id;
	// 		esm.Company__c = em[i].Company__c;
	// 		esm.Workshop__c = w[i].Id;
	// 		esm.Start_Date__c = Date.today().addDays(i+1);
	// 		//esm.End_Date__c = Date.today().addDays(i+7);
	// 		esm.End_Date__c = Date.today().addDays(i+2);
	// 		esm.Appointment_Slots__c = 10;
	// 		esmList.add(esm);
	// 	}

	// 	if (addToDB) {
	// 		insert esmList;
	// 	}

	// 	return esmList;
	// }

	// public static List<Employees_Shift_Unproductive_Transaction__c> genEmpShiftUnTrans(Integer numCreate, Boolean addToDB) {
	// 	List<Employees_Shift_Unproductive_Transaction__c> esutList = new List<Employees_Shift_Unproductive_Transaction__c>();
	// 	List<Employees_Shift_Maintenance__c> esm = genEmpShiftMaint(numCreate,true);
	// 	Employees_Shift_Unproductive_Transaction__c esut;
	// 	for (Integer i = 0; i < numCreate; i++) {
	// 		esut = new Employees_Shift_Unproductive_Transaction__c();
	// 		esut.ESM_Name__c = esm[i].Id;
	// 		esut.Employee_Name__c = esm[i].Employee_Name__c;
	// 		esut.offdate__c = Date.today().addDays(i+1);
	// 		esut.Total_Unavailable_Slots__c = 2;
	// 		esutList.add(esut);
	// 	}

	// 	if (addToDB) {
	// 		insert esutList;
	// 	}

	// 	return esutList;
	// }

	public static List<Employee_Shift__c> genEmpShift(Integer numCreate, Boolean addToDB) {
		List<Employee_Shift__c> esList = new List<Employee_Shift__c>();
		List<Employee_Master__c> emList = genEmpMaster(numCreate, true);
		Employee_Shift__c es;
		Time t = Time.newInstance(9, 0, 0, 0);
		for (Integer i = 0; i < numCreate; i++) {
			es = new Employee_Shift__c();
			es.Employee_Master__c = emList[i].Id;
			es.Company__c = emList[i].Company__c;
			es.Workshop__c = emList[i].Workshop__c;
			es.Active_Date__c = Date.today().addDays(7);
			es.Maximum_Appointment__c = 8;
			esList.add(es);
		}

		if (addToDB) {
			insert esList;
		}

		return esList;
	}

	public static List<Service_Slot__c> genServiceSlot(Integer numCreate, Boolean addToDB) {
		List<Service_Slot__c> slotList = new List<Service_Slot__c>();
		Service_Slot__c slot;
		Workshop__c ws = genWorkshop(1, true)[0];
		Company__c pml = getCompany('028');
		Date startD = Date.today().addDays(1);
		for (Integer i = 0; i < numCreate; i++) {
			slot = new Service_Slot__c();
			slot.Company__c = pml.Id;
			slot.Workshop__c = ws.Id;
			slot.Active_Date__c = startD.addDays(i);
			slotList.add(slot);
		}
		if (addToDB) {
			insert slotList;
		}
		return slotList;
	}

	public static List<Service_Quota__c> genServiceQuota(Integer numCreate, Boolean addToDB){
		List<Service_Quota__c> sqList = new List<Service_Quota__c>();
		Service_Quota__c sq;
		Service_Slot__c ss = genServiceSlot(2, true)[1]; // 2-day ahead

		for (Integer i = 0; i < numCreate; i++) {
			sq = new Service_Quota__c();
			sq.Max_Appt_Per_Timeslot__c = 1;
			sq.Max_Quota__c = 1;
			sq.Interval_Per_Appt__c = 1;
			sq.Service_Slot__c = ss.Id;
			sq.Start_Time__c = DateTime.newInstance(ss.Active_Date__c, Time.newInstance(8,0,0,0));
			sq.End_Time__c = DateTime.newInstance(ss.Active_Date__c, Time.newInstance(11,0,0,0));
			sq.Type__c = 'test' + getUnique();
			sqList.add(sq);
		}

		if (addToDB) {
			insert sqList;
		}

		return sqList;
	}

	public static List<Service_Quota__c> genCSAServiceQuota(Integer numCreate, Boolean addToDB) {
		List<Service_Quota__c> sqList = new List<Service_Quota__c>();
		Service_Quota__c sq;
		Employee_Shift__c es = genEmpShift(1, true)[0];
		for (Integer i = 0; i < numCreate; i++) {
			sq = new Service_Quota__c();
			sq.Max_Quota__c = 1;
			sq.Interval_Per_Appt__c = 1;
			sq.Employee_Shift__c = es.Id;
			sq.Start_Time__c = DateTime.newInstance(es.Active_Date__c, Time.newInstance(8,0,0,0));
			sq.End_Time__c = DateTime.newInstance(es.Active_Date__c, Time.newInstance(11,0,0,0));
			sq.Type__c = 'test' + getUnique();
			sqList.add(sq);
		}
		if (addToDB) {
			insert sqList;
		}
		return sqList;
	}

	public static List<Appointment_Utilization__c> genApptUtilization(Integer numCreate, Boolean addToDB){
		List<Appointment_Utilization__c> auList = new List<Appointment_Utilization__c>();
		Appointment_Utilization__c au;
		List<Service_Quota__c> sqList = genServiceQuota(numCreate,true);
		List<Service_Appointment__c> saList = genSvcAppt(numCreate,true);

		for (Integer i = 0; i < numCreate; i++) {
			au = new Appointment_Utilization__c();
			au.Service_Quota__c = sqList[i].Id;
			au.Service_Appointment__c = saList[i].Id;
			auList.add(au);
		}

		if (addToDB) {
			insert auList;
		}

		return auList;
	}

	public static List<Insurance_Policy__c> genInsurancePolicy(Integer numCreate, Boolean addToDB) {
		List<Insurance_Policy__c> insList = new List<Insurance_Policy__c>();
		List<Account> accList = genAccount(numCreate, true);
		List<Vehicle__c> vehList = genVehicle(numCreate, true);
		Insurance_Company__c insCmp = genInsCompany('028', 'AIG', true);
		Insurance_Policy__c ins;
		Company__c cmp = getCompany('028');
		for (Integer i = 0; i < numCreate; i++) {
			ins = new Insurance_Policy__c();
			ins.Covernote_No__c = 'CN ' + getUnique();
			ins.Policy_Inception_Date__c = System.today();
			ins.Policy_Expiry_Date__c = System.today().addDays(5);
			ins.Company__c = cmp.Id;
			ins.Original_Expiry_Date__c = ins.Policy_Expiry_Date__c;
			ins.Policy_Holder__c = accList[i].Id;
			ins.Vehicle__c = vehList[i].Id;
			ins.Policy_Classification__c = 'Motor';
			ins.Insurance_Product__c = 'Passenger';
			ins.Opportunity_Stage__c = 'New Insurance Biz';
			ins.Ext_Underwriter__c = insCmp.Name;
			// ins.Underwriter_Code__c = insCmp.Id;
			ins.Basic_Price__c = 1000;
			ins.Excess__c = 10;
			ins.Commission__c = 100;
			ins.Original_Basic_Price__c = 1000;
			ins.Original_Commission__c = 100;
			ins.Original_Discount__c = 100;
			ins.Original_Discount_Percentage__c = 15;
			ins.Original_GST_Percentage__c = 10;
			ins.Original_No_Claim_Discount_NCD__c = 10;
			ins.Original_Offence_Free_Discount_OFD__c = 10;
			insList.add(ins);
		}

		if (addToDB) {
			insert insList;
		}

		return insList;
	}

	public static List<Insurance_Transaction__c> genInsuranceTxn(Integer numCreate, Boolean addToDB) {
		List<Insurance_Transaction__c> txnList = new List<Insurance_Transaction__c>();
		List<Insurance_Policy__c> insList = genInsurancePolicy(numCreate, true);
		Insurance_Transaction__c txn;
		for (Integer i = 0; i < numCreate; i++) {
			txn = new Insurance_Transaction__c();
			txn.Insurance_Name_ID__c = insList[i].Id;
			txn.Status_Code__c = 'POSTED';
			txn.Basic_Price__c = 1;
			txn.No_Claim_Discount__c = 1;
			txn.Offence_Free_Discount_OFD__c = 1;
			txn.Commission__c = 1;
			txn.Insurance_Transaction_Type_ID__c = '(+) NEW POLICY WITH UW';
			txnList.add(txn);
		}

		if (addToDB) {
			insert txnList;
		}

		return txnList;
	}

	// public static List<Insurance_Quotation__c> genInsQuotation(Integer numCreate, Boolean addToDB) {
	// 	List<Insurance_Quotation__c> insQ = new List<Insurance_Quotation__c>();
	// 	Insurance_Quotation__c q;
	// 	Opportunity opp = TestFactory.genOpportunity(1, true)[0];
	// 	Company__c cmp = TestFactory.getCompany('02');
	// 	for (Integer i = 0; i < numCreate; i++) {
	// 		q = new Insurance_Quotation__c();
	// 		q.Opportunity__c = opp.Id;
	// 		q.Company__c = cmp.Id;
	// 		q.Driving_experience_Months__c = 0;
	// 		q.Driving_experience_Years__c = 2;
	// 		q.Age__c = 30;
	// 		q.No_Claim_Discount_NCD__c = 50;
	// 		insQ.add(q);
	// 	}

	// 	if (addToDB) {
	// 		insert insQ;
	// 	}

	// 	return insQ;
	// }

	public static List<Test_Drive__c> genTestDrive(Integer numcreate, Boolean addToDB) {
		List<Test_Drive__c> tdList = new List<Test_Drive__c>();
		Test_Drive__c td;
		List<Opportunity> oppList = genOpportunity(numCreate, true);
		Vehicle_Stock_Master__c vehStock = genVehicleStockMaster(1, true)[0];
		Company__c cmp = getCompany('028');
		for (Integer i = 0; i < numCreate; i++) {
			td = new Test_Drive__c();
			td.Opportunity__c = oppList[i].Id;
			// td.Vehicle_Stock_Master__c = vehStock.Id;
			td.Vehicle__c = vehStock.Chassis__c;
			// td.Vehicle_Out_DateTime__c = System.now();
			td.Account__c = oppList[i].AccountId;
			td.Company__c = cmp.Id;
			tdList.add(td);
		}
		if (addToDB) {
			insert tdList;
		}
		return tdList;
	}

	public static List<ACP_Announcement__c> genAnnouncement(Integer numCreate, Boolean addToDB) {
		List<ACP_Announcement__c> announceList = new List<ACP_Announcement__c>();
		ACP_Announcement__c cur;
		for (Integer i = 0; i < numCreate; i++) {
			cur = new ACP_Announcement__c();
			cur.Name = 'Test' + getUnique();
			cur.Announcement__c = 'Test test';
			cur.Active__c = true;
			cur.Company__c = '028';
			announceList.add(cur);
		}
		if (addToDB) { insert announceList; }
		return announceList;
	}

	public static List<ACP_Login_Alert__c> genLoginAlert(Integer numCreate, Boolean addToDB) {
		List<ACP_Login_Alert__c> alertList = new List<ACP_Login_Alert__c>();
		ACP_Login_Alert__c cur;
		for (Integer i = 0; i < numCreate; i++) {
			cur = new ACP_Login_Alert__c();
			cur.Name = 'Test' + getUnique();
			cur.Body__c = 'Test test';
			cur.Header__c = 'Test 2';
			cur.Active__c = true;
			cur.Company__c = '028';
			alertList.add(cur);
		}
		if (addToDB) { insert alertList; }
		return alertList;
	}

	public static List<ServiceOrder__c> genServiceOrder(Integer numCreate, Boolean addToDB) {
		Vehicle_Ownership__c[] vos = [SELECT Id FROM Vehicle_Ownership__c];
		if (vos.size() == 0) { vos = genVO(1, true); }
		List<ServiceOrder__c> orderList = new List<ServiceOrder__c>();
		ServiceOrder__c svc;
		for (Integer i = 0; i < numCreate; i++) {
			svc = new ServiceOrder__c();
			svc.Name = getUnique();
			svc.VehicleOwnership__c = vos[0].Id;
			svc.ACP_Service_Started__c = true;
			svc.ACP_Service_Completed__c = true;
			svc.ACP_Ready_for_Collection__c = true;
			// svc.End_Control_Date_Time_Text__c = '08/11/2015_1501';
			orderList.add(svc);
		}
		if (addToDB) { insert orderList; }
		return orderList;
	}
	public static List<Notification__c> genNotification(Integer numCreate, Boolean addToDB) {
		List<Notification__c> notifications = new List<Notification__c>();
		Notification__c n;
		Company__c cmp = getCompany('028');
		for (Integer i = 0; i < numCreate; i++) {
			n = new Notification__c();
			n.Name = 'Test ' + getUnique();
			n.Company__c = cmp.Id;
			n.Message__c = 'Test';
			n.App_ID__c = 'Test';
			n.User__c = UserInfo.getUserId();
			notifications.add(n);
		}
		if (addToDB) { insert notifications; }
		return notifications;
	}

	public static List<User_Message_Token__c> genUserMessageToken(Integer numCreate, Boolean addToDB) {
		List<User_Message_Token__c> messageTokens = new List<User_Message_Token__c>();
		User_Message_Token__c m;
		for (Integer i = 0; i < numCreate; i++) {
			m = new User_Message_Token__c();
			m.Name = 'Test ' + getUnique();
			m.App_ID__c = 'Test';
			m.Device_Name__c = 'Test Device' + getUnique();
			m.IsActive__c = true;
			m.Last_Active_DateTime__c = DateTime.now();
			m.Token__c = 'Test';
			m.User__c = UserInfo.getUserId();
			messageTokens.add(m);
		}
		if (addToDB) { insert messageTokens; }
		return messageTokens;
	}

	public static List<Customer_External_Account__c> genCustExtAcc(Integer numCreate, Boolean addToDB) {
		List<Customer_External_Account__c> extAcc = new List<Customer_External_Account__c>();
		Company__c cmp = getCompany('028');
		String type = CustAppAccount.EXT_ACC_TYPE.get(cmp.Name);
		Customer_External_Account__c eAcc;
		List<Account> accList = genAccount(numCreate, true);
		for (Integer i = 0; i < numCreate; i++) {
			eAcc = new Customer_External_Account__c();
			eAcc.UUID__c = 'UUID' + getUnique();
			eAcc.Type__c = type;
			eAcc.Account__c = accList[i].Id;
			extAcc.add(eAcc);
		}
		if (addToDB) { insert extAcc; }
		return extAcc;
	}

	public static List<Alternative_Driver__c> genAltDriver(Integer numCreate, Boolean addToDB) {
		List<Alternative_Driver__c> altDList = new List<Alternative_Driver__c>();
		List<Account> accList = genAccount(numCreate, true);
		Vehicle_Ownership__c vo = genVO(1, true)[0];
		Company__c cmp = getCompany('028');
		String type = CustAppAccount.EXT_ACC_TYPE.get(cmp.Name);
		for (Integer i = 0; i < numCreate; i++) {
			Alternative_Driver__c aD = new Alternative_Driver__c();
			aD.Account__c = accList[0].Id;
			aD.Created_From__c = 'Customer App';
			aD.Status__c = 'Active';
			aD.Type__c = type;
			aD.Vehicle_Ownership__c = vo.Id;
			altDList.add(aD);
		}
		if (addToDB) { insert altDList; }
		return altDList;
	}

	public static List<ServiceOrder__c> genRepairOrder(Integer numCreate, Boolean addToDB) {
		List<ServiceOrder__c> roList = new List<ServiceOrder__c>();
		Company__c cmp = getCompany('028');
		Workshop__c ws = genWorkshop(1, false)[0];
		ws.Company__c = cmp.Id;
		insert ws;
		Vehicle_Ownership__c vo = genVO(1, true)[0];
		Employee_Master__c em = TestFactory.genEmpMaster(1, true)[0];
		string[] accNos = new List<string>{ 'C0000002', 'G0000001', 'I0000001', 'N0000001', 'S0000001' };
		for (Integer i = 0; i < numCreate; i++) {
			integer accIdx = Math.mod(i, accNos.size());
			ServiceOrder__c ro = new ServiceOrder__c();
			ro.RepairOrderNo__c = String.valueOf(12345 + i);
			ro.WipKey__c = Datetime.now().addSeconds(i).format('yyyyMMddHHmm') + i;
			ro.Service_Order_Date__c = Date.today();
			ro.CheckIn__c = ro.Service_Order_Date__c;
			ro.VehicleOwnership__c = vo.Id;
			ro.Vehicle__c = vo.Vehicle__c;
			ro.RegistrationNo__c = vo.Registration_No__c;
			ro.Account__c = vo.Customer__c;
			ro.Workshop__c = ws.Id;
			ro.WorkshopCode__c = ws.Name;
			ro.Company__c = cmp.Id;
			ro.CSA__c = em.Id;
			ro.Status__c = 'Memo';
			ro.ContactAccNumber__c = accNos[accIdx];
			ro.ContactPhone__c = '+60123456789';
			/** Keys */
			ro.roKey__c = ro.WipKey__c + ws.Name;
			ro.ExternalId__c = String.format('{0}_{1}_{2}_{3}', new string[] { cmp.Name, ws.Name, ro.RepairOrderNo__c, vo.Vehicle__r.Name });
			roList.add(ro);
		}
		if (addToDB) { insert roList; }
		return roList;
	}

	public static List<ServiceInvoice__c> genServiceInvoice(Integer numCreate, Boolean addToDB) {
		List<ServiceInvoice__c> siList = new List<ServiceInvoice__c>();
		Company__c cmp = getCompany('028');
		Workshop__c ws = genWorkshop(1, false)[0];
		ws.Company__c = cmp.Id;
		insert ws;
		Account[] acs = genAccount(numCreate, true);
		Vehicle__c[] vs = genVehicle(numCreate, true);
		genRepairOrder(numCreate, true);
		ServiceOrder__c[] sos = [SELECT Id, Workshop__r.Id, Workshop__r.Name, RepairOrderNo__c, RoKey__c FROM ServiceOrder__c];

		for (Integer i = 0; i < numCreate; i++) {
			string invNo = String.valueOf(1000+i).leftPad(8, '0');
			ServiceInvoice__c si = new ServiceInvoice__c();
			si.Name = String.format('{0} {1}', new string[] { ws.Name, invNo });
			si.Company__c = cmp.Id;
			si.Workshop__c = sos[i].Workshop__r.Id;
			si.Vehicle__c = vs[i].Id;
			si.RepairOrder__c = sos[i].Id;
			si.AccountNumber__c = 'C0000002'; // 'A' + String.valueOf(i).leftPad(6, '0');
			si.ExternalId__c = String.format('{0}_{1}_{2}', new string[] { cmp.Name, ws.Name, invNo });
			si.InvoiceDate__c = Date.today();
			si.InvoiceNumber__c = Integer.valueOf(invNo);
			si.InvoiceKey__c = invNo + sos[i].Workshop__r.Name;
			si.InvoiceValue__c = Decimal.valueOf((i + 2)*5);
			si.ServiceDetails__c = ws.Name + '/Service n: ' + String.valueOf(i);
			si.RoKey__c = sos[i].RoKey__c;
			siList.add(si);
		}
		if (addToDB) { insert siList; }
		return siList;
	}

	public static List<PaymentDetail__c> genPaymentDetail(Integer numCreate, Boolean addToDB) {
		List<PaymentDetail__c> pdList = new List<PaymentDetail__c>();
		// Company__c cmp = getCompany('028');
		// Workshop__c ws = genWorkshop(1, true)[0];
		// Account[] acs = genAccount(numCreate, true);
		ServiceInvoice__c[] sis = genServiceInvoice(numCreate, true);
		
		for (Integer i = 0; i < numCreate; i++) {
			PaymentDetail__c pd = new PaymentDetail__c();
			string pdName = sis[i].InvoiceKey__c + i;
			pd.Name = pdName;
			pd.RecordTypeId = Schema.SObjectType.PaymentDetail__c.getRecordTypeInfosByName().get('Service Invoice (counter)').getRecordTypeId();
			pd.Company__c = sis[i].Company__c;
			pd.Workshop__c = sis[i].Workshop__c;
			pd.Account__c = sis[i].Account__c;
			pd.BankRefNumber__c = '67890';
			pd.SequenceNumber__c = i;
			pd.PayForServiceInvoice__c = sis[i].Id;
			pd.RespTime__c = String.valueOf(sis[i].InvoiceDate__c);
			pd.Amount__c = sis[i].InvoiceValue__c;
			pd.AmountVat__c = 0;
			pd.HashValue1__c = '12345';
			pd.HashValue2__c = '1122334455';
			pd.CreatedFrom__c = 'Autoline';			
			pdList.add(pd);
		}
		update sis;
		if (addToDB) { insert pdList; }
		return pdList;

	}

	public static Enquiry_Type__c genEnquiryType(String enqType, Boolean addToDB) {
		Enquiry_Type__c enq = new Enquiry_Type__c(Name = enqType, Company__c = '028', Scope__c = 'Test', WS_Filter__c = 'W1', Active__c = true,
												  Label__c = enqType);
		if (addToDB) { insert enq; }
		return enq;
	}


	public static Insurance_Company__c genInsCompany(String cmpCode, String insName, Boolean addToDB) {
		// Insurance_Company__c newCmp = new Insurance_Company__c(Description__c = insName, Name = '106066', SDSL_Partner__c = true,
		// 													   Company__c = getCompany(cmpCode).Id);
		Insurance_Company__c newCmp = new Insurance_Company__c(Description__c = insName, Name = insName, SDSL_Partner__c = true,
															   Company__c = getCompany(cmpCode).Id);
		if (addToDB) {
			insert newCmp;
		}
		return newCmp;
	}

	public static Legislation_Type__c genLegislationType(String legName, Boolean addtoDB) {
		Legislation_Type__c newLeg = new Legislation_Type__c(Name = legName);
		if (addtoDB) {
			insert newLeg;
		}

		return newLeg;
	}

	public static Vehicle_Type__c genVehType(String typeName, Boolean addToDB) {
		Vehicle_Type__c vType = new Vehicle_Type__c(Name = typeName, Company__c = getCompany('028').Id);
		if (addToDB) {
			insert vType;
		}

		return vType;
	}

	public static Vehicle_Make__c genVehMake(String makeName, Boolean addToDB) {
		Vehicle_Make__c vM = new Vehicle_Make__c(Name = makeName, Company__c = getCompany('028').Id);
		if (addToDB) {
			insert vM;
		}

		return vM;
	}

	public static Global_Trigger_Settings__c genTriggerSettings(String csName, Boolean addtoDB) {
		Global_Trigger_Settings__c newT = new Global_Trigger_Settings__c();
		newT.Name = csName;
		newT.Activated__c = true;

		if (addtoDB) {
			insert newT;
		}

		return newT;
	}


	public static Account genVODummy(Boolean addToDB) {
		Account dummyAcc = new Account();
		dummyAcc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business Account').getRecordTypeId();
		dummyAcc.Name = 'Pls key into Salesforce updated owner details';
		dummyAcc.Doc_Type__c = ' Company (e.g. 198912345K)';
		dummyAcc.NRIC_Number__c = 'A198912345' + getUnique();
		if (addToDB) { insert dummyAcc; }
		return dummyAcc;
	}

	public static Force_com_Site_URL__c genForceSite(String name, Boolean addToDB) {
		Force_com_Site_URL__c url = new Force_com_Site_URL__c(Name = name, URL__c = 'test');
		if (addToDB) { insert url; }
		return url;
	}

	public static Service_Type__c genServiceType(String svcType, Boolean addToDB) {
		Service_Type__c svc = new Service_Type__c(Name = svcType, Company__c = '028', Workshop__c = '', Available__c = true, Allow_External__c = true);
		if (addToDB) { insert svc; }
		return svc;
	}

	public static WarrantyPackage__c genWtyPack(String name, Boolean addToDB) {
		Company__c co = getCompany('028');
		WarrantyPackage__c wp = new WarrantyPackage__c(Name = name, Company__c = co.Id, CompanyCode__c = co.Name, Description__c = 'Desc:' + name);
		if (addToDB) { insert wp; }
		return wp;
	}
	public static List<VehicleWarranty__c> genVehWty(Integer numCreate, Boolean addToDB) {
		Company__c co = getCompany('028');
		WarrantyPackage__c wp = genWtyPack('Pack1', true);
		VehicleWarranty__c[] vws = new VehicleWarranty__c[]{};
		for (Integer i = 0; i < numCreate; i++) {
			string vin = 'VIN' + i;
			VehicleWarranty__c vw = new VehicleWarranty__c(Name = wp.Name + '-' + vin, Company__c = co.Id, WarrantyPackage__c = wp.Id);
			vw.ChassisNo__c = vin;
			vw.CompanyCode__c = co.Name;
			vw.ContractCode__c = wp.Name + vin;
			vw.Distance__c = 100000;
			vw.Duration__c = 12;
			vw.DateEnd__c = Datetime.now().addYears(1).date();
			vw.DateStart__c = Datetime.now().addMonths(-1).date();
			vws.add(vw);
		}
		if (addToDB) { insert vws; }
		return vws;
	}
	public static void genApiSetup() {
		List<String> apiSetups = new List<String> { 
			'MobyMyUat Username', 'MobyMyUat Password', 'MobyMyUat Endpoint',
			'MobyMyPrd Username', 'MobyMyPrd Password', 'MobyMyPrd Endpoint',
			'Sync Care Dev Password', 'Sync Care Dev Username',
			'Sync Care Dev Endpoint', 'Sync Care Dev QR Endpoint',
			'Sync Care Prd Password', 'Sync Care Prd Username',
			'Sync Care Prd Endpoint', 'Sync Care Prd QR Endpoint',
			'Sync Moby Dev Endpoint', 'Sync Moby Dev Password', 'Sync Moby Dev Username',
			'Sync Moby Prd Endpoint', 'Sync Moby Prd Password', 'Sync Moby Prd Username'
		};
		List<API_Setup__c> setupList = new List<API_Setup__c>();
		for (String s : apiSetups) {
			setupList.add(new API_Setup__c(Name = s, Value__c = 'Test'));
		}
		insert setupList;
	}
}