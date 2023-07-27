@isTest
private class ServiceAppointmentBookingPage_Test {

    public class TestException extends Exception{}
    @TestSetup
    public static void setup() {
        Test.startTest();
        TestFactory.genTriggerSettings('Vehicle', true);
        TestFactory.genTriggerSettings('Vehicle Ownership', true);
        TestFactory.genTriggerSettings('Employees Shift Maintenance', true);

        Service_Type__c custSetST = TestFactory.genServiceType('TestService', true);

        List<Company__c> companyList = TestFactory.genCompany(1, false);
        companyList[0].name = '028';
        insert companyList;

        BusinessHours BH = [SELECT Id FROM BusinessHours WHERE Name = 'Default'];
        Time BH_INIT = Time.newInstance(12, 0, 0, 0);
        DateTime startDateTime = System.today();
        do {
            startDateTime = startDateTime.addDays(1);
        } while (!BusinessHours.isWithin(BH.Id, DateTime.newInstance(startDateTime.date(), BH_INIT)));

        Employee_Shift__c es = TestFactory.genEmpShift(1, false)[0];
        update (new Workshop__c(Id = es.Workshop__c, Service_Centre_Name__c = 'Test', Vehicle_Type__c = 'NC', company__c = companyList[0].Id));
        es.Active_Date__c = startDateTime.date();
        insert es;

        Service_Slot__c ss = new Service_Slot__c();
        ss.Active_Date__c = es.Active_Date__c;
        ss.Company__c = es.Company__c;
        ss.Workshop__c = es.Workshop__c;
        insert ss;

        Service_Quota__c sq = new Service_Quota__c();
        sq.Employee_Shift__c = es.Id;
        sq.Start_Time__c = startDateTime;
        sq.End_Time__c = startDateTime.addHours(5);
        sq.Max_Quota__c = es.Maximum_Appointment__c;
        sq.Type__c = custSetST.Name;
        sq.Interval_Per_Appt__c = 1;
        insert sq;

        sq = new Service_Quota__c();
        sq.Service_Slot__c = ss.Id;
        sq.Start_Time__c = startDateTime;
        sq.End_Time__c = startDateTime.addHours(5);
        sq.Max_Quota__c = es.Maximum_Appointment__c;
        sq.Type__c = custSetST.Name;
        sq.Interval_Per_Appt__c = 1;
        sq.Max_Appt_Per_Timeslot__c = 1;
        insert sq;

		/** Inject ServiceAppointmentBook__c records */
		Workshop__c[] workshopList = [SELECT Id, Name FROM Workshop__c];
        List<UserDepotAccess__c> userDepotAccessList = new List<UserDepotAccess__c>();
        for(Workshop__c workshop : workshopList){
            UserDepotAccess__c userDepotAccess = new UserDepotAccess__c(
                IsReadOnly__c = false,
                Workshop__c = workshop.Id,
                Company__c = companyList[0].Id,
                User__c = UserInfo.getUserId(),
                Type__c = 'Booking'
            );
            userDepotAccessList.add(userDepotAccess);
            /*
            userDepotAccess = new UserDepotAccess__c(
                IsReadOnly__c = true,
                Workshop__c = workshop.Id,
                Company__c = companyList[0].Id,
                User__c = UserInfo.getUserId()
            );
            userDepotAccessList.add(userDepotAccess);
            */
        }
        insert userDepotAccessList;
		Test.stopTest();
    }

