@isTest
private class ServiceAppointmentSetupPage_Test {

	public class testException extends Exception{}
	@TestSetup
	public static void setup() {
		Test.startTest();

		// Service_Type__c custSetST = new Service_Type__c();
		// custSetST.Name = 'TestService';
		// custSetST.Company__c = '028';
		// custSetST.Available__c = true;
		// insert custSetST;
		Service_Type__c custSetST = TestFactory.genServiceType('TestService', false);
		custSetST.Company__c = '028';
		custSetST.Available__c = true;
		insert custSetST;

		// List<Service_Quota__c> sq = TestFactory.genServiceQuota(1, true);
		// Service_Slot__c> ss = TestFactory.genServiceSlot(1, false);
		// ss.Is_Template__c = FALSE;
		// insert ss;
		// System.debug(ss);

		BusinessHours bh = [SELECT Id FROM BusinessHours LIMIT 1];

		Workshop__c ws = TestFactory.genWorkshop(1, false)[0];
		ws.Company__c = TestFactory.getCompany('028').Id;
		ws.BusinessHours__c = bh.Id;
		insert ws;

        UserDepotAccess__c userDepotAccess = new UserDepotAccess__c(
            User__c = UserInfo.getUserId(),
            Type__c = UserDepotAccessRepository.ACCESS_TYPE_SETUP,
            Workshop__c = ws.Id,
            Company__c = ws.Company__c
        );

        insert userDepotAccess;

		Employee_Master__c em = TestFactory.genEmpMaster(1, false)[0];
		em.Workshop__c = ws.Id;
		insert em;


		Test.stopTest();
	}

	@isTest static ServiceAppointmentSetupPage_Ctrl TestSetupTemplate() {
		PageReference curP = Page.ServiceAppointmentSetupPage;
		Test.setCurrentPage(curP);
		ServiceAppointmentSetupPage_Ctrl ctr = new ServiceAppointmentSetupPage_Ctrl();

        List<SelectOption> wsOpt = ctr.getWSList();
		debugMsg(ctr);

		String ws = wsOpt[1].getValue();
		ctr.selectedWS = ws;
		Integer yr = System.today().year();
		Integer mth = System.today().month();
		ApexPages.currentPage().getParameters().put('mth', String.valueOf(mth));
		ApexPages.currentPage().getParameters().put('yr', String.valueOf(yr));
        
		Service_Slot__c ss = new Service_Slot__c();
		ss.Is_Template__c = true;
		//ss.Active_Date__c = ServiceAppointmentSetupPage_Ctrl.TEMPLATE_DEFAULT;
        ss.Active_Date__c = System.today();
		ss.Workshop__c = [SELECT Id FROM Workshop__c LIMIT 1].Id;
		ss.Company__c = [SELECT Id FROM Company__c WHERE Name = '028'].Id;
		ss.Template_Day__c = System.now().format('EEE');
		insert ss;

		Service_Quota__c sq = TestFactory.genServiceQuota(1, false)[0];
		sq.Max_Appt_Per_Timeslot__c = 1;
		sq.Max_Quota__c = 1;
		sq.Interval_Per_Appt__c = 1;
		sq.Service_Slot__c = ss.Id;
		sq.Start_Time__c = DateTime.newInstance(ss.Active_Date__c, Time.newInstance(8,0,0,0));
		sq.End_Time__c = DateTime.newInstance(ss.Active_Date__c, Time.newInstance(11,0,0,0));
		insert sq;

		Employee_Shift__c emp = new Employee_Shift__c();
		emp.Is_Template__c = true;
		//emp.Active_Date__c = ServiceAppointmentSetupPage_Ctrl.TEMPLATE_DEFAULT;
		emp.Active_Date__c = System.today();
		emp.Workshop__c = [SELECT Id FROM Workshop__c LIMIT 1].Id;
		emp.Company__c = [SELECT Id FROM Company__c WHERE Name = '028'].Id;
		emp.Template_Day__c = System.now().format('EEE');
		emp.Employee_Master__c = [SELECT Id FROM Employee_Master__c LIMIT 1].Id;
        emp.Maximum_Appointment__c = 10;
		insert emp;

		sq = TestFactory.genServiceQuota(1, false)[0];
		sq.Max_Appt_Per_Timeslot__c = 1;
		sq.Max_Quota__c = 1;
		sq.Interval_Per_Appt__c = 1;
		sq.Service_Slot__c = null;
		sq.Start_Time__c = DateTime.newInstance(ss.Active_Date__c, Time.newInstance(8,0,0,0));
		sq.End_Time__c = DateTime.newInstance(ss.Active_Date__c, Time.newInstance(11,0,0,0));
		sq.Employee_Shift__c = emp.Id;
		insert sq;

		ctr.changeSetup();
		System.debug(ctr.templateSetup);
		debugMsg(ctr);
		System.assert(ctr.templateSetup);

		ctr.copyTemplate();


		debugMsg(ctr);

		//KL
		ctr.changeSetup();
		System.debug(ctr.templateSetup);
		ctr.copyTemplate();
		//KL

		return ctr;
	}

