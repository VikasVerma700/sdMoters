@isTest
private class CareBooking_Test {
	@TestSetup
	public static void setup() {
		Test.startTest();
		Global_Trigger_Settings__c vehTrig = TestFactory.genTriggerSettings('Vehicle', false);
		vehTrig.Activated__c = false;
		Global_Trigger_Settings__c voTrig = TestFactory.genTriggerSettings('Vehicle Ownership', false);
		voTrig.Activated__c = false;
		insert (new List<Global_Trigger_Settings__c> { vehTrig, voTrig });
		Test.stopTest();
	}

	@isTest
	public static void testBookingChangeCSA() {
		List<Appointment_Utilization__c> apptUtil = TestFactory.genApptUtilization(1, false);
		Service_Quota__c wsQuota = [SELECT Id, Service_Slot__r.Active_Date__c, Type__c, Service_Slot__r.Workshop__c FROM Service_Quota__c
									WHERE Id = :apptUtil[0].Service_Quota__c];
		List<Service_Quota__c> csaQuota = TestFactory.genCSAServiceQuota(2, false);
		List<Employee_Shift__c> empList = new List<Employee_Shift__c>();
		empList.add(new Employee_Shift__c(Id = csaQuota[0].Employee_Shift__c, Active_Date__c = wsQuota.Service_Slot__r.Active_Date__c,
											Workshop__c = wsQuota.Service_Slot__r.Workshop__c));
		empList.addAll(TestFactory.genEmpShift(1, false));
		empList[1].Active_Date__c = wsQuota.Service_Slot__r.Active_Date__c;
		empList[1].Workshop__c = wsQuota.Service_Slot__r.Workshop__c;
		upsert empList;
		csaQuota[1].Employee_Shift__c = empList[1].Id;

		for (Service_Quota__c q : csaQuota) {
			q.Type__c = wsQuota.Type__c;
			q.Start_Time__c = DateTime.newInstance(wsQuota.Service_Slot__r.Active_Date__c, q.Start_Time__c.time());
			q.End_Time__c = DateTime.newInstance(wsQuota.Service_Slot__r.Active_Date__c, q.End_Time__c.time());
		}
		insert csaQuota;

		apptUtil.add(new Appointment_Utilization__c(Service_Appointment__c = apptUtil[0].Service_Appointment__c, Service_Quota__c = csaQuota[0].Id));
		insert apptUtil;

		Vehicle_Ownership__c vo = TestFactory.genVO(1, true)[0];
		Service_Appointment__c updSA = new Service_Appointment__c(Id = apptUtil[0].Service_Appointment__c);
		updSA.Service_Request__c = wsQuota.Type__c;
		updSA.System_Control__c = true;
		updSA.Vehicle_Ownership__c = vo.Id;
		updSA.Account__c = vo.Customer__c;
		updSA.Workshop__c = wsQuota.Service_Slot__r.Workshop__c;
		update updSA;

		Employee_Shift__c newES = [SELECT Id, Employee_Master__c FROM Employee_Shift__c WHERE Id = :csaQuota[1].Employee_Shift__c];
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		ServiceApptBooking.APIBooking booking = new ServiceApptBooking.APIBooking(apptUtil[0].Service_Appointment__c);
		booking.csaId = newES.Employee_Master__c;
		booking.selectedTime = csaQuota[0].Start_Time__c;
		booking.altTransport = new ServiceApptBooking.AlternateTransport();
		booking.altTransport.transportType = 'Taxi';
		booking.altTransport.remarks = 'Test';
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(booking));

