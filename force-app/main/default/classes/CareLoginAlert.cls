@RestResource(urlMapping='/care/loginAlert')
global without sharing class CareLoginAlert {
	@HttpGet
	global static void getLoginAlert() {
		RestResponse res = RestContext.response;
		res.addHeader('Content-Type', 'application/json');
		try {
			RestRequest req = RestContext.request;
			String cmp = req.params.get('cmp');
			String division = req.params.get('division');
			if (String.isBlank(cmp)) { throw new ServiceApptBooking.ApptException('No Company defined.'); }
			List<String> filterList;
			if (cmp == '03') {
				filterList = ServiceApptBooking.DIV_MAP.get(division);
				if (filterList == null) { throw new ServiceApptBooking.ApptException('Unable to find WS Map for:' + req.params.get('division')); }
			}
			LoginAlertResp rv = new LoginAlertResp();
			List<ACP_Login_Alert__c> annList = [SELECT Body__c, Header__c, Company__c, Workshop__c FROM ACP_Login_Alert__c
												 WHERE Active__c = TRUE ORDER BY CreatedDate DESC];
			Boolean inFilter;
			for (ACP_Login_Alert__c a : annList) {
				inFilter = true;
				if (filterList != null && a.Workshop__c != null) {
					for (String filter : filterList) { inFilter = inFilter && (a.Workshop__c.contains(filter)); }
				}
				if (inFilter && a.Company__c.contains(cmp)) {
					rv.body = a.Body__c;
					rv.header = a.Header__c;
					break;
				 }
			}
			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(rv));
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new LoginAlertResp(e)));
			res.statusCode = 400;
		}

	}

	global class LoginAlertResp extends ServiceApptBooking.ApiResp {
		public LoginAlertResp(Exception e) { super(e); }
		public LoginAlertResp() { super(); }
		public String header;
		public String body;
	}

}