	@isTest static ServiceAppointmentSetupPage_Ctrl TestSlotsSetup() {
		PageReference curP = Page.ServiceAppointmentSetupPage;
		Test.setCurrentPage(curP);
		ServiceAppointmentSetupPage_Ctrl ctr = new ServiceAppointmentSetupPage_Ctrl();


		List<SelectOption> wsOpt = ctr.getWSList();
		debugMsg(ctr);
		System.assertEquals(2, wsOpt.size());
		System.assertEquals('', wsOpt[0].getValue());
		System.assertEquals('--Select--', wsOpt[0].getLabel());

		String ws = wsOpt[1].getValue();
		ctr.selectedWS = ws;

		Integer yr = System.today().year();
		Integer mth = System.today().month();
		ApexPages.currentPage().getParameters().put('mth', String.valueOf(mth));
		ApexPages.currentPage().getParameters().put('yr', String.valueOf(yr));
		ctr.populateSlots();
		debugMsg(ctr);
		Date startDate = Date.newInstance(yr, mth, 1).toStartOfWeek();
		Date endDate = Date.newInstance(yr, mth, Date.daysInMonth(yr, mth)).toStartOfWeek().addDays(6);
		System.assertEquals(startDate.daysBetween(endDate) + 1, ctr.slotMap.size());

		Date activeDate;
		for (ServiceAppointmentSetupPage_Ctrl.CalDaySlot cds : ctr.slotMap.values()) {
			if (cds.isActive) {
				activeDate = cds.day;
				break;
			}
		}

		ApexPages.currentPage().getParameters().put('date', activeDate.format());
		ctr.showSlotsModal();
		debugMsg(ctr);
		System.assertEquals(activeDate, ctr.selectedSlot.day);
		System.assertEquals(0, ctr.curSlotsList.size());

		ApexPages.currentPage().getParameters().put('modal', 'slot');
		ctr.addNewService();
		debugMsg(ctr);
		System.assertEquals(1, ctr.curSlotsList.size());

		List<SelectOption> stList = ctr.getServicesList();
		System.assertEquals(2, stList.size());
		System.assertEquals('TestService', stList[1].getValue());
		ctr.curSlotsList[0].Type__c = stList[1].getValue();
		ctr.curSlotsList[0].Max_Quota__c = 10;
		ctr.curSlotsList[0].Interval_Per_Appt__c = 20;
		ctr.curSlotsList[0].Start_Time__c = DateTime.newInstance(activeDate, Time.newInstance(8, 0, 0, 0));
		ctr.curSlotsList[0].End_Time__c = DateTime.newInstance(activeDate, Time.newInstance(18, 0, 0, 0));
		ctr.saveServices();
		debugMsg(ctr);
		List<Service_Slot__c> ss = [SELECT Id FROM Service_Slot__c];
		List<Service_Quota__c> sq = [SELECT Id FROM Service_Quota__c];
		System.assertEquals(1, ss.size());
		System.assertEquals(1, sq.size());

		return ctr;
	}