    @isTest static void testPageWithVO() {
        Vehicle_Ownership__c vo = TestFactory.genVO(1,true)[0];
        Vehicle_Type__c vType = TestFactory.genVehType('NC', true);
        update (new Vehicle__c(Id = vo.Vehicle__c, Vehicle_Type__c = vType.Id));
        PageReference curP = Page.ServiceAppointmentBookingPage;
        curP.getParameters().put('vo', vo.Id);
        Test.setCurrentPage(curP);
        ServiceAppointmentBookingPage_Ctrl ctr = new ServiceAppointmentBookingPage_Ctrl();
        debugMsg(ctr);
        ctr.curBooking.cmp = '028';
        List<Service_Type__c> serviceList = ctr.getServiceList();
        debugMsg(ctr);
        System.assertEquals(1, serviceList.size());
        System.assertEquals('TestService', serviceList[0].Name);
        List<String> selectedTypes = new List<String>();
        for (Service_Type__c s : serviceList) { selectedTypes.add(s.Name); }
        ApexPages.currentPage().getParameters().put('types', String.join(selectedTypes, ','));
        ctr.saveTypes();
        debugMsg(ctr);
        System.assertEquals(ctr.curBooking.selectedTypes, selectedTypes);
        System.assert(ctr.workshopList.size() > 0);
        System.assert(ctr.csaList.size() > 0);

        ApexPages.currentPage().getParameters().put('wsId', ctr.workshopList[0].Id);
        ctr.saveWSAndCSA();
        debugMsg(ctr);
        System.assertEquals(ctr.workshopList[0].Id, ctr.curBooking.ws.Id);

        Service_Quota__c sq = [SELECT Start_Time__c FROM Service_Quota__c WHERE Employee_Shift__c != null];
        ApexPages.currentPage().getParameters().put('year', String.valueOf(sq.Start_Time__c.year()));
        ApexPages.currentPage().getParameters().put('mth', String.valueOf(sq.Start_Time__c.month()));
        ctr.populateSlots();
        ApexPages.currentPage().getParameters().put('date', String.valueOf(sq.Start_Time__c.date()));
        ctr.getTimes();
        debugMsg(ctr);
        Integer TIME_ZONE = 8;
        System.assertEquals(sq.Start_Time__c.date(), ctr.curBooking.selectedTime.addhours(TIME_ZONE));
        System.assert(ctr.slotList.size() > 0);

        ApexPages.currentPage().getParameters().put('hour', String.valueOf(sq.Start_Time__c.hour()));
        ApexPages.currentPage().getParameters().put('min', String.valueOf(sq.Start_Time__c.minute()));
        ctr.saveTimes();
        debugMsg(ctr);
        System.assertEquals(sq.Start_Time__c, ctr.curBooking.selectedTime);

        ApexPages.currentPage().getParameters().put('contact', 'Test Name');
        ApexPages.currentPage().getParameters().put('number', '98765432');
        ApexPages.currentPage().getParameters().put('descStr', 'Test Comments');
        List<Company__c> companyList = [
            SELECT Id,Name
            FROM Company__c
        ];
        ApexPages.currentPage().getParameters().put('companyId',companyList[0].Id);
        ctr.saveCompany();
        ctr.createAppt();
        debugMsg(ctr);
        List<Service_Appointment__c> sa = [SELECT Appointment_Date__c, Vehicle_Ownership__c, Contact_Name__c, Contact_No__c, Customer_Comment__c
                                           FROM Service_Appointment__c];
        System.assertEquals(1, sa.size());
        System.assertEquals(sq.Start_Time__c, sa[0].Appointment_Date__c);
        System.assertEquals(vo.Id, sa[0].Vehicle_Ownership__c);
        System.assertEquals('Test Name', sa[0].Contact_Name__c);
        System.assertEquals('98765432', sa[0].Contact_No__c);
        System.assertEquals('Test Comments', sa[0].Customer_Comment__c);

    }

