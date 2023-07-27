@RestResource(urlMapping='/whip/v1/workshop/csa')
global without sharing class WhipWorkshopCsa {
	public class WhipWorkshopCsaException extends Exception {}
	public static string cmp = '028';

	@HttpGet
	global static void getWorkshopCsa() {
		RestResponse res = RestContext.response;
		try {
			RestRequest req = RestContext.request;
			string reqSvcTy = req.params.get('type');
			string reqWsCode = req.params.get('workshop');

			if (String.isBlank(reqSvcTy)) { throw new WhipWorkshopCsaException('Service Type is not provided.'); }
			// if (String.isBlank(reqWsCode)) { throw new WhipWorkshopCsaException('Workshop code is not provided.'); }

			/** Get Workshop__c.Id if specified */
			Workshop__c[] ws;
			system.debug('reqWsCode: ' + reqWsCode);
			if (String.isBlank(reqWsCode)) {
				ws = [SELECT Id, Name FROM Workshop__c WHERE AllowInWhip__c = True];
				if (ws.size() == 0) { throw new WhipWorkshopCsaException('No workshop defined.'); }
			}
			else {
				ws = [SELECT Id, Name FROM Workshop__c WHERE AllowInWhip__c = True AND Name = :reqWsCode];
				if (ws.size() == 0) { throw new WhipWorkshopCsaException(string.format('Workshop: {0} is not found.', new string[] { reqWsCode })); }
			}

			/** Immitate CareProviders.cls */
			WorkshopCsaResp rv = new WorkshopCsaResp();
			for (Workshop__c w :ws) {
				ServiceApptBooking.APIBooking bookingReq = new ServiceApptBooking.APIBooking();
				bookingReq.cmp = cmp;
				bookingReq.selectedTypes = new List<string>{ reqSvcTy };
				ServiceApptBooking.Booking curBooking = bookingReq.toBooking();

				Workshop__c[] filteredExternal = new List<Workshop__c>();
				for (Workshop__c wks : ServiceApptBooking.populateWSList(curBooking)) {
					if (wks.AllowInWhip__c && wks.Name == w.Name) { filteredExternal.add(wks); }
				}
				curBooking.checkWS(filteredExternal);
				// this must be filtered by the available workshops
				Employee_Master__c[] csaList = new List<Employee_Master__c>();
				for (Employee_Master__c em : ServiceApptBooking.populateCSAList(filteredExternal, curBooking)) {
					if (em.Allow_Appt_External__c || (curBooking.csa != null && curBooking.csa.Id == em.Id)) { csaList.add(em); }
				}
				curBooking.checkCSA(csaList);
				List<Workshop__c> wsList = ServiceApptBooking.filterAutoAssignWS(filteredExternal, csaList);

				for (Employee_Master__c em : csaList) { rv.csaList.add(new WorkshopCsa(em)); {}}
			}

			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(rv));
		}
		catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new WorkshopCsaResp(e)));
			res.statusCode = 400;
		}
	}

	global class WorkshopCsaResp extends ServiceApptBooking.APIResp {
		global WorkshopCsa[] csaList;
		public WorkshopCsaResp() { csaList = new List<WorkshopCsa>(); }
		public WorkshopCsaResp(Exception e) { super(e); }
	}
	global class WorkshopCsa {
		global String csaId;
		global String csaName;
		global String mobile;
		global String workshopId;
		global String workshopName;
		public WorkshopCsa(Employee_Master__c em) {
			this.csaId = em.Id;
			this.csaName = em.Name;
			this.mobile = em.Mobile_Number__c;
			this.workshopId = em.Workshop__c;
			this.workshopName = em.Workshop__r.Name;
		}
	}

}