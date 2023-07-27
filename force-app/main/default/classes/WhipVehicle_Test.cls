@isTest private class WhipVehicle_Test {
	
	@TestSetup static void makeData() {
		Company__c[] cos = TestFactory.genCompany(1, true);
		Workshop__c[] wos = TestFactory.genWorkshop(1, true);
		Vehicle_Ownership__c[] vos = TestFactory.genVO(1, true);
		Account[] acs = [Select Id, Name From Account];
		Vehicle__c[] ves = [Select Id, Name From Vehicle__c];
		/** Update Lookup fields */
		for (Company__c c :cos) {
			for (Workshop__c w :wos) {
				w.Company__c = c.Id;
				w.AllowInWhip__c = true;
			}
		}
		update wos;

		// WarrantyPackage__c[] wps = new List<WarrantyPackage__c>();
		WarrantyPackage__c wp = new WarrantyPackage__c();
		wp.Name = 'ABCD';
		wp.CompanyCode__c = cos[0].Name;
		wp.Description__c = 'Test Description';
		wp.ExternalId__c = string.format('{0}-{1}', new string[] { wp.Name, wp.CompanyCode__c });
		insert wp;

		VehicleWarranty__c[] vws = new List<VehicleWarranty__c>();
		for (Vehicle__c v :ves) {
			VehicleWarranty__c vw = new VehicleWarranty__c();
			vw.ChassisNo__c = v.Name;
			vw.ContractCode__c = wp.Name;
			vw.Duration__c = 12;
			vw.Distance__c = 20000;
			vw.DateStart__c = Date.today();
			vw.DateEnd__c = Date.today().addMonths(12);
			vw.Vehicle__c = v.Id;
			vw.WarrantyPackage__c = wp.Id;
			vws.add(vw);
		}
		insert vws;
	}

	@isTest static void getVehicle_TestException() {
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		Test.startTest();
		WhipVehicle.getVehicles();
		Test.stopTest();
	}
	@isTest static void getVehicle_TestRegNo() {
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		Vehicle_Ownership__c[] vos = [
			Select
				Id, Registration_No__c, Customer__r.Mobile_Preferred__pc
			From Vehicle_Ownership__c
		];
		system.debug(JSON.serialize(vos));
		RestContext.request.params.put('registration_number', vos[0].Registration_No__c);
		RestContext.request.params.put('phone_number', vos[0].Customer__r.Mobile_Preferred__pc);
		Test.startTest();
		WhipVehicle.getVehicles();
		Test.stopTest();
	}

	@isTest static void getVehicle_TestCoReg() {
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		Vehicle_Ownership__c[] vos = [
			Select
				Id, Registration_No__c, Customer__r.NRIC_Number__c
			From Vehicle_Ownership__c
		];
		system.debug(JSON.serialize(vos));
		RestContext.request.params.put('registration_number', vos[0].Registration_No__c);
		RestContext.request.params.put('company_registration', vos[0].Customer__r.NRIC_Number__c);
		Test.startTest();
		WhipVehicle.getVehicles();
		Test.stopTest();
	}
}