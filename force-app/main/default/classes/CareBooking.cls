@RestResource(urlMapping='/care/service/booking')
global without sharing class CareBooking {
	@HttpPost
	global static void book() {
		RestResponse res = RestContext.response;
		SavePoint sp = Database.setSavePoint();
		try {
			RestRequest req = RestContext.request;
			System.debug(req.requestBody.toString());
			Object rawReq = JSON.deserialize(req.requestBody.toString(), ServiceApptBooking.APIBooking.class);
			ServiceApptBooking.APIBooking bookingReq = (ServiceApptBooking.APIBooking) rawReq;
			ServiceApptBooking.Booking curBooking = bookingReq.toBooking();
			System.debug('curBooking:' + curBooking);

			// If inserting Service Appointment
			if (curBooking.sa == null) {
				if (String.isBlank(curBooking.ContactName)) {
					if (curBooking.vo.Customer__r.IsPersonAccount) {
						curBooking.ContactName = curBooking.vo.Customer__r.Salutation + ' ';
						curBooking.ContactName = (String.isBlank(curBooking.vo.Customer__r.Account_Name__c)) ? curBooking.vo.Customer__r.LastName :
													curBooking.vo.Customer__r.Account_Name__c;
					} else {
						curBooking.ContactName = curBooking.vo.Customer__r.Name;
					}
				}
			} else {
				// cannot amend same day appointment
				if (curBooking.sa.Appointment_Date__c.date() == Date.today()) {
					throw new ServiceApptBooking.ApptException('Record is locked. No changes allowed.');
				}
			}

			if (curBooking.selectedTime == null) { throw new ServiceApptBooking.ApptException('No date time provided.'); }
			Date searchD = curBooking.selectedTime.date();
			Map<Date, ServiceApptBooking.CalDay> calMap = ServiceApptBooking.populateCalDayMap(curBooking.selectedTime.date(), curBooking.selectedTime.date(),
																							   curBooking);

			ServiceApptBooking.CalDay curCal = calMap.get(searchD);
			System.debug('curCal:' + curCal);
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
			// TODO: update care app with source
			curBooking.source = ((curBooking.sa == null || curBooking.sa.Id == null) && String.isBlank(curBooking.source)) ? 'Care App' : curBooking.source;
			curBooking.makeBooking(true);
			curBooking.genUtil(true);

			ServiceApptBooking.APIBooking rv = new ServiceApptBooking.APIBooking(curBooking.sa.Id);
			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(rv));
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			Database.rollback(sp);
			res.responseBody = Blob.valueOf(JSON.serialize(new BookingResp(e)));
			res.statusCode = 400;
		}
	}

	@HttpDelete
	global static void cancel() {
		RestResponse res = RestContext.response;
		SavePoint sp = Database.setSavePoint();
		try {
			RestRequest req = RestContext.request;
			System.debug(req.params);
			String apptId = req.params.get('apptId');
			List<Service_Appointment__c> sa = [SELECT Id, Cancel_Appointment__c FROM Service_Appointment__c WHERE Apppointment_Status__c = 'ACTIVE' AND Id = :apptId];
			if (sa.size() <= 0) { throw new ServiceApptBooking.ApptException('Invalid Appointment ID.'); }
			sa[0].Cancel_Appointment__c = true;
			sa[0].Apppointment_Status__c = 'CANCELLED';
			sa[0].Remarks__c = 'Online Cancellation';
			update sa;
			res.statusCode = 200;
		} catch (Exception e) {
			Database.rollback(sp);
			res.responseBody = Blob.valueOf(JSON.serialize(new BookingResp(e)));
			res.statusCode = 400;
		}
	}

	global class BookingResp extends ServiceApptBooking.ApiResp {
		public BookingResp(Exception e) { super(e); }
	}

}