		Test.startTest();
		CareBooking.book();
		Test.stopTest();
		Service_Appointment__c sa = [SELECT Id, Employee_Master__c, Alternate_Transport__c, Alternate_Transport_Remarks__c,(SELECT Id, Service_Quota__c FROM
									Appointment_Utilizations__r) FROM Service_Appointment__c WHERE Id = :apptUtil[0].Service_Appointment__c];
		System.assertEquals(sa.Employee_Master__c, newES.Employee_Master__c);
		System.assertEquals(sa.Appointment_Utilizations__r.size(), 2);
		System.assertEquals(sa.Alternate_Transport__c, booking.altTransport.transportType);
		System.assertEquals(sa.Alternate_Transport_Remarks__c, booking.altTransport.remarks);
		Boolean seenWS = false;
		Boolean seenES = false;
		System.debug(sa.Appointment_Utilizations__r);
		for (Appointment_Utilization__c aU : sa.Appointment_Utilizations__r) {
			if (aU.Service_Quota__c == wsQuota.Id) { seenWS = true; }
			if (aU.Service_Quota__c == csaQuota[1].Id) { seenES = true; }
		}
		System.assert(seenWS);
		System.assert(seenES);
	}

	// @IsTest
	// public static void testBookingAllocateCSA() {
	// 	List<Appointment_Utilization__c> apptUtil = TestFactory.genApptUtilization(1, false);
	// 	Service_Quota__c wsQuota = [SELECT Id, Service_Slot__r.Active_Date__c, Type__c, Service_Slot__r.Workshop__c FROM Service_Quota__c
	// 								WHERE Id = :apptUtil[0].Service_Quota__c];
	// 	update (new Workshop__c(Id = wsQuota.Service_Slot__r.Workshop__c, Auto_Assign_CSA__c = true));
	// 	Service_Quota__c csaQuota = TestFactory.genCSAServiceQuota(1, false)[0];
	// 	update (new Employee_Shift__c(Id = csaQuota.Employee_Shift__c, Active_Date__c = wsQuota.Service_Slot__r.Active_Date__c,
	// 									Workshop__c = wsQuota.Service_Slot__r.Workshop__c));
	// 	csaQuota.Type__c = wsQuota.Type__c;
	// 	csaQuota.Start_Time__c = DateTime.newInstance(wsQuota.Service_Slot__r.Active_Date__c, csaQuota.Start_Time__c.time());
	// 	csaQuota.End_Time__c = DateTime.newInstance(wsQuota.Service_Slot__r.Active_Date__c, csaQuota.End_Time__c.time());
	// 	insert csaQuota;
	// 	User csaUser = [SELECT Id FROM User WHERE Profile.Name = 'PML Aftersales - CSA' AND IsActive = TRUE LIMIT 1];
	// 	User_Config__c uConfig = new User_Config__c();
	// 	uConfig.Sharing_Rule_Company__c = '028';
	// 	uConfig.User__c = csaUser.Id;
	// 	insert uConfig;
	// 	Employee_Shift__c empShift = [SELECT Id, Employee_Master__c FROM Employee_Shift__c WHERE Id = :csaQuota.Employee_Shift__c];
	// 	update (new Employee_Master__c(Id = empShift.Employee_Master__c, SFDC_User_Name__c = uConfig.User__c));
	// 	apptUtil.add(new Appointment_Utilization__c(Service_Appointment__c = apptUtil[0].Service_Appointment__c, Service_Quota__c = csaQuota.Id));
	// 	insert apptUtil;

	// 	Vehicle_Ownership__c vo = TestFactory.genVO(1, true)[0];
	// 	Service_Appointment__c updSA = new Service_Appointment__c(Id = apptUtil[0].Service_Appointment__c);
	// 	updSA.Service_Request__c = wsQuota.Type__c;
	// 	updSA.System_Control__c = true;
	// 	updSA.Vehicle_Ownership__c = vo.Id;
	// 	updSA.Account__c = vo.Customer__c;
	// 	updSA.Workshop__c = wsQuota.Service_Slot__r.Workshop__c;
	// 	updSA.Employee_Master__c = null;
	// 	update updSA;

	// 	RestContext.response = new RestResponse();
	// 	RestContext.request = new RestRequest();
	// 	ServiceApptBooking.APIBooking booking = new ServiceApptBooking.APIBooking(apptUtil[0].Service_Appointment__c);
	// 	booking.csaId = '';
	// 	booking.selectedTime = csaQuota.Start_Time__c;
	// 	RestContext.request.requestBody = Blob.valueOf(JSON.serialize(booking));

	// 	Test.startTest();
	// 	CareBooking.book();
	// 	Test.stopTest();
	// 	Service_Appointment__c sa = [SELECT Id, Employee_Master__c, (SELECT Id, Service_Quota__c FROM Appointment_Utilizations__r) FROM Service_Appointment__c
	// 								WHERE Id = :apptUtil[0].Service_Appointment__c];
	// 	System.assertNotEquals(sa.Employee_Master__c, null);
	// 	System.assertEquals(sa.Appointment_Utilizations__r.size(), 2);
	// }

	@isTest
	public static void testCancel() {
		Service_Appointment__c sa = TestFactory.genSvcAppt(1, true)[0];
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		RestContext.request.params.put('apptId', sa.Id);
		User u = [SELECT Id FROM User WHERE Alias = 'fireapi' LIMIT 1];
		Test.startTest();
		System.runAs(u) {
			CareBooking.cancel();
		}
		Test.stopTest();
		Service_Appointment__c checkSA = [SELECT Id, Apppointment_Status__c FROM Service_Appointment__c WHERE Id = :sa.Id];
		System.assertEquals(checkSA.Apppointment_Status__c, 'CANCELLED');
	}

	@isTest
	public static void testErrorsameDay() {
		Service_Appointment__c sa = TestFactory.genSvcAppt(1, false)[0];
		sa.Appointment_Date__c = DateTime.now();
		insert sa;
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		ServiceApptBooking.APIBooking booking = new ServiceApptBooking.APIBooking(sa.Id);
		booking.selectedTime = DateTime.now().addDays(7);
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(booking));
		Test.startTest();
		CareBooking.book();
		Test.stopTest();
		System.assertEquals(RestContext.response.statusCode, 400);
	}
}