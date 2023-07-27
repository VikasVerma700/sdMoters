@IsTest
private class ServiceApptBooking_Test {
	@TestSetup
	public static void setup() {
		TestFactory.genTriggerSettings('Vehicle', true);
		TestFactory.genTriggerSettings('Vehicle Ownership', true);
		M3TechApiWrapper_Test.setup();
	}

	@isTest static void testSend1() {
		Service_Appointment__c sa = TestFactory.genSvcAppt(1, true)[0];
		sa.Contact_No__c = '0192651650';
		update sa;
		String ret = null;
		String expected = string.format('{0} ({1})', new string[] { ret, u.beautifyPhone('', sa.Contact_No__c) });
		//TestWSMock.M3TechAPI_Mock mock = new TestWSMock.M3TechAPI_Mock(ret);
		TestWSMock.M3TechApiService_Mock mock = new TestWSMock.M3TechApiService_Mock(ret);
		Test.setMock(WebServiceMock.class, mock);
		Test.startTest();
		String actual = ServiceApptBooking.sendApptSMS(sa, 'test');
		Test.stopTest();
		System.assertEquals(expected, actual);
	}

	@isTest static void testSend2() {
		Service_Appointment__c sa = TestFactory.genSvcAppt(1, true)[0];
		sa.Contact_No__c = '0192651650';
		update sa;
		string success = '00';
		string msgID = '1234';
		TestWSMock.M3TechApiService_SUCC mock = new TestWSMock.M3TechApiService_SUCC(msgID,success);
		test.setMock(WebServiceMock.class,mock);
		test.startTest();
		M3TechApiServiceWrapper.DeliverMsgReturnWrapper actual = ServiceApptBooking.sendApptSMS2(sa, 'test');
		test.stopTest();
		System.assertEquals(msgID, actual.msgId);
		system.assertEquals(success, actual.returnCode);
		/** 
		String ret = 'YES';
		String expected = string.format('{0} ({1})', new string[] { ret, u.beautifyPhone('', sa.Contact_No__c) });
		TestWSMock.M3TechAPI2_Mock mock = new TestWSMock.M3TechAPI2_Mock(ret);
		Test.setMock(WebServiceMock.class, mock);
		Test.startTest();
		String actual = ServiceApptBooking.sendApptSMS2(sa, 'test');
		Test.stopTest();
		System.assertEquals(expected, actual);
		*/
		
	}

	@isTest static void testServiceTypes() {
		Service_Type__c svcType = new Service_Type__c(Name = 'Test1', Company__c = '028', Workshop__c = 'A1,A3');
		insert svcType;
		Test.startTest();
		List<Service_Type__c> withFilterSvc = ServiceApptBooking.getServices('028', new List<String> { 'A1' });
		List<Service_Type__c> wrongFilterSvc = ServiceApptBooking.getServices('028', new List<String> { 'TEST' });
		Test.stopTest();
		System.assertEquals(withFilterSvc.size(), 1);
		System.assertEquals(withFilterSvc[0].Name, svcType.Name);
		System.assertEquals(wrongFilterSvc.size(), 0);
	}

	@isTest static void testWSList() {
		List<Service_Quota__c> curQ = TestFactory.genServiceQuota(2, true);
		List<String> types = new List<String>();
		for (Service_Quota__c q : curQ) { types.add(q.Type__c); }
		Service_Slot__c ss = [SELECT Id, Workshop__c, Company__r.Name FROM Service_Slot__c WHERE Id = :curQ[0].Service_Slot__c];
		update (new Workshop__c(Id = ss.Workshop__c, Service_Centre_Name__c = 'LALA CENTRE', Vehicle_Type__c = 'NC'));
		Vehicle_Ownership__c vo = TestFactory.genVO(1, true)[0];
		Vehicle_Type__c vType = TestFactory.genVehType('NC', true);
		update (new Vehicle__c(Id = vo.Vehicle__c, Vehicle_Type__c = vType.Id));
		vo = [SELECT Id, Vehicle__r.Vehicle_Type__r.Name, Vehicle__r.Vehicle_Make__r.Name FROM Vehicle_Ownership__c WHERE Id = :vo.Id];
		ServiceApptBooking.Booking curBooking = new ServiceApptBooking.Booking();
		curBooking.cmp = ss.Company__r.Name;
		curBooking.vo = vo;
		curBooking.selectedTypes = types;
		Test.startTest();
		List<Workshop__c> wsList = ServiceApptBooking.populateWSList(curBooking);
		curBooking.selectedTypes.add('nosuchtype');
		try {
			List<Workshop__c> noWSList = ServiceApptBooking.populateWSList(curBooking);
			System.assert(false);
		} catch (ServiceApptBooking.ApptException e) {}
		Test.stopTest();

		System.assertEquals(wsList.size(), 1);
		System.assertEquals(wsList[0].Id, ss.Workshop__c);
	}