	@isTest static ServiceAppointmentSetupPage_Ctrl TestEditServiceSlot() {
		ServiceAppointmentSetupPage_Ctrl ctr = TestSlotsSetup();

		Date activeDate;
		for (ServiceAppointmentSetupPage_Ctrl.CalDaySlot cds : ctr.slotMap.values()) {
			if (cds.isActive) {
				activeDate = cds.day;
				break;
			}
		}

		ApexPages.currentPage().getParameters().put('date', activeDate.format());
		ctr.showSlotsModal();
		debugMsg(ctr);
		System.assertEquals(activeDate, ctr.selectedSlot.day);
		System.assertEquals(1, ctr.curSlotsList.size());
		ctr.curSlotsList[0].Max_Quota__c = 5;

		ApexPages.currentPage().getParameters().put('modal', 'slot');
		ctr.addNewService();
		debugMsg(ctr);
		System.assertEquals(2, ctr.curSlotsList.size());
		ctr.curSlotsList[1].Type__c = 'EditService';
		ctr.curSlotsList[1].Max_Quota__c = 10;
		ctr.curSlotsList[1].Interval_Per_Appt__c = 10;
		ctr.curSlotsList[1].Start_Time__c = ctr.curSlotsList[0].Start_Time__c;
		ctr.curSlotsList[1].End_Time__c = ctr.curSlotsList[0].End_Time__c;

		ctr.saveServices();
		debugMsg(ctr);
		List<Service_Slot__c> ss = [SELECT Id FROM Service_Slot__c];
		List<Service_Quota__c> sq = [SELECT Id FROM Service_Quota__c];
		System.assertEquals(1, ss.size());
		System.assertEquals(2, sq.size());

		return ctr;
	}

	@isTest static ServiceAppointmentSetupPage_Ctrl TestShiftsSetup() {
		PageReference curP = Page.ServiceAppointmentSetupPage;
		Test.setCurrentPage(curP);
		ServiceAppointmentSetupPage_Ctrl ctr = new ServiceAppointmentSetupPage_Ctrl();

		List<SelectOption> wsOpt = ctr.getWSList();
		debugMsg(ctr);
		System.assertEquals(2, wsOpt.size());
		System.assertEquals('', wsOpt[0].getValue());
		System.assertEquals('--Select--', wsOpt[0].getLabel());
		String ws = wsOpt[1].getValue();
		ctr.selectedWS = ws;



		Integer yr = System.today().year();
		Integer mth = System.today().month();
		ApexPages.currentPage().getParameters().put('mth', String.valueOf(mth));
		ApexPages.currentPage().getParameters().put('yr', String.valueOf(yr));
		ctr.populateSlots();
		debugMsg(ctr);
		Date startDate = Date.newInstance(yr, mth, 1).toStartOfWeek();
		Date endDate = Date.newInstance(yr, mth, Date.daysInMonth(yr, mth)).toStartOfWeek().addDays(6);
		System.assertEquals(startDate.daysBetween(endDate) + 1, ctr.slotMap.size());

		Date activeDate;
		Boolean found = false;
		for (ServiceAppointmentSetupPage_Ctrl.CalDayShift cds : ctr.shiftMap.values()) {
			if (cds.isActive) {
				activeDate = cds.day;
				break;
			}
		}
		ApexPages.currentPage().getParameters().put('date', activeDate.format());
		ApexPages.currentPage().getParameters().put('empId', '');
		ctr.showShiftModal();
		debugMsg(ctr);
		System.assertEquals(activeDate, ctr.selectedShift.day);
		System.assertEquals(0, ctr.curShiftList.size());

		List<SelectOption> emOpt = ctr.getCSAList();
		debugMsg(ctr);
		System.assertEquals(2, emOpt.size());
		System.assertEquals('', emOpt[0].getValue());
		System.assertEquals('--Select--', emOpt[0].getLabel());

		ctr.selectedEmp.Employee_Master__c = emOpt[1].getValue();
		ctr.selectedEmp.Maximum_Appointment__c = 10;
		ApexPages.currentPage().getParameters().put('modal', 'shift');
		ctr.addNewService();
		debugMsg(ctr);
		System.assertEquals(1, ctr.curShiftList.size());
		List<SelectOption> stList = ctr.getServicesList();
		System.assertEquals(2, stList.size());
		System.assertEquals('TestService', stList[1].getValue());
		ctr.curShiftList[0].Type__c = stList[1].getValue();
		ctr.curShiftList[0].Max_Quota__c = 10;
		ctr.curShiftList[0].Start_Time__c = DateTime.newInstance(activeDate, Time.newInstance(8, 0, 0, 0));
		ctr.curShiftList[0].End_Time__c = DateTime.newInstance(activeDate, Time.newInstance(18, 0, 0, 0));

		ctr.saveShift();
		debugMsg(ctr);
		List<Employee_Shift__c> es = [SELECT Id FROM Employee_Shift__c];
		List<Service_Quota__c> sq = [SELECT Id FROM Service_Quota__c];
		System.assertEquals(1, es.size());
		System.assertEquals(1, sq.size());

		ctr.templateSetup = true;
		ctr.showShiftModal();

		return ctr;
	}