    @isTest static void testPageWithSvcAppt() {
        Service_Quota__c sq = [SELECT Id, Start_Time__c, Type__c, Service_Slot__r.Workshop__c, Service_Slot__r.Workshop__r.Appointment_Interval__c
                               FROM Service_Quota__c WHERE Service_Slot__c != null];
        Service_Quota__c csaQuota = [SELECT Id, Employee_Shift__r.Employee_Master__c FROM Service_Quota__c WHERE Employee_Shift__c != null];
        Integer wsInterval = (Integer) sq.Service_Slot__r.Workshop__r.Appointment_Interval__c;
        Vehicle_Ownership__c vo = TestFactory.genVO(1, true)[0];
        Vehicle_Type__c vType = TestFactory.genVehType('NC', true);
        update (new Vehicle__c(Id = vo.Vehicle__c, Vehicle_Type__c = vType.Id));
        Service_Appointment__c sa = TestFactory.genSvcAppt(1, false)[0];
        sa.Service_Request__c = sq.Type__c;
        sa.Appointment_Date__c = sq.Start_Time__c;
        sa.Vehicle_Ownership__c = vo.Id;
        sa.System_Control__c = true;
        sa.Contact_Name__c = 'Test Name';
        sa.Contact_No__c = '98765432';
        sa.Customer_Comment__c = 'Test Comments';
        sa.Workshop__c = sq.Service_Slot__r.Workshop__c;
        sa.Employee_Master__c = csaQuota.Employee_Shift__r.Employee_Master__c;
        insert sa;

        Appointment_Utilization__c au = new Appointment_Utilization__c();
        au.Service_Quota__c = sq.Id;
        au.Service_Appointment__c = sa.Id;
        insert au;

        DateTime newApptSlot = sq.Start_Time__c.addMinutes(wsInterval);

        PageReference curP = Page.ServiceAppointmentBookingPage;
        curP.getParameters().put('appt', sa.Id);
        Test.setCurrentPage(curP);
        ServiceAppointmentBookingPage_Ctrl ctr = new ServiceAppointmentBookingPage_Ctrl();
        debugMsg(ctr);
        System.assertEquals(sa.Id, ctr.curBooking.sa.Id);
        System.assertEquals(vo.Id, ctr.curBooking.vo.Id);
        //System.assertEquals(sq.Start_Time__c, ctr.curBooking.selectedTime);
        Integer TIME_ZONE = 8;
        System.assertEquals(sq.Start_Time__c.date(), ctr.curBooking.selectedTime.addhours(TIME_ZONE));

        ctr.curBooking.selectedTypes = new List<String> { 'test' }; // we make it an invalid value so that additional checks will be run
        List<String> selectedTypes = new List<String> { sq.Type__c };
        ApexPages.currentPage().getParameters().put('types', String.join(selectedTypes, ','));
        ctr.saveTypes();

        Test.startTest();
        ApexPages.currentPage().getParameters().put('wsId', sa.Workshop__c);
        ApexPages.currentPage().getParameters().put('csaId', sa.Employee_Master__c);
        ctr.saveWSAndCSA();

        ApexPages.currentPage().getParameters().put('hour', String.valueOf(newApptSlot.hour()));
        ApexPages.currentPage().getParameters().put('min', String.valueOf(newApptSlot.minute()));
        ctr.saveTimes();
        debugMsg(ctr);
        System.assertEquals(newApptSlot, ctr.curBooking.selectedTime);
        List<Company__c> companyList = [
            SELECT Id,Name
            FROM Company__c
        ];
        ApexPages.currentPage().getParameters().put('companyId',companyList[0].Id);
        ctr.saveCompany();
        ctr.createAppt();
        debugMsg(ctr);
        List<Service_Appointment__c> updatedSA = [SELECT Appointment_Date__c FROM Service_Appointment__c];
        Test.getEventBus().deliver();
        Test.stopTest();
        System.assertEquals(1, updatedSA.size());
        System.assertNotEquals(newApptSlot, sa.Appointment_Date__c);
        System.assertEquals(newApptSlot, updatedSA[0].Appointment_Date__c);
        ctr.clearErrorMessage();
    }

    @isTest static void testVisualforceComponents() {
        Vehicle_Ownership__c vo = TestFactory.genVO(1,true)[0];
        PageReference curP = Page.ServiceAppointmentBookingPage;
        curP.getParameters().put('vo', vo.Id);
        Test.setCurrentPage(curP);
        ServiceAppointmentBookingPage_Ctrl ctr = new ServiceAppointmentBookingPage_Ctrl();
        ctr.curBooking.cmp = '028';

        List<String> weekDays = ctr.getWeekDays();
        debugMsg(ctr);
        System.assertEquals(7, weekDays.size());

        List<String> year = ctr.getSelectYear();
        debugMsg(ctr);
        System.assertEquals(2, year.size());
    }

    private static void debugMsg(ServiceAppointmentBookingPage_Ctrl ctr) {
        if (ctr.errMsg != null && ctr.errMsg.size() > 0) {
            System.debug('ERROR DEBUG: ' + ctr.errMsg);
            throw new testException(ctr.errMsg[0]);
        }
    }

    @isTest
    static void blankVO(){
        try{
            ServiceAppointmentBookingPage_Ctrl ctr = new ServiceAppointmentBookingPage_Ctrl();
            System.assert(false);
        }
        catch(Exception apptException){
            System.assert(true);
        }
    }