	@isTest static void testVALWSList() {
		List<Service_Quota__c> curQ = TestFactory.genServiceQuota(2, true);
		List<String> types = new List<String>();
		for (Service_Quota__c q : curQ) { types.add(q.Type__c); }
		Service_Slot__c ss = [SELECT Id, Workshop__c, Company__r.Name FROM Service_Slot__c WHERE Id = :curQ[0].Service_Slot__c];
		update (new Workshop__c(Id = ss.Workshop__c, Service_Centre_Name__c = 'TEST CENTRE', Vehicle_Type__c = 'NC'));
		Vehicle_Ownership__c vo = TestFactory.genVO(1, true)[0];
		Vehicle_Type__c vType = TestFactory.genVehType('NC', true);
		update (new Vehicle__c(Id = vo.Vehicle__c, Vehicle_Type__c = vType.Id));
		vo = [SELECT Id, Vehicle__r.Vehicle_Type__r.Name, Vehicle__r.Vehicle_Make__r.Name FROM Vehicle_Ownership__c WHERE Id = :vo.Id];
		ServiceApptBooking.Booking curBooking = new ServiceApptBooking.Booking();
		curBooking.cmp = ss.Company__r.Name;
		curBooking.division = 'test';
		curBooking.vo = vo;
		curBooking.selectedTypes = types;
		Test.startTest();
		List<Workshop__c> wsList = ServiceApptBooking.populateWSList(curBooking);
		Test.stopTest();

		System.assertEquals(wsList.size(), 1);
		System.assertEquals(wsList[0].Id, ss.Workshop__c);
	}

	@IsTest static void testCSAList() {
		List<Service_Quota__c> curQ = TestFactory.genCSAServiceQuota(2, true);
		List<String> types = new List<String>();
		for (Service_Quota__c q : curQ) { types.add(q.Type__c); }
		Employee_Shift__c es = [SELECT Id, Workshop__c, Company__r.Name, Employee_Master__c FROM Employee_Shift__c WHERE Id = :curQ[0].Employee_Shift__c];
		List<Workshop__c> wsList = new List<Workshop__c> { new Workshop__c(Id = es.Workshop__c, Service_Centre_Name__c = 'TEST CENTRE') };
		update wsList;
		ServiceApptBooking.Booking curBooking = new ServiceApptBooking.Booking();
		curBooking.cmp = es.Company__r.Name;
		curBooking.division = 'test';
		curBooking.selectedTypes = types;
		Test.startTest();
		List<Employee_Master__c> emList = ServiceApptBooking.populateCSAList(wsList, curBooking);
		curBooking.selectedTypes.add('nosuchtype');
		List<Employee_Master__c> noTypeList = ServiceApptBooking.populateCSAList(wsList, curBooking);
		Test.stopTest();
		System.assertEquals(emList.size(), 1);
		System.assertEquals(emList[0].Id, es.Employee_Master__c);
		System.assertEquals(noTypeList.size(), 0);
	}