	@isTest static ServiceAppointmentSetupPage_Ctrl TestEditEmployeeShift() {
		ServiceAppointmentSetupPage_Ctrl ctr = TestShiftsSetup();
		List<Employee_Shift__c> es = [SELECT Id FROM Employee_Shift__c];
		Date activeDate;
		Boolean found = false;
		for (ServiceAppointmentSetupPage_Ctrl.CalDayShift cds : ctr.shiftMap.values()) {
			if (cds.isActive) {
				activeDate = cds.day;
				break;
			}
		}
		ApexPages.currentPage().getParameters().put('date', activeDate.format());
		ApexPages.currentPage().getParameters().put('empId', es[0].Id);
		ctr.showShiftModal();
		debugMsg(ctr);
		System.assertEquals(activeDate, ctr.selectedShift.day);
		System.assertEquals(1, ctr.curShiftList.size());

		ctr.selectedEmp.Maximum_Appointment__c = 5;
		ctr.curShiftList[0].Max_Quota__c = 5;
		ctr.addNewService();
		debugMsg(ctr);
		System.assertEquals(2, ctr.curShiftList.size());

		ctr.curShiftList[1].Type__c = 'EditService';
		ctr.curShiftList[1].Max_Quota__c = 10;
		ctr.curShiftList[1].Start_Time__c = ctr.curShiftList[0].Start_Time__c;
		ctr.curShiftList[1].End_Time__c = ctr.curShiftList[0].End_Time__c;
		ctr.saveShift();
		debugMsg(ctr);
		List<Employee_Shift__c> esUpd = [SELECT Id FROM Employee_Shift__c];
		List<Service_Quota__c> sq = [SELECT Id FROM Service_Quota__c];
		System.assertEquals(1, esUpd.size());
		System.assertEquals(2, sq.size());

		return ctr;
	}

	@isTest static void TestSaveUnProd() {
		PageReference curP = Page.ServiceAppointmentSetupPage;
		Test.setCurrentPage(curP);
		ServiceAppointmentSetupPage_Ctrl ctr = new ServiceAppointmentSetupPage_Ctrl();
		Employee_Master__c em = [SELECT Id FROM Employee_Master__c];

		ApexPages.currentPage().getParameters().put('unprod', 'Sick Leave');
		ApexPages.currentPage().getParameters().put('csaId', em.Id);
		ApexPages.currentPage().getParameters().put('dates', String.valueOf(System.today()));
		ApexPages.currentPage().getParameters().put('mth', String.valueOf(System.today().month()));
		ApexPages.currentPage().getParameters().put('yr', String.valueOf(System.today().year()));
		ctr.saveUnprod();
		debugMsg(ctr);
		List<Employee_Shift__c> es = [SELECT Id, Unproductivity__c FROM Employee_Shift__c];
		System.assertEquals(1, es.size());
		System.assertEquals('Sick Leave', es[0].Unproductivity__c);

	}

