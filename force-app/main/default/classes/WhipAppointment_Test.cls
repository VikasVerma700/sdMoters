@isTest private class WhipAppointment_Test {

	private static Date today = Date.today();
	private static Datetime slot = Datetime.newInstanceGmt(today.year(), today.month(), today.day(), 0, 0, 0).addDays(1);
	private static string type = 'Mobility';

	@TestSetup static void makeData(){
		// Company__c[] cos = TestFactory.genCompany(1, true);
		// Workshop__c[] wos = TestFactory.genWorkshop(1, true);
		Vehicle_Ownership__c[] vos = TestFactory.genVO(1, true);
		Service_Quota__c[] sqs = TestFactory.genServiceQuota(2, true);
		Service_Slot__c[] ss = TestFactory.genServiceSlot(2, true);
		Account[] acs = [Select Id, Name From Account];
		Vehicle__c[] ves = [Select Id, Name From Vehicle__c];
		/** Update Lookup fields */
		// for (Company__c c :cos) {
		// 	for (Workshop__c w :wos) {
		// 		w.Company__c = c.Id;
		// 		w.AllowInWhip__c = true;
		// 	}
		// }
		// update wos;
		Company__c[] cos = [SELECT Id, Name FROM Company__c];
		Workshop__c[] wos = [SELECT Id, Name, AllowInWhip__c FROM Workshop__c];
		for (Workshop__c w :wos) { w.AllowInWhip__c = true; }
		update wos;

		/** Update Service Quota type = 'Mobility' */
		sqs = [
			SELECT
				Id, Available_Slots__c, Day__c, Employee_Master__c, Employee_Shift__c
				, End_Time__c, Interval_Per_Appt__c, Max_Appt_Per_Timeslot__c
				, Max_Quota__c, Service_Slot__c, Start_Time__c, Utilization__c
				, Utilized__c, Workshop__c
				, Type__c
			FROM Service_Quota__c];
		for (Service_Quota__c sq :sqs) { sq.Type__c = type; }
		update sqs;
		system.debug('sqs: ' + sqs);

		/** Insert Service_Appointment__c */
		Date targetDate = Date.valueOf(slot);	// Date.today().addDays(1);
		Service_Appointment__c[] sas = new List<Service_Appointment__c>();
		wos = [Select Id, Name From Workshop__c];
		for (Workshop__c ws :wos) {
			Service_Appointment__c sa = new Service_Appointment__c();
			sa.Appointment_Date__c = slot;	//Datetime.now();
			sa.Company__c = cos[0].Id;
			sa.Chassis__c = ves[0].Id;
			sa.Workshop__c = ws.Id;
			sa.Service_Request__c = type;
			sas.add(sa);
			system.debug('insert: ' + sa);
		}
		insert sas;
	}
	
	@isTest static void getAppointment_TestNoType() {
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		Test.startTest();
		WhipAppointment.getAppointment();
		Test.stopTest();
		WhipAppointment.ApptGetResp resp = (WhipAppointment.ApptGetResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptGetResp.class);
		System.assertNotEquals(resp.err, null);
	}
	@isTest static void getAppointment_TestNoYear() {
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();

		RestContext.request.params.put('type', type);
		Test.startTest();
		WhipAppointment.getAppointment();
		Test.stopTest();
		WhipAppointment.ApptGetResp resp = (WhipAppointment.ApptGetResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptGetResp.class);
		System.assertNotEquals(resp.err, null);
	}
	@isTest static void getAppointment_TestNoMonth() {
		Date targetDate = Date.valueOf(slot); //Date.today().addDays(1);
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		
		RestContext.request.params.put('type', type);
		RestContext.request.params.put('yearf', String.valueOf(targetDate.year()));
		RestContext.request.params.put('yeart', String.valueOf(targetDate.year()));
		Test.startTest();
		WhipAppointment.getAppointment();
		Test.stopTest();
		WhipAppointment.ApptGetResp resp = (WhipAppointment.ApptGetResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptGetResp.class);
		System.assertNotEquals(resp.err, null);
	}
	@isTest static void getAppointment_TestNoWorkshop() {
		Date targetDate = Date.newInstance(slot.year(), slot.month(), slot.day());
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		
		RestContext.request.params.put('type', type);
		RestContext.request.params.put('yearf', String.valueOf(targetDate.year()));
		RestContext.request.params.put('yeart', String.valueOf(targetDate.year()));
		RestContext.request.params.put('monthf', String.valueOf(targetDate.month()));
		RestContext.request.params.put('montht', String.valueOf(targetDate.month()));
		Test.startTest();
		WhipAppointment.getAppointment();
		Test.stopTest();
		WhipAppointment.ApptGetResp resp = (WhipAppointment.ApptGetResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptGetResp.class);
		system.debug('getAppointment_TestNoWorkshop(): ' + resp);
		System.assertNotEquals(resp.apptList.size(), null);
	}
	// @isTest static void getAppointment_Test() {
	// 	system.debug('getAppointment_Test');
	// 	Date targetDate = Date.valueOf(slot); //Date.today().addDays(1);
	// 	RestContext.response = new RestResponse();
	// 	RestContext.request = new RestRequest();
		
	// 	RestContext.request.params.put('type', type);
	// 	RestContext.request.params.put('year', String.valueOf(targetDate.year()));
	// 	RestContext.request.params.put('month', String.valueOf(targetDate.month()));
	// 	// Workshop__c[] ws = [Select Id, Name From Workshop__c];
	// 	// RestContext.request.params.put('workshop', ws[0].Name);
	// 	Service_Quota__c sq = [SELECT Id, Workshop__c FROM Service_Quota__c WHERE Type__c = :type LIMIT 1];
	// 	RestContext.request.params.put('workshop', sq.Workshop__c);
	// 	Test.startTest();
	// 	WhipAppointment.getAppointment();
	// 	Test.stopTest();
	// 	// WhipAppointment.ApptGetResp[] agrs = (List<WhipAppointment.ApptGetResp>)JSON.deserialize(RestContext.response.responseBody.toString(), List<WhipAppointment.ApptGetResp>.class);
	// 	// system.debug('getAppointment_Test()' + agrs);
	// 	WhipAppointment.ApptGetResp resp = (WhipAppointment.ApptGetResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptGetResp.class);
	// 	system.debug('getAppointment_Test: ' + resp);
	// 	System.assertNotEquals(resp.apptList.size(), null);
	// }

	@isTest static void reserveAppointment_NoSlotTest() {
		Date targetDate = Date.valueOf(slot); //Date.today().addDays(1);
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();

		RestContext.request.params.put('type', type);
		RestContext.request.params.put('yearf', String.valueOf(targetDate.year()));
		RestContext.request.params.put('yeart', String.valueOf(targetDate.year()));
		RestContext.request.params.put('monthf', String.valueOf(targetDate.month()));
		RestContext.request.params.put('montht', String.valueOf(targetDate.month()));
		WhipAppointment.getAppointment();
		WhipAppointment.ApptGetResp agrs = (WhipAppointment.ApptGetResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptGetResp.class);
		system.debug('NoSlotTest(): agrs: ' + agrs);
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		WhipAppointment.ApptPostReq apr = new WhipAppointment.ApptPostReq();
		for (WhipAppointment.ApptGet agr :agrs.apptList) {
			if (agr.slots != null) {
				for (CareCalendar.Cal s :agr.slots) {
					if (s.slots != null && s.remaining > 0) {
						apr.workshopId = agr.workshopId;
						// apr.slotDate = s.slots[0];
						break;
					}
				}
			}
		}
		Vehicle_Ownership__c vo = [Select Id From Vehicle_Ownership__c][0];
		apr.vehicleOwner = vo.Id;
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(apr));
		Test.startTest();
		WhipAppointment.reserveAppointment();
		RestContext.request.params.put('yearf', String.valueOf(targetDate.year()));
		RestContext.request.params.put('yeart', String.valueOf(targetDate.year()));
		RestContext.request.params.put('monthf', String.valueOf(targetDate.month()));
		RestContext.request.params.put('montht', String.valueOf(targetDate.month()));
		WhipAppointment.getAppointment();
		Test.stopTest();
		WhipAppointment.ApptGetResp resp = (WhipAppointment.ApptGetResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptGetResp.class);
	}

	@isTest static void reserveAppointment_Test() {
		Date targetDate = Date.valueOf(slot);
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();

		RestContext.request.params.put('type', type);
		RestContext.request.params.put('yearf', String.valueOf(targetDate.year()));
		RestContext.request.params.put('yeart', String.valueOf(targetDate.year()));
		RestContext.request.params.put('monthf', String.valueOf(targetDate.month()));
		RestContext.request.params.put('montht', String.valueOf(targetDate.month()));
		WhipAppointment.getAppointment();
		WhipAppointment.ApptGetResp apptGet = (WhipAppointment.ApptGetResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptGetResp.class);
		system.debug('getAppointment(): ' + apptGet);
		System.assertNotEquals(apptGet.apptList, null);

		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		WhipAppointment.ApptPostReq apptReq = new WhipAppointment.ApptPostReq();
		for (WhipAppointment.ApptGet agr :apptGet.apptList) {
			if (agr.slots != null) {
				for (CareCalendar.Cal s :agr.slots) {
					if (s.slots != null && s.remaining > 0) {
						apptReq.workshopId = agr.workshopId;
						apptReq.slotDate = s.slots[0];
						apptReq.type = type;
						apptReq.fullName = 'Mr. Apex Test';
						apptReq.phoneNumber = '0192651650';
						apptReq.emailAddress = 'test@apex.com.test';
						break;
					}
				}
			}
		}
		Vehicle_Ownership__c vo = [Select Id From Vehicle_Ownership__c][0];
		apptReq.vehicleOwner = vo.Id;
		system.debug('apptReq: ' + JSON.serialize(apptReq));
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(apptReq));
		Test.startTest();
		WhipAppointment.reserveAppointment();
		Test.stopTest();
		WhipAppointment.ApptPostResp postRes = (WhipAppointment.ApptPostResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptPostResp.class);
		system.debug('reserveAppointment(): ' + postRes);
		
		RestContext.request.params.put('type', type);
		RestContext.request.params.put('yearf', String.valueOf(targetDate.year()));
		RestContext.request.params.put('yeart', String.valueOf(targetDate.year()));
		RestContext.request.params.put('monthf', String.valueOf(targetDate.month()));
		RestContext.request.params.put('montht', String.valueOf(targetDate.month()));
		WhipAppointment.getAppointment();
		WhipAppointment.ApptGetResp getRes = (WhipAppointment.ApptGetResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptGetResp.class);
		system.debug('getAppointment(): ' + getRes);
	}

	@isTest static void releaseAppointment_TestNoApptId() {
		system.debug('releaseAppointment_TestNoApptId');
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		Test.startTest();
		WhipAppointment.releaseAppointment();
		Test.stopTest();
	}
	@isTest static void releaseAppointment_TestInvalidApptId() {
		system.debug('releaseAppointment_TestInvalidApptId');
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		RestContext.request.params.put('appointmentId', '1234567');
		Test.startTest();
		WhipAppointment.releaseAppointment();
		Test.stopTest();
		WhipAppointment.ApptGetResp resp = (WhipAppointment.ApptGetResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptGetResp.class);
	}

	@isTest static void releaseAppointment_Test() {
		Date targetDate = Date.valueOf(slot);
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();

		RestContext.request.params.put('type', type);
		RestContext.request.params.put('yearf', String.valueOf(targetDate.year()));
		RestContext.request.params.put('yeart', String.valueOf(targetDate.year()));
		RestContext.request.params.put('monthf', String.valueOf(targetDate.month()));
		RestContext.request.params.put('montht', String.valueOf(targetDate.month()));
		WhipAppointment.getAppointment();
		WhipAppointment.ApptGetResp apptGet = (WhipAppointment.ApptGetResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptGetResp.class);
		system.debug('getAppointment(): ' + apptGet);
		System.assertNotEquals(apptGet.apptList, null);

		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		WhipAppointment.ApptPostReq apptReq = new WhipAppointment.ApptPostReq();
		for (WhipAppointment.ApptGet agr :apptGet.apptList) {
			if (agr.slots != null) {
				for (CareCalendar.Cal s :agr.slots) {
					if (s.slots != null && s.remaining > 0) {
						apptReq.workshopId = agr.workshopId;
						apptReq.slotDate = s.slots[0];
						apptReq.type = type;
						apptReq.fullName = 'Mr. Apex Test';
						apptReq.phoneNumber = '0192651650';
						apptReq.emailAddress = 'test@apex.com.test';
						break;
					}
				}
			}
		}
		Vehicle_Ownership__c vo = [Select Id From Vehicle_Ownership__c][0];
		apptReq.vehicleOwner = vo.Id;
		system.debug('apptReq: ' + JSON.serialize(apptReq));
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(apptReq));
		WhipAppointment.reserveAppointment();
		WhipAppointment.ApptPostResp postRes = (WhipAppointment.ApptPostResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptPostResp.class);
		system.debug('reserveAppointment(): ' + postRes);
		
		RestContext.request.params.put('type', type);
		RestContext.request.params.put('yearf', String.valueOf(targetDate.year()));
		RestContext.request.params.put('yeart', String.valueOf(targetDate.year()));
		RestContext.request.params.put('monthf', String.valueOf(targetDate.month()));
		RestContext.request.params.put('montht', String.valueOf(targetDate.month()));
		WhipAppointment.getAppointment();
		WhipAppointment.ApptGetResp getRes = (WhipAppointment.ApptGetResp)JSON.deserialize(RestContext.response.responseBody.toString(), WhipAppointment.ApptGetResp.class);
		system.debug('getAppointment(): ' + getRes);

		RestContext.request = new RestRequest();
		Test.startTest();
		system.debug('releaseAppointment_Test(): try release appointment: ' + getRes.apptList[0].books[0].appointmentId);
		RestContext.request.params.put('appointmentId', getRes.apptList[0].books[0].appointmentId);
		WhipAppointment.releaseAppointment();
		Test.stopTest();

		Integer statusCode = RestContext.response.statusCode;
		System.assertEquals(statusCode, 200);
	}

	@isTest static void updateAppointmentStatus_TestNoRequest() {
		system.debug('updateAppointmentStatus_TestNoRequest');
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		Test.startTest();
		WhipAppointment.updateAppointmentStatus();
		Test.stopTest();

		Integer statusCode = RestContext.response.statusCode;
		system.debug('Status: ' + statusCode);
		System.assertEquals(404, statusCode);
	}
	@isTest static void updateAppointmentStatus_TestNoApptId() {
		system.debug('updateAppointmentStatus_TestNoApptId');
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		WhipAppointment.ApptUpdaReq apptReq = new WhipAppointment.ApptUpdaReq();
		system.debug('apptReq: ' + JSON.serialize(apptReq));
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(apptReq));

		Test.startTest();
		WhipAppointment.updateAppointmentStatus();
		Test.stopTest();

		Integer statusCode = RestContext.response.statusCode;
		system.debug('Status: ' + statusCode);
		System.assertEquals(400, statusCode);
	}
	// @isTest static void updateAppointmentStatus_TestNoFromStatus() {
	// 	system.debug('updateAppointmentStatus_TestNoFromStatus');
	// 	RestContext.response = new RestResponse();
	// 	RestContext.request = new RestRequest();
	// 	Service_Appointment__c[] sas = [
	// 		SELECT Id, Apppointment_Status__c
	// 		FROM Service_Appointment__c
	// 	];
	// 	WhipAppointment.ApptUpdaReq apptReq = new WhipAppointment.ApptUpdaReq();
	// 	apptReq.appointmentId = sas[0].Id;
	// 	system.debug('apptReq: ' + JSON.serialize(apptReq));
	// 	RestContext.request.requestBody = Blob.valueOf(JSON.serialize(apptReq));

	// 	Test.startTest();
	// 	WhipAppointment.updateAppointmentStatus();
	// 	Test.stopTest();

	// 	Integer statusCode = RestContext.response.statusCode;
	// 	system.debug('Status: ' + statusCode);
	// 	System.assertEquals(400, statusCode);
	// }
	@isTest static void updateAppointmentStatus_TestNoToStatus() {
		system.debug('updateAppointmentStatus_TestNoToStatus');
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		Service_Appointment__c[] sas = [
			SELECT Id, Apppointment_Status__c
			FROM Service_Appointment__c
		];
		WhipAppointment.ApptUpdaReq apptReq = new WhipAppointment.ApptUpdaReq();
		apptReq.appointmentId = sas[0].Id;
		// apptReq.fromStatus = sas[0].Apppointment_Status__c;
		system.debug('apptReq: ' + JSON.serialize(apptReq));
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(apptReq));

		Test.startTest();
		WhipAppointment.updateAppointmentStatus();
		Test.stopTest();

		Integer statusCode = RestContext.response.statusCode;
		system.debug('Status: ' + statusCode);
		System.assertEquals(400, statusCode);
	}

	@isTest static void updateAppointmentStatus_TestInvalidApptId() {
		system.debug('updateAppointmentStatus_TestInvalidApptId');
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		WhipAppointment.ApptUpdaReq apptReq = new WhipAppointment.ApptUpdaReq();
		apptReq.appointmentId = 'ABCD';
		// apptReq.fromStatus = 'ACTIVE';
		apptReq.toStatus = 'ARRIVED';
		system.debug('apptReq: ' + JSON.serialize(apptReq));
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(apptReq));

		Test.startTest();
		WhipAppointment.updateAppointmentStatus();
		Test.stopTest();

		Integer statusCode = RestContext.response.statusCode;
		system.debug('Status: ' + statusCode);
		System.assertEquals(404, statusCode);
	}
	// @isTest static void updateAppointmentStatus_TestInvalidFromStatus() {
	// 	system.debug('updateAppointmentStatus_TestInvalidFromStatus');
	// 	RestContext.response = new RestResponse();
	// 	RestContext.request = new RestRequest();
	// 	Service_Appointment__c[] sas = [
	// 		SELECT Id, Apppointment_Status__c
	// 		FROM Service_Appointment__c
	// 	];
	// 	WhipAppointment.ApptUpdaReq apptReq = new WhipAppointment.ApptUpdaReq();
	// 	apptReq.appointmentId = sas[0].Id;
	// 	apptReq.fromStatus = 'INVALID';
	// 	apptReq.toStatus = 'ARRIVED';
	// 	system.debug('apptReq: ' + JSON.serialize(apptReq));
	// 	RestContext.request.requestBody = Blob.valueOf(JSON.serialize(apptReq));

	// 	Test.startTest();
	// 	WhipAppointment.updateAppointmentStatus();
	// 	Test.stopTest();
		
	// 	Integer statusCode = RestContext.response.statusCode;
	// 	system.debug('Status: ' + statusCode);
	// 	System.assertEquals(404, statusCode);
	// }
	@isTest static void updateAppointmentStatus_TestInvalidToStatus() {
		system.debug('updateAppointmentStatus_TestInvalidToStatus');
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		Service_Appointment__c[] sas = [
			SELECT Id, Apppointment_Status__c
			FROM Service_Appointment__c
		];
		WhipAppointment.ApptUpdaReq apptReq = new WhipAppointment.ApptUpdaReq();
		apptReq.appointmentId = sas[0].Id;
		// apptReq.fromStatus = sas[0].Apppointment_Status__c;
		apptReq.toStatus = 'INVALID';
		system.debug('apptReq: ' + JSON.serialize(apptReq));
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(apptReq));

		Test.startTest();
		WhipAppointment.updateAppointmentStatus();
		Test.stopTest();

		Integer statusCode = RestContext.response.statusCode;
		system.debug('Status: ' + statusCode);
		System.assertEquals(400, statusCode);
	}

	@isTest static void updateAppointmentStatus_Test() {
		system.debug('updateAppointmentStatus_Test');
		RestContext.response = new RestResponse();
		RestContext.request = new RestRequest();
		Service_Appointment__c[] sas = [
			SELECT Id, Apppointment_Status__c
			FROM Service_Appointment__c
		];
		WhipAppointment.ApptUpdaReq apptReq = new WhipAppointment.ApptUpdaReq();
		apptReq.appointmentId = sas[0].Id;
		// apptReq.fromStatus = sas[0].Apppointment_Status__c;
		apptReq.toStatus = 'ARRIVED';
		system.debug('apptReq: ' + JSON.serialize(apptReq));
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(apptReq));

		Test.startTest();
		WhipAppointment.updateAppointmentStatus();
		Test.stopTest();

		Integer statusCode = RestContext.response.statusCode;
		system.debug('Status: ' + statusCode);
		System.assertEquals(200, statusCode);
	}

}