	@IsTest static void testWSCalDayMap() {
		List<Service_Quota__c> curQ = TestFactory.genServiceQuota(2, true);
		List<String> types = new List<String>();
		for (Service_Quota__c q : curQ) { types.add(q.Type__c); }
		Service_Slot__c ss = [SELECT Id, Workshop__c, Workshop__r.Id, Workshop__r.Name, Workshop__r.Appointment_Interval__c, Workshop__r.Auto_Assign_CSA__c,
							Company__r.Name, Active_Date__c FROM Service_Slot__c WHERE Id = :curQ[0].Service_Slot__c];
		Service_Quota__c specialQ = TestFactory.genServiceQuota(2, false)[0];
		Date newD = ss.Active_Date__c.addDays(2);
		update (new Service_Slot__c(Id = specialQ.Service_Slot__c, Active_Date__c = newD));
		specialQ.Start_Time__c = DateTime.newInstance(newD, specialQ.Start_Time__c.time());
		specialQ.End_Time__c = DateTime.newInstance(newD, specialQ.End_Time__c.time());
		specialQ.Type__c = types[0];
		insert specialQ;
		DateTime avoidT = curQ[0].Start_Time__c.addMinutes(ss.Workshop__r.Appointment_Interval__c.intValue());
		Non_Working__c nW = new Non_Working__c(Name = 'Lunch', Company__c = ss.Company__r.Name, Workshop__c = ss.Workshop__r.Name,
											Hour__c = avoidT.hour(), Minute__c = avoidT.minute());
		insert nW;
		ServiceApptBooking.Booking curBooking = new ServiceApptBooking.Booking();
		curBooking.cmp = ss.Company__r.Name;
		curBooking.ws = ss.Workshop__r;
		curBooking.selectedTypes = types;

		Test.startTest();
		Map<Date, ServiceApptBooking.CalDay> res = ServiceApptBooking.populateCalDayMap(ss.Active_Date__c.addDays(-1), newD.addDays(2), curBooking);
		Test.stopTest();
		System.assertEquals(1, res.size());
		System.assert(res.containsKey(ss.Active_Date__c));
		ServiceApptBooking.CalDay day = res.get(ss.Active_Date__c);
		System.assert(day.avail);
		DateTime curTime = curQ[0].Start_Time__c;
		while(curTime.addMinutes(ss.Workshop__r.Appointment_Interval__c.intValue()) < curQ[0].End_Time__c) {
			if (curTime == avoidT) {
				System.assert(!day.slots.contains(curTime));
			} else {
				System.assert(day.slots.contains(curTime));
			}
			curTime = curTime.addMinutes(ss.Workshop__r.Appointment_Interval__c.intValue());
		}
	}

	@IsTest static void testWSCalDayMapWithFullSlots() {
		List<Service_Quota__c> curQ = TestFactory.genServiceQuota(2, false);
		for (Service_Quota__c q : curQ) { q.Max_Quota__c = 3; }
		Integer maxInterval = 2;
		curQ[1].Interval_Per_Appt__c = maxInterval;
		insert curQ;
		List<String> types = new List<String>();
		for (Service_Quota__c q : curQ) { types.add(q.Type__c); }
		Service_Slot__c ss = [SELECT Id, Workshop__c, Workshop__r.Id, Workshop__r.Appointment_Interval__c, Workshop__r.Auto_Assign_CSA__c, Company__c,
							Company__r.Name, Active_Date__c FROM Service_Slot__c WHERE Id = :curQ[0].Service_Slot__c];
		List<Service_Appointment__c> saList = TestFactory.genSvcAppt(2, false);
		List<Appointment_Utilization__c> utilList = new List<Appointment_Utilization__c>();
		for (Service_Appointment__c sa : saList) {
			sa.Appointment_Date__c = curQ[0].Start_Time__c.addMinutes(ss.Workshop__r.Appointment_Interval__c.intValue());
			sa.Workshop__c = ss.Workshop__c;
			sa.Company__c = ss.Company__c;
		}
		saList[0].Service_Request__c = String.join(types, ';');
		saList[1].Appointment_Date__c = saList[0].Appointment_Date__c.addMinutes((maxInterval * ss.Workshop__r.Appointment_Interval__c).intValue());
		saList[1].Service_Request__c = curQ[0].Type__c;
		insert saList;

		for (Service_Quota__c q : curQ) { utilList.add(new Appointment_Utilization__c(Service_Appointment__c = saList[0].Id, Service_Quota__c = q.Id)); }
		utilList.add(new Appointment_Utilization__c(Service_Appointment__c = saList[1].Id, Service_Quota__c = curQ[0].Id));
		insert utilList;

		// we add in the times that the appt takes up here
		// start with the first since we start the first appt later
		Set<DateTime> avoidT = new Set<DateTime> { curQ[0].Start_Time__c };
		// time taken by first appt
		for (Integer i = 0; i < maxInterval; i++) {
			avoidT.add(saList[0].Appointment_Date__c.addMinutes((i * ss.Workshop__r.Appointment_Interval__c).intValue()));
		}
		avoidT.add(saList[1].Appointment_Date__c);

		ServiceApptBooking.Booking curBooking = new ServiceApptBooking.Booking();
		curBooking.cmp = ss.Company__r.Name;
		curBooking.ws = ss.Workshop__r;
		curBooking.selectedTypes = types;

		Test.startTest();
		Map<Date, ServiceApptBooking.CalDay> res = ServiceApptBooking.populateCalDayMap(ss.Active_Date__c.addDays(-1), ss.Active_Date__c.addDays(2), curBooking);
		Test.stopTest();
		System.assertEquals(1, res.size());
		System.assert(res.containsKey(ss.Active_Date__c));
		ServiceApptBooking.CalDay day = res.get(ss.Active_Date__c);
		System.assert(day.avail);
		DateTime curTime = curQ[0].Start_Time__c;
		while (curTime.addMinutes(ss.Workshop__r.Appointment_Interval__c.intValue()) < curQ[0].End_Time__c) {
			if (avoidT.contains(curTime)) {
				System.assert(!day.slots.contains(curTime));
			} else {
				System.assert(day.slots.contains(curTime));
			}
			curTime = curTime.addMinutes(ss.Workshop__r.Appointment_Interval__c.intValue());
		}
	}