	@isTest static void TestVisualforceComponents() {
		Service_Type__c custSetST = [SELECT Id, Name, DisplayName__c FROM Service_Type__c LIMIT 1];

		Service_Slot__c ss = TestFactory.genServiceSlot(1, false)[0];
		// Service_Slot__c ss = [SELECT Id, Name FROM Service_Slot__c][0];
		ss.Is_Template__c = false;
		//ss.Active_Date__c = ServiceAppointmentSetupPage_Ctrl.TEMPLATE_DEFAULT;
		ss.Active_Date__c = System.today();
		ss.Workshop__c = [SELECT Id FROM Workshop__c LIMIT 1].Id;
		ss.Company__c = [SELECT Id FROM Company__c WHERE Name = '028'].Id;
		ss.Template_Day__c = System.now().format('EEE');
		insert ss;

		Service_Quota__c sq = TestFactory.genServiceQuota(1, false)[0];
		sq.Max_Appt_Per_Timeslot__c = 1;
		sq.Max_Quota__c = 1;
		sq.Interval_Per_Appt__c = 1;
		sq.Service_Slot__c = ss.Id;
		sq.Start_Time__c = DateTime.newInstance(ss.Active_Date__c, Time.newInstance(8,0,0,0));
		sq.End_Time__c = DateTime.newInstance(ss.Active_Date__c, Time.newInstance(11,0,0,0));
		sq.Type__c = custSetST.DisplayName__c;
		insert sq;

		Employee_Shift__c emp = new Employee_Shift__c();
		emp.Is_Template__c = false;
		//emp.Active_Date__c = ServiceAppointmentSetupPage_Ctrl.TEMPLATE_DEFAULT;
		emp.Active_Date__c = System.today();
		emp.Workshop__c = [SELECT Id FROM Workshop__c LIMIT 1].Id;
		emp.Company__c = [SELECT Id FROM Company__c WHERE Name = '028'].Id;
		emp.Template_Day__c = System.now().format('EEE');
		emp.Employee_Master__c = [SELECT Id FROM Employee_Master__c LIMIT 1].Id;
        emp.Maximum_Appointment__c = 10;
		insert emp;

		sq = TestFactory.genServiceQuota(1, false)[0];
		sq.Max_Appt_Per_Timeslot__c = 1;
		sq.Max_Quota__c = 1;
		sq.Interval_Per_Appt__c = 1;
		sq.Service_Slot__c = null;
		sq.Start_Time__c = DateTime.newInstance(ss.Active_Date__c, Time.newInstance(8,0,0,0));
		sq.End_Time__c = DateTime.newInstance(ss.Active_Date__c, Time.newInstance(11,0,0,0));
		sq.Employee_Shift__c = emp.Id;
		insert sq;
		
		PageReference curP = Page.ServiceAppointmentSetupPage;
		Test.setCurrentPage(curP);
		ServiceAppointmentSetupPage_Ctrl ctr = new ServiceAppointmentSetupPage_Ctrl();

		ApexPages.currentPage().getParameters().put('mth', String.valueOf(System.today().month()));
		ApexPages.currentPage().getParameters().put('yr', String.valueOf(System.today().year()));
		ctr.populateSlots();
		debugMsg(ctr);
		ctr.changeCmp();
		debugMsg(ctr);

		//	Select WS
		Workshop__c ws = [SELECT Id, Name FROM Workshop__c LIMIT 1];
		ctr.selectedWS = ws.Id;
		ctr.populateSlots();
		
		System.assert(!ctr.slotMap.isEmpty());
		System.assert(!ctr.shiftMap.isEmpty());

		List<String> weekDays = ctr.getWeekDays();
		debugMsg(ctr);
		System.assertEquals(7, weekDays.size());

		Map<String, String> sbgMap = ctr.getServiceBg();
		debugMsg(ctr);
		System.assertEquals(1, sbgMap.size());

		System.debug(ctr.slotMap.isEmpty());
		List<String> sortServices = ctr.getLegends();	
		System.debug('sortServices: ' + JSON.serialize(sortServices));
		System.assertEquals(2, sortServices.size());

		Employee_Master__c empMaster = [SELECT Id, IsActive__c FROM Employee_Master__c LIMIT 1];
		empMaster.IsActive__c = false;
		update empMaster;

		//Test with employee active = false
		sortServices = ctr.getLegends();	
		System.debug('sortServices: ' + JSON.serialize(sortServices));
		System.assertEquals(2, sortServices.size());
	}

