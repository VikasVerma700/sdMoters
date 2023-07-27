public class ServiceAppointmentSetupPage_Ctrl {
	public class ServiceAppointmentSetupException extends Exception {}

	public static final Date TEMPLATE_DEFAULT = Date.newInstance(1970, 1, 1);
	public static final String TODAY_DATE {get{return System.today().format();}}

	//public static final Service_Appointment_Setup__c SA_SETUP = Service_Appointment_Setup__c.getInstance(UserInfo.getUserId());
    public static final String SETUP = UserDepotAccessRepository.ACCESS_TYPE_SETUP;

	public User CUR_USER {get; private set;}
	public Boolean readOnly {get; private set;}
	public Boolean templateSetup {get;set;}
	public Boolean hasSetupBH { get; set; }
	public List<List<String>> calendar {get;set;}
	public Map<String, CalDaySlot> slotMap {get; private set;}
	public Map<String, CalDayShift> shiftMap {get; private set;}

	public String selectedCmp {get; set;}
	public Company__c curCmp;
	public String selectedWS {get; set;}
	public Workshop__c ws {get; private set;}

	public List<String> errMsg {get; private set;}
	public List<String> modalErr {get; private set;}

	public String selectedDay {get; private set;} // For the Template selected day
	// slotModal
	public CalDaySlot selectedSlot {get; private set;} // the active selected service slot for editing/insertion
	public List<Service_Quota__c> curSlotsList {get; set;} // the active list of slots shown on modal
	public Map<Id, Decimal> curPrevSlotsMap {get; set;}
	// shiftModal
	public CalDayShift selectedShift {get; private set;} // active selected shift for editing/insertion
	public List<Service_Quota__c> curShiftList {get; set;} // active list of slots
	public Employee_Shift__c selectedEmp {get; set;} // active csa chosen

	private List<String> wsWriteAccess = new List<String>();

	private static BusinessHours BH { get; set; } // = [SELECT Id FROM BusinessHours WHERE Name = 'ABD Service'];
	private final static Time BH_INIT = Time.newInstance(12, 0, 0, 0); // used to calculate whether the current day is a working day
	private final String OPACITY = '0.7';
	private Map<String, String> serviceBg;


	public ServiceAppointmentSetupPage_Ctrl() {
		CUR_USER = [SELECT Id, Name, Company__c, Profile.Name FROM User WHERE Id = :UserInfo.getUserId()];
        try{
            selectedCmp = getCmpList()[0].getValue();
            changeCmp();
            templateSetup = FALSE;
            readOnly = true;
            slotMap = new Map<String, CalDaySlot>();
            shiftMap = new Map<String, CalDayShift>();
        }catch(exception e){}
	}

	public void changeSetup() {
		errMsg = new List<String>();
		if (String.isBlank(selectedws)) {
			errMsg.add('Please select your workshop first');
		} else {
			Integer mth = Integer.valueOf(ApexPages.currentPage().getParameters().get('mth'));
			Integer yr = Integer.valueOf(ApexPages.currentPage().getParameters().get('yr'));
			templateSetup = !templateSetup;
			populateSlots(yr, mth);
		}
	}

	public void getTemplate() {
		List<Service_Slot__c> ssList = [SELECT Id, Template_Day__c, Company__c, Workshop__c, Workshop__r.Appointment_Interval__c, Active_Date__c,
										(SELECT Id, Start_Time__c, Available_Slots__c, End_Time__c, Max_Appt_Per_Timeslot__c, Interval_Per_Appt__c,
										 Workshop__c, Max_Quota__c, Type__c, Employee_Master__c, Service_Slot__c, Employee_Shift__c FROM Service_Quotas__r)
										FROM Service_Slot__c WHERE Is_Template__c = TRUE AND Workshop__c = :selectedWS AND Company__r.Name = :selectedCmp];
		slotMap = new Map<String, CalDaySlot>();
		for (Service_Slot__c ss : ssList) {
			String dayOfWeek = ss.Template_Day__c.toUpperCase();
			if (!slotMap.containsKey(dayOfWeek)) {
				slotMap.put(dayOfWeek, new CalDaySlot(dayOfWeek));
			}
			CalDaySlot curD = slotMap.get(dayOfWeek);
			if (curD.curSlot == null) {
				curD.curSlot = ss;
				curD.slots = new Map<String, Service_Quota__c>();
				curD.day = ss.Active_Date__c;
			}
			for (Service_Quota__c sq : ss.Service_Quotas__r) {
				// First initialization
				curD.slots.put(sq.Type__c, sq);
			}
		}

		List<Employee_Shift__c> empList = [SELECT Id, Employee_Master__c, Company__c, Workshop__c, Maximum_Appointment__c, Employee_Master__r.Name, Active_Date__c,
										   Employee_Master__r.IsActive__c, Template_Day__c, Unproductivity__c, Unproductive_Start_Time__c,
										   Unproductive_End_Time__c, Allow_Work_On_Unprod__c,
										   (SELECT Id, Start_Time__c, Available_Slots__c, End_Time__c, Max_Appt_Per_Timeslot__c, Interval_Per_Appt__c,
											Workshop__c, Max_Quota__c, Type__c, Employee_Master__c, Service_Slot__c, Employee_Shift__c FROM Service_Quotas__r)
										   FROM Employee_Shift__c WHERE Is_Template__c = TRUE AND Workshop__c = :selectedWS AND Company__r.Name = :selectedCmp
										   AND Employee_Master__r.IsActive__c = true ORDER BY Employee_Master__r.Name ASC];
		shiftMap = new Map<String, CalDayShift>();
		for (Employee_Shift__c emp : empList) {
			String dayOfWeek = emp.Template_Day__c.toUpperCase();
			if (!shiftMap.containsKey(dayOfWeek)) {
				shiftMap.put(dayOfWeek, new CalDayShift(dayOfWeek));
			}
			CalDayShift curD = shiftMap.get(dayOfWeek);
			if (curD.empShiftList == null) {
				curD.empShiftList = new List<Employee_Shift__c>();
				curD.shiftTypeMap = new Map<Id, Map<String, Service_Quota__c>>();
			}
			Set<Employee_Shift__c> empSet = new Set<Employee_Shift__c>(curD.empShiftList);
			if (!empSet.contains(emp)) {
				curD.empShiftList.add(emp);
				curD.shiftTypeMap.put(emp.Id, new Map<String, Service_Quota__c>());
				curD.day = emp.Active_Date__c;
			}
			for (Service_Quota__c sq : emp.Service_Quotas__r) {
				curD.shiftTypeMap.get(emp.Id).put(sq.Type__c, sq);
			}
		}
		// ensure that all days have the proper setup if wasn't setup before
		for (String dayOfWeek : getWeekDays()) {
			if (!slotMap.containsKey(dayOfWeek)) {
				slotMap.put(dayOfWeek, new CalDaySlot(dayOfWeek));
				slotMap.get(dayOfWeek).curSlot = new Service_Slot__c(Company__c = curCmp.Id, Workshop__c = selectedWS,
																			 Active_Date__c = TEMPLATE_DEFAULT, Is_Template__c = true,
																			 Template_Day__c = dayOfWeek);
				slotMap.get(dayOfWeek).slots = new Map<String, Service_Quota__c>();
				slotMap.get(dayOfWeek).day = TEMPLATE_DEFAULT;
			}
			if (!shiftMap.containsKey(dayOfWeek)) {
				shiftMap.put(dayOfWeek, new CalDayShift(dayOfWeek));
				shiftMap.get(dayOfWeek).empShiftList = new List<Employee_Shift__c>();
				shiftMap.get(dayOfWeek).shiftTypeMap = new Map<Id, Map<String, Service_Quota__c>>();
				shiftMap.get(dayOfWeek).day = TEMPLATE_DEFAULT;
			}
		}

	}

	public List<String> getWeekDays() {
		DateTime curD = DateTime.newInstance(Date.today().toStartOfWeek(), Time.newInstance(0, 0, 0, 0));
		List<String> days = new List<String>();
		for (Integer i = 0; i < 7; i++) { days.add(curD.addDays(i).format('EEE').toUpperCase()); }
		return days;
	}

	public List<String> getLegends() {
		Set<String> services = new Set<String>();
		System.debug(JSON.serialize(slotMap));
        try{
            for (String mapKey : slotMap.keySet()) {
				System.debug('mapKey.slotMap: ' + mapKey);
                for (Service_Quota__c sq : slotMap.get(mapKey).slots.values()) {
					System.debug(mapKey + ': ' + JSON.serialize(sq));
					services.add(sq.Type__c);
                }
            }
            for (String mapKey : shiftMap.keySet()) {
				System.debug('mapKey.shiftMap: ' + mapKey);
				System.debug(shiftMap.get(mapKey).shiftTypeMap.keySet());
                for (Id empId : shiftMap.get(mapKey).shiftTypeMap.keySet()) {					
                    for (Service_Quota__c sq : shiftMap.get(mapKey).shiftTypeMap.get(empId).values()) {
                        services.add(sq.Type__c);
                    }
                }
            }
        }
		catch(exception e) {}
        List<String> sortServices = new List<String>(services);
        sortServices.sort();
		system.debug(sortServices);
		return sortServices;
	}

	public List<SelectOption> getServicesList() {
		List<Service_Type__c> services = ServiceApptBooking.getServices(this.selectedCmp, new List<String>{null, ws.Name});
		List<SelectOption> optList = new List<SelectOption> { new SelectOption('', '--Select--') };
		// for (Service_Type__c s : services) { optList.add(new SelectOption(s.Name, s.Name)); }
		for (Service_Type__c s : services) { optList.add(new SelectOption(s.DisplayName__c, s.DisplayName__c)); }
		return optList;
	}

	// used to get the background color of the chosen service
	public Map<String, String> getServiceBg() {
		if (serviceBg != null) { return serviceBg; }
		Map<String, Service_Type__c> allTypes = Service_Type__c.getAll();
		Map<String, String> rv = new Map<String, String>();
		// for (Service_Type__c cur : allTypes.values()) { rv.put(cur.Name, rgbVal(cur.Name)); }
		for (Service_Type__c cur : allTypes.values()) { rv.put(cur.DisplayName__c, rgbVal(cur.DisplayName__c)); }
		return rv;
	}

	public List<SelectOption> getCmpList() {
        set<string> compStr=new set<string> ();
        for(UserDepotAccess__c cuser: UserDepotAccessRepository.getUserDepotAccess(SETUP,false)){
            compStr.add(cuser.Company__r.name); 
        }   
        String removeSpace1=string.valueof(compStr).replace('(','');
        String removeSpace2=removeSpace1.replace(')','').replace('{','').replace('}','');
        
        List<SelectOption> options = new List<SelectOption>();
        String cmpAvail = removeSpace2.replace(' ','');
        List<String> splitCmp = new List<String>();
        if (!String.isBlank(cmpAvail)) {
            splitCmp = cmpAvail.split(',');
            for (Integer i = 0; i < splitCmp.size(); i++) {
                splitCmp[i] = splitCmp[i].trim();
                options.add(new SelectOption(splitCmp[i], splitCmp[i]));
            }
        }
        if (splitCmp.isEmpty()) {
            options.add(new SelectOption('--Select--', '--Select--'));
        }
        //changes done on 17th Sep 2022: START
        if(!options.isEmpty() && (string.isBlank(selectedCmp) || string.isEmpty(selectedCmp))){
            selectedCmp = options[0].getValue();
            changeCmp();
        }
        //changes done on 17th Sep 2022: END
        return options;
    }


	public List<SelectOption> getWSList() {
		//List<String> splitWS = new List<String>();
		wsWriteAccess = new List<String>();
		/*String wsAvail = SA_SETUP.Workshop_Read__c;
		if (!String.isBlank(wsAvail)) {
			splitWS.addAll(wsAvail.split(','));
		}
		wsAvail = SA_SETUP.Workshop_Write__c;
		if (!String.isBlank(wsAvail)) {
			splitWS.addAll(wsAvail.split(','));
			wsWriteAccess.addAll(wsAvail.split(','));
		}
		for (Integer i = 0; i < splitWS.size(); i++) {
			splitWS[i] = splitWS[i].trim();
		}
		for (Integer i = 0; i < wsWriteAccess.size(); i++) {
			wsWriteAccess[i] = wsWriteAccess[i].trim();
        }
        string query = 'SELECT Id,IsReadOnly__c,Workshop__r.Name, Workshop__r.Short_Address__c FROM UserDepotAccess__c'+
            ' WHERE Company__r.Name = :selectedCmp AND Workshop__r.IsActive__c = true'+
            ' ORDER BY Workshop__r.Name ASC';*/
        //String query = 'SELECT Id, Name, Short_Address__c FROM Workshop__c WHERE Company__r.Name = :selectedCmp AND IsActive__c = true ';
        //query += splitWS.isEmpty() ? '' : 'AND Name IN :splitWS ';
        //query += 'ORDER BY Name ASC ';
		//List<Workshop__c> wsList = Database.query(query);
		
        Set<String> duplicates = new Set<String>(); //changes done on 27th Sep 2022
		List<SelectOption> optList = new List<SelectOption> { new SelectOption('', '--Select--') };
		for (UserDepotAccess__c w : UserDepotAccessRepository.getUserDepotAccess(SETUP,false)) {
            if(duplicates.contains(w.Workshop__r.Name) || w.Workshop__r.IsActive__c == false || w.Company__r.Name != selectedCmp) {
                continue; //changes done on 27th Sep 2022
            }
            duplicates.add(w.Workshop__r.Name); //changes done on 27th Sep 2022
			string name = string.format('{0} ({1})', new string[] { w.Workshop__r.Name, w.Workshop__r.Short_Address__c });
			optList.add(new SelectOption(w.Workshop__c, name));
            if(!w.IsReadOnly__c) wsWriteAccess.add(w.Workshop__r.Name);
		}
		return optList;
	}

	public List<SelectOption> getCSAList() {
		List<SelectOption> optList = new List<SelectOption> { new SelectOption('', '--Select--') };
		if(!String.isBlank(selectedWS))
		{
			List<Employee_Master__c> emList = [SELECT Id, Name FROM Employee_Master__c WHERE Company__r.Name = :selectedCmp AND IsActive__c = true
										   AND Workshop__c = :selectedWS AND Employee_Status_Code__c = 'CA' ORDER BY Name ASC];
		// List<SelectOption> optList = new List<SelectOption> { new SelectOption('', '--Select--') };
		for (Employee_Master__c e : emList) { optList.add(new SelectOption(e.Id, e.Name)); }
		}
		
		// System.debug(emList);
		// System.debug(selectedWS);
		return optList;
	}



	////////////////////////////////////////////////////
	// CLASSES TO HELP STORE INFO RELATED TO CALENDAR //
	////////////////////////////////////////////////////
	public virtual class BaseCal {
		public Date day {get; private set;}
		public Boolean isActive {get; private set;}

		public String dayOfWeek {get; private set;}

		public BaseCal(Date day) {
			this.day = day;

			this.isActive = (Date.today() <= day && BusinessHours.isWithin(BH.Id, DateTime.newInstance(day, BH_INIT)));
		}

		public BaseCal(String day) {
			this.dayOfWeek = day;
			this.isActive = true;
		}

		public Service_Quota__c cloneQuota(Service_Quota__c sQ, Date day) {
			Service_Quota__c curQ = sQ.clone(false, false, false, false);
			curQ.Service_Slot__c = null;
			curQ.Employee_Shift__c = null;
			curQ.Start_Time__c = DateTime.newInstance(day, sQ.Start_Time__c.time());
			curQ.End_Time__c = DateTime.newInstance(day, sQ.End_Time__c.time());
			return curQ;
		}
	}

	public class CalDaySlot extends BaseCal {
		public Service_Slot__c curSlot;
		public Map<String, Service_Quota__c> slots {get; set;}
		public Integer slotsCount {get {return slots.size();}}

		public CalDaySlot(Date day, Service_Slot__c curSlot) {
			super(day);
			this.curSlot = curSlot;
			this.slots = new Map<String, Service_Quota__c>();
		}

		public CalDaySlot(String day) {
			super(day);
		}

		public CalDaySlot clone(Date day) {
			Service_Slot__c curSlot = this.curSlot.clone(false, false, false, false);
			curSlot.Active_Date__c = day;
			curSlot.Unique_Field__c = null;
			CalDaySlot newD = new CalDaySlot(day, curSlot);

			Service_Quota__c curQ;
			for (Service_Quota__c sQ : this.slots.values()) {
				curQ = super.cloneQuota(sQ, day);
				newD.slots.put(sQ.Type__c, curQ);
			}
			return newD;
		}
	}

	public void showSlotsModal() {
		errMsg = new List<String>();
		modalErr = new List<String>();
		try {
			String dateSel = ApexPages.currentPage().getParameters().get('date');
			if (templateSetup) {
				selectedDay = dateSel.toUpperCase();
				selectedSlot = slotMap.get(selectedDay);
			} else {
				selectedSlot = slotMap.get(dateSel);
			}
			if (selectedSlot == null || !selectedSlot.isActive) {
				throw new ServiceAppointmentSetupException('Invalid day chosen.');
			}
			curSlotsList = selectedSlot.slots.values();
			curPrevSlotsMap = new Map<Id, Decimal>();
			for (Integer i = 0; i < curSlotsList.size(); i++) {
				curPrevSlotsMap.put(curSlotsList[i].Id, curSlotsList[i].Max_Quota__c);
			}
			system.debug(curPrevSlotsMap);
		} catch (Exception e) {
			errMsg.add(e.getMessage() + ' | ' + e.getStackTraceString());
		}
	}

	// used in Slots Modal to save new services/update existing services
	public void saveServices() {
		modalErr = new List<String>();
		try {
			Integer mth = Integer.valueOf(ApexPages.currentPage().getParameters().get('mth'));
			Integer yr = Integer.valueOf(ApexPages.currentPage().getParameters().get('yr'));
			Set<String> seen = new Set<String>();
			Decimal totalSlots = 0;
			Set<String> workshop = new Set<String>();
			System.debug('curPrevSlotsMap : ' + curPrevSlotsMap);
			if (selectedSlot.curSlot.Id == null) { insert selectedSlot.curSlot; }
			for (Service_Quota__c q : curSlotsList) {
				if (q.Type__c.contains('PDI'))
					totalSlots += q.Max_Quota__c;
				workshop.add(q.Workshop__c);
				if (seen.contains(q.Type__c)) { throw new ServiceAppointmentSetupException('Duplicated service type'); }
				if (q.Service_Slot__c == null) { q.Service_Slot__c = selectedSlot.curSlot.Id; }
				seen.add(q.Type__c);
			}
			if (workshop.contains('W4') && totalSlots > 30) {
				for (Service_Quota__c sq : curSlotsList) {
					sq.Max_Quota__c = (curPrevSlotsMap.get(sq.Id) == null) ? 0 : curPrevSlotsMap.get(sq.Id);
				}
				throw new ServiceAppointmentSetupException('Total Slot count for PDI related cannot be more than 30.');
			} else {
				upsert curSlotsList;
				populateSlots(yr, mth);
			}

		} catch (Exception e) {
			modalErr.add(e.getMessage() + ' | ' + e.getStackTraceString());
		}
	}

	public class CalDayShift extends BaseCal {
		public List<Employee_Shift__c> empShiftList {get; set;}
		public Map<Id, Map<String, Service_Quota__c>> shiftTypeMap {get; set;}
		public Integer shiftCount {get {return empShiftList.size();}}

		public CalDayShift(Date day) {
			super(day);
			this.empShiftList = new List<Employee_Shift__c>();
			this.shiftTypeMap = new Map<Id, Map<String, Service_Quota__c>>();
		}

		public CalDayShift(String day) {
			super(day);
		}
	}

	public void showShiftModal() {
		errMsg = new List<String>();
		modalErr = new List<String>();
		try {
			String dateSel = ApexPages.currentPage().getParameters().get('date');
			Date shiftModalDate;
			if (templateSetup) {
				selectedDay = dateSel;
				selectedShift = shiftMap.get(selectedDay);
				shiftModalDate = TEMPLATE_DEFAULT;
				if (selectedShift.day == null) {
					selectedShift.day = shiftModalDate;
				}
			} else {
				shiftModalDate = Date.parse(dateSel);
				selectedShift = shiftMap.get(dateSel);
			}
			String empShift = ApexPages.currentPage().getParameters().get('empId');
			if (selectedShift == null) { throw new ServiceAppointmentSetupException('Invalid day chosen.'); }

			if (String.isBlank(empShift)) { // adding new emp shift, we initialize the variable
				selectedEmp = new Employee_Shift__c(Company__c = curCmp.Id, Workshop__c = selectedWS, Active_Date__c = shiftModalDate);
				if (templateSetup) {
					selectedEmp.Template_Day__c = selectedDay;
					selectedEmp.Is_Template__c = true;
				}
				curShiftList = new List<Service_Quota__c>();
				return;
			}

			for (Employee_Shift__c es : selectedShift.empShiftList) {
				if (es.Id == empShift) { // search for the new emp shift in the list
					selectedEmp = es;
					curShiftList = selectedShift.shiftTypeMap.get(es.Id).values();
					break;
				}
			}

		} catch (Exception e) {
			errMsg.add(e.getMessage() + ' | ' + e.getStackTraceString());
		}
	}

	// used in shift modal to save/update the new shift and also related services
	public void saveShift() {
		modalErr = new List<String>();
		try {
			Integer mth = Integer.valueOf(ApexPages.currentPage().getParameters().get('mth'));
			Integer yr = Integer.valueOf(ApexPages.currentPage().getParameters().get('yr'));
			upsert selectedEmp;
			Set<String> seen = new Set<String>();
			for (Service_Quota__c q : curShiftList) {
				if (seen.contains(q.Type__c)) { throw new ServiceAppointmentSetupException('Duplicated service type'); }
				if (q.Employee_Shift__c == null) { q.Employee_Shift__c = selectedEmp.Id; }
				seen.add(q.Type__c);
			}
			upsert curShiftList;
			populateSlots(yr, mth);
		} catch (Exception e) {
			modalErr.add(e.getMessage() + ' | ' + e.getStackTraceString());
		}
	}

	// used in modals to get new service quota row
	public void addNewService() {
		modalErr = new List<String>();
		try {
			String modalType = ApexPages.currentPage().getParameters().get('modal');
			Time curT = Time.newInstance(8, 0, 0, 0);
			DateTime initDT;
			if (modalType == 'shift') { // differentiate which modal is currently open
				initDT = DateTime.newInstance(selectedShift.day, curT);
				curShiftList.add(new Service_Quota__c(Start_Time__c = initDT, End_Time__c = initDT, Interval_Per_Appt__c = 1));
			}
			if (modalType == 'slot') {
				initDT = DateTime.newInstance(selectedSlot.day, curT);
				curSlotsList.add(new Service_Quota__c(Start_Time__c = initDT, End_Time__c = initDT, Interval_Per_Appt__c = 1));
			}
		} catch (Exception e) {
			modalErr.add(e.getMessage() + ' | ' + e.getStackTraceString());
		}
	}

	/** we always send the year and month so that it isnt changed upon reload */
	public void populateSlots() {
		Integer mth = Integer.valueOf(ApexPages.currentPage().getParameters().get('mth'));
		Integer yr = Integer.valueOf(ApexPages.currentPage().getParameters().get('yr'));
		populateSlots(yr, mth);
	}
	public void populateSlots(Integer yr, Integer mth) {
		errMsg = new List<String>();
		try {
			this.selectedSlot = null;
			this.selectedEmp = null;
			getWorkshop();
			if (ws == null) {
				return;
			}

			/*if (wsWriteAccess.isEmpty()) {
				if (String.isBlank(SA_SETUP.Workshop_Read__c)) {
					readOnly = SA_SETUP.Read_Only__c;
				} else {
					readOnly = SA_SETUP.Workshop_Read__c.contains(ws.Name);
				}
                readOnly = true;
			} else {
				readOnly = !wsWriteAccess.contains(ws.Name);
			}*/
            readOnly = !wsWriteAccess.contains(ws.Name);
			//readOnly = wsWriteAccess.isEmpty() ? SA_SETUP.Read_Only__c : !wsWriteAccess.contains(ws.Name);

			genCalendar(yr, mth);
			if (templateSetup) {
				getTemplate();
			} else {
				System.debug('set slot calendar');
				setSlotCalendar(yr, mth);
				setShiftCalendar(yr, mth);
			}
		} catch (Exception e) {
			errMsg.add(e.getMessage() + ' | ' + e.getStackTraceString());
		}
	}

	private void getWorkshop() {
		List<Workshop__c> wsList = [
			SELECT
				Id, Name, Appointment_Interval__c, BusinessHours__c
			FROM Workshop__c
			WHERE Id = :selectedws
			AND Company__r.Name = :selectedCmp
		];
		if (!wsList.isEmpty()) {
			ws = wsList[0];

			if (ws.BusinessHours__c != null) {
				/** Refresh BH */
				BH = [SELECT Id FROM BusinessHours WHERE Id = :ws.BusinessHours__c];
				this.hasSetupBH = true;
			}
			else {
				this.ws = null;
				this.selectedWS = null;
				this.selectedSlot = null;
				this.selectedEmp = null;
				this.calendar = new List<List<String>>();
				this.slotMap = new Map<String, CalDaySlot>();
				this.shiftMap = new Map<String, CalDayShift>();
				this.hasSetupBH = false;
				System.NullPointerException e = new System.NullPointerException();
				e.setMessage(String.format('Business Hours for Workshop \'\'{0}\'\' is not setup.', new string[] { wsList[0].Name }));
				throw e;
			}
		}
		else {
			this.ws = null;
			this.selectedWS = null;
			this.selectedSlot = null;
			this.selectedEmp = null;
			this.calendar = new List<List<String>>();
			this.slotMap = new Map<String, CalDaySlot>();
			this.shiftMap = new Map<String, CalDayShift>();
			this.hasSetupBH = false;
		}
	}

	private void genCalendar(Integer yr, Integer mth) {
		Date beginMonth = Date.newInstance(yr, mth, 1);
		Date startDate = beginMonth.toStartOfWeek();
		Date endDate = beginMonth.addMonths(1).addDays(-1).toStartOfWeek().addDays(6);
		calendar = new List<List<String>>();
		if (templateSetup) {
			calendar.add(getWeekDays());
		} else {
			for (Date curDate = startDate; curDate <= endDate; ) {
				List<String> weekly = new List<String>();
				for (Integer i = 0; i < 7; i++) {
					weekly.add(curDate.format());
					curDate = curDate.addDays(1);
				}
				calendar.add(weekly);
			}
		}
	}

	// once company is changed, we reset everything on the page. mainly for admin use.
	public void changeCmp() {
		errMsg = new List<String>();
		curCmp = [SELECT Id, Name FROM Company__c WHERE Name = :selectedCmp];
		try {
			this.selectedWS = null;
			this.selectedEmp = null;
			this.selectedSlot = null;
			this.calendar = new List<List<String>>();
			this.slotMap = new Map<String, CalDaySlot>();
			this.shiftMap = new Map<String, CalDayShift>();
		} catch (Exception e) {
			errMsg.add(e.getMessage() + ' | ' + e.getStackTraceString());
		}
	}

	/**
	 * function to bring info from prev month to this month
	 * note that we match the day of week for the copying
	 */
	public void copyTemplate() {
		errMsg = new List<String>();
		SavePoint sp = Database.setSavePoint();
		try {
			Integer mth = Integer.valueOf(ApexPages.currentPage().getParameters().get('mth'));
			Integer yr = Integer.valueOf(ApexPages.currentPage().getParameters().get('yr'));
			copySlots(yr, mth);
			copyShifts(yr, mth);
			if (!templateSetup) {
				setSlotCalendar(yr, mth);
				setShiftCalendar(yr, mth);
			}
		} catch (Exception e) {
			Database.rollback(sp);
			errMsg.add(e.getMessage() + ' | ' + e.getStackTraceString());
			System.debug('Error: ' + errMsg);
		}
	}

	/**
	 * this is to cater for the ability for service admins to set multiple days of unproductivity
	 * we need the
	 * @param unprod [unproductive reason]
	 * @param csaId  [the csa we r setting for]
	 * @param dates  [list of applicable dates]
	 * @param mth    [month to load later upon reload]
	 * @param yr     [year to use when loading calendar]
	 */
	public void saveUnprod() {
		errMsg = new List<String>();
		try {
			String unprod = ApexPages.currentPage().getParameters().get('unprod');
			Id csaId = ApexPages.currentPage().getParameters().get('csaId');
			List<String> dateStr = ApexPages.currentPage().getParameters().get('dates').split(',');
			Integer mth = Integer.valueOf(ApexPages.currentPage().getParameters().get('mth'));
			Integer yr = Integer.valueOf(ApexPages.currentPage().getParameters().get('yr'));
			List<Date> dates = new List<Date>();
			for (String s : dateStr) { dates.add(Date.valueOf(s)); }
			List<Employee_Shift__c> esList = [SELECT Id, Unproductivity__c, Active_Date__c FROM Employee_Shift__c WHERE Employee_Master__c = :csaId
											  AND Active_Date__c = :dates AND Is_Template__c = FALSE];
			Map<Date, Employee_Shift__c> esMap = new Map<Date, Employee_Shift__c>();
			for (Employee_Shift__c es : esList) { esMap.put(es.Active_Date__c, es); }
			List<Employee_Shift__c> upsertList = new List<Employee_Shift__c>();
			Employee_Shift__c defShift = new Employee_Shift__c(Company__c = curCmp.Id, Workshop__c = selectedWS, Employee_Master__c = csaId);
			Employee_Shift__c curES;
			for (Date d : dates) {
				curES = esMap.get(d);
				if (curES == null) {
					curES = defShift.clone(); // we clone the default shift that just creates the unproductivity if nothing existing
					curES.Active_Date__c = d;
				}
				curES.Unproductivity__c = unprod;
				curES.Unproductive_Start_Time__c = DateTime.newInstance(d, Time.newInstance(8, 0, 0, 0));
				curES.Unproductive_End_Time__c = DateTime.newInstance(d, Time.newInstance(18, 30, 0, 0));
				upsertList.add(curES);
			}
			upsert upsertList;
			populateSlots(yr, mth);
		} catch (Exception e) {
			errMsg.add(e.getMessage() + ' | ' + e.getStackTraceString());
		}
	}

	/////////////////////
	// PRIVATE HELPERS //
	/////////////////////

	/**
	 * helper function to first find the same day of week in the prev month and then copy the info to this month
	 * we use the fact that setSlotCalendar is a matrix following the calendar format
	 * @param yr  [current year to insert]
	 * @param mth [current month to insert]
	 */
	private void copySlots(Integer yr, Integer mth) {
		Date startDate = Date.newInstance(yr, mth, 1);
		Date endDate = startDate.addMonths(1).addDays(-1);
		System.debug(startDate);
        System.debug(endDate);
		/** Refresh BH */
		BH = [SELECT Id FROM BusinessHours WHERE Id = :ws.BusinessHours__c];

		Map<String, Service_Slot__c> templateSSMap = new Map<String, Service_Slot__c>();
		for (Service_Slot__c ss : [SELECT Id, Active_Date__c, Workshop__c, Company__c, Template_Day__c, Is_Template__c,
								   (SELECT Id, Start_Time__c, End_Time__c, Max_Appt_Per_Timeslot__c, Interval_Per_Appt__c,
								    Max_Quota__c, Type__c, Available_Slots__c FROM Service_Quotas__r) FROM Service_Slot__c WHERE Workshop__c = :selectedWS
								   AND Company__r.Name = :selectedCmp AND Is_Template__c = TRUE]) {
			templateSSMap.put(ss.Template_Day__c.toUpperCase(), ss);
		}
		Map<Date, Service_Slot__c> existSSMap = new Map<Date, Service_Slot__c>();
		for (Service_Slot__c ss : [SELECT Id, Active_Date__c, Workshop__c, Company__c, Template_Day__c, Is_Template__c,
		     					   (SELECT Id, Type__c, Available_Slots__c FROM Service_Quotas__r) FROM Service_Slot__c
		     					   WHERE Workshop__c = :selectedWS AND Company__r.Name = :selectedCmp AND Active_Date__c >= :startDate
		     					   AND Active_Date__c <= :endDate]) {
			existSSMap.put(ss.Active_Date__c, ss);
		}

		List<Service_Slot__c> ssUpList = new List<Service_Slot__c>();
		Map<String, List<Service_Quota__c>> sqUpMap = new Map<String, List<Service_Quota__c>>();
		Map<String, Service_Slot__c> ssMap = new Map<String, Service_Slot__c>();

		for (Date curDate = startDate; curDate <= endDate; curDate = curDate.addDays(1)) {
			if (!BusinessHours.isWithin(BH.Id, DateTime.newInstance(curDate, BH_INIT))) {
				continue;
			}
			DateTime tempDT = DateTime.newInstance(curDate, BH_INIT);
			String dayOfWeek = tempDT.format('EEE').toUpperCase();
			Set<String> skipServices = new Set<String>();
			Service_Slot__c ss;
			if (existSSMap.containsKey(curDate)) {
				ss = existSSMap.get(curDate);
				system.debug(ss);
				system.debug(ss.Service_Quotas__r);
				for (Service_Quota__c sq : ss.Service_Quotas__r) {
					skipServices.add(sq.Type__c);
				}
			} else if (templateSSMap.containsKey(dayOfWeek)) {
				ss = new Service_Slot__c();
				ss.Active_Date__c = curDate;
				ss.Workshop__c = selectedWS;
				ss.Company__c = curCmp.Id;
				ssUpList.add(ss);
			}

			// To add all the service types that are not included inside Exist SS.
			if (templateSSMap.containsKey(dayOfWeek)) {
				for (Service_Quota__c sq : templateSSMap.get(dayOfWeek).Service_Quotas__r) {
					if (skipServices.contains(sq.Type__c) || sq.Available_Slots__c == 0 || sq.Available_Slots__c == null) { continue; }
					Service_Quota__c newSQ = sq.clone(false, true, false, false);
					newSQ.Start_Time__c = DateTime.newInstance(curDate, sq.Start_Time__c.Time());
					newSQ.End_Time__c = DateTime.newInstance(curDate, sq.End_Time__c.Time());
					String uniqueSS = String.valueOf(ss.Workshop__c) + String.valueOf(ss.Company__c) + (ss.Is_Template__c ? String.valueOf(ss.Template_Day__c) : String.valueOf(ss.Active_Date__c));
					ssMap.put(uniqueSS, ss);
					if (!sqUpMap.containsKey(uniqueSS)) {
						sqUpMap.put(uniqueSS, new List<Service_Quota__c>());
					}
					sqUpMap.get(uniqueSS).add(newSQ);
				}
			}
		}
		insert ssUpList;
		List<Service_Quota__c> sqUpList = new List<Service_Quota__c>();
		for (String uniqueSS : sqUpMap.keySet()) {
			for (Service_Quota__c sq : sqUpMap.get(uniqueSS)) {
				sq.Service_Slot__c = ssMap.get(uniqueSS).Id;
				sqUpList.add(sq);
			}
		}
		insert sqUpList;
	}

	/**
	 * see copySlots description
	 * we need to copy each employee shift and the related quota for each day
	 */
	private void copyShifts(Integer yr, Integer mth) {
		Date startDate = Date.newInstance(yr, mth, 1);
		Date endDate = startDate.addMonths(1).addDays(-1);

		Map<String, List<Employee_Shift__c>> templateEmpMap = new Map<String, List<Employee_Shift__c>>();

		for (Employee_Shift__c emp : [SELECT Id, Template_Day__c, Employee_Master__c, Company__c, Workshop__c, Maximum_Appointment__c, Employee_Master__r.IsActive__c,
									  (SELECT Id, Start_Time__c, End_Time__c, Max_Appt_Per_Timeslot__c, Interval_Per_Appt__c, Max_Quota__c, Type__c, Available_Slots__c
									  FROM Service_Quotas__r) FROM Employee_Shift__c WHERE Workshop__c = :selectedWS AND Company__r.Name = :selectedCmp
									  AND Is_Template__c = TRUE AND Employee_Master__r.IsActive__c = TRUE]) {
			if (!templateEmpMap.containsKey(emp.Template_Day__c.toUpperCase())) {
				templateEmpMap.put(emp.Template_Day__c.toUpperCase(), new List<Employee_Shift__c>());
			}
			templateEmpMap.get(emp.Template_Day__c.toUpperCase()).add(emp);
		}
		Map<Date, Map<Id, Employee_Shift__c>> existEmpMap = new Map<Date, Map<Id, Employee_Shift__c>>();
		for (Employee_Shift__c emp : [SELECT Id, Active_Date__c, Employee_Master__c, Maximum_Appointment__c, Employee_Master__r.IsActive__c, Company__c,
		     						  Workshop__c, Is_Template__c,
									  (SELECT Id, Type__c, Available_Slots__c FROM Service_Quotas__r) FROM Employee_Shift__c WHERE Workshop__c = :selectedWS
									  AND Company__r.Name = :selectedCmp AND Active_Date__c >= :startDate AND Active_Date__c <= :endDate]) {
			if (!existEmpMap.containsKey(emp.Active_Date__c)) {
				existEmpMap.put(emp.Active_Date__c, new Map<Id, Employee_Shift__c>());
			}
			existEmpMap.get(emp.Active_Date__c).put(emp.Employee_Master__c, emp);
		}

		List<Employee_Shift__c> empUpList = new List<Employee_Shift__c>();
		Map<String, List<Service_Quota__c>> sqUpMap = new Map<String, List<Service_Quota__c>>();
		Map<String, Employee_Shift__c> empMap = new Map<String, Employee_Shift__c>();

		List<Employee_Master__c> emList = [SELECT Id, Name, Company__c, Workshop__c, IsActive__c FROM Employee_Master__c WHERE Company__r.Name = :selectedCmp
										   AND IsActive__c = true AND Workshop__c = :selectedWS AND Employee_Status_Code__c = 'CA'];
		for (Date curDate = startDate; curDate <= endDate; curDate = curDate.addDays(1)) {
			Map<String, Employee_Shift__c> empKeyMap = new Map<String, Employee_Shift__c>();
			DateTime tempDT = DateTime.newInstance(curDate, BH_INIT);
			String dayOfWeek = tempDT.format('EEE').toUpperCase();
			if (!BusinessHours.isWithin(BH.Id, DateTime.newInstance(curDate, BH_INIT))) {
				for (Employee_Master__c e : emList) {
					if (existEmpMap.containsKey(curDate) && existEmpMap.get(curDate).containsKey(e.Id)) {continue; }
					empUpList.add(new Employee_Shift__c(Active_Date__c = curDate, Company__c = e.Company__c, Workshop__c = e.Workshop__c,
														Employee_Master__c = e.Id, Unproductivity__c = 'PH - Public Holiday', Holiday__c = true,
														Unproductive_Start_Time__c = DateTime.newInstance(curDate, Time.newInstance(8, 0, 0, 0)),
														Unproductive_End_Time__c = DateTime.newInstance(curDate, Time.newInstance(18, 30, 0, 0))));
				}
			} else {
				Map<Id, Set<String>> skipServices = new Map<Id, Set<String>>();
				List<Employee_Shift__c> empList = new List<Employee_Shift__c>();

				if (existEmpMap.containsKey(curDate)) {
					for (Employee_Shift__c emp : existEmpMap.get(curDate).values()) {
						if (!skipServices.containsKey(emp.Employee_Master__c)) {
							skipServices.put(emp.Employee_Master__c, new Set<String>());
						}
						for (Service_Quota__c sq : emp.Service_Quotas__r) {
							skipServices.get(emp.Employee_Master__c).add(sq.Type__c);
						}
					}
				}

				if (templateEmpMap.containsKey(dayOfWeek)) {
					for (Employee_Shift__c emp : templateEmpMap.get(dayOfWeek)) {
						if (skipServices.containsKey(emp.Employee_Master__c) || emp.Maximum_Appointment__c == 0 ||
						    emp.Maximum_Appointment__c == null || !emp.Employee_Master__r.IsActive__c) { continue; }
						Employee_Shift__c newEmp = new Employee_Shift__c();
						newEmp.Active_Date__c = curDate;
						newEmp.Workshop__c = selectedWS;
						newEmp.Company__c = curCmp.Id;
						newEmp.Employee_Master__c = emp.Employee_Master__c;
						newEmp.Maximum_Appointment__c = emp.Maximum_Appointment__c;
						empUpList.add(newEmp);
						empKeyMap.put(String.valueOf(newEmp.Active_Date__c) + newEmp.Employee_Master__c + newEmp.Company__c + newEmp.Workshop__c, newEmp);
					}

					for (Employee_Shift__c emp : templateEmpMap.get(dayOfWeek)) {
						String strKey = String.valueOf(curDate) + emp.Employee_Master__c + emp.Company__c + emp.Workshop__c;
						// Template Shifts
						Employee_Shift__c sqEmp = empKeyMap.get(strKey);
						if (emp.Maximum_Appointment__c == 0 || emp.Maximum_Appointment__c == null) {continue;}
						for (Service_Quota__c sq : emp.Service_Quotas__r) {
							Boolean skipThisQuota = false;
							if (skipServices.containsKey(emp.Employee_Master__c)) {
								sqEmp = existEmpMap.get(curDate).get(emp.Employee_Master__c);
								if (skipServices.get(emp.Employee_Master__c).contains(sq.Type__c)) {
									skipThisQuota = true;
								}
							}
							if (skipThisQuota || sq.Available_Slots__c == 0 || sq.Available_Slots__c == null) { continue; }

							Service_Quota__c newSQ = sq.clone(false, true, false, false);
							newSQ.Start_Time__c = DateTime.newInstance(curDate, sq.Start_Time__c.time());
							newSQ.End_Time__c = DateTime.newInstance(curDate, sq.End_Time__c.time());
							String uniqueEmp = String.valueOf(sqEmp.Company__c) + String.valueOf(sqEmp.Workshop__c) + String.valueOf(sqEmp.Employee_Master__c)
											 + (sqEmp.Is_Template__c ? String.valueOf(sqEmp.Template_Day__c) : String.valueOf(sqEmp.Active_Date__c));
							empMap.put(uniqueEmp, sqEmp);
							if (!sqUpMap.containsKey(uniqueEmp)) {
								sqUpMap.put(uniqueEmp, new List<Service_Quota__c>());
							}
							sqUpMap.get(uniqueEmp).add(newSQ);
						}
					}
				}
			}
		}
		insert empUpList;
		List<Service_Quota__c> sqUpList = new List<Service_Quota__c>();
		for (String uniqueEmp : sqUpMap.keySet()) {
			for (Service_Quota__c sq : sqUpMap.get(uniqueEmp)) {
				sq.Employee_Shift__c = empMap.get(uniqueEmp).Id;
				sqUpList.add(sq);
			}
		}
		insert sqUpList;
	}

	/** we find the diff bw weekdays to work out how far back to retrieve info */
/*	private Date findPrevStartDate(Integer mth, Integer yr) {
		Date beginDate = Date.newInstance(yr, mth, 1);
		Integer daysBegin = beginDate.daysBetween(beginDate.toStartOfWeek());
		Date prevDate = beginDate.addMonths(-1);
		Integer daysPrev = prevDate.daysBetween(prevDate.toStartOfWeek());
		return prevDate.addDays(Math.mod(daysPrev - daysBegin - 7, 7));
	}*/

	// helper function to call the set slot calendar based on a full viewable month
	private void setSlotCalendar(Integer yr, Integer mth) {
		Date startDate = Date.newInstance(yr, mth, 1).toStartOfWeek();
		Date endDate = Date.newInstance(yr, mth, Date.daysInMonth(yr, mth)).toStartOfWeek().addDays(6);
		setSlotCalendar(startDate, endDate);
	}

	/**
	 * we retrieve the existing service quota based on the given arguments
	 * and then translate that into the CalDaySlot helper class
	 * we then organize it into a 2x2 matrix for the calendar display
	 * @param startDate
	 * @param endDate
	 */
	private void setSlotCalendar(Date startDate, Date endDate) {
		System.debug('@@@@ setSlotCalendar');
		List<Service_Slot__c> listSS = [SELECT Id, Company__c, Workshop__c, Active_Date__c,
										(SELECT Id, Service_Slot__c, Service_Slot__r.Company__c, Service_Slot__r.Workshop__c, Max_Quota__c, Type__c,
										 Start_Time__c, End_Time__c, Available_Slots__c, Max_Appt_Per_Timeslot__c, Interval_Per_Appt__c, Workshop__c,
										 Service_Slot__r.Workshop__r.Appointment_Interval__c FROM Service_Quotas__r
										 ORDER BY Type__c ASC)
										FROM Service_Slot__c WHERE Active_Date__c >= :startDate AND Active_Date__c <= :endDate AND
										Company__r.Name = :selectedCmp AND Workshop__c = :selectedWS AND Is_Template__c = FALSE];
		List<Workshop__c> ws = [SELECT Id, Name FROM Workshop__c WHERE Id = :selectedWS LIMIT 1];

		this.slotMap = new Map<String, CalDaySlot>();
		Service_Quota__c checkQ;
		CalDaySlot curD;
		for (Service_Slot__c ss : listSS) {			
			curD = this.slotMap.get(ss.Active_Date__c.format());
			curD = (curD == null) ? new CalDaySlot(ss.Active_Date__c, ss) : curD;
			if (ws.size() > 0 ) { activeHolidaySlot(ss.Active_Date__c, curD); }
			for (Service_Quota__c q : ss.Service_Quotas__r) {
				checkQ = curD.slots.get(q.Type__c);
				if (checkQ != null) { throw new ServiceAppointmentSetupException('Multiple Types found for Date:' + q.Start_Time__c.date()); }
				curD.slots.put(q.Type__c, q);
			}
			this.slotMap.put(ss.Active_Date__c.format(), curD);
		}

		for (String day : slotMap.keySet()) {
		}

		Date curCal = startDate.toStartOfWeek();
		Date calEnd = endDate.toStartOfWeek().addDays(6);
		List<CalDaySlot> curWeek;
		Service_Slot__c curSlot;
		Service_Slot__c defaultSlot = new Service_Slot__c(Company__c = curCmp.Id, Workshop__c = selectedWS);
		while (curCal < calEnd) {
			curWeek = new List<CalDaySlot>();
			for (Integer i = 0; i < 7; i++) {
				curD = this.slotMap.get(curCal.format());
				if (curD == null) {
					curSlot = defaultSlot.clone();
					curSlot.Active_Date__c = curCal;
					curD = new CalDaySlot(curCal, curSlot);
					if (ws.size() > 0 ) { activeHolidaySlot(curCal, curD); }
					this.slotMap.put(curCal.format(), curD);
				}
				curWeek.add(curD);
				curCal = curCal.addDays(1);
			}
		}
	}

	private void activeHolidaySlot(Date slotDate, CalDaySlot curD) {
		if (Date.today() <= slotDate) {
			if (BusinessHours.isWithin(BH.Id, DateTime.newInstance(slotDate, BH_INIT)))
				curD.isActive = true;
		}
	}

	// helper method to call the setshiftcalendar method based on a full month
	private void setShiftCalendar(Integer yr, Integer mth) {
		Date startDate = Date.newInstance(yr, mth, 1).toStartOfWeek();
		Date endDate = Date.newInstance(yr, mth, Date.daysInMonth(yr, mth)).toStartOfWeek().addDays(6);
		setShiftCalendar(startDate, endDate);
	}

	/**
	 * similar to setSlotCalendar
	 * we retrieve the existing service quota based on the given arguments
	 * and then translate that into the CalDaySlot helper class
	 * we then organize it into a 2x2 matrix for the calendar display
	 *
	 * Main Diff is that each day has multiple employee shifts to account for
	 * @param startDate
	 * @param endDate
	 */
	private void setShiftCalendar(Date startDate, Date endDate) {
		// Getting Service Quota
		List<Employee_Shift__c> listES = [SELECT Id, Name, Employee_Master__c, Company__c, Workshop__c, Unproductivity__c, Unproductive_Start_Time__c,
										 Unproductive_End_Time__c, Allow_Work_On_Unprod__c, Maximum_Appointment__c, Employee_Master__r.Name, Active_Date__c,
										 Employee_Master__r.IsActive__c,
										 (SELECT Id, Max_Quota__c, Type__c, Utilized__c, Start_Time__c, End_Time__c, Available_Slots__c, Employee_Shift__c,
										  Interval_Per_Appt__c, Workshop__c FROM Service_Quotas__r ORDER BY Type__c)
										 FROM Employee_Shift__c WHERE Active_Date__c >= :startDate AND Active_Date__c <= :endDate AND Is_Template__c = FALSE
										 AND Company__r.Name = :selectedCmp AND Workshop__c = :selectedWS ORDER BY Employee_Master__r.Name ASC];
		List<Workshop__c> ws = [SELECT Id, Name FROM Workshop__c WHERE Id = :selectedWS LIMIT 1];
		this.shiftMap = new Map<String, CalDayShift>();
		Map<String, Service_Quota__c> curS;
		CalDayShift curD;
		Integer checkUtil;
		for (Employee_Shift__c es : listES) {
			if (!es.Employee_Master__r.IsActive__c) {
				checkUtil = 0;
				for (Service_Quota__c checkQ : es.Service_Quotas__r) { checkUtil += Integer.valueOf(checkQ.Utilized__c); }
				if (checkUtil <= 0) { continue; }
			}
			curD = this.shiftMap.get(es.Active_Date__c.format());
			curD = (curD == null) ? new CalDayShift(es.Active_Date__c) : curD;
			if (ws.size() > 0 ) { activeESHolidaySlot(es.Active_Date__c, curD); }
			curD.empShiftList.add(es);
			curS = new Map<String, Service_Quota__c>();
			for (Service_Quota__c q : es.Service_Quotas__r) { curS.put(q.Type__c, q); }
			curD.shiftTypeMap.put(es.Id, curS);
			this.shiftMap.put(es.Active_Date__c.format(), curD);
		}
		Date curCal = startDate.toStartOfWeek();
		Date calEnd = endDate.toStartOfWeek().addDays(6);
		while (curCal <= calEnd) {
			curD = this.shiftMap.get(curCal.format());
			if (curD == null) {
				curD = new CalDayShift(curCal);
				activeESHolidaySlot(curCal, curD);
				this.shiftMap.put(curCal.format(), curD);
			}
			curCal = curCal.addDays(1);
		}
	}

	private void activeESHolidaySlot(Date slotDate, CalDayShift curD) {
		if (Date.today() <= slotDate) {
			if (!BusinessHours.isWithin(BH.Id, DateTime.newInstance(slotDate, BH_INIT)))
				curD.isActive = true;
		}
	}

	/** use a string function to get a deterministic color */
	private String rgbVal(String inp) {
		Integer curHash = Math.abs(inp.hashCode());
		//Integer r = (curHash & 16711680) >> 16; // 0xFF0000 in hex
		//Integer g = (curHash & 65280) >> 8; // 0x00FF00 in hex
		//Integer b = (curHash & 255);
		return 'hsla(' + Math.mod(curHash, 360) + ',' + (50 + Math.mod(curHash, 50)) + '%,' + (40 + Math.mod(curHash, 50)) + '%, ' + OPACITY + ')';
	}
}