	@IsTest static void testCSACalDayMap() {
		List<Service_Quota__c> curQ = TestFactory.genCSAServiceQuota(2, true);
		List<String> types = new List<String>();
		for (Service_Quota__c q : curQ) { types.add(q.Type__c); }

		Employee_Shift__c es = [SELECT Id, Workshop__c, Workshop__r.Id, Workshop__r.Name, Workshop__r.Appointment_Interval__c, Workshop__r.Auto_Assign_CSA__c,
								Company__r.Name, Active_Date__c FROM Employee_Shift__c WHERE Id = :curQ[0].Employee_Shift__c];

		List<Service_Quota__c> wsQuota = TestFactory.genServiceQuota(curQ.size(), false);
		for (Integer i = 0; i < curQ.size(); i++) {
			wsQuota[i].Type__c = curQ[i].Type__c;
			wsQuota[i].Start_Time__c = curQ[i].Start_Time__c;
			wsQuota[i].End_Time__c = curQ[i].End_Time__c;
		}
		update (new Service_Slot__c(Id = wsQuota[0].Service_Slot__c, Workshop__c = es.Workshop__c, Active_Date__c = curQ[0].Start_Time__c.date()));
		insert wsQuota;

		Service_Quota__c specialQ = TestFactory.genCSAServiceQuota(1, false)[0];
		Date newD = es.Active_Date__c.addDays(1);
		update (new Employee_Shift__c(Id = specialQ.Employee_Shift__c, Active_Date__c = newD, Workshop__c = es.Workshop__c));
		specialQ.Start_Time__c = DateTime.newInstance(newD, specialQ.Start_Time__c.time());
		specialQ.End_Time__c = DateTime.newInstance(newD, specialQ.End_Time__c.time());
		specialQ.Type__c = types[0];

		insert specialQ;
		DateTime avoidT = curQ[0].Start_Time__c.addMinutes(es.Workshop__r.Appointment_Interval__c.intValue());
		Non_Working__c nW = new Non_Working__c(Name = 'Lunch', Company__c = es.Company__r.Name, Workshop__c = es.Workshop__r.Name,
											Hour__c = avoidT.hour(), Minute__c = avoidT.minute());
		insert nW;
		ServiceApptBooking.Booking curBooking = new ServiceApptBooking.Booking();
		curBooking.cmp = es.Company__r.Name;
		curBooking.ws = es.Workshop__r;
		curBooking.ws.Auto_Assign_CSA__c = true;
		curBooking.selectedTypes = types;

		Test.startTest();
		Map<Date, ServiceApptBooking.CalDay> res = ServiceApptBooking.populateCalDayMap(es.Active_Date__c.addDays(-1), newD.addDays(1), curBooking);
		Test.stopTest();
		System.assertEquals(res.size(), 1);
		System.assert(res.containsKey(es.Active_Date__c));
		ServiceApptBooking.CalDay day = res.get(es.Active_Date__c);
		System.assert(day.avail);
		DateTime curTime = curQ[0].Start_Time__c;
		while(curTime.addMinutes(es.Workshop__r.Appointment_Interval__c.intValue()) < curQ[0].End_Time__c) {
			if (curTime == avoidT) {
				System.assert(!day.slots.contains(curTime));
			} else {
				System.assert(day.slots.contains(curTime));
			}
			curTime = curTime.addMinutes(es.Workshop__r.Appointment_Interval__c.intValue());
		}
	}

