global class MOBY_API_Base {
	global class MobyAuthenticationException extends Exception {}

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

	/**
	 * Login to Moby API
	 * Return: Access token string.
	 */
	public static MobyLoginResponse Login() {
		string path = 'api/sforce/v1.0/login';
		MobyLoginRequest paramReq = new MobyLoginRequest();
		
		Http http = new Http();
		HttpRequest req;
		HttpResponse res;
		req = new HttpRequest();
		req.setEndpoint(END_POINT + path);
		req.setMethod('POST');
		req.setHeader('Content-Type', 'application/json');
		req.setHeader('DeviceId', DEVICE_ID);
		req.setHeader('Version', VERSION_ID);
		req.setBody(JSON.serialize(paramReq, false));

		res = http.send(req);
		if (res.getStatusCode() == 200) {
			MobyLoginResponse ret = (MobyLoginResponse)JSON.deserialize(res.getBody(), MobyLoginResponse.class);
			return ret;
		}
		else {
			MobyLoginResponse ret = new MobyLoginResponse();
			ret.IsAuthenticated = false;
			return ret;
		}
	}

	private class MobyLoginRequest {
		public string UserId = MOBY_USER;
		public string Password = MOBY_PASS;
	}

	public class MobyLoginResponse {
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
	public virtual class MobyAuthenticatedBaseRequest {
		public string TokenId;
	}
}