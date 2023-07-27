@RestResource(urlMapping='/care/service/calendar')
global without sharing class CareCalendar {
	public final static Integer BMW_MAX_SLOT = 5;

	@HttpPost
	global static void calendar() {
		RestResponse res = RestContext.response;
		try {
			RestRequest req = RestContext.request;
			System.debug('Request: ' + req.requestBody.toString());
			CalendarReq calReq = (CalendarReq) JSON.deserialize(req.requestBody.toString(), CalendarReq.class);
			if (calReq.startDate == null || calReq.endDate == null || calReq.endDate < calReq.startDate) {
				throw new ServiceApptBooking.ApptException('Invalid dates provided.');
			}
			if (calReq.booking == null) { throw new ServiceApptBooking.ApptException('No booking information'); }
			ServiceApptBooking.Booking curBooking = calReq.booking.toBooking();

			Map<Date, ServiceApptBooking.CalDay> calMap = ServiceApptBooking.populateCalDayMap(calReq.startDate, calReq.endDate, curBooking);
			Map<Date, Cal> rv = new Map<Date, Cal>();
			for (ServiceApptBooking.CalDay cur : calMap.values()) { rv.put(cur.day, new Cal(cur, curBooking)); }

			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(rv));
			System.debug('Response: ' + JSON.serialize(rv));
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new CalendarResp(e)));
			res.statusCode = 400;
		}
	}

	global class CalendarReq {
		global ServiceApptBooking.APIBooking booking;
		global Date startDate;
		global Date endDate;
	}

	global class CalendarResp extends ServiceApptBooking.ApiResp {
		public CalendarResp(Exception e) { super(e); }
	}

	global class Cal {
		global Boolean available;
		global Date day;
		global List<DateTime> slots;
		global Integer remaining;

		public Cal(ServiceApptBooking.CalDay cur, ServiceApptBooking.Booking curBooking) {
			this.available = cur.avail;
			this.day = cur.day;
			if (cur.slots == null || cur.slots.size() <= 0) {
				this.slots = new List<DateTime>();
			} else {
				List<DateTime> allSlots = new List<DateTime>(cur.slots);
				allSlots.sort();
				this.slots = new List<DateTime>();
				Integer MAX_SLOT = BMW_MAX_SLOT;
				for (Integer i = 0; i < Math.min(MAX_SLOT, allSlots.size()); i++) { this.slots.add(allSlots[i]); }
				this.remaining = cur.remSlots;
			}
			if (curBooking != null && curBooking.sa != null && curBooking.sa.Appointment_Date__c.date() == this.day) {
				Boolean seen = false;
				for (DateTime dt : this.slots) { seen = seen || (dt == curBooking.sa.Appointment_Date__c); }
				if (!seen) { this.slots.add(curBooking.sa.Appointment_Date__c); }
			}
		}
	}

}