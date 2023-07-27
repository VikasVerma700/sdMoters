@RestResource(urlMapping='/whip/v1/appointment')
global without sharing class WhipAppointment {
	public class ApptException extends Exception {}
	public static string cmp = '028';

	@HttpGet
	global static void getAppointment() {
		RestResponse res = RestContext.response;
		try {
			RestRequest req = RestContext.request;
			string reqType = req.params.get('type');
			string reqYearF = req.params.get('yearf');
			string reqYearT = req.params.get('yeart');
			string reqMonthF = req.params.get('monthf');
			string reqMonthT = req.params.get('montht');
			string reqWsCode = req.params.get('workshop');
			string reqCsaId = req.params.get('csaId');

			if (String.isBlank(reqType)) { throw new ApptException('Invalid service type provided.'); }
			if (String.isBlank(reqYearF) || String.isBlank(reqYearT)) { throw new ApptException('Invalid year from/to provided.'); }
			if (String.isBlank(reqMonthF) || String.isBlank(reqMonthT)) { throw new ApptException('Invalid month from/to provided.'); }
			// if (reqWsCode == null) { throw new ApptException('Invalid workshop provided.'); }

			integer yearF = Integer.valueOf(reqYearF);
			integer yearT = Integer.valueOf(reqYearT);
			integer monthF = Integer.valueOf(reqMonthF);
			integer monthT = Integer.valueOf(reqMonthT);
			Date dFrom = Date.newInstance(yearF, monthF, 1);
			Date dTo = Date.newInstance(yearT, monthT, 1).addMonths(1).addDays(-1);

			/** Get Workshop__c.Id if specified */
			Service_Slot__c[] ss;
			if (String.isBlank(reqWsCode)) {
				ss = [
					SELECT Workshop__r.Id, Workshop__r.Name
					FROM Service_Slot__c
					WHERE Workshop__r.IsActive__c = True
					AND Workshop__r.AllowInWhip__c = True
				];
				if (ss.size() == 0) { throw new ApptException('No workshop defined.'); }
			}
			else {
				ss = [
					SELECT Workshop__r.Id, Workshop__r.Name
					FROM Service_Slot__c
					WHERE Workshop__r.IsActive__c = True
					AND Workshop__r.AllowInWhip__c = True
					AND Workshop__r.Name = :reqWsCode
				];
				if (ss.size() == 0) { throw new ApptException(string.format('Workshop: {0} is not found.', new string[] { reqWsCode })); }
			}
			
			Set<Id> workshopIds = new Set<Id>();
			for (Service_Slot__c s :ss) { workshopIds.add(s.Workshop__r.Id); }
			Workshop__c[] ws = [SELECT Id, Name, AllowInWhip__c FROM Workshop__c WHERE Id IN :workshopIds ORDER BY Name];

			ApptGetResp rv = new ApptGetResp();
			/** Booked slots. */
			Service_Appointment__c[] sas = [
				Select
					Id, Name, Appointment_Date_Only__c, Appointment_Date__c
					, Company__r.Name, Chassis__r.Name, Registration_No__c
					, Workshop__r.Name, Contact_Name__c, Contact_No__c
					, Apppointment_Status__c
				From Service_Appointment__c
				Where Workshop__r.Id In :workshopIds
					And Service_Request__c = :reqType
					And Appointment_Date_Only__c >= :dFrom
					And Appointment_Date_Only__c <= :dTo
				Order By Workshop__r.Name, Appointment_Date__c
			];
			Map<string, Map<Date, List<ApptMade>>> mapSvcAppt = new Map<string, Map<Date, List<ApptMade>>>();
			for (Service_Appointment__c sa :sas) {
				if (mapSvcAppt.containsKey(sa.Workshop__r.Name)) {
					Map<Date, List<ApptMade>> mapTmp = mapSvcAppt.get(sa.Workshop__r.Name);
					if (mapTmp.containsKey(sa.Appointment_Date_Only__c)) {
						((List<ApptMade>)mapTmp.get(sa.Appointment_Date_Only__c)).add(new ApptMade(sa));
					}
					else {
						List<ApptMade> amrs = new List<ApptMade>{ new ApptMade(sa) };
						mapTmp.put(sa.Appointment_Date_Only__c, amrs);
					}
				}
				else {
					List<ApptMade> amrs = new List<ApptMade>{ new ApptMade(sa) };
					Map<Date, List<ApptMade>> mapTmp = new Map<Date, List<ApptMade>>();
					mapTmp.put(sa.Appointment_Date_Only__c, amrs);
					mapSvcAppt.put(sa.Workshop__r.Name, mapTmp);
				}
			}

			/** Compose POST /care/service/calendar request parameter. */
			CareCalendar.CalendarReq calReq = new CareCalendar.CalendarReq();
			calReq.startDate = dFrom;
			calReq.endDate = dTo;
			
			// List<ApptGet> listResp = new List<ApptGet>();
			for (Workshop__c w :ws) {
				ApptGet agr = new ApptGet();
				agr.workshop = w.Name;
				agr.workshopId = w.Id;

				ServiceApptBooking.APIBooking booking = new ServiceApptBooking.APIBooking();
				booking.cmp = WhipAppointment.cmp;
				booking.wsId = w.Id;
				booking.csaId = reqCsaId;
				booking.selectedTypes = new string[] { reqType };

				calReq.booking = booking;
				ServiceApptBooking.Booking curBooking = booking.toBooking();
				Map<Date, ServiceApptBooking.CalDay> calMap = ServiceApptBooking.populateCalDayMap(dFrom, dTo, curBooking);
	
				/** Populate slots */
				Map<Date, CareCalendar.Cal> cal = new Map<Date, CareCalendar.Cal>();
				for (ServiceApptBooking.CalDay cur : calMap.values()) { cal.put(cur.day, new CareCalendar.Cal(cur, curBooking)); }
				agr.slots = cal.values();

				/** Populate books */
				agr.books = new List<ApptMade>();
				if (mapSvcAppt.containsKey(agr.workshop)) {
					Map<Date, List<ApptMade>> mapApptMade = mapSvcAppt.get(agr.workshop);
					for (List<ApptMade> ams :mapApptMade.values()) {
						agr.books.addAll(ams);
					}
				}
				if (agr.slots.size() > 0 || agr.books.size() > 0) { rv.apptList.add(agr); }
			}

			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(rv));
		}
		catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new ApptGetResp(e)));
			res.statusCode = 400;
		}
	}
	global class ApptGetResp extends ServiceApptBooking.ApiResp {
		public ApptGet[] apptList;
		public ApptGetResp() { apptList = new List<ApptGet>(); }
		public ApptGetResp(Exception e) { super(e); }
	}
	global class ApptGet {
		global string workshop;
		global Id workshopId;
		global List<CareCalendar.Cal> slots;
		global List<ApptMade> books;
	}
	global class ApptMade {
		global Id appointmentId;
		global string customerName;
		global string customerPhone;
		global string registrationNumber;
		global Datetime slot;
		global string status;
		public ApptMade(Service_Appointment__c sa) {
			this.appointmentId = sa.Id;
			this.customerName = sa.Contact_Name__c;
			this.customerPhone = sa.Contact_No__c;
			this.registrationNumber = sa.Registration_No__c;
			this.slot = sa.Appointment_Date__c;
			this.status = sa.Apppointment_Status__c;
		}
	}

	@HttpPost
	global static void reserveAppointment() {
		RestResponse res = RestContext.response;
		try {
			RestRequest req = RestContext.request;
			ApptPostReq reqAppt = (ApptPostReq) JSON.deserialize(req.requestBody.toString(), ApptPostReq.class);
			if (reqAppt.slotDate == null) { throw new ApptException('Appointment Slot data is missing'); }
			if (String.isBlank(reqAppt.type)) { throw new ApptException('Appointment Type data is missing'); }
			if (reqAppt.vehicleOwner == null) { throw new ApptException('Vehicle Ownernership data is missing'); }
			if (reqAppt.workshopId == null) { throw new ApptException('Workshop Id data is missing'); }
			if (String.isBlank(reqAppt.fullName)) { throw new ApptException('Customer\'s full name data is missing'); }
			if (String.isBlank(reqAppt.phoneNumber)) { throw new ApptException('Customer\'s phone number data is missing'); }

			/** Compose POST /care/service/booking request parameter. */
			ServiceApptBooking.APIBooking booking = new ServiceApptBooking.APIBooking();
			booking.cmp = cmp;
			booking.selectedTypes = new string[] { reqAppt.type };
			booking.selectedTime = reqAppt.slotDate;
			booking.vo = reqAppt.vehicleOwner;
			booking.wsId = reqAppt.workshopId;
			booking.csaId = reqAppt.csaId;
			booking.contactName = reqAppt.fullName;
			booking.contactNumber = reqAppt.phoneNumber;
			booking.contactEmail = reqAppt.emailAddress;

			ServiceApptBooking.Booking curBooking = booking.toBooking();
			curBooking.source = 'Whip App';
			
			/** Execute CareBooking.book() */
			// If inserting Service Appointment
			if (curBooking.sa == null) {
				if (curBooking.vo.Customer__r.IsPersonAccount) {
					curBooking.ContactName = curBooking.vo.Customer__r.Salutation + ' ' + curBooking.vo.Customer__r.Account_Name__c;
				} else {
					curBooking.ContactName = curBooking.vo.Customer__r.Name;
				}
			}

			if (curBooking.selectedTime == null) { throw new ServiceApptBooking.ApptException('No date time provided.'); }
			Date searchD = curBooking.selectedTime.date();
			Map<Date, ServiceApptBooking.CalDay> calMap = ServiceApptBooking.populateCalDayMap(curBooking.selectedTime.date(), curBooking.selectedTime.date(),
																							   curBooking);

			ServiceApptBooking.CalDay curCal = calMap.get(searchD);
			// System.debug('curCal:' + curCal);
			if (curCal == null) { throw new ServiceApptBooking.ApptException('Unable to find available slots for given date time.'); }
			if (curBooking.util != null) { delete curBooking.util; } // we remove the existing utilizations
			curBooking.slotQuota = curCal.slotQuota;
			if (curBooking.csa == null && curBooking.ws.Auto_Assign_CSA__c) { curBooking.csa = ServiceApptBooking.allocateCSA(curBooking, curCal); }

			if (curBooking.csa != null) {
				curBooking.csaQuota = curCal.csaQuota.get(curBooking.csa.Id);
				if (curBooking.csaQuota == null) { throw new ServiceApptBooking.ApptException('No CSA Quota to retrieve from map.'); }
			} else {
				curBooking.csaQuota = new List<Service_Quota__c>();
			}

			curBooking.makeBooking(true);
			curBooking.genUtil(true);

			if (curBooking.sa != null) {
				/** Similar to ServiceAppointmentBookingPage_Ctrl.createApptHelper(descStr, emailNoti)
					Manually include Customer_Comment__c.
				*/
				// if (string.isBlank(reqAppt.remarks)) { reqAppt.remarks = 'Automated pre-filled remarks.'; }
				curBooking.sa.Customer_Comment__c = reqAppt.remarks == null ? '': reqAppt.remarks;
				update curBooking.sa;
			}
			ApptPostResp rv = new ApptPostResp();
			rv.appointment = new ServiceApptBooking.APIBooking(curBooking.sa.Id);
			
			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(rv));
		}
		catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new ApptPostResp(e)));
			res.statusCode = 400;
		}
	}
	global class ApptPostResp extends ServiceApptBooking.APIResp {
		public ServiceApptBooking.APIBooking appointment;
		public ApptPostResp() { appointment = new ServiceApptBooking.APIBooking(); }
		public ApptPostResp(Exception e) { super(e); }
	}
	global class ApptPostReq {
		global Id workshopId;
		global Id csaId;
		global DateTime slotDate;
		global string type;
		global string vehicleOwner;
		global string fullName;
		global string phoneNumber;
		global string emailAddress;
		global string remarks;
	}

	@HttpDelete
	global static void releaseAppointment() {
		RestResponse res = RestContext.response;
		SavePoint sp = Database.setSavePoint();
		try {
			RestRequest req = RestContext.request;
			string appointmentId = req.params.get('appointmentId');
			if (appointmentId == null) { throw new ApptException('AppointmentId not specified.'); }

			List<Service_Appointment__c> sa = [
				SELECT
					Id, Cancel_Appointment__c
				FROM Service_Appointment__c
				WHERE Id = :appointmentId 
			];
			if (sa.size() <= 0) { throw new ServiceApptBooking.ApptException('Invalid Appointment ID.'); }
			sa[0].Cancel_Appointment__c = true;
			sa[0].Apppointment_Status__c = 'CANCELLED';
			sa[0].Remarks__c = 'Cancelled in Whip';
			update sa;

			res.statusCode = 200;
		}
		catch (Exception e) {
			Database.rollback(sp);
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new ApptDeleEx(e)));
			res.statusCode = 400;
		}
	}
	global class ApptDeleReq {
		global string appointmentId;
	}
	global class ApptDeleEx {
		public string err;
		public ApptDeleEx(Exception e) { this.err = e.getMessage() + '|' + e.getStackTraceString(); }
		public ApptDeleEx() { this.err = null; }
	}

	@HttpPatch
	global static void updateAppointmentStatus() {
		RestResponse res = RestContext.response;
		try {
			RestRequest req = RestContext.request;
			if (req.requestBody == null || req.requestBody.size() == 0) { 
				throw new ApptNotFoundException(
					'Request body is empty or missing.' +
					'Request: {' +
					'appointmentId: <string>' +
					// 'fromStatus: <string>' +
					'toStatus: <string>' +
					'}'
				);
			}
			ApptUpdaReq reqAppt = (ApptUpdaReq) JSON.deserialize(req.requestBody.toString(), ApptUpdaReq.class);
			if (String.isBlank(reqAppt.appointmentId)) { throw new ApptException('Appointment Id is missing'); }
			// if (String.isBlank(reqAppt.fromStatus)) { throw new ApptException('Appointment From status is missing'); }
			if (String.isBlank(reqAppt.toStatus)) { throw new ApptException('Appointment To status is missing'); }

			/** Query Service_Appointment__c for Id */
			Service_Appointment__c[] sas = [
				SELECT 
					Id, Apppointment_Status__c
				FROM Service_Appointment__c
				WHERE Id = :reqAppt.appointmentId
			];
			if (sas.size() == 0) { throw new ApptNotFoundException(String.format('Appointment Id: {0} not found.', new string[] { reqAppt.appointmentId } )); }
			Service_Appointment__c sa = sas[0];
			// if (!sa.Apppointment_Status__c.equalsIgnoreCase(reqAppt.fromStatus)) {
			// 	throw new ApptNotFoundException(String.format('Appointment Id: {0} with Status: \'\'{1}\'\' not found.', new string[] { reqAppt.appointmentId, reqAppt.fromStatus }));
			// }

			string[] validStatuses = new List<string>{ 'ACTIVE', 'CONVERTED TO RO', 'CANCELLED', 'NO SHOW', 'NOT TRANSFERRED', 'ARRIVED' };
			if (!validStatuses.contains(reqAppt.toStatus)) {
				throw new ApptException(String.format('Status \'\'{0}\'\' is not accepted. Valid status: {1}', new string[] { reqAppt.toStatus, String.join(validStatuses, ', ') }));
			}
			/** Update Apppointment_Status__c to toStatus */
			sa.Apppointment_Status__c = reqAppt.toStatus;
			update sas;

			/** Success if no exception. */
			ApptUpdaResp resAppt = new ApptUpdaResp();
			resAppt.appointment = new Appointment(sa, reqAppt.toStatus);
			res.responseBody = Blob.valueOf(JSON.serialize(resAppt));
			res.statusCode = 200;
		}
		// catch (ApptException e) {
		// 	System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
		// 	res.responseBody = Blob.valueOf(JSON.serialize(new ApptUpdaResp(e)));
		// 	res.statusCode = 204;
		// }
		catch (ApptNotFoundException e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new ApptUpdaResp(e)));
			res.statusCode = 404;
		}
		catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new ApptUpdaResp(e)));
			res.statusCode = 400;
		}
	}
	global class ApptUpdaReq {
		public string appointmentId;
		public string fromStatus;
		public string toStatus;
	}
	global class ApptUpdaResp extends ServiceApptBooking.APIResp {
		global Appointment appointment;
		public ApptUpdaResp() { appointment = new Appointment(); }
		public ApptUpdaResp(Exception e) { super(e); }
	}
	global class Appointment {
		global string appointmentId;
		global string newStatus;
		global string status;
		public Appointment() {}
		public Appointment(Service_Appointment__c appt, string toStatus) { Parse(appt, toStatus); }
		public void Parse(Service_Appointment__c appt, string toStatus) {
			this.appointmentId = appt.Id;
			this.newStatus = appt.Apppointment_Status__c;
			this.status = toStatus.equalsIgnoreCase(appt.Apppointment_Status__c) ? 'success' : 'fail';
		}
	}
	public class ApptNotFoundException extends Exception {}
}