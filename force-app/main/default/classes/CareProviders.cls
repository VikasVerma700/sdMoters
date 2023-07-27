@RestResource(urlMapping='/care/service/providers')
global without sharing class CareProviders {
	@HttpPost
	global static void providers() {
		RestResponse res = RestContext.response;
		try {
			RestRequest req = RestContext.request;
			System.debug('Request: ' + req.requestBody.toString());
			Object rawReq = JSON.deserialize(req.requestBody.toString(), ServiceApptBooking.APIBooking.class);
			ServiceApptBooking.APIBooking bookingReq = (ServiceApptBooking.APIBooking) rawReq;
			ServiceApptBooking.Booking curBooking = bookingReq.toBooking();

			List<Workshop__c> filteredExternal = new List<Workshop__c>();
			for (Workshop__c ws : ServiceApptBooking.populateWSList(curBooking)) {
				if (ws.Allow_Appt_External__c) {
					filteredExternal.add(ws);
				}
			}
			curBooking.checkWS(filteredExternal);
			// this must be filtered by the available workshops
			List<Employee_Master__c> csaList = new List<Employee_Master__c>();
			for (Employee_Master__c em : ServiceApptBooking.populateCSAList(filteredExternal, curBooking)) {
				if (em.Allow_Appt_External__c || (curBooking.csa != null && curBooking.csa.Id == em.Id)) { csaList.add(em); }
			}
			curBooking.checkCSA(csaList);
			List<Workshop__c> wsList = ServiceApptBooking.filterAutoAssignWS(filteredExternal, csaList);

			ProviderResp rv = new ProviderResp();
			rv.wsList = new List<CareWS>();
			for (Workshop__c w : wsList) { rv.wsList.add(new CareWS(w)); }

			rv.csaList = new List<CareCSA>();
			for (Employee_Master__c em : csaList) { rv.csaList.add(new CareCSA(em)); {}}
			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(rv));
			System.debug('Response: ' + JSON.serialize(rv));
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new ProviderResp(e)));
			res.statusCode = 400;
		}
	}

	global class CareWS {
		global String wsId;
		global String wsName;
		global String address;
		global String contact;
		global Decimal latitude;
		global Decimal longitude;
		public CareWS(Workshop__c ws) {
			this.wsId = ws.Id;
			this.wsName = ws.Service_Centre_Name__c;
			this.address = ws.Address__c;
			this.contact = ws.Contact_Number__c;
			this.latitude = ws.Geolocation__Latitude__s;
			this.longitude = ws.Geolocation__Longitude__s;
		}
	}

	global class CareCSA {
		global String csaId;
		global String csaName;
		global String mobile;
		global String wsId;
		public CareCSA(Employee_Master__c em) {
			this.csaId = em.Id;
			this.csaName = em.Name;
			this.mobile = em.Mobile_Number__c;
			this.wsId = em.Workshop__c;
		}
	}

	global class ProviderResp extends ServiceApptBooking.ApiResp {
		global List<CareWS> wsList;
		global List<CareCSA> csaList;
		public ProviderResp() {}
		public ProviderResp(Exception e) { super(e); }
	}

	global class ServiceType {
		global String name;
		global String description;
		global List<String> includedTypes;
	}
}