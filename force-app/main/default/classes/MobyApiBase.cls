public class MobyApiBase {
	public class MobyAuthException extends Exception {}

	public static String MOBY_USER;
	public static String MOBY_PASS;
	public static String END_POINT;
	public static string DEVICE_ID;
	public static string VERSION_ID;
	public static Integer TIME_ZONE = 8;
	public static final Organization ORG = [SELECT Id, IsSandbox FROM Organization LIMIT 1];
	public static DateTime RETRY_LIMIT = DateTime.now().addMinutes(-15);
	static {
		MOBY_USER = (ORG.IsSandbox) ? API_Setup__c.getInstance('MobyMyUat Username').Value__c : API_Setup__c.getInstance('MobyMyPrd Username').Value__c;
		MOBY_PASS = (ORG.IsSandbox) ? API_Setup__c.getInstance('MobyMyUat Password').Value__c : API_Setup__c.getInstance('MobyMyPrd Password').Value__c;
		END_POINT = (ORG.IsSandbox) ? API_Setup__c.getInstance('MobyMyUat Endpoint').Value__c : API_Setup__c.getInstance('MobyMyPrd Endpoint').Value__c;
		DEVICE_ID = (ORG.IsSandbox) ? 'sf.abd.uat.' + ORG.Id : 'sf.abd.prd.' + ORG.Id;
		VERSION_ID = 'v1.0';
	}

	public static MobyAuthResponse Login() {
		string path = 'api/security/login';
		MobyAuthRequest request = new MobyAuthRequest();

		Http http = new Http();
		HttpRequest req;
		HttpResponse res;
		req = new HttpRequest();
		req.setEndpoint(END_POINT + path);
		req.setMethod('POST');
		req.setHeader('Content-Type', 'application/json');
		req.setHeader('DeviceId', DEVICE_ID);
		req.setHeader('Version', VERSION_ID);
		req.setTimeout(60000);
		req.setBody(JSON.serialize(request, false));

		res = http.send(req);
		MobyAuthResponse response;
		if (res.getStatusCode() == 200) {
			response = (MobyAuthResponse)JSON.deserialize(res.getBody(), MobyAuthResponse.class);
			return response;
		}
		else {
			response = new MobyAuthResponse();
			response.IsAuthenticated = false;
			return response;
		}
	}

	private class MobyAuthRequest {
		public string UserId = MOBY_USER;
		public string Password = MOBY_PASS;
	}
	public class MobyAuthResponse {
		public Boolean IsAuthenticated;
		public string TokenId;
		public MobyAppUser AppUser;
	}
	public class MobyAppUser {
		public Integer UserId;
		public string Username;
		public string DisplayName;
		public string Email;
		public Integer CompanyId;
		public string CompanyCode;
		public string CompanyName;
		public Boolean IsActive;
	}
	/** Moby API based request */
	public virtual class MobyAuthBaseRequest {
		public string TokenId;
	}

	/** Moby: Lead Request */
	public class MobyLeadSetRequest extends MobyAuthBaseRequest {
		public integer CompanyId;
		public string ExtCompanyCode;
		public integer MakeId;
		public string MakeCode;
		public integer BranchId;
		public string BranchCode;
		public string Title;
		public string ContactName;
		public string MobileCountry;
		public string MobileNo;
		public string Email;
		public string Location;
		public string Remarks;
		public string Source;
		public string[] VariantText;
		public string ReferenceText;
		public string SforceParam;
		public string DocumentType;
		public string DocumentNo;
	}
}