	@IsTest static void testCSACalDayMapWithUnprod() {
		Service_Quota__c normalQ = TestFactory.genCSAServiceQuota(1, true)[0];
		List<String> types = new List<String>{ normalQ.Type__c };
		Employee_Shift__c es = [SELECT Id, Workshop__c, Workshop__r.Id, Workshop__r.Name, Workshop__r.Appointment_Interval__c, Workshop__r.Auto_Assign_CSA__c,
								Company__r.Name, Active_Date__c FROM Employee_Shift__c WHERE Id = :normalQ.Employee_Shift__c];
		List<Service_Quota__c> wsQuota = TestFactory.genServiceQuota(1, false);
		wsQuota[0].Type__c = normalQ.Type__c;
		wsQuota[0].Start_Time__c = normalQ.Start_Time__c;
		wsQuota[0].End_Time__c = normalQ.End_Time__c;
		update (new Service_Slot__c(Id = wsQuota[0].Service_Slot__c, Workshop__c = es.Workshop__c, Active_Date__c = normalQ.Start_Time__c.date()));
		insert wsQuota;
		Date newD = es.Active_Date__c.addDays(1);
		Service_Quota__c unprodQ = TestFactory.genCSAServiceQuota(1, false)[0]; // creating another employee shift
		unprodQ.Start_Time__c = DateTime.newInstance(newD, unprodQ.Start_Time__c.time());
		unprodQ.End_Time__c = DateTime.newInstance(newD, unprodQ.End_Time__c.time());
		unprodQ.Type__c = types[0];
		DateTime endTime = unprodQ.Start_Time__c.addMinutes(es.Workshop__r.Appointment_Interval__c.intValue());
		Employee_Shift__c newES = new Employee_Shift__c(Id = unprodQ.Employee_Shift__c, Active_Date__c = newD, Unproductivity__c = 'Test',
														Workshop__c = es.Workshop__c, Allow_Work_On_Unprod__c = true,
														Unproductive_Start_Time__c = unprodQ.Start_Time__c, Unproductive_End_Time__c = endTime);
		update newES;
		insert unprodQ;
		wsQuota = TestFactory.genServiceQuota(1, false);
		wsQuota[0].Type__c = unprodQ.Type__c;
		wsQuota[0].Start_Time__c = unprodQ.Start_Time__c;
		wsQuota[0].End_Time__c = unprodQ.End_Time__c;
		update (new Service_Slot__c(Id = wsQuota[0].Service_Slot__c, Workshop__c = es.Workshop__c, Active_Date__c = unprodQ.Start_Time__c.date()));
		insert wsQuota;

		ServiceApptBooking.Booking curBooking = new ServiceApptBooking.Booking();
		curBooking.cmp = es.Company__r.Name;
		curBooking.ws = es.Workshop__r;
		curBooking.ws.Auto_Assign_CSA__c = true;
		curBooking.selectedTypes = types;

		Test.startTest();
		Map<Date, ServiceApptBooking.CalDay> res = ServiceApptBooking.populateCalDayMap(es.Active_Date__c.addDays(-1), newD.addDays(1), curBooking);
		Test.stopTest();
		System.assertEquals(res.size(), 2);
		System.assert(res.containsKey(es.Active_Date__c));
		ServiceApptBooking.CalDay day1 = res.get(es.Active_Date__c);
		System.assert(day1.avail);
		DateTime curTime = normalQ.Start_Time__c;
		while (curTime.addMinutes(es.Workshop__r.Appointment_Interval__c.intValue()) < normalQ.End_Time__c) {
			System.assert(day1.slots.contains(curTime));
			curTime = curTime.addMinutes(es.Workshop__r.Appointment_Interval__c.intValue());
		}
		ServiceApptBooking.CalDay day2 = res.get(newES.Active_Date__c);
		System.assert(day2.avail);
		System.assert(!day2.slots.contains(unprodQ.Start_Time__c));
		curTime = endTime;
		while (curTime.addMinutes(es.Workshop__r.Appointment_Interval__c.intValue()) < unprodQ.End_Time__c) {
			System.assert(day2.slots.contains(curTime));
			curTime = curTime.addMinutes(es.Workshop__r.Appointment_Interval__c.intValue());
		}
	}