    @isTest
    static void noAccessSaveTimes(){
        Vehicle_Ownership__c vo = TestFactory.genVO(1,true)[0];
        Vehicle_Type__c vType = TestFactory.genVehType('NC', true);
        update (new Vehicle__c(Id = vo.Vehicle__c, Vehicle_Type__c = vType.Id));
        PageReference curP = Page.ServiceAppointmentBookingPage;
        curP.getParameters().put('vo', vo.Id);
        Test.setCurrentPage(curP);
        ServiceAppointmentBookingPage_Ctrl ctr = new ServiceAppointmentBookingPage_Ctrl();
        debugMsg(ctr);
        ctr.curBooking.cmp = '028';
        List<Service_Type__c> serviceList = ctr.getServiceList();
        debugMsg(ctr);

        List<String> selectedTypes = new List<String>();
        for (Service_Type__c s : serviceList) { selectedTypes.add(s.Name); }
        ApexPages.currentPage().getParameters().put('types', String.join(selectedTypes, ','));
        ctr.saveTypes();
        debugMsg(ctr);

        ApexPages.currentPage().getParameters().put('wsId', ctr.workshopList[0].Id);
        ctr.saveWSAndCSA();
        debugMsg(ctr);
        System.assertEquals(ctr.workshopList[0].Id, ctr.curBooking.ws.Id);

        Service_Quota__c sq = [SELECT Start_Time__c FROM Service_Quota__c WHERE Employee_Shift__c != null];
        ApexPages.currentPage().getParameters().put('year', String.valueOf(sq.Start_Time__c.year()));
        ApexPages.currentPage().getParameters().put('mth', String.valueOf(sq.Start_Time__c.month()));
        ctr.populateSlots();
        ApexPages.currentPage().getParameters().put('date', String.valueOf(sq.Start_Time__c.date()));
        ctr.getTimes();
        debugMsg(ctr);
        Integer TIME_ZONE = 8;

        ApexPages.currentPage().getParameters().put('hour', String.valueOf(sq.Start_Time__c.hour()));
        ApexPages.currentPage().getParameters().put('min', String.valueOf(sq.Start_Time__c.minute()));
        List<UserDepotAccess__c> userDepotAccessList = [SELECT ID FROM UserDepotAccess__c];
        delete userDepotAccessList;
        ctr.saveTimes();
        System.assert(String.isNotBlank(ctr.errMsg[0]));
        ApexPages.currentPage().getParameters().put('contact', 'Test Name');
        ApexPages.currentPage().getParameters().put('number', '98765432');
        ApexPages.currentPage().getParameters().put('descStr', 'Test Comments');
        ctr.clearErrorMessage();
        ctr.createAppt();
        System.assert(String.isNotBlank(ctr.errMsg[0]));
        ctr.clearErrorMessage();
        ctr.saveTypes();
        System.assert(String.isNotBlank(ctr.errMsg[0]));
    }

    @isTest
    static void testSaveCompany(){
        Vehicle_Ownership__c vo = TestFactory.genVO(1,true)[0];
        Vehicle_Type__c vType = TestFactory.genVehType('NC', true);
        update (new Vehicle__c(Id = vo.Vehicle__c, Vehicle_Type__c = vType.Id));
        PageReference curP = Page.ServiceAppointmentBookingPage;
        curP.getParameters().put('vo', vo.Id);
        Test.setCurrentPage(curP);
        ServiceAppointmentBookingPage_Ctrl ctr = new ServiceAppointmentBookingPage_Ctrl();
        List<Company__c> companyList = [
            SELECT Id,Name
            FROM Company__c
        ];
        ApexPages.currentPage().getParameters().put('companyId',companyList[0].Id);
        ctr.saveCompany();
        System.assertEquals(companyList[0].Id, ctr.curBooking.cmpId);
        ApexPages.currentPage().getParameters().put('companyId',companyList[0].Name);
        ctr.clearErrorMessage();
        ctr.saveCompany();
        System.assert(String.isNotBlank(ctr.errMsg[0]));
    }

    @isTest
    static void noCompanyDefined(){
        List<UserDepotAccess__c> userDepotAccessList = [SELECT ID FROM UserDepotAccess__c];
        delete userDepotAccessList;
        Vehicle_Ownership__c vo = TestFactory.genVO(1,true)[0];
        Vehicle_Type__c vType = TestFactory.genVehType('NC', true);
        update (new Vehicle__c(Id = vo.Vehicle__c, Vehicle_Type__c = vType.Id));
        PageReference curP = Page.ServiceAppointmentBookingPage;
        curP.getParameters().put('vo', vo.Id);
        Test.setCurrentPage(curP);
        ServiceAppointmentBookingPage_Ctrl ctr = new ServiceAppointmentBookingPage_Ctrl();
        ctr.getRenderAsc();
        try{
            ctr.getErrMsg();
            System.assertEquals(null, ctr.selectedCmp);
            System.assertNotEquals(null,ctr.voContactNo);
            System.assertEquals(null,ctr.acctStatus);
            System.assertEquals(null,ctr.autoRemarks);
            debugMsg(ctr);
            System.assert(false);
        }
        catch(Exception testException){
            User CUR_USER = [SELECT Id, Name, Username, Email, Profile.Name, Company__c FROM User WHERE Id = :UserInfo.getUserId()];
            System.assertEquals(testException.getMessage(), 'No company available/defined for ' + CUR_USER.Name + '.');
        }
    }
}