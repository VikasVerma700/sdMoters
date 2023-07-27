@RestResource(urlMapping='/whip/v1/workshop')
global without sharing class WhipWorkshop {
	public class WhipWorkshopException extends Exception {}
	public static string cmp = '028';

	@HttpGet
	global static void getWorkshop() {
		RestResponse res = RestContext.response;
		try {
			RestRequest req = RestContext.request;
			string reqSvcTy = req.params.get('type');
			string reqVoId = req.params.get('voId');

			if (String.isBlank(reqSvcTy)) { throw new WhipWorkshopException('No service type is provided.'); }

			/** Immitate CareProviders.cls */
			ServiceApptBooking.APIBooking bookingReq = new ServiceApptBooking.APIBooking();
			bookingReq.cmp = cmp;
			bookingReq.selectedTypes = new List<string>{ reqSvcTy };
			if (String.isNotBlank(reqVoId)) { bookingReq.vo = reqVoId; }
			ServiceApptBooking.Booking curBooking = bookingReq.toBooking();

			WorkshopResp rv = new WorkshopResp();
			for (Workshop__c ws : ServiceApptBooking.populateWSList(curBooking)) {
				if (ws.AllowInWhip__c) { rv.workshopList.add(new Workshop(ws)); }
			}
			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(rv));
		}
		catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new WorkshopResp(e)));
			res.statusCode = 400;
		}
	}

	global class WorkshopResp extends ServiceApptBooking.APIResp {
		global Workshop[] workshopList;
		public WorkshopResp() { workshopList = new List<Workshop>(); }
		public WorkshopResp(Exception e) { super(e); }
	}
	global class Workshop {
		global String workshopId;
		global String shortName;
		global String longName;
		global String address;
		global String contact;
		global Decimal latitude;
		global Decimal longitude;
		public Workshop(Workshop__c ws) {
			this.workshopId = ws.Id;
			this.shortName = ws.Name;
			this.longName = ws.Service_Centre_Name__c;
			this.address = ws.Address__c;
			this.contact = ws.Contact_Number__c;
			this.latitude = ws.Geolocation__Latitude__s;
			this.longitude = ws.Geolocation__Longitude__s;
		}
	}
}