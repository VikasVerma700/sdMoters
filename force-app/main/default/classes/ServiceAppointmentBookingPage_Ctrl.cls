public with sharing class ServiceAppointmentBookingPage_Ctrl {
    public final static User CUR_USER = [SELECT Id, Name, Username, Email, Profile.Name, Company__c FROM User WHERE Id = :UserInfo.getUserId()];
    
    /** User booking permission - read, write */
    public static final ServiceAppointmentBooking__c SA_BOOK = ServiceAppointmentBooking__c.getInstance(UserInfo.getUserId());
    public boolean workshopRead { get; private set; }
    public boolean workshopWrite { get; private set; }

    public String acctStatus { get; private set; }
    public String autoRemarks { get; private set; }
    public List<Company__c> companyList { get; set; }
    public List<Service_Type__c> serviceList { get; set; }
    public List<Workshop__c> workshopList {get; set;}
    public List<Employee_Master__c> csaList {get; set;}
    public List<List<ServiceApptBooking.CalDay>> calendar {get; private set;}
    public List<String> slotList {get; private set;}
    public Map<Date, ServiceApptBooking.CalDay> calDayMap;
    public List<String> errMsg;
    public ServiceApptBooking.Booking curBooking;
    public String selectedCmp {get; set;}
    public string voContactNo {
        get {
            return u.beautifyPhone(this.curBooking.vo.Customer__r.Mobile_Country_Code_1__pc, this.curBooking.vo.Customer__r.Mobile_Preferred__pc);
        }
    }
	public void clearErrorMessage() { errMsg = new List<String>(); }

    public List<String> getWeekDays() {
        DateTime curD = DateTime.newInstance(Date.today().toStartOfWeek(), Time.newInstance(0, 0, 0, 0));
        List<String> days = new List<String>();
        for (Integer i = 0; i < 7; i++) { days.add(curD.addDays(i).format('EEE').toUpperCase()); }
        return days;
    }

    public List<String> getErrMsg() { return this.errMsg; }
    public ServiceApptBooking.Booking getCurBooking() { return this.curBooking; }

    public Boolean getRenderAsc() {
        Company__c[] companyList = populateCmpList('');
        return companyList.size() == 1;
    }

    public List<String> getSelectYear() { return new List<String> { DateTime.now().format('yyyy'), DateTime.now().addYears(1).format('yyyy') }; }

    // public List<Service_Type__c> getServiceList() {
    //     /*
    //     system.debug('!curBooking.cmp--'+curBooking.cmp);
    //     try{
    //         return ServiceApptBooking.getServices(curBooking.cmp, null);
    //     }
    //     catch (NullPointerException udaException){
    //         return new List<Service_Type__c> ();
    //     }
    //     */
    //     system.debug('testtttttttttttttttttttttt');
    //     return ServiceApptBooking.getServices(curBooking.cmp, null);
    // }

    public ServiceAppointmentBookingPage_Ctrl() {
       // selectedCmp='028';
        errMsg = new List<String>();
        this.companyList = populateCmpList('');
        String curAppt;
        String curVO;
        try {
            curAppt = ApexPages.currentPage().getParameters().get('appt');
            curVO = ApexPages.currentPage().getParameters().get('vo');
            curBooking = new ServiceApptBooking.Booking();
            if (!String.isBlank(curAppt)) {
                initAppt(curAppt); // we run thru all the initializations to reinstate the VF page
            } else if (!String.isBlank(curVO)) {
                initVO(curVO); // get the vo info
            } else {
                // curBooking.cmp = CUR_USER.Company__c;
                throw new ServiceApptBooking.ApptException('Appointment Id / Vehicle Ownership Id not specified.');
            }
        } catch (Exception e) {
            System.debug('ServiceAppointmentBookingPage_Ctrl(): goes into exception');
            string error = e.getMessage();
            string user = String.format('{0} ({1})', new string[] { CUR_USER.Name, CUR_USER.Username });
            string load;
            if (String.isNotBlank(curAppt)) { load = 'Appt Id: ' + curAppt; }
            else if (String.isNotBlank(curVO)) { load = 'VO Id: ' + curVO; }
            else { load = CUR_USER.Company__c; }

            e.setMessage(error + '\n\n' + user + '\n' + load);
            throw e;
        }
    }

    public void saveCompany() {
        errMsg = new List<String>();
        try {
            String cmpId = ApexPages.currentPage().getParameters().get('companyId');
            curBooking.cmpId = cmpId;
            curBooking.cmp = [SELECT Name FROM Company__c WHERE Id = :cmpId][0].Name;

            serviceList = ServiceApptBooking.getServices(curBooking.cmp, null);
        }
        catch (Exception e) {
            errMsg.add(e.getMessage() + ' | ' + e.getStackTraceString());
        }
    }
    /**
     * we take in the list of types as comma separated values
     * and proceed to find the available workshops and CSAs
     */
    public void saveTypes() {
        errMsg = new List<String>();
        try {
            chooseTypes();
            Workshop__c[] availWS = new List<Workshop__c>();
            list<string> workshopStr=UserDepotAccessRepository.getAccessibleWorkhopNames('Booking');

            Workshop__c[] allWS = ServiceApptBooking.populateWSList(curBooking);
            for (Workshop__c ws :allWS) 
            {
                if (workshopStr.contains(ws.Name) ) {
                    availWS.add(ws);
                }
            }
            curBooking.checkWS(availWS);
            // this must be filtered by the available workshops
            this.csaList = ServiceApptBooking.populateCSAList(availWS, curBooking);
            curBooking.checkCSA(this.csaList);
            this.workshopList = ServiceApptBooking.filterAutoAssignWS(availWS, this.csaList);
            if (this.workshopList.size() <= 0) {
                throw new ServiceApptBooking.ApptException('No workshops available/defined for ' + CUR_USER.Name + '.'); 
            }
        } catch (Exception e) {
            errMsg.add(e.getMessage() + ' | ' + e.getStackTraceString());
        }
    }
    
    /**
    * given a workshop id and potentially empty csa id (any csa)
    * we then populate the calendar based on whats chosen
    * note that if CSA is null and the workshop has chosen to auto assign CSA, the auto assignment based on user config will be done
    */
    public void saveWSAndCSA() {
        errMsg = new List<String>();
        try {
            String wsId = ApexPages.currentPage().getParameters().get('wsId');
            String csaId = ApexPages.currentPage().getParameters().get('csaId');
            
            // if the ws is changed, we get rid of the slot quota since that will affect the slots calculation
            if (curBooking.ws != null && curBooking.ws.Id != wsId) { curBooking.slotQuota = null; }
            curBooking.ws = [SELECT Id, Name, Short_Address__c, Description__c, Appointment_Interval__c, Auto_Assign_CSA__c FROM Workshop__c WHERE Id = :wsId];
            if (curBooking.ws == null || curBooking.ws.Appointment_Interval__c == null || curBooking.ws.Appointment_Interval__c <= 0) {
                throw new ServiceApptBooking.ApptException('Invalid Appointment Interval.');
            }

            this.workshopWrite = false;
            this.workshopRead = false;
            for(UserDepotAccess__c userDepotAccess: UserDepotAccessRepository.getUserDepotAccess('Booking', false)){
                if (curBooking.cmpId == userDepotAccess.company__c && curBooking.ws.name == userDepotAccess.Workshop__r.Name){
                    this.workshopRead = true;
                    if(userDepotAccess.IsReadOnly__c == false){
                        this.workshopWrite = true;
                    }
                }
            }
            // if csa is changed, we get rid of the csa quota since that will affect the csa calculation
            if (curBooking.csa != null && (csaId == null || csaId == '' || curBooking.csa.Id != csaId)) { curBooking.csaQuota = null; }
            curBooking.csa = (csaId != null && csaId != '') ? [SELECT Id, Name FROM Employee_Master__c WHERE Id = :csaId] : null;

            Date searchD = (curBooking.selectedTime != null) ? curBooking.selectedTime.date() : Date.today();
            populateSlotsHelper(searchD.month(), searchD.year()); // we set up all the slots for the current date

            // reset this since users can move backwards
            checkSelectedTimes();
        } catch (Exception e) {
            errMsg.add(e.getMessage() + ' | ' + e.getStackTraceString());
        }
    }

    /**
     * we set the time part of the chosen date and then set the chosen quota accordingly
     */
    public void saveTimes() {
        errMsg = new List<String>();
        try {
            string[] wsWrite = new string[]{};
            if (!UserDepotAccessRepository.getAccessibleWorkhopNames('Booking',true).contains(curBooking.ws.Name)) {// no write access to this workshop
                NoAccessException e = new NoAccessException();

                e.setMessage(String.format('User has no permission to book service for workshop \'\'{0}\'\'', new string[] { curBooking.ws.Name }));
                throw e;
            }
            Integer hour = Integer.valueOf(ApexPages.currentPage().getParameters().get('hour'));
            Integer minute = Integer.valueOf(ApexPages.currentPage().getParameters().get('min'));
            curBooking.selectedTime = DateTime.newInstance(curBooking.selectedTime.date(), Time.newInstance(hour, minute, 0, 0));
            ServiceApptBooking.CalDay curCal = calDayMap.get(curBooking.selectedTime.date());
            curBooking.slotQuota = curCal.slotQuota;
        } catch (Exception e) {
            errMsg.add(e.getMessage() + ' | ' + e.getStackTraceString());
        }
    }

    /**
     * we update the selectedTime with the chosen date portion
     * then get the relevant time slots available
     */
    public void getTimes() {
        errMsg = new List<String>();
        try {
            Date d = Date.valueOf(ApexPages.currentPage().getParameters().get('date'));
            curBooking.selectedTime = DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0));
            getTimesHelper(d);
        } catch (Exception e) {
            errMsg.add(e.getMessage() + ' | ' + e.getStackTraceString());
        }
    }

    /**
     * we need to get the contact number, name and customer comments before saving the appointment
     * @return [if successful, redirect to the appt page]
     */
    public PageReference createAppt() {
        errMsg = new List<String>();
        SavePoint sp = Database.setSavePoint();
        try {
            this.workshopWrite = false;
            this.workshopRead = false;
            for(UserDepotAccess__c userDepotAccess: UserDepotAccessRepository.getUserDepotAccess('Booking', false)){
                if (curBooking.cmpId == userDepotAccess.company__c && curBooking.ws.name == userDepotAccess.Workshop__r.Name){
                    this.workshopRead = true;
                    if(userDepotAccess.IsReadOnly__c == false){
                        this.workshopWrite = true;
                    }
                }
            }
            if (!workshopWrite) {
                NoAccessException e = new NoAccessException();
                e.setMessage(String.format('User has no permission to book service for workshop \'\'{0}\'\'', new string[] { curBooking.ws.Name }));
                throw e;
            }

            curBooking.contactName = ApexPages.currentPage().getParameters().get('contact');
            curBooking.contactNumber = ApexPages.currentPage().getParameters().get('number');
            if (!String.isBlank(curBooking.contactNumber)) {
                curBooking.contactNumber = curBooking.contactNumber.deleteWhitespace();
            }
            String descStr = ApexPages.currentPage().getParameters().get('descStr');
            String emailNoti = ApexPages.currentPage().getParameters().get('emailNoti');
            if (curBooking.util != null) { delete curBooking.util; } // we remove the existing utilizations
            checkCSAQuota();
            curBooking.source = ((curBooking.sa == null || curBooking.sa.Id == null) && String.isBlank(curBooking.source)) ? 'VF Page' : curBooking.source;
            curBooking.makeBooking(false);
            createApptHelper(descStr, emailNoti);
            return new PageReference(Site.getBaseUrl() + '/' + curBooking.sa.Id + '/e?retURL=%2F' + curBooking.sa.Id);
        } catch (Exception e) {
            Database.rollback(sp);
            errMsg.add(e.getMessage() + ' | ' + e.getStackTraceString());
            return null;
        }
    }

    /**
     * given the month and year, we will update the calendar accordingly
     */
    public void populateSlots() {
        errMsg = new List<String>();
        try {
            Integer mth = Integer.valueOf(ApexPages.currentPage().getParameters().get('mth'));
            Integer year = Integer.valueOf(ApexPages.currentPage().getParameters().get('year'));
            populateSlotsHelper(mth, year);
        } catch (Exception e) {
            errMsg.add(e.getMessage() + ' | ' + e.getStackTraceString());
        }
    }

    /////////////////////
    // SHARED HELPERS  //
    /////////////////////

    // insert and generate utilizations for appt
    public void createApptHelper(String descStr) { createApptHelper(descStr, null); }
    public void createApptHelper(String descStr, String emailNoti) {
        curBooking.sa.Customer_Comment__c = descStr;
        curBooking.sa.Email_Address_Notification__c = emailNoti;
        curBooking.sa.System_Control__c = true; // special field to ensure we can create the service appt
        upsert curBooking.sa;
        curBooking.genUtil(true);
    }

    // update the selected types and if types have changed, update the current slots
    public void chooseTypes() {
        List<String> selectedTypes = ApexPages.currentPage().getParameters().get('types').split(',');
        if (curBooking.selectedTypes != null && curBooking.selectedTypes != selectedTypes) { filterCurrentSlots(selectedTypes); }
        curBooking.selectedTypes = selectedTypes;
    }

    // populate the CalDayMap with the selected time, normally upon selection of workshop or csa
    public void findCurrentMonthSlots() {
        Date searchD = (curBooking.selectedTime != null) ? curBooking.selectedTime.date() : Date.today();
        populateSlotsHelper(searchD.month(), searchD.year()); // we set up all the slots for the current date

        // reset this since users can move backwards
        checkSelectedTimes();
    }

    /**
     * we populate the page with all the details required since we are editing the appointment
     * all prior variables are instantiated by calling the previous functions
     * @param curAppt [description]
     */
    public void initAppt(String curAppt) {
        //this.companyList = populateCmpList(curAppt);
        curBooking = new ServiceApptBooking.Booking(curAppt);
        List<Workshop__c> availWS = ServiceApptBooking.populateWSList(curBooking);
        curBooking.checkWS(availWS);
        // this must be filtered by the available workshops
        this.csaList = ServiceApptBooking.populateCSAList(availWS, curBooking);
        curBooking.checkCSA(this.csaList);
        this.workshopList = ServiceApptBooking.filterAutoAssignWS(availWS, this.csaList);
        populateSlotsHelper(curBooking.selectedTime.month(), curBooking.selectedTime.year()); // we get all available slots for chosen services
        getTimesHelper(curBooking.selectedTime.date()); // then we populate other available time slots
        this.workshopWrite = false;
        this.workshopRead = false;
        for(UserDepotAccess__c userDepotAccess: UserDepotAccessRepository.getUserDepotAccess('Booking', false)){
            if (curBooking.cmpId == userDepotAccess.company__c && curBooking.ws.name == userDepotAccess.Workshop__r.Name){
                this.workshopRead = true;
                if(userDepotAccess.IsReadOnly__c == false){
                    this.workshopWrite = true;
                }
            }
        }
    }

    public Company__c[] populateCmpList(String curAppt) {
        Company__c[] cmpList = new Company__c[]{};

        if (String.isBlank(curAppt)) {
            UserDepotAccess__c[] userDepotAccessList = UserDepotAccessRepository.getUserDepotAccess('Booking',false,UserInfo.getUserId());
            Set<Id> companySet = new Set<Id>();
            for (UserDepotAccess__c userDepotAccess :userDepotAccessList) { companySet.add(userDepotAccess.Company__c); }
            cmpList = [SELECT Id, Name, Description__c FROM Company__c WHERE Id IN :companySet ORDER BY Name];
        }

        if(cmpList.size()==0){
            errMsg.add('No company available/defined for ' + CUR_USER.Name + '.');
        }
        return cmpList;
    }
    /**
     * for a given month and year we populate a calendar of dates with the availability for each day
     * note that the method accounts for quotas taken up by the existing appt we are trying to edit
     * @param mth
     * @param year
     */
    public void populateSlotsHelper(Integer mth, Integer year) {
        Date curD = Date.newInstance(year, mth, 1).toStartOfWeek();
        Date endD = Date.newInstance(year, mth, Date.daysInMonth(year, mth)).toStartOfWeek().addDays(6);
        calendar = new List<List<ServiceApptBooking.CalDay>>();
        calDayMap = ServiceApptBooking.populateCalDayMap(curD, endD, curBooking);
        ServiceApptBooking.CalDay curCal;
        List<ServiceApptBooking.CalDay> curWeek;
        // since curD and endD always follow start and end of week
        while (curD <= endD) {
            curWeek = new List<ServiceApptBooking.CalDay>();
            for (Integer i = 0; i < 7; i++) {
                curCal = calDayMap.get(curD);
                if (curCal == null) {
                    curCal = new ServiceApptBooking.CalDay(curD); // if no slot, we just populate an empty day
                    calDayMap.put(curD, curCal);
                }
                curWeek.add(curCal);
                curD = curD.addDays(1);
            }
            calendar.add(curWeek);
        }
    }

    /////////////////////
    // PRIVATE HELPERS //
    /////////////////////

     /**
     * ensure that csa is allocated if needed and that appropriate quota is attached
     */
    private void checkCSAQuota() {
        ServiceApptBooking.CalDay curCal = calDayMap.get(curBooking.selectedTime.date());
        if (curBooking.csa == null && curBooking.ws.Auto_Assign_CSA__c) { curBooking.csa = ServiceApptBooking.allocateCSA(curBooking, curCal); }

        if (curBooking.csa != null) {
            curBooking.csaQuota = curCal.csaQuota.get(curBooking.csa.Id);
            if (curBooking.csaQuota == null) { throw new ServiceApptBooking.ApptException('No CSA Quota to retrieve from map.'); }
        }
    }
    /**
     * if the slots are changed from the originally chosen ones when user moves back, we need to adjust the chosen slot quota
     * @param selectedTypes [new list of types that user has chosen]
     */
    private void filterCurrentSlots(List<String> selectedTypes) {
        Set<String> curTypes = new Set<String>(selectedTypes);
        if (curBooking.slotQuota != null) {
            List<Service_Quota__c> newSlotQuota = new List<Service_Quota__c>();
            for (Service_Quota__c q : curBooking.slotQuota) {
                if (curTypes.contains(q.Type__c)) { newSlotQuota.add(q); }
            }
            curBooking.slotQuota = newSlotQuota;
        }

        if (curBooking.csaQuota != null) {
            List<Service_Quota__c> newCSAQuota = new List<Service_Quota__c>();
            for (Service_Quota__c q : curBooking.csaQuota) {
                if (curTypes.contains(q.Type__c)) { newCSAQuota.add(q); }
            }
            curBooking.csaQuota = newCSAQuota;
        }
    }

    /**
     * once new slots are populated, we check if the existing selected time is still available
     * if it isnt, then we reset the necessary lists
     * if it is then we continue to allow the existing selection
     */
    public void checkSelectedTimes() {
        if (curBooking.selectedTime == null) { return; }
        ServiceApptBooking.CalDay curD = calDayMap.get(curBooking.selectedTime.date());
        if (curD == null) { // cannot find the date anymore
            curBooking.selectedTime = null;
            this.slotList = null;
            return;
        }

        // can find date but cannot find time
        if (curD.slots == null || !curD.slots.contains(curBooking.selectedTime)) {
            curBooking.selectedTime = DateTime.newInstance(curBooking.selectedTime.date(), Time.newInstance(0, 0, 0, 0));
            getTimesHelper(curBooking.selectedTime.date()); // set the newly available slots
        }
    }

    /**
     * based on the slots populated, we return what the appropriate times are in hours and minutes
     * @param d [description]
     */
    public void getTimesHelper(Date d) {
        this.slotList = new List<String>();
        ServiceApptBooking.CalDay curDay = calDayMap.get(d);
        if (curDay.slots == null) { return; }
        List<DateTime> sortedSlots = new List<DateTime>(curDay.slots);
        sortedSlots.sort();
        for (DateTime t : sortedSlots) { this.slotList.add(t.format('HH:mm')); }
    }

    /**
     * we get the vo details. it must be an active VO
     * we also get the apbu details so that we can show whether its a VIP customer or not
     * @param curVO [description]
     */
    private void initVO(String curVO) {
        List<Vehicle_Ownership__c> vo = [SELECT Id, Customer__r.Name, Customer__r.Default_Email__c, Customer__r.Salutation, Customer__r.Account_Name__c
                                        , Customer__r.Mobile_Country_Code_1__pc, Customer__r.Mobile_Preferred__pc
										, Customer__r.PersonMobilePhone, Customer__r.PersonEmail
                                        , Customer__r.IsPersonAccount, Registration_No__c, Customer__c, Vehicle__r.Vehicle_Model_Description__c
										, Registration_Date__c
										, Vehicle__r.Vehicle_Make__r.Name, Status__c FROM Vehicle_Ownership__c WHERE Id = :curVO
                                        // AND Status__c = 'Active'
                                        ];
        if (vo.size() <= 0) { throw new ServiceApptBooking.ApptException('Invalid VO.'); }
        if (vo[0].Status__c != 'Active') { throw new ServiceApptBooking.ApptException('Vehicle ownership is not ACTIVE.'); }
        curBooking.vo = vo[0];
        list<string> compStr=new list<string> ();
        for(UserDepotAccess__c cuser: UserDepotAccessRepository.getUserDepotAccess('Booking',false,UserInfo.getUserId())){
            system.debug('~~cuser--'+cuser);
            compStr.add(cuser.Company__r.name);
        }
        for(string str:compStr){
            if(compStr.contains(str) && str!=null ){
                curBooking.cmp = str;
                system.debug('!!curBooking.cmp:2--'+curBooking.cmp);
            }
            else{
                curBooking.cmp = '0';
            }
        }
    }

}