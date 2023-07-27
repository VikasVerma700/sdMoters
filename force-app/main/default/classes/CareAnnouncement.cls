@RestResource(urlMapping='/care/announcements')
global without sharing class CareAnnouncement {
	@HttpGet
	global static void getAnnouncement() {
		RestResponse res = RestContext.response;
		try {
			RestRequest req = RestContext.request;
			String cmp = req.params.get('cmp');
			String division = req.params.get('division');
			if (String.isBlank(cmp)) { throw new ServiceApptBooking.ApptException('No Company defined.'); }
			List<String> filterList;
			List<ACP_Announcement__c> annList = [SELECT Name, Announcement__c, Company__c, WS_Filter__c FROM ACP_Announcement__c
												 WHERE Active__c = TRUE ORDER BY CreatedDate ASC];
			List<String> rv = new List<String>();
			Boolean inFilter;
			for (ACP_Announcement__c a : annList) {
				inFilter = true;
				if (filterList != null && a.WS_Filter__c != null) {
					for (String filter : filterList) { inFilter = inFilter && (a.WS_Filter__c.contains(filter)); }
				}
				if (inFilter && a.Company__c.contains(cmp)) { rv.add(a.Announcement__c); }
			}
			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(rv));
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new AnnResp(e)));
			res.statusCode = 400;
		}

	}

	global class AnnResp extends ServiceApptBooking.ApiResp {
		public AnnResp(Exception e) { super(e); }
	}

}