global class ServiceApptBooking {
	public final static List<User> ERR_USER = [SELECT Id, Email FROM User WHERE Alias = 'godlike' LIMIT 1];
	private final static Organization CUR_ORG = [SELECT Id, IsSandbox FROM Organization LIMIT 1];
	private final static String[] DEF_NUM = new string[] {
												'+60139553552' // Iqah
											};
	private final static String CTRY_PREFIX = '60';
	public final static String QR_SRC = 'https://api.qrserver.com/v1/create-qr-code/?data=';
	public final static Map<String, String> WS_DIV = new Map<String, String> { 'WP' => 'AUTOFRANCE',
																			   'WG' => 'REGENT',
																			   'WX' => 'QUICK LANE',
																			   'W9' => 'QUICK LANE',
																			   'WY' => 'E-AUTO' };
	public final static Map<String, List<String>> DIV_MAP = new Map<String, List<String>> { 'REGENT' => new List<String> { 'WG' },
																							'AUTOFRANCE' => new List<String> { 'WP' },
																							'QUICK LANE' => new List<String> { 'WX', 'W9' },
																							'E-AUTO' => new List<String> { 'WY' } };
	public class ApptException extends Exception {}
	// NOTE: we will make the simplifying assumption that the methods here pertain to insertion of one appt,
	// since there isnt much biz need for multiple appt insertion

	public static String sendApptSMS(Service_Appointment__c sa, String smsText) {
		string recipientNumber = u.sandboxPhone(CTRY_PREFIX, sa.Contact_No__c, CUR_ORG.IsSandbox, DEF_NUM);
		system.debug('sendApptSMS: ' + sa.Contact_No__c + ' / ' + recipientNumber);
		//string saName = sa.Name.length() > 8 ? sa.Name.substring(sa.Name.length() - 8, sa.Name.length()) : sa.Name;

		List<Task> relatedTasks = [SELECT Id FROM Task WHERE WhatId = :sa.Id all rows];
		integer newRelatedTask = relatedTasks.size()+1;
		string msgId = sa.Id +'_'+ newRelatedTask;
        system.debug('MsgId '+ msgId);

		//string msgId = string.format('{0}{1}', new string[] { Datetime.now().format('yyMMddHHmmss'), saName });
		string serviceId = string.format('{0}_{1}_{2}_Care', new string[] { (CUR_ORG.IsSandbox ? 'Sbox' : 'Prod'), sa.Company__r.Name, sa.Workshop__r.Name });
		string ret = M3TechApiServiceWrapper.deliverMessage(msgId, smsText, recipientNumber);

		return string.format('{0} ({1})', new string[] { ret, recipientNumber });
	}

	public static M3TechApiServiceWrapper.DeliverMsgReturnWrapper sendApptSMS2(Service_Appointment__c sa, String smsText) {
		string recipientNumber = u.sandboxPhone(CTRY_PREFIX, sa.Contact_No__c, CUR_ORG.IsSandbox, DEF_NUM);
		system.debug('sendApptSMS2: ' + sa.Contact_No__c + ' / ' + recipientNumber);
		//string saName = sa.Name.length() > 8 ? sa.Name.substring(sa.Name.length() - 8, sa.Name.length()) : sa.Name;

		List<Task> relatedTasks = [select Id from task where whatId =: sa.id all rows];
		integer newRelatedTask = relatedTasks.size() +1;
		string msgId = sa.id+'_' + newRelatedTask;
        system.debug('MsgId '+ msgId);
		//string msgId = string.format('{0}{1}', new string[] { Datetime.now().format('yyMMddHHmmss'), saName });
		string serviceId = string.format('{0}_{1}_{2}_Care', new string[] { (CUR_ORG.IsSandbox ? 'Sbox' : 'Prod'), sa.Company__r.Name, sa.Workshop__r.Name });
		//string ret = M3TechApiWrapper.deliverMessage2(msgId, serviceId, smsText, recipientNumber);
		//return string.format('{0} ({1})', new string[] { ret, recipientNumber });
		M3TechApiServiceWrapper.DeliverMsgReturnWrapper ret = new M3TechApiServiceWrapper.DeliverMsgReturnWrapper();
		ret = M3TechApiServiceWrapper.deliverMessage2(msgId,smsText,recipientNumber, sa.Workshop__r.name, sa.Workshop__r.SmsEndpoint__c, sa.Workshop__r.SmsServiceId__c, sa.Workshop__r.SmsUserKey__c, sa.Workshop__r.SmsPassword__c);

		return ret;
	}

	public static List<String> getApptQR(List<Id> saList) {
		List<Service_Appointment__c> apptList = [SELECT Id, Vehicle_Ownership__r.Customer__c, Vehicle_Ownership__r.Registration_No__c,
												Vehicle_Ownership__r.Vehicle__r.Name, Contact_Name__c, Contact_No__c, Company__r.Name
												FROM Service_Appointment__c WHERE Id IN :saList];
		return getApptQR(apptList);
	}

	public static List<String> getApptQR(List<Service_Appointment__c> saList) {
		List<String> qrStrings = new List<String>();
		CareQR qr;
		for (Service_Appointment__c sa : saList) {
			qr = new CareQR(sa);
			qrStrings.add(QR_SRC + EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(qr))));
		}
		return qrStrings;
	}

	public static List<String> getVOQR(List<Id> voList, String cmp) {
		List<Vehicle_Ownership__c> ownerList = [SELECT Customer__c, Registration_No__c, Vehicle__r.Name FROM Vehicle_Ownership__c WHERE Id IN :voList];
		return getVOQR(ownerList, cmp);
	}

	public static List<String> getVOQR(List<Vehicle_Ownership__c> voList, String cmp) {
		List<String> qrStrings = new List<String>();
		CareQR qr;
		for (Vehicle_Ownership__c vo : voList) {
			qr = new CareQR(vo, cmp);
			qrStrings.add(QR_SRC + EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(qr))));
		}
		return qrStrings;
	}

	public static List<Service_Type__c> getServices(String cmpName, List<String> filterList, Boolean ignoreInternal) {
		return getServices(cmpName, filterList, false, ignoreInternal);
	}

	public static List<Service_Type__c> getServices(String cmpName, List<String> filterList) {
		return getServices(cmpName, filterList, false, false);
	}

	public static List<Service_Type__c> getServices(String cmpName, List<String> filterList, Boolean isVIP, Boolean ignoreInternal) {
		List<Service_Type__c> sList = [SELECT Name, Description__c, DisplayName__c, Company__c, Included_Types__c, Workshop__c, VIP__c, Allow_External__c,
									   Allow_Customer_Comments__c, Internal_Appointments__c FROM Service_Type__c WHERE Available__c = TRUE
									   ORDER BY Sort_Order__c ASC NULLS LAST];
		List<Service_Type__c> rv = new List<Service_Type__c>();
		// NOTE: filter has possibility of being NULL for special case (VANTAGE)
		String filter;
		for (Service_Type__c cur : sList) {
			Boolean inFilter = false;
			if ((!isVIP && cur.VIP__c) || (ignoreInternal && cur.Internal_Appointments__c)) { continue; }
			if (filterList != null) {
				for (Integer i = 0; i < filterList.size(); i++) {
					filter = filterList[i];
					Boolean nullValue = (cur.Workshop__c == null && filter == null);
					inFilter = nullValue || (cur.Workshop__c != null && filter != null && cur.Workshop__c.contains(filter));
					if (inFilter) { break; }
				}
			} else {
				if (String.isBlank(cur.Workshop__c)) {
					inFilter = true;
				}
			}
			if (cur.Company__c.contains(cmpName) && inFilter) { rv.add(cur); }
		}
		return rv;
	}

	/////////////////////////////////////////////////
	// USED IN CALCULATION OF WS AND CSA AVAILABLE //
	/////////////////////////////////////////////////
	/**
	 * we find the available workshops that can handle the chosen services
	 * @param selectedTypes [types that have been chosen
	 */
	public static List<Workshop__c> populateWSList(Booking curBooking) {
		if (curBooking == null || curBooking.cmp == null) { throw new ApptException('No Company assigned for current booking.'); }
		if (curBooking.selectedTypes == null || curBooking.selectedTypes.size() <= 0) { throw new ApptException('No types selected.'); }
		// we extract any current chosen slots with this current appt to include in the count
		Set<Id> apptQuotas = new Set<Id>();
		if (curBooking.slotQuota != null) {
			for (Service_Quota__c q : curBooking.slotQuota) { apptQuotas.add(q.Id); }
		}

		String typeFilter;
		if (curBooking.so != null) {
			typeFilter = curBooking.so.Vehicle__r.Vehicle_Make__r.Name;
		} else if (curBooking.veh != null) {
			typeFilter = curBooking.veh.Vehicle_Make__r.Name;
		} else {
			typeFilter = curBooking.vo.Vehicle__r.Vehicle_Make__r.Name;
		}
		String cmp = curBooking.cmp;
		List<String> selectedTypes = curBooking.selectedTypes;

		String query = 'SELECT Id, Type__c, Service_Slot__c, Service_Slot__r.Workshop__c, Service_Slot__r.Workshop__r.Name,';
		query += ' Service_Slot__r.Workshop__r.Short_Address__c, ';
		query += ' Service_Slot__r.Workshop__r.Address__c, Service_Slot__r.Workshop__r.Contact_Number__c,';
		query += ' Service_Slot__r.Workshop__r.Service_Centre_Name__c, Service_Slot__r.Workshop__r.Geolocation__Longitude__s,';
		query += ' Service_Slot__r.Workshop__r.Geolocation__Latitude__s, Service_Slot__r.Workshop__r.Auto_Assign_CSA__c,';
		query += ' Service_Slot__r.Workshop__r.AllowInWhip__c, ';
		query += ' Service_Slot__r.Workshop__r.Allow_Appt_External__c, Service_Slot__r.Active_Date__c FROM Service_Quota__c';
		query += ' WHERE (Service_Slot__r.Company__r.Name = :cmp AND Service_Slot__r.Workshop__r.IsActive__c = TRUE';
		query += (String.isBlank(curBooking.division)) ? '' : ' AND Service_Slot__r.Workshop__r.Service_Centre_Name__c LIKE \'%' + curBooking.division + '%\'';
		query += ' AND Service_Slot__r.Status__c = \'Active\'';
		query += (String.isBlank(typeFilter)) ? '' : ' AND Service_Slot__r.Workshop__r.Vehicle_Make__c INCLUDES (:typeFilter)';
		query += ' AND Type__c IN :selectedTypes AND Available_Slots__c > 0) OR (Id = :apptQuotas)';

		List<Service_Quota__c> unfilteredQuota = Database.query(query);
		// for each date, we save a map of each type and then workshops
		Map<Date, Map<String, Set<Id>>> dateTypeMap = new Map<Date, Map<String, Set<Id>>>();
		Map<String, Set<Id>> typeMap;
		Set<Id> curSet;
		Map<Id, Workshop__c> wsMap = new Map<Id, Workshop__c>();
		system.debug('unfilteredQuota : ' + unfilteredQuota);
		for (Service_Quota__c q : unfilteredQuota) {
			typeMap = dateTypeMap.get(q.Service_Slot__r.Active_Date__c);
			typeMap = (typeMap == null) ? new Map<String, Set<Id>>() : typeMap;
			curSet = typeMap.get(q.Type__c);
			curSet = (curSet == null) ? new Set<Id>() : curSet;
			curSet.add(q.Service_Slot__r.Workshop__c);
			typeMap.put(q.Type__c, curSet);
			dateTypeMap.put(q.Service_Slot__r.Active_Date__c, typeMap);

			wsMap.put(q.Service_Slot__r.Workshop__c, q.Service_Slot__r.Workshop__r);
		}
		Set<Id> finalSet = new Set<Id>();
		Set<Id> initSet = wsMap.keySet();
		Set<Id> filteredSet;
		Set<String> unseenTypes = new Set<String>(curBooking.selectedTypes);
		for (Map<String, Set<Id>> curTMap : dateTypeMap.values()) {
			if (curTMap.size() < curBooking.selectedTypes.size()) { continue; }
			filteredSet = initSet.clone();
			for (Set<Id> curWS : curTMap.values()) { filteredSet.retainAll(curWS); }
			for (String typ : curTMap.keySet()) { unseenTypes.remove(typ); } //  to see what types we have not seen before
			finalSet.addAll(filteredSet);
		}
		if (finalSet.size() <= 0) { throw new ApptException('Unable to find slots for: ' + String.join(new List<String>(unseenTypes), ',')); }

		List<Workshop__c> rv = new List<Workshop__c>();
		for (Id ws : finalSet) { rv.add(wsMap.get(ws)); }
		if (curBooking.ws != null && !finalSet.contains(curBooking.ws.Id)) { curBooking.ws = null; }
		rv.sort();
		return rv;
	}

	/**
	 * same logic as ServiceApptBooking.populateWSList where we create a map of the services available each day for each csa and then use sets to filter down the available csas
	 * we have an additional filter for the workshops since we must limit ourselves to the workshops that can handle this appt as well
	 * @param selectedTypes
	 * @param wsList
	 */
	public static List<Employee_Master__c> populateCSAList(List<Workshop__c> wsList, Booking curBooking) {
		Set<Id> wsId = new Set<Id>();
		for (Workshop__c w : wsList) { wsId.add(w.Id); }
		Set<Id> apptQuotas = new Set<Id>();
		if (curBooking.csaQuota != null) {
			for (Service_Quota__c q : curBooking.csaQuota) { apptQuotas.add(q.Id); }
		}
		String divFilter = '%' + curBooking.division + '%';
		List<Service_Quota__c> unfilteredQuota = [SELECT Id, Employee_Shift__c, Employee_Shift__r.Employee_Master__c, Employee_Shift__r.Employee_Master__r.Name,
													Employee_Shift__r.Employee_Master__r.Workshop__c, Employee_Shift__r.Employee_Master__r.Workshop__r.Name,
													Employee_Shift__r.Employee_Master__r.Workshop__r.Short_Address__c,
													Employee_Shift__r.Employee_Master__r.SFDC_User_Name__c, Employee_Shift__r.Employee_Master__r.Mobile_Number__c,
													Employee_Shift__r.Employee_Master__r.Allow_Appt_External__c, Type__c, Employee_Shift__r.Maximum_Appointment__c,
													Employee_Shift__r.Active_Date__c,
													(SELECT Id FROM Appointment_Utilizations__r)
													FROM Service_Quota__c WHERE Employee_Shift__r.Company__r.Name = :curBooking.cmp
													AND Employee_Shift__r.Workshop__r.Service_Centre_Name__c LIKE :divFilter
													AND Employee_Shift__r.Workshop__c IN :wsId
													AND (((Employee_Shift__r.Unproductivity__c = null OR
															(Employee_Shift__r.Unproductivity__c != null AND Employee_Shift__r.Allow_Work_on_Unprod__c = true))
															AND Type__c IN :curBooking.selectedTypes AND Available_Slots__c > 0
															AND Employee_Shift__r.Employee_Master__r.IsActive__c = true
															AND Employee_Shift__r.Active_Date__c > :System.today()) OR (Id = :apptQuotas))];
		System.debug('Employee Shift: ' + unfilteredQuota);
		Map<Date, Map<String, Set<Id>>> dateTypeMap = new Map<Date, Map<String, Set<Id>>>();
		Map<String, Set<Id>> typeMap;
		Set<Id> curSet;
		Map<Id, Employee_Master__c> csaMap = new Map<Id, Employee_Master__c>();
		for (Service_Quota__c q : unfilteredQuota) {
			if (q.Appointment_Utilizations__r.size() >= q.Employee_Shift__r.Maximum_Appointment__c) { continue; }
			typeMap = dateTypeMap.get(q.Employee_Shift__r.Active_Date__c);
			typeMap = (typeMap == null) ? new Map<String, Set<Id>>() : typeMap;

			curSet = typeMap.get(q.Type__c);
			curSet = (curSet == null) ? new Set<Id>() : curSet;
			curSet.add(q.Employee_Shift__r.Employee_Master__c);
			typeMap.put(q.Type__c, curSet);
			dateTypeMap.put(q.Employee_Shift__r.Active_Date__c, typeMap);
			csaMap.put(q.Employee_Shift__r.Employee_Master__c, q.Employee_Shift__r.Employee_Master__r);
		}

		Set<Id> finalSet = new Set<Id>();
		Set<Id> initSet = csaMap.keySet();
		Set<Id> filteredSet;
		Set<String> unseenTypes = new Set<String>(curBooking.selectedTypes);
		for (Map<String, Set<Id>> curType : dateTypeMap.values()) {
			if (curType.size() < curBooking.selectedTypes.size()) { continue; }
			filteredSet = initSet.clone();
			for (Set<Id> curCSA : curType.values()) { filteredSet.retainAll(curCSA); }
			for (String typ : curType.keySet()) { unseenTypes.remove(typ); } //  to see what types we have not seen before
			finalSet.addAll(filteredSet);
		}
		List<Employee_Master__c> rv = new List<Employee_Master__c>();
		for (Id csa : finalSet) { rv.add(csaMap.get(csa)); }
		return rv;
	}

	///////////////////////////////////////
	// USED TO CALCULATE AVAILABLE SLOTS //
	///////////////////////////////////////

	public static Map<Date, CalDay> populateCalDayMap(Date curD, Date endD, Booking curBooking) {
		// if (curBooking != null && curBooking.selectedTypes.contains('Delivery Booking')) {
		// 	return populateCalDayMapDB(curD, endD, curBooking);
		// }
		if (curBooking.ws == null) { throw new ApptException('Empty Workshop selected. Unable to populate calendar'); }
		Set<Id> apptQuotas = new Set<Id>();
		if (curBooking.sa != null && curBooking.slotQuota != null) { // we search for existing slots if its coming from an existing appt
			for (Service_Quota__c q : curBooking.slotQuota) { apptQuotas.add(q.Id); }
		}
		// we get the necessary information for the WS side here
		List<Service_Quota__c> calQuota = [SELECT Id, Start_Time__c, End_Time__c, Available_Slots__c, Interval_Per_Appt__c, Type__c, Max_Appt_Per_Timeslot__c
											FROM Service_Quota__c WHERE Service_Slot__r.Company__r.Name = :curBooking.cmp AND
											Service_Slot__r.Workshop__c = :curBooking.ws.Id AND Type__c IN :curBooking.selectedTypes
											AND DAY_ONLY(convertTimeZone(Start_Time__c)) >= :curD AND DAY_ONLY(convertTimeZone(Start_Time__c)) <= :endD AND DAY_ONLY(convertTimeZone(Start_Time__c)) > :System.today()
											AND ((Service_Slot__r.Status__c = 'Active' AND Available_Slots__c > 0) OR Id = :apptQuotas)];
		// we check that we have all the required slots on each day too
		Map<Date, List<Service_Quota__c>> quotaMap = catByDate(calQuota, curBooking.selectedTypes.size()); // organize the slots into each date to get the slot quota later
		List<String> wrappedTypes = new List<String>();
		for (String s : curBooking.selectedTypes) { wrappedTypes.add('\'' + s + '\''); }
		String curSelection = String.join(wrappedTypes, ',');
		String apptWSQuery = 'SELECT Id, Appointment_Date__c, Service_Request__c, ' +
							'(SELECT Id, Service_Quota__r.Interval_Per_Appt__c FROM Appointment_Utilizations__r) ' +
							'FROM Service_Appointment__c WHERE Workshop__c = \'' + curBooking.ws.Id + '\' ' +
							'AND Apppointment_Status__c IN (\'CONVERTED TO RO\', \'ACTIVE\') AND DAY_ONLY(convertTimeZone(Appointment_Date__c)) >= :curD ' +
							'AND DAY_ONLY(convertTimeZone(Appointment_Date__c)) <= :endD AND Service_Request__c INCLUDES (' + curSelection + ') ' +
							((curBooking != null && curBooking.sa != null) ? 'AND Id != \'' + curBooking.sa.Id + '\'' : '');

		Map<Date, List<Service_Appointment__c>> wsApptMap = catByDate((List<Service_Appointment__c>) Database.query(apptWSQuery));
		Set<Date> dateRange = quotaMap.keySet();
		// collect the necessary information if is autoAssign WS or if CSA is chosen
		Map<Date, Map<Id, List<Service_Quota__c>>> csaQuotaMap = new Map<Date, Map<Id, List<Service_Quota__c>>>();
		Map<Date, Map<Id, List<Service_Appointment__c>>> csaApptMap = new Map<Date, Map<Id, List<Service_Appointment__c>>>();

		if (checkNeedCSA(curBooking)) {
			Set<Id> csaApptQuotas = new Set<Id>();
			if (curBooking.sa != null && curBooking.csaQuota != null) { // we search for existing slots if its coming from an existing appt
				for (Service_Quota__c q : curBooking.csaQuota) { csaApptQuotas.add(q.Id); }
			}
			List<String> selectedTypes = curBooking.selectedTypes; // movin the variable out here since we cannot reference from query
			Date sysToday = System.today();
			String queryStr = 'SELECT Id, Start_Time__c, End_Time__c, Available_Slots__c, Interval_Per_Appt__c, Type__c, ';
			queryStr += 'Employee_Shift__r.Allow_Work_on_Unprod__c, Employee_Shift__r.Unproductive_Start_Time__c,Employee_Shift__r.Unproductive_End_Time__c,';
			queryStr += 'Employee_Shift__c, Employee_Shift__r.Unproductivity__c, Employee_Shift__r.Active_Date__c, Employee_Shift__r.Maximum_Appointment__c, ';
			queryStr += 'Employee_Shift__r.Employee_Master__c FROM Service_Quota__c WHERE ';
			queryStr += (curBooking.csa != null) ? 'Employee_Shift__r.Employee_Master__c = \'' + curBooking.csa.Id + '\' AND ' : '';
			queryStr += 'Employee_Shift__r.Company__r.Name = \'' + curBooking.cmp + '\' ';
			queryStr += 'AND DAY_ONLY(convertTimeZone(Start_Time__c)) >= :curD AND DAY_ONLY(convertTimeZone(Start_Time__c)) <= :endD AND Type__c IN :selectedTypes ';
			queryStr += (curBooking.selectedTypes.contains('360 Point Check/Pre-Delivery Check')) ? 'AND DAY_ONLY(convertTimeZone(Start_Time__c)) >= :sysToday ' : 'AND DAY_ONLY(convertTimeZone(Start_Time__c)) > :sysToday ';
			queryStr += 'AND Employee_Shift__r.Workshop__c = \'' + curBooking.ws.Id + '\' AND Employee_Shift__r.Maximum_Appointment__c > 0 AND ((';
			queryStr += '(Employee_Shift__r.Unproductivity__c = null OR ';
			queryStr += '(Employee_Shift__r.Unproductivity__c != null AND Employee_Shift__r.Allow_Work_on_Unprod__c = true)) ';
			queryStr += 'AND Available_Slots__c > 0 AND Employee_Shift__r.Employee_Master__r.IsActive__c = true) ';
			queryStr += 'OR (Id = :csaApptQuotas))';
			System.debug('queryStr: ' + queryStr);
			List<Service_Quota__c> csaQuota = Database.query(queryStr);
			csaQuotaMap = catByDateAndCSA(csaQuota, curBooking.selectedTypes.size());
			System.debug('csaQuotaMap:' + csaQuotaMap);
			Id includeId = (curBooking != null && curBooking.sa != null) ? curBooking.sa.Id : null;
			String apptQueryStr = 'SELECT Id, Appointment_Date__c, Employee_Master__c, (SELECT Id, Service_Quota__r.Interval_Per_Appt__c, ';
			apptQueryStr += 'Service_Quota__r.Employee_Shift__r.Maximum_Appointment__c FROM Appointment_Utilizations__r ';
			apptQueryStr += 'WHERE Service_Quota__r.Employee_Shift__c != null) FROM Service_Appointment__c WHERE ';
			apptQueryStr += 'Workshop__c = \'' + curBooking.ws.Id + '\' AND Apppointment_Status__c IN (\'CONVERTED TO RO\', \'ACTIVE\') AND Id != :includeId ';
			apptQueryStr += 'AND DAY_ONLY(convertTimeZone(Appointment_Date__c)) >= :curD AND DAY_ONLY(convertTimeZone(Appointment_Date__c)) <= :endD AND DAY_ONLY(convertTimeZone(Appointment_Date__c)) > :sysToday ';
			apptQueryStr += (curBooking.csa != null) ? ' AND Employee_Master__c = \'' + curBooking.csa.Id + '\' ' : 'AND Employee_Master__c != null';
			csaApptMap = catByDateAndCSA((List<Service_Appointment__c>) Database.query(apptQueryStr));
			dateRange = csaQuotaMap.keySet();
		}
		Map<Date, Set<DateTime>> avoidTime = avoidNonWorking(curD, endD, curBooking);
		Map<Date, CalDay> calMap = new Map<Date, CalDay>();
		CalDay curDay;
		for (Date d : dateRange) {
			curDay = new CalDay(d, quotaMap.get(d), wsApptMap.get(d), csaQuotaMap.get(d), csaApptMap.get(d), avoidTime.get(d), curBooking);
			calMap.put(d, curDay);
		}
		return calMap;
	}

	private static Boolean checkNeedCSA(Booking curBooking) {
		return (curBooking.csa != null || (!overrideCSAAssignment(curBooking.selectedTypes) && curBooking.csa == null && curBooking.ws.Auto_Assign_CSA__c));
	}

	private static Boolean overrideCSAAssignment(List<String> serviceTypes) {
		Map<String, Service_Type__c> typeMap = Service_Type__c.getAll();
		for (String s : serviceTypes) {
			if (typeMap.containsKey(s) && typeMap.get(s).Override_CSA_Assignment__c) {
				return true;
			}
		}
		return false;
	}

	/**
	 * helper function to categorize the slots based on the start date.
	 * note that we only return the dates where there is a full list of all selected types
	 * if there are any dates with missing types, we skip those
	 * note that if this quota is attached to an appt, we give it back 1 avaialble slot since we r now editing that appt
	 * @param  calQuota [the quota list to organize]
	 * @return          [the organized map of date to service quota list for post-processing]
	 */
	@TestVisible private static Map<Date, List<Service_Quota__c>> catByDate(List<Service_Quota__c> calQuota, Integer expectedSize) {
		Map<Date, List<Service_Quota__c>> quotaMap = new Map<Date, List<Service_Quota__c>>();
		List<Service_Quota__c> curQList;
		for (Service_Quota__c q : calQuota) {
			curQList = quotaMap.get(q.Start_Time__c.date()); // relies on validation rule that start time and end time are the same
			curQList = (curQList == null) ? new List<Service_Quota__c>() : curQList;
			curQList.add(q);
			quotaMap.put(q.Start_Time__c.date(), curQList);
		}
		// we only add it in once we have all the types counted
		Map<Date, List<Service_Quota__c>> finalMap = new Map<Date, List<Service_Quota__c>>();
		for (Date d : quotaMap.keySet()) {
			if (quotaMap.get(d).size() >= expectedSize) { finalMap.put(d, quotaMap.get(d)); }
		}
		return finalMap;
	}

	private static Map<Date, List<Service_Appointment__c>> catByDate(List<Service_Appointment__c> apptList) {
		Map<Date, List<Service_Appointment__c>> rv = new Map<Date, List<Service_Appointment__c>>();
		List<Service_Appointment__c> curList;
		for (Service_Appointment__c sa : apptList) {
			curList = rv.get(sa.Appointment_Date__c.date());
			curList = (curList == null) ? new List<Service_Appointment__c>() : curList;
			curList.add(sa);
			rv.put(sa.Appointment_Date__c.date(), curList);
		}
		return rv;
	}

	@TestVisible private static Map<Date, Map<Id, List<Service_Quota__c>>> catByDateAndCSA(List<Service_Quota__c> calQuota, Integer expectedSize) {
		Map<Date, Map<Id, List<Service_Quota__c>>> empShiftMap = new Map<Date, Map<Id, List<Service_Quota__c>>>();

		List<Service_Quota__c> curList;
		Map<Id, List<Service_Quota__c>> curMap;
		for (Service_Quota__c q : calQuota) {
			curMap = empShiftMap.get(q.Start_Time__c.date());
			curMap = (curMap == null) ? new Map<Id, List<Service_Quota__c>>() : curMap;
			curList = curMap.get(q.Employee_Shift__r.Employee_Master__c);
			curList = (curList == null) ? new List<Service_Quota__c>() : curList;
			curList.add(q);
			curMap.put(q.Employee_Shift__r.Employee_Master__c, curList);
			empShiftMap.put(q.Start_Time__c.date(), curMap);
		}
		Map<Date, Map<Id, List<Service_Quota__c>>> finalMap = new Map<Date, Map<Id, List<Service_Quota__c>>>();
		Map<Id, List<Service_Quota__c>> qMap, qFinalMap;
		List<Service_Quota__c> quotaList;
		for (Date d : empShiftMap.keySet()) {
			qMap = empShiftMap.get(d);
			qFinalMap = new Map<Id, List<Service_Quota__c>>();
			for (Id curE : qMap.keySet()) {
				quotaList = qMap.get(curE);
				if (quotaList.size() >= expectedSize) { qFinalMap.put(curE, quotaList); }
			}
			if (qFinalMap.size() > 0) { finalMap.put(d, qFinalMap); }
		}
		return finalMap;
	}

	private static Map<Date, Map<Id, List<Service_Appointment__c>>> catByDateAndCSA(List<Service_Appointment__c> apptList) {
		Map<Date, Map<Id, List<Service_Appointment__c>>> svcApptMap = new Map<Date, Map<Id, List<Service_Appointment__c>>>();
		List<Service_Appointment__c> curList;
		Map<Id, List<Service_Appointment__c>> curMap;
		for (Service_Appointment__c sa : apptList) {
			curMap = svcApptMap.get(sa.Appointment_Date__c.date());
			curMap = (curMap == null) ? new Map<Id, List<Service_Appointment__c>>() : curMap;
			curList = curMap.get(sa.Employee_Master__c);
			curList = (curList == null) ? new List<Service_Appointment__c>() : curList;
			curList.add(sa);
			curMap.put(sa.Employee_Master__c, curList);
			svcApptMap.put(sa.Appointment_Date__c.date(), curMap);
		}
		return svcApptMap;
	}

	/**
	 * based on the non-working timings in cusetom settings per company and workshop, we then calculate what times to avoid each day
	 * @param  startD [the start date]
	 * @param  endD   [the end date]
	 * @return        [the map of date to the set of datetimes to avoid]
	 */
	private static Map<Date, Set<DateTime>> avoidNonWorking(Date startD, Date endD, Booking curBooking) {
		Map<String, Non_Working__c> nonWorking = Non_Working__c.getAll();
		Set<Time> baseTime = new Set<Time>();
		for (Non_Working__c nW : nonWorking.values()) {
			if (nw.Company__c.contains(curBooking.cmp) && curBooking != null && curBooking.ws != null && nw.Workshop__c != null &&
				nw.Workshop__c.split(',').contains(curBooking.ws.Name)) {
				baseTime.add(Time.newInstance(nW.Hour__c.intValue(), nW.Minute__c.intValue(), 0, 0)); }
		}

		Map<Date, Set<DateTime>> avoidTime = new Map<Date, Set<DateTime>>();
		Set<DateTime> curT;
		while (startD <= endD) {
			curT = new Set<DateTime>();
			for (Time t : baseTime) { curT.add(DateTime.newInstance(startD, t)); }
			avoidTime.put(startD, curT);
			startD = startD.addDays(1);
		}
		return avoidTime;
	}

	public static Employee_Master__c allocateCSA(Booking curBooking, CalDay curCal) {
		if (curCal == null || curCal.csaAvailTimes == null) { throw new ApptException('No CSA Available times'); }
		Set<Id> possCSA = curCal.csaAvailTimes.get(curBooking.selectedTime);
		if (possCSA == null || possCSA.size() <= 0) { throw new ApptException('Empty list of possible CSA for Assignment.'); }
		List<Employee_Master__c> emList = [SELECT Id, Name, Workshop__c, Workshop__r.Name, SFDC_User_Name__c FROM Employee_Master__c WHERE Id IN :possCSA
										   ORDER BY SFDC_User_Name__r.LastName, SFDC_User_Name__r.FirstName, Name];
		Map<Id, Employee_Master__c> userMap = new Map<Id, Employee_Master__c>();
		for (Employee_Master__c em : emList)  {
			System.debug('bengdebug: ' + em.Name);
			userMap.put(em.Id, em);
		}
		List<User_Config__c> userList = [SELECT Id, User__c, Lead_Mark__c, Employee_Master__c FROM User_Config__c WHERE IsActive__c = true
										 AND Department__c = 'Aftersales' AND Lead_Assignment_Opt_Out__c = false
										 AND (User__c IN :userMap.keySet() OR Employee_Master__c IN :userMap.keySet())
										 ORDER BY User__r.LastName, User__r.FirstName, Name];
		Id csaId = CommonMethodsLibrary.assignSC(userList, 1)[0];
		curBooking.isAutoAssign = true;
		return userMap.get(csaId);
	}

	public static List<Workshop__c> filterAutoAssignWS(List<Workshop__c> wsList, List<Employee_Master__c> emList) {
        List<Workshop__c> finalWS = new List<Workshop__c>();
        Set<Id> seenWS = new Set<Id>();
        for (Employee_Master__c e : emList) {
            seenWS.add(e.Workshop__c); 
        }
        for (Workshop__c w : wsList) {
            if (!w.Auto_Assign_CSA__c || seenWS.contains(w.Id)) { 
                finalWS.add(w); }
        }
        system.debug('!!finalWS:--'+finalWS);
        return finalWS;
    }
    
    /////////////////////////////////////////////////////////////////
    // CALDAY OBJECT WHICH SAVES THE RELEVANT CALENDAR INFORMATION //
    /////////////////////////////////////////////////////////////////
    
    // helper to save info to display on the calendar in VF page
    global class CalDay implements Comparable {
        public Boolean avail {get; set;}
        public Date day {get; set;}
        public Set<DateTime> slots {get; set;}
        public Integer remSlots {get; set;}
        
        public List<Service_Quota__c> slotQuota;
        public Map<Id, List<Service_Quota__c>> csaQuota;
        public Map<DateTime, Set<Id>> csaAvailTimes;
        public Map<DateTime, DateTime> slotMap;
        public Map<DateTime, Boolean> validateSlotMap;

		public CalDay(Date day) { this(day, null, null, null, null, null, null); }
		public CalDay(Date day, List<Service_Quota__c> slotQuota, List<Service_Appointment__c> wsAppt, Map<Id, List<Service_Quota__c>> csaQuota,
						Map<Id, List<Service_Appointment__c>> csaApptMap, Set<DateTime> avoidT, Booking curBooking) {
			this.day = day;
			this.slotQuota = slotQuota;
			this.csaQuota = csaQuota;
			Time curT = Time.newInstance(0, 0, 0, 0);
			DateTime curDT = DateTime.newInstance(day, curT);
			if (curBooking != null && slotQuota != null) {
				system.debug('pre checkNeedCSA');
				if (checkNeedCSA(curBooking)) {
					system.debug('checkNeedCSA.calDayCSA');
					calDayCSA(csaApptMap, avoidT, curBooking);
				} else {
					system.debug('non checkNeedCSA.calDayWS');
					calDayWS(wsAppt, avoidT, curBooking);
				}
			}
			this.avail = (day >= Date.today().addDays(1) && slotQuota != null && curBooking != null && remSlots != null && remSlots > 0 && slots != null &&
							slots.size() > 0);
		}

		global Integer compareTo(Object compareTo) {
			CalDay d = (CalDay) compareTo;
			if (this.day == d.day) { return 0; }
			if (this.day == null || (d.day != null && this.day < d.day)) { return -1; }
			return 1;
		}

		//////////////////////
		// CSA CALCULATIONS //
		//////////////////////

		/**
		 * perform the necessary calculation on the available times per csa and then calculate what times are available for that day
		 * @param csaQuota   [map of csa to the list of quotas under him]
		 * @param csaApptMap [map of csa to the list of appts under him]
		 * @param avoidT     [set of times to avoid due to non working hours]
		 * @param curBooking [current booking status]
		 */
		private void calDayCSA(Map<Id, List<Service_Appointment__c>> csaApptMap, Set<DateTime> avoidT, Booking curBooking) {
			Map<Id, Set<DateTime>> avoidMap = csaAvoidUnprod(curBooking, avoidT);
			Set<Id> fullCSA = new Set<Id>();
			// System.debug('csaApptMap:' + csaApptMap);
			if (csaApptMap != null && csaApptMap.size() > 0) {
				fullCSA = csaAvoidMaxAppt(csaApptMap, curBooking);
				Map<Id, Set<DateTime>> apptAvoidMap = csaAvoidActiveAppt(csaApptMap, curBooking);
				Set<DateTime> curSet;
				for (Id emp : apptAvoidMap.keySet()) {
					curSet = avoidMap.get(emp);
					if (curSet == null) { continue; }
					curSet.addAll(apptAvoidMap.get(emp));
					avoidMap.put(emp, curSet);
				}
			}
			calcCSASlots(fullCSA, avoidMap, curBooking);
		}

		/**
		 * using the set of timings to avoid per csa, we then go through the list of service quotas to find all available times
		 * we then save the set of CSAs that are available during that particular time so that we can use this for the allocation later on
		 * @param fullCSA    [set of csa that are already fully booked]
		 * @param avoidMap   [the set of times to avoid due to unproductivity or due to prior appts]
		 * @param curBooking [current booking status]
		 */
		@TestVisible private void calcCSASlots(Set<Id> fullCSA, Map<Id, Set<DateTime>> avoidMap, Booking curBooking) {
			this.csaAvailTimes = new Map<DateTime, Set<Id>>();
			this.remSlots = 0;
			List<Service_Quota__c> curQuota;
			DateTime earliestDT, latestDT;
			Integer apptInterval, minSlots, curSlot;
			Set<DateTime> availTimes;
			Set<Id> availCSA;
			Set<Id> apptQuota = new Set<Id>();
			if (curBooking != null && curBooking.sa != null && curBooking.sa.Id != null && curBooking.csaQuota != null) {
				for (Service_Quota__c apptQ : curBooking.csaQuota) { apptQuota.add(apptQ.Id); }
			}
			for (Id curE : this.csaQuota.keySet()) {
				curQuota = this.csaQuota.get(curE);
				if (fullCSA.contains(curE)) { continue; }

				// we find out the latpossible start and end time for this csa
				earliestDT = curQuota[0].Start_Time__c;
				latestDT = curQuota[0].End_Time__c;
				apptInterval = curQuota[0].Interval_Per_Appt__c.intValue();
				minSlots = curQuota[0].Available_Slots__c.intValue() + (apptQuota.contains(curQuota[0].Id) ? 1 : 0); // if its the same appt we r editing, include in count;
				for (Service_Quota__c q : curQuota) {
					earliestDT = (q.Start_Time__c > earliestDT) ? q.Start_Time__c : earliestDT;
					latestDT = (q.End_Time__c < latestDT) ? q.End_Time__c : latestDT;
					apptInterval = Math.max(q.Interval_Per_Appt__c.intValue(), apptInterval);
					curSlot = q.Available_Slots__c.intValue() + (apptQuota.contains(q.Id) ? 1 : 0); // if its the same appt we r editing, include in count
					minSlots = Math.min(curSlot, minSlots);
				}
				// using this, we get the set of timings that are currently available
				availTimes = calcSlots(earliestDT, latestDT, apptInterval, curBooking.ws.Appointment_Interval__c.intValue(), avoidMap.get(curE));
				// System.debug('availTimes' + availTimes);
				if (availTimes.size() > 0) { this.remSlots += minSlots; }
				for (DateTime dt : availTimes) {
					availCSA = this.csaAvailTimes.get(dt);
					availCSA = (availCSA == null) ? new Set<Id>() : availCSA;
					availCSA.add(curE);
					this.csaAvailTimes.put(dt, availCSA);
				}
			}
			this.slots = this.csaAvailTimes.keySet();
		}

		/**
		 * for each csa, we determine the set of times that he is unavailable due to unproductivity
		 * @param  curBooking [current booking status]
		 * @return            [map of csa to the set of times that is unavailable]
		 */
		@TestVisible private Map<Id, Set<DateTime>> csaAvoidUnprod(Booking curBooking, Set<DateTime> baseAvoid) {
			Map<Id, Set<DateTime>> unprodMap = new Map<Id, Set<DateTime>>();
			Set<DateTime> curSet;
			DateTime unprodTime;
			Service_Quota__c q;
			List<Service_Quota__c> qList;
			for (Id curE : this.csaQuota.keySet()) {
				qList = this.csaQuota.get(curE);
				curSet = baseAvoid.clone();
				if (qList == null || qList.size() <= 0) { continue; }
				q = qList[0];
				if (q.Employee_Shift__c == null) { throw new ApptException('Unable to find Employee Shift for:' + q.Id); }
				if (q.Employee_Shift__r.Unproductivity__c != null && q.Employee_Shift__r.Allow_Work_on_Unprod__c) {
					unprodTime = q.Employee_Shift__r.Unproductive_Start_Time__c;
					while (unprodTime < q.Employee_Shift__r.Unproductive_End_Time__c) {
						curSet.add(unprodTime);
						unprodTime = unprodTime.addMinutes(curBooking.ws.Appointment_Interval__c.intValue());
					}
				}
				unprodMap.put(curE, curSet);
			}
			return unprodMap;
		}

		/**
		 * for all the CSAs available on that day, we first those that have already hit the maximum number of appointments
		 * @param  saMap [map of csa to the respective appointments under them]
		 * @return       [set of csa to avoid]
		 */
		@TestVisible private Set<Id> csaAvoidMaxAppt(Map<Id, List<Service_Appointment__c>> saMap, Booking curBooking) {
			Set<Id> avoidCSAs = new Set<Id>();
			List<Service_Quota__c> csaQuotas;
			Integer maxAppt;
			// we go thru the list of csa and find out which ones already hit the max appointments
			for (Id curKey : saMap.keySet()) {
				csaQuotas = this.csaQuota.get(curKey);
				if (csaQuotas == null || csaQuotas.size() <= 0) { continue; }
				maxAppt = csaQuotas[0].Employee_Shift__r.Maximum_Appointment__c.intValue();
				if (saMap.get(curKey).size() >= maxAppt) { avoidCSAs.add(curKey); }
			}
			System.debug('avoidCSA:' + avoidCSAs);
			return avoidCSAs;
		}

		/**
		 * for the times where the csa has an appointment, we need to block that particular slot from selection
		 * @param  saMap      [map of csa to the respective service appt]
		 * @param  curBooking [current booking status]
		 * @return            [map of csa to the set of datetimes to avoid]
		 */
		@TestVisible private Map<Id, Set<DateTime>> csaAvoidActiveAppt(Map<Id, List<Service_Appointment__c>> saMap, Booking curBooking) {
			Map<Id, Set<DateTime>> avoidTimes = new Map<Id, Set<DateTime>>();
			Set<DateTime> curSet;
			Integer curCnt;
			for (Id curE : saMap.keySet()) {
				curSet = new Set<DateTime>();
				for (Service_Appointment__c sa : saMap.get(curE)) {
					curCnt = 0;
					for (Appointment_Utilization__c aUtil : sa.Appointment_Utilizations__r) {
						curCnt = Math.max(curCnt, aUtil.Service_Quota__r.Interval_Per_Appt__c.intValue());
					}

					for (Integer i = 0; i < curCnt; i++) {
						curSet.add(sa.Appointment_Date__c.addMinutes(i * curBooking.ws.Appointment_Interval__c.intValue()));
					}
				}
				avoidTimes.put(curE, curSet);
			}
			return avoidTimes;
		}

		/////////////////////
		// WS CALCULATIONS //
		/////////////////////

		/**
		 * used to calculate the slots available for each day. only for WS whether its possible to book under a particular WS without an actual CSA
		 * @param slotQuota  [list of quotas under the ws]
		 * @param wsAppt     [list of appt under the workshop currently]
		 * @param avoidT     [set of times to avoid under this ws]
		 * @param curBooking [description]
		 */
		private void calDayWS(List<Service_Appointment__c> wsAppt, Set<DateTime> avoidT, Booking curBooking) {
			if (slotQuota == null || slotQuota.size() <= 0) { return; }
			Set<Id> existing = new Set<Id>();
			if (curBooking.sa != null && curBooking.slotQuota != null) {
				for (Service_Quota__c q : curBooking.slotQuota) { existing.add(q.Id); }
			}
			DateTime earliestDT = slotQuota[0].Start_Time__c;
			DateTime latestDT = slotQuota[0].End_Time__c;
			this.remSlots = slotQuota[0].Available_Slots__c.intValue();
			Integer apptInterval = slotQuota[0].Interval_Per_Appt__c.intValue();
			for (Service_Quota__c q : slotQuota) {
				earliestDT = (q.Start_Time__c > earliestDT) ? q.Start_Time__c : earliestDT;
				latestDT = (q.End_Time__c < latestDT) ? q.End_Time__c : latestDT;
				this.remSlots = Math.min(q.Available_Slots__c.intValue(), this.remSlots);
				apptInterval = Math.max(q.Interval_Per_Appt__c.intValue(), apptInterval);
			}
			avoidT.addAll(wsAvoidTimes(wsAppt, curBooking));
			// if (curBooking != null && curBooking.selectedTypes.contains('Delivery Booking')) {
			// 	this.slots = calcDBSlots(earliestDT, latestDT, apptInterval, curBooking.ws.Appointment_Interval__c.intValue(), avoidT, curBooking);
			// } else {
				this.slots = calcSlots(earliestDT, latestDT, apptInterval, curBooking.ws.Appointment_Interval__c.intValue(), avoidT);
			// }
		}


		/**
		 * we calculate if we reached the maximum number of appt per timeslot
		 * @param  apptList   [list of appointments with that particular type]
		 * @param  curBooking [Current Booking status]
		 * @return            [set of date times that have already reached the max status]
		 */
		@TestVisible private Set<DateTime> wsAvoidTimes(List<Service_Appointment__c> apptList, Booking curBooking) {
			Set<DateTime> avoidTimes = new Set<DateTime>();
			if (apptList == null || apptList.size() <= 0) { return avoidTimes; }
			// we organize the quotas for that day so that we can compare what the max value is
			Map<String, Service_Quota__c> quotaMap = new Map<String, Service_Quota__c>();
			for (Service_Quota__c q : slotQuota) { quotaMap.put(q.Type__c, q); }
			Map<DateTime, Map<String, Integer>> apptCnt = new Map<DateTime, Map<String, Integer>>();
			Map<String, Integer> curCnt;
			Integer duration, typeCnt;
			DateTime curDT;
			List<String> requestType;
			for (Service_Appointment__c sa : apptList) {
				if (sa.Service_Request__c == null) { continue; }
				duration = 0;
				requestType = sa.Service_Request__c.split(';');
				for (Appointment_Utilization__c aUtil : sa.Appointment_Utilizations__r) {
					duration = Math.max(duration, aUtil.Service_Quota__r.Interval_Per_Appt__c.intValue());
				}
				for (Integer i = 0; i < duration; i++) {
					curDT = sa.Appointment_Date__c.addMinutes(i * curBooking.ws.Appointment_Interval__c.intValue());
					curCnt = apptCnt.get(curDT);
					curCnt = (curCnt == null) ? new Map<String, Integer>() : curCnt;
					for (String apptType : requestType) {
						typeCnt = curCnt.get(apptType);
						typeCnt = (typeCnt == null) ? 0 : typeCnt;
						typeCnt++;
						curCnt.put(apptType, typeCnt);
					}
					apptCnt.put(curDT, curCnt);
				}
			}
			for (DateTime dt : apptCnt.keySet()) {
				curCnt = apptCnt.get(dt);
				for (String apptType : quotaMap.keySet()) {
					typeCnt = curCnt.get(apptType);
					if (typeCnt != null && typeCnt >= quotaMap.get(apptType).Max_Appt_Per_Timeslot__c) { avoidTimes.add(dt); }
				}
			}
			return avoidTimes;
		}

		/**
		 * go thru all possible timings within the range to determine what the available times are
		 * @param  startDT    [start time]
		 * @param  endDT      [end time]
		 * @param  avoidTimes [set of times that we know we should avoid]
		 * @param  wsInterval [the interval we should step thru]
		 * @return            [set of available times for booking]
		 */
		@TestVisible private Set<DateTime> calcSlots(DateTime startDT, DateTime endDT, Integer apptInterval, Integer wsInterval, Set<DateTime> avoidTimes) {
			Set<DateTime> curSlots = new Set<DateTime>();
			DateTime curDT = startDT;
			if (curDT == null) { return curSlots; }
			Boolean addSlot;
			while (curDT.addMinutes(apptInterval * wsInterval) <= endDT) {
				addSlot = true;
				for (Integer i = 0; i < apptInterval; i++) {
					addSlot = addSlot && (avoidTimes == null || !avoidTimes.contains(curDT.addMinutes(i * wsInterval)));
				}
				if (addSlot) { curSlots.add(curDT); }
				curDT = curDT.addMinutes(wsInterval);
			}
			return curSlots;
		}
	}
	///////////////////////////////////////
	// METHODS RELATED TO BOOKING OBJECT //
	///////////////////////////////////////
	public class Booking {
		public Company__c co					{ get; set; }
		public String cmp						{ get; set; }
		public String division					{
            get{
                if (this.division == null){
                    return '';
                }
                return this.division;
            }
            set;
        }
		public List<Service_Quota__c> slotQuota	{ get; set; }
		public List<Service_Quota__c> csaQuota	{ get; set; }
		public Vehicle_Ownership__c vo			{ get; set; }
		public Sales_Order__c so				{ get; set; }
		public Vehicle__c veh					{ get; set; }
		public Workshop__c ws					{ get; set; }
		public Employee_Master__c csa			{ get; set; }
		// public Delivery_Room__c deliveryRoom	{ get; set; }
		// public Delivery_Room__c curRoom		{ get; set; }
		// public List<Delivery_Room__c> deliveryRoomList
		// 										{ get; set; }
		// transient public Map<DateTime, Set<Delivery_Room__c>> mapRoomAvailTime
		// 										{ get; set; }
		// transient public Map<Id, Map<Date, CalDay>> mapRoomAvailSlot
		// 										{ get; set; }
		// transient public Map<DateTime, Set<Id>> mapUnavailRoom
		// 										{ get; set; }
		public List<String> selectedTypes		{ get; set; }
		public DateTime selectedTime			{ get; set; }
		public DateTime selectedEndTime			{ get; set; }
		public String contactName				{ get; set; }
		public String contactNumber				{ get; set; }
		public String contactEmail				{ get; set; } // used in the care app where customers can edit if necessary
		public String custCom					{ get; set; }
		public AlternateTransport altTransport	{ get; set; }
		public String source					{ get; set; } // { source = 'VisualForce App'; }

		public Service_Appointment__c sa		{ get; set; }
		public List<Appointment_Utilization__c> util;

		public Boolean isAutoAssign = false;
		private Id slotId;
		public Id cmpId							{ get; set; }

		public Booking() {}
		public Booking(Id apptId) {
			Service_Appointment__c svcAppt = [SELECT Id, Company__c, Company__r.Name, Company__r.Description__c
												, Contact_Name__c, Contact_No__c, Service_Request__c, Employee_Master__c,
												Customer_Comment__c, Employee_Master__r.Name, Workshop__c, Workshop__r.Name, Workshop__r.Description__c,
												Workshop__r.Appointment_Interval__c, Appointment_Date__c, Appointment_Date_End_Time__c, SFDC_Transfer_Flag__c,
												Vehicle_Ownership__c, Vehicle_Ownership__r.Customer__r.Name, Vehicle_Ownership__r.Customer__r.Default_Email__c,
												Vehicle_Ownership__r.Customer__r.Salutation, Vehicle_Ownership__r.Customer__r.Account_Name__c,
												Vehicle_Ownership__r.Customer__r.Mobile_Preferred__pc, Vehicle_Ownership__r.Registration_No__c,
												Vehicle_Ownership__r.Customer__c, Vehicle_Ownership__r.Vehicle__r.Vehicle_Model_Description__c,
												Vehicle_Ownership__r.Vehicle__r.Vehicle_Make__r.Name, Vehicle_Ownership__r.Registration_Date__c
												, Special_Req_for_CSA__c, Workshop__r.Auto_Assign_CSA__c,
												Account_Status__c, Email_Address_Notification__c, Remarks__c,
												// Delivery_Room__c, Delivery_Room__r.Name,
												Alternate_Transport__c, Alternate_Transport_Remarks__c, Created_From__c,
												Source__c, Workshop__r.Short_Address__c,
												Apppointment_Status__c,
												(SELECT Id, Service_Quota__c, Service_Quota__r.Start_Time__c, Service_Quota__r.End_Time__c,
												Service_Quota__r.Type__c,Service_Quota__r.Available_Slots__c, Service_Quota__r.Service_Slot__c,
												Service_Quota__r.Employee_Shift__c FROM Appointment_Utilizations__r)
												FROM Service_Appointment__c WHERE Id = :apptId];// AND Apppointment_Status__c = 'ACTIVE'];
			if (svcAppt != null && svcAppt.Apppointment_Status__c != 'ACTIVE') { throw new ApptException('Service Appointment is not ACTIVE.'); }
			this.co = svcAppt.Company__r;
			this.sa = svcAppt;
			this.vo = svcAppt.Vehicle_Ownership__r;
			// this.selectedTime = datetime.newInstance(svcAppt.Appointment_Date__c.year(),svcAppt.Appointment_Date__c.month(),svcAppt.Appointment_Date__c.day());
			this.selectedTime = svcAppt.Appointment_Date__c;
			this.selectedEndTime = svcAppt.Appointment_Date_End_Time__c;
			this.selectedTypes = (svcAppt.Service_Request__c != null) ? svcAppt.Service_Request__c.split(';') : new List<String>();
			this.csa = (svcAppt.Employee_Master__c != null) ? svcAppt.Employee_Master__r : null;
			this.ws = svcAppt.Workshop__r;
			// this.deliveryRoom = svcAppt.Delivery_Room__r;
			this.util = svcAppt.Appointment_Utilizations__r;
			this.slotQuota = new List<Service_Quota__c>();
			this.isAutoAssign = (svcAppt.Employee_Master__c != null && !svcAppt.Special_Req_for_CSA__c && svcAppt.Workshop__r.Auto_Assign_CSA__c);
			this.contactName = svcAppt.Contact_Name__c;
			this.contactNumber = svcAppt.Contact_No__c;
			this.contactEmail = svcAppt.Email_Address_Notification__c;
			this.altTransport = new AlternateTransport();
			this.altTransport.transportType = svcAppt.Alternate_Transport__c;
			this.altTransport.remarks = svcAppt.Alternate_Transport_Remarks__c;
			if (this.csa != null) { this.csaQuota = new List<Service_Quota__c>(); }
			for (Appointment_Utilization__c util : svcAppt.Appointment_Utilizations__r) {
				if (util.Service_Quota__r.Service_Slot__c != null) { this.slotQuota.add(util.Service_Quota__r); }
				if (this.csaQuota != null && util.Service_Quota__r.Employee_Shift__c != null) { this.csaQuota.add(util.Service_Quota__r);}
			}
			this.cmp = svcAppt.Company__r.Name;
			this.cmpId = svcAppt.Company__c;
			this.source = svcAppt.Created_From__c;
		}

		// use process builder to populate the account and the vehicle details
		// get company from the workshop
		// verify that ws and emp is the same company
		public Service_Appointment__c makeBooking(Boolean addToDB) {
			if (vo == null) { throw new ApptException('No VO populated. Please contact administrator'); }
			// if (sa != null && sa.Created_in_GDMS__c == 'YES-RO' && sa.Appointment_Date__c.date() != selectedTime.date()) {
			// 	cancelAppt(sa, 'Ammendments on GDMS Synced Appt. Recreated another Service Appointment');
			// 	util = null;
			// 	sa = null;
			// }
			setAndvalidate();
			if (sa == null) {
				sa = new Service_Appointment__c();
				Vehicle_Ownership__c voDetails = [SELECT Id, Customer__c, Vehicle__c FROM Vehicle_Ownership__c WHERE Id = :this.vo.Id];
				sa.Account__c = voDetails.Customer__c;
				sa.Chassis__c = voDetails.Vehicle__c;
				sa.Vehicle_Ownership__c = voDetails.Id;
				sa.Company__c = this.cmpId;
				sa.Appt_Type__c = 'Service Appointment';
				sa.Created_From__c = this.source;
			}
			makeBookingHelper(sa);
			if (addToDB) {
				sa.System_Control__c = true;
				upsert sa;
			}
			return sa;
		}

		// public Service_Appointment__c makeBooking(Sales_Order__c salesOrder, Boolean addToDB) {
		// 	if (salesOrder == null) { throw new ApptException('No Sales Order provided.'); }
		// 	setAndvalidate();
		// 	if (sa == null) {
		// 		sa = new Service_Appointment__c();
		// 		sa.Account__c = salesOrder.Opportunity__r.AccountId;
		// 		sa.Chassis__c = salesOrder.Vehicle__c;
		// 		sa.Company__c = this.cmpId;
		// 		sa.Vehicle_Stock_Master__c = salesOrder.Vehicle_Stock_Master__c;
		// 		sa.Sales_Order_BMW__c = salesOrder.Id;
		// 		sa.Appt_Type__c = 'PDI Kickstart';
		// 	}
		// 	makeBookingHelper(sa);
		// 	sa.Est_Completion_Date__c = PDIBooking_Ext.calcEstCompletionDate(sa.Appointment_Date__c.date());
		// 	sa.Send_SMS__c = false;
		// 	sa.Reason_for_Not_Sending_SMS__c = 'Internal PDI Appointment';
		// 	sa.Send_Confirmation_Email__c = false;
		// 	if (addToDB) {
		// 		sa.System_Control__c = true;
		// 		upsert sa;
		// 	}
		// 	return sa;
		// }

		// public Service_Appointment__c makeBooking(Vehicle_Stock_Master__c veh, Boolean addToDB) {
		// 	if (veh == null) { throw new ApptException('No Vehicle information provided.'); }
		// 	setAndvalidate();
		// 	if (sa == null) {
		// 		sa = new Service_Appointment__c();
		// 		sa.Chassis__c = veh.Chassis__c;
		// 		sa.Vehicle_Stock_Master__c = veh.Id;
		// 		sa.Company__c = this.cmpId;
		// 		sa.Appt_Type__c = 'PDI Kickstart';
		// 	}
		// 	makeBookingHelper(sa);
		// 	sa.Est_Completion_Date__c = BusinessHours.add(PDIBooking_Ext.BH.Id, sa.Appointment_Date__c.date(), PDIBooking_Ext.COMPLETION_OFFSET).date();
		// 	sa.Send_SMS__c = false;
		// 	sa.Reason_for_Not_Sending_SMS__c = 'Internal PDI Appointment';
		// 	sa.Send_Confirmation_Email__c = false;
		// 	if (addToDB) {
		// 		sa.System_Control__c = true;
		// 		upsert sa;
		// 	}
		// 	return sa;
		// }

		public Service_Appointment__c makeBooking(Vehicle__c veh, Boolean addToDB) {
			if (veh == null) { throw new ApptException('No Vehicle information provided.'); }
			setAndvalidate();
			if (sa == null) {
				sa = new Service_Appointment__c();
				sa.Chassis__c = veh.Id;
				sa.Company__c = this.cmpId;
				sa.Appt_Type__c = 'Internal Appointment';
			}
			makeBookingHelper(sa);
			sa.Send_SMS__c = false;
			sa.Reason_for_Not_Sending_SMS__c = 'Internal Appointment';
			sa.Send_Confirmation_Email__c = false;
			if (addToDB) {
				sa.System_Control__c = true;
				upsert sa;
			}
			return sa;
		}

		public List<Appointment_Utilization__c> genUtil(Boolean addToDB) {
			List<Appointment_Utilization__c> utilList = new List<Appointment_Utilization__c>();
			for (Service_Quota__c q : slotQuota) {
				utilList.add(new Appointment_Utilization__c(Service_Appointment__c = sa.Id, Service_Quota__c = q.Id));
			}
			if (csaQuota != null) {
				for (Service_Quota__c q : csaQuota) {
					utilList.add(new Appointment_Utilization__c(Service_Appointment__c = sa.Id, Service_Quota__c = q.Id));
				}
			}
			if (addToDB) { insert utilList; }
			return utilList;
		}

		public void checkWS(List<Workshop__c> wsList) {
			if (this.ws == null) { return; }
			Set<Id> checkWS = new Set<Id>();
			for (Workshop__c w : wsList) { checkWS.add(w.Id); }
			if (!checkWS.contains(this.ws.Id)) { this.ws = null; }
		}

		public void checkCSA(List<Employee_Master__c> emList) {
			if (this.csa == null) { return; }
			Set<Id> checkCSA = new Set<Id>();
			for (Employee_Master__c em : emList) { checkCSA.add(em.Id); }
			if (!checkCSA.contains(this.csa.Id)) { this.csa = null; }
		}

		private void setAndvalidate() {
			if (slotQuota == null) { throw new ApptException('No Slots populated. Please contact administrator.'); }
			if (ws.Auto_Assign_CSA__c && csa == null) { }
			Set<Id> allQuota = new Set<Id>();
			for (Service_Quota__c q : slotQuota) { allQuota.add(q.Id); }
			if (csaQuota != null) {
				for (Service_Quota__c q : csaQuota) { allQuota.add(q.Id); }
			}
			Map<Id, Service_Quota__c> checkQuota = new Map<Id, Service_Quota__c>([SELECT Id, Service_Slot__r.Company__c, Service_Slot__c, Employee_Shift__c
																				FROM Service_Quota__c WHERE Id = :allQuota]);
			Service_Quota__c initQuota = checkQuota.get(slotQuota[0].Id);
			Id slot = initQuota.Service_Slot__c;
			if (slot == null) { throw new ApptException('No Service Slot for Service Quota (' + slotQuota[0].Id + ')'); }
			for (Service_Quota__c q : slotQuota) {
				if (slot != checkQuota.get(q.Id).Service_Slot__c) { throw new ApptException('Multiple Service slots found for selected service quota.'); }
			}
			this.slotId = slot;
			this.cmpId = initQuota.Service_Slot__r.Company__c;

			if (csaQuota != null && csaQuota.size() > 0) {
				Id csa = checkQuota.get(csaQuota[0].Id).Employee_Shift__c;
				if (csa == null) { throw new ApptException('No Employee_Shift__c for Service Quota (' + csaQuota[0].Id + ')'); }
				for (Service_Quota__c q : csaQuota) {
					if (csa != checkQuota.get(q.Id).Employee_Shift__c) {
						throw new ApptException('Multiple Employee Shifts found for selected service quota.');
					}
				}
			}
		}

		private void makeBookingHelper(Service_Appointment__c sa) {
			sa.Service_Request__c = String.join(this.selectedTypes, ';');
			sa.Appointment_Date__c = this.selectedTime;
			sa.Appointment_Time__c = this.selectedTime.format('HH:mm');
			sa.Appointment_Year__c = this.selectedTime.year();
			sa.Workshop__c = this.ws.Id;
			sa.Contact_Name__c = this.contactName;
			sa.Contact_No__c = this.contactNumber;
			sa.Email_Address_Notification__c = this.contactEmail;
			sa.Customer_Comment__c = this.custCom;
			if (this.altTransport != null) {
				sa.Alternate_Transport__c = this.altTransport.transportType;
				sa.Alternate_Transport_Remarks__c = (String.isBlank(this.altTransport.remarks)) ? '' : this.altTransport.remarks;
			}
			if (this.csa != null) {
				sa.Employee_Master__c = this.csa.Id;
				sa.Special_Req_for_CSA__c = !this.isAutoAssign;
				sa.Auto_Assigned_CSA__c = (this.isAutoAssign) ? this.csa.Name : '';
			}
			if (this.csa == null && this.sa.Id != null) {
				sa.Employee_Master__c = null;
				sa.Special_Req_for_CSA__c = false;
				sa.Auto_Assigned_CSA__c = '';
			}
		}

		private void cancelAppt(Service_Appointment__c sa, String cancelRemarks) {
			sa.Cancel_Appointment__c = true;
			sa.Apppointment_Status__c = 'CANCELLED';
			sa.Remarks__c = cancelRemarks;
			update sa;
		}
	}

	global virtual class APIResp {
		public String err;
		public APIResp(Exception e) { this.err = e.getMessage() + '|' + e.getStackTraceString(); }
		public APIResp() { this.err = null; }
	}

	global class APIBooking {
		global String cmp;
		global String division;
		global String wsId;
		global String vo;
		global String csaId;
		global String csaName;
		global List<String> selectedTypes;
		global DateTime selectedTime;
		global String apptId;
		global Boolean isAutoAssign;
		global String regNum;
		global String contactName;
		global String contactNumber;
		global String contactEmail;
		global String custCom;
		global String qrUrl;
		global AlternateTransport altTransport;
		global String source;

		public APIBooking() {}
		public APIBooking(Id apptId) {
			this([SELECT Id, Vehicle_Ownership__c, Vehicle_Ownership__r.Customer__c, Vehicle_Ownership__r.Registration_No__c, Created_From__c,
					Vehicle_Ownership__r.Vehicle__r.Name, Workshop__c, Workshop__r.Name, Employee_Master__c, Employee_Master__r.Name, Appointment_Date__c,
					Service_Request__c,  Special_Req_for_CSA__c, Workshop__r.Auto_Assign_CSA__c, Company__r.Name,
					Contact_Name__c, Contact_No__c, Email_Address_Notification__c, Customer_Comment__c, Account__c,
					Alternate_Transport__c, Alternate_Transport_Remarks__c FROM Service_Appointment__c WHERE Id = :apptId]);
		}

		public APIBooking(Service_Appointment__c sa) {
			this.apptId = sa.Id;
			this.vo = sa.Vehicle_Ownership__c;
			this.wsId = sa.Workshop__c;
			this.csaId = sa.Employee_Master__c;
			this.csaName = sa.Employee_Master__r.Name;
			this.selectedTime = sa.Appointment_Date__c;
			this.selectedTypes = (sa.Service_Request__c != null) ? sa.Service_Request__c.split(';') : new List<String>();
			this.regNum = sa.Vehicle_Ownership__r.Registration_No__c;
			this.isAutoAssign = (sa.Employee_Master__c != null && !sa.Special_Req_for_CSA__c && sa.Workshop__r.Auto_Assign_CSA__c);
			this.cmp = sa.Company__r.Name;
			// this.division = (sa.Company__r.Name == '02') ? '' : WS_DIV.get(sa.Workshop__r.Name);
			this.contactName = sa.Contact_Name__c;
			this.contactNumber = sa.Contact_No__c;
			this.contactEmail = sa.Email_Address_Notification__c;
			this.custCom = sa.Customer_Comment__c;
			List<String> qrStr = ServiceApptBooking.getApptQR(new List<Service_Appointment__c> { sa });
			this.qrUrl = (qrStr.size() > 0) ? qrStr[0] : null;
			this.altTransport = new AlternateTransport();
			this.altTransport.transportType = sa.Alternate_Transport__c;
			this.altTransport.remarks = (String.isBlank(sa.Alternate_Transport_Remarks__c)) ? '' : sa.Alternate_Transport_Remarks__c;
			this.source = sa.Created_From__c;
		}

		public Booking toBooking() {
			Booking rv = new Booking();
			rv.cmp = this.cmp;
			rv.division = (this.division != null) ? this.division : '';
			rv.vo = (this.vo != null && this.vo != '') ? [SELECT Id, Customer__r.Name, Customer__r.Salutation, Customer__r.Account_Name__c,
														  Customer__r.Mobile_Preferred__pc, Customer__r.IsPersonAccount, Registration_No__c, Customer__c,
														  Vehicle__r.Vehicle_Model_Description__c, Vehicle__r.Vehicle_Make__r.Name, Customer__r.LastName
														  FROM Vehicle_Ownership__c WHERE Id = :this.vo AND Status__c = 'Active'] : null;
			rv.ws = (this.wsId != null && this.wsId != '') ?
					[SELECT Id, Name, Description__c, Appointment_Interval__c, Auto_Assign_CSA__c FROM Workshop__c WHERE Id = :wsId] : null;
			rv.csa = (this.csaId != null && this.csaId != '') ? [SELECT Id, Name, Workshop__c, Workshop__r.Name, SFDC_User_Name__c FROM Employee_Master__c
																 WHERE Id = :this.csaId] : null;
			rv.selectedTypes = this.selectedTypes;
			rv.selectedTime = this.selectedTime;
			rv.contactName = this.contactName;
			rv.contactNumber = this.contactNumber;
			rv.contactEmail = this.contactEmail;
			rv.custCom = this.custCom;
			if (this.apptId != null && this.apptId != '') {
				rv.sa = [SELECT Id, Company__r.Name, Contact_Name__c, Contact_No__c, Service_Request__c, Special_Req_for_CSA__c, Workshop__r.Auto_Assign_CSA__c,
						 Appointment_Date__c, SFDC_Transfer_Flag__c, Alternate_Transport__c, Alternate_Transport_Remarks__c, (SELECT Id, Service_Quota__c,
						 Service_Quota__r.Start_Time__c, Service_Quota__r.End_Time__c, Service_Quota__r.Type__c, Service_Quota__r.Available_Slots__c,
						 Service_Quota__r.Service_Slot__c, Service_Quota__r.Employee_Shift__c FROM Appointment_Utilizations__r) FROM Service_Appointment__c
						 WHERE Id = :this.apptId];
				rv.util = rv.sa.Appointment_Utilizations__r;
				rv.csaQuota = new List<Service_Quota__c>();
				rv.slotQuota = new List<Service_Quota__c>();
				for (Appointment_Utilization__c u : rv.util) {
					if (u.Service_Quota__r.Service_Slot__c != null) { rv.slotQuota.add(u.Service_Quota__r); }
					if (u.Service_Quota__r.Employee_Shift__c != null) { rv.csaQuota.add(u.Service_Quota__r); }
				}
			}
			rv.altTransport = this.altTransport;
			rv.source = this.source;
			return rv;
		}
	}

	global class AlternateTransport {
		public String transportType;
		public String remarks;
	}

	global class CareQR {
		String apptId;
		String custId;
		String vehReg;
		String chassis;
		String contactName;
		String contactNo;
		String cmp;
		public CareQR(Account a, String cmp) {
			this.custId = a.Id;
			this.contactName = a.LastName;
			this.contactNo = a.Mobile_Preferred__pc;
			this.cmp = cmp;
		}

		public CareQR(Service_Appointment__c sa) {
			this.apptId = sa.Id;
			this.custId = sa.Vehicle_Ownership__r.Customer__c;
			this.vehReg = sa.Vehicle_Ownership__r.Registration_No__c;
			this.chassis = sa.Vehicle_Ownership__r.Vehicle__r.Name;

			this.contactName = sa.Contact_Name__c;
			this.contactNo = sa.Contact_No__c;
			this.cmp = sa.Company__r.Name;
		}

		public CareQR(Vehicle_Ownership__c vo, String cmp) {
			this.custId = vo.Customer__c;
			this.vehReg = vo.Registration_No__c;
			this.chassis = vo.Vehicle__r.Name;
			this.cmp = cmp;
		}
	}
}