	@IsTest static void testCSACalDayMapWithMaxCSA() {
		Service_Quota__c normalQ = TestFactory.genCSAServiceQuota(1, false)[0];
		normalQ.Max_Quota__c = 3;
		insert normalQ;

		List<String> types = new List<String>{ normalQ.Type__c };
		Employee_Shift__c es = [SELECT Id, Workshop__c, Workshop__r.Id, Workshop__r.Name, Workshop__r.Appointment_Interval__c, Workshop__r.Auto_Assign_CSA__c,
								Company__r.Name, Active_Date__c, Employee_Master__c FROM Employee_Shift__c WHERE Id = :normalQ.Employee_Shift__c];

		Service_Quota__c apptQuota = TestFactory.genCSAServiceQuota(1, false)[0]; // creating another employee shift
		apptQuota.Max_Quota__c = 2;
		apptQuota.Type__c = types[0];
		Employee_Shift__c newES = new Employee_Shift__c(Id = apptQuota.Employee_Shift__c, Maximum_Appointment__c = 1, Workshop__c = es.Workshop__c);
		update newES;
		insert apptQuota;

		List<Service_Quota__c> wsQuota = TestFactory.genServiceQuota(2, false);
		update (new Service_Slot__c(Id = wsQuota[0].Service_Slot__c, Workshop__c = es.Workshop__c, Active_Date__c = normalQ.Start_Time__c.date()));
		wsQuota[0].Type__c = normalQ.Type__c;
		wsQuota[0].Start_Time__c = normalQ.Start_Time__c;
		wsQuota[0].End_Time__c = normalQ.End_Time__c;
		wsQuota[1].Type__c = apptQuota.Type__c;
		wsQuota[1].Start_Time__c = apptQuota.Start_Time__c;
		wsQuota[1].End_Time__c = apptQuota.End_Time__c;
		insert wsQuota;

		List<Service_Appointment__c> apptList = TestFactory.genSvcAppt(2, false);
		for (Service_Appointment__c sa : apptList) {
			sa.Workshop__c = es.Workshop__c;
			sa.Company__c = es.Company__c;
		}
		apptList[0].Employee_Master__c = es.Employee_Master__c;
		apptList[0].Appointment_Date__c = normalQ.Start_Time__c;
		apptList[1].Appointment_Date__c = apptQuota.Start_Time__c;
		apptList[1].Employee_Master__c = [SELECT Id, Employee_Master__c FROM Employee_Shift__c WHERE Id = :newES.Id].Employee_Master__c;
		insert apptList;

		List<Appointment_Utilization__c> apptUtil = new List<Appointment_Utilization__c> { new Appointment_Utilization__c(Service_Appointment__c = apptList[0].Id,
																														Service_Quota__c = normalQ.Id),
																						new Appointment_Utilization__c(Service_Appointment__c = apptList[1].Id,
																														Service_Quota__c = apptQuota.Id) };
		insert apptUtil;
		ServiceApptBooking.Booking curBooking = new ServiceApptBooking.Booking();
		curBooking.cmp = es.Company__r.Name;
		curBooking.ws = es.Workshop__r;
		curBooking.ws.Auto_Assign_CSA__c = true;
		curBooking.selectedTypes = types;

		Test.startTest();
		Map<Date, ServiceApptBooking.CalDay> res = ServiceApptBooking.populateCalDayMap(es.Active_Date__c.addDays(-1), es.Active_Date__c.addDays(1), curBooking);
		Test.stopTest();
		System.assertEquals(res.size(), 1);
		System.assert(res.containsKey(es.Active_Date__c));
		ServiceApptBooking.CalDay day1 = res.get(es.Active_Date__c);
		System.assert(day1.avail);
		DateTime curTime = normalQ.Start_Time__c.addMinutes(es.Workshop__r.Appointment_Interval__c.intValue());
		System.assert(!day1.slots.contains(normalQ.Start_Time__c));
		while (curTime.addMinutes(es.Workshop__r.Appointment_Interval__c.intValue()) < normalQ.End_Time__c) {
			System.assert(day1.slots.contains(curTime));
			System.assert(day1.csaAvailTimes.get(curTime).contains(es.Employee_Master__c));
			curTime = curTime.addMinutes(es.Workshop__r.Appointment_Interval__c.intValue());
		}
	}

