@RestResource(urlMapping='/care/enquiryTypes')
global without sharing class CareEnquiry {
	@HttpGet
	global static void getEnquiryTypes() {
		RestResponse res = RestContext.response;
		try {
			RestRequest req = RestContext.request;
			String cmp = req.params.get('cmp');
			String division = req.params.get('division');
			if (String.isBlank(cmp)) { throw new ServiceApptBooking.ApptException('No Company defined.'); }
			List<String> filterList;
			List<Enquiry_Type__c> typeList = [SELECT Name, Scope__c, WS_Filter__c, Label__c, Company__c FROM Enquiry_Type__c
											  WHERE Active__c = TRUE ORDER BY Name ASC];
			List<Enq> enqList = new List<Enq>();
			Boolean inFilter;
			for (Enquiry_Type__c e : typeList) {
				inFilter = true;
				if (inFilter && e.Company__c.contains(cmp)) { enqList.add(new Enq(e)); }
			}
			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(enqList));
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new QueryResp(e)));
			res.statusCode = 400;
		}
	}

	global class QueryResp extends ServiceApptBooking.ApiResp {
		public QueryResp(Exception e) { super(e); }
	}
	global class Enq {
		global String name;
		global String scope;
		public Enq(Enquiry_Type__c enq) {
			this.name = enq.Label__c;
			this.scope = enq.Scope__c;
		}
	}
}