    @isTest
    static void testNoAccessSlotSetup(){
        PageReference curP = Page.ServiceAppointmentSetupPage;
		Test.setCurrentPage(curP);
		ServiceAppointmentSetupPage_Ctrl ctr = new ServiceAppointmentSetupPage_Ctrl();
        
		List<SelectOption> wsOpt = ctr.getWSList();
        Integer yr = System.today().year();
		Integer mth = System.today().month();
		ApexPages.currentPage().getParameters().put('mth', String.valueOf(mth));
		ApexPages.currentPage().getParameters().put('yr', String.valueOf(yr));
		ctr.populateSlots();
    }

    @isTest
    static void testNoBusinessHours(){
        for(Workshop__c workshop:[SELECT Id,BusinessHours__c FROM Workshop__c]){
            workshop.BusinessHours__c = null;
            update workshop;
        }
		PageReference curP = Page.ServiceAppointmentSetupPage;
		Test.setCurrentPage(curP);
		ServiceAppointmentSetupPage_Ctrl ctr = new ServiceAppointmentSetupPage_Ctrl();
        try{
            List<SelectOption> wsOpt = ctr.getWSList();
            debugMsg(ctr);
    
            String ws = wsOpt[1].getValue();
            ctr.selectedWS = ws;
            Integer yr = System.today().year();
            Integer mth = System.today().month();
            ApexPages.currentPage().getParameters().put('mth', String.valueOf(mth));
            ApexPages.currentPage().getParameters().put('yr', String.valueOf(yr));
    
            ctr.changeSetup();

            debugMsg(ctr);
            System.assert(false);
        }
        catch (Exception bhException){
            System.assert(true ,ctr.hasSetupBH);
        }
    }

	@isTest
	static void testClone(){
		PageReference curP = Page.ServiceAppointmentSetupPage;
		Test.setCurrentPage(curP);
		ServiceAppointmentSetupPage_Ctrl ctr = new ServiceAppointmentSetupPage_Ctrl();	
		
		BusinessHours bh = [SELECT Id FROM BusinessHours LIMIT 1];
		Workshop__c ws = TestFactory.genWorkshop(1, false)[0];
		ws.Company__c = TestFactory.getCompany('028').Id;
		ws.BusinessHours__c = bh.Id;
		insert ws;

		Integer yr = System.today().year();
		Integer mth = System.today().month();
		ApexPages.currentPage().getParameters().put('mth', String.valueOf(mth));
		ApexPages.currentPage().getParameters().put('yr', String.valueOf(yr));

		ctr.selectedWS = ws.Id;
		ctr.populateSlots();

		Service_Slot__c ss = TestFactory.genServiceSlot(1, true)[0];

		Service_Quota__c sq = TestFactory.genServiceQuota(2, false)[0];
		sq.Max_Appt_Per_Timeslot__c = 1;
		sq.Max_Quota__c = 1;
		sq.Interval_Per_Appt__c = 1;
		sq.Service_Slot__c = ss.Id;
		sq.Start_Time__c = DateTime.newInstance(ss.Active_Date__c, Time.newInstance(8,0,0,0));
		sq.End_Time__c = DateTime.newInstance(ss.Active_Date__c, Time.newInstance(11,0,0,0));
		insert sq;
	
		ServiceAppointmentSetupPage_Ctrl.CalDaySlot currD = new ServiceAppointmentSetupPage_Ctrl.CalDaySlot(System.today(), ss);
		currD.slots.put(sq.Type__c, sq);
		ServiceAppointmentSetupPage_Ctrl.CalDaySlot currE = currD.clone(System.today());
	}

	private static void debugMsg(ServiceAppointmentSetupPage_Ctrl ctr) {
		if (ctr.errMsg != null && ctr.errMsg.size() > 0) {
			System.debug('ERROR DEBUG: ' + ctr.errMsg);
			throw new testException(ctr.errMsg[0]);
		}
	}
}