	@IsTest static void testAllocateCSA() {
		Employee_Master__c em = TestFactory.genEmpMaster(1, true)[0];
	/*    System.debug('bengdebug: ' +[SELECT Id, Unique_Check__c FROM User_Config__c]);
		User_Config__c uConfig;
		uConfig = TestFactory.genUserConfig(1, false)[0];
		uConfig.Employee_Master__c = em.Id;
		uConfig.User__c = null;
		insert uConfig;*/

		ServiceApptBooking.Booking curBooking = new ServiceApptBooking.Booking();
		curBooking.selectedTime = DateTime.now();
		ServiceApptBooking.CalDay day = new ServiceApptBooking.CalDay(curBooking.selectedTime.date());
		day.csaAvailTimes = new Map<DateTime, Set<Id>> { curBooking.selectedTime => new Set<Id> { em.Id }};
		Test.startTest();
		Employee_Master__c rv = ServiceApptBooking.allocateCSA(curBooking, day);
		Test.stopTest();
		System.debug(rv);
		System.assertEquals(rv.Id, em.Id);
	}

	@IsTest static void testFilterAutoAssignWS() {
		List<Workshop__c> wsList = TestFactory.genWorkshop(1, false);
		wsList[0].Auto_Assign_CSA__c = true;
		insert wsList;
		List<Employee_Master__c> empMaster = TestFactory.genEmpMaster(2, false);
		empMaster[0].Workshop__c = wsList[0].Id;
		Test.startTest();
		List<Workshop__c> rv = ServiceApptBooking.filterAutoAssignWS(wsList, empMaster);
		Test.stopTest();
		System.assertEquals(rv.size(), 1);
		System.assertEquals(wsList[0].Id, rv[0].Id);
	}

	@IsTest static void testCheckBooking() {
		Global_Trigger_Settings__c vehTrig = TestFactory.genTriggerSettings('Vehicle', false);
		vehTrig.Activated__c = false;
		Global_Trigger_Settings__c voTrig = TestFactory.genTriggerSettings('Vehicle Ownership', false);
		voTrig.Activated__c = false;
		insert (new List<Global_Trigger_Settings__c> { vehTrig, voTrig });
		Service_Quota__c quota = TestFactory.genServiceQuota(1, true)[0];
		Vehicle_Ownership__c vo = TestFactory.genVO(1, true)[0];
		List<Appointment_Utilization__c> apptUtil = TestFactory.genApptUtilization(1, true);
		Service_Appointment__c sa = new Service_Appointment__c(Id = apptUtil[0].Service_Appointment__c);
		sa.Vehicle_Ownership__c = vo.Id;
		sa.Appointment_Date__c = quota.Start_Time__c;
		sa.System_Control__c = true;
		update sa;

		Test.startTest();
		ServiceApptBooking.Booking curBooking = new ServiceApptBooking.Booking(sa.Id);
		curBooking.selectedTime = curBooking.selectedTime.addMinutes(30);
		curBooking.makeBooking(true);
		Test.stopTest();
		Service_Appointment__c checkSA = [SELECT Id, Appointment_Date__c FROM Service_Appointment__c WHERE Id = :sa.Id];
		System.assertEquals(checkSA.Appointment_Date__c, curBooking.selectedTime);
	}

	@IsTest static void testToBooking() {
		Service_Appointment__c sa = TestFactory.genSvcAppt(1, true)[0];
		Test.startTest();
		ServiceApptBooking.APIBooking apiBook = new ServiceApptBooking.APIBooking(sa.Id);
		ServiceApptBooking.Booking curBooking = apiBook.toBooking();
		Test.stopTest();
		System.assertEquals(curBooking.sa.Id, sa.Id);
	}

	@IsTest static void testApptQR() {
		Service_Appointment__c sa = TestFactory.genSvcAppt(1, true)[0];
		Test.startTest();
		List<String> qr = ServiceApptBooking.getApptQR(new List<Id> { sa.Id });
		Test.stopTest();
		for (String s : qr) {
		  System.assert(s.startsWith(ServiceApptBooking.QR_SRC));
		}
	}

	@IsTest static void testVOQR() {
		Service_Appointment__c sa = TestFactory.genSvcAppt(1, true)[0];
		Test.startTest();
		List<String> qr = ServiceApptBooking.getVOQR(new List<Id> { sa.Vehicle_Ownership__c }, '02');
		Test.stopTest();
		for (String s : qr) {
		  System.assert(s.startsWith(ServiceApptBooking.QR_SRC));
		}
	}
}