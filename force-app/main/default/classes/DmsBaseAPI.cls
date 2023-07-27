public without sharing class DmsBaseAPI {
    public class CustAppException extends Exception {}	
	public final static String CMP_CODE = '099' ;
	public final static String ACC_FIELDS = String.join(new List<String>(schema.SObjectType.Account.fields.getMap().keySet()),',');
	public final static String EXT_SYST_ACC_FIELDS = String.join(new List<String>(schema.SObjectType.ExternalSystemAccount__c.fields.getMap().keySet()),',');
	public final static String VEHI_FIELDS = String.join(new List<String>(schema.SObjectType.Vehicle__c.fields.getMap().keySet()),',');
	public final static String VEHI_OWNER_FIELDS = String.join(new List<String>(schema.SObjectType.Vehicle_Ownership__c.fields.getMap().keySet()),',');
	public final static String INSTANCE_URL = URL.getSalesforceBaseUrl().toExternalForm();
	private final static String UAT_BASE = '';
	private final static String UAT_KEY = '';

	private final static String PRD_BASE = '';
	private final static String PRD_KEY = '';

    private final static Boolean IS_SANDBOX = Envir.IsSandbox;
	public final static List<User> EMAIL_LIST = new User[] { Envir.USER_ADMIN };
	public static String urlBase;
	public static String key;
	public static SQL_API_Base.API_DEBUG api;

    static {
		urlBase = IS_SANDBOX ? UAT_BASE : PRD_BASE;
		key = IS_SANDBOX ? UAT_KEY : PRD_KEY;
	}
 
    private static HttpRequest createRequest(String method, String servicePath) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(urlBase+servicePath);
        req.setMethod(method);
        return req;
    }
    
    private static HttpResponse invokeWebService(HttpRequest httpReq){          
        Http h = new Http();
        HttpResponse  res = h.send(httpReq);
        return res;
    }

    public static String login(String cmp) {
        getKey(cmp);
        HttpRequest req ;      
        HttpResponse resp ;
        req = createRequest('POST', '/v1.0/app/auth'); 
        req.setHeader('Content-Type', 'application/json;charset=UTF-8'); 
        req.setHeader('Accept', 'application/json');
        req.setTimeout(30000);
        LoginReq login = new LoginReq();
		login.appKey = key;
		req.setBody(JSON.serialize(login));
        resp = invokeWebService(req);
		if (resp == null || String.isBlank(resp.getBody())) {
			throw new CustAppException('Invalid response.');
		}
		System.debug('LoginResp:' + resp.getBody());
		LoginResp loginResp = (LoginResp) JSON.deserialize(resp.getBody(), LoginResp.class);
		if (resp.getStatusCode() == 200 && loginResp.httpStatus == 200) {
			if (loginResp.response == null || loginResp.response.data == null || String.isBlank(loginResp.response.data.token)) {
				throw new CustAppException('Invalid JWT Token.');
			}
			return loginResp.response.data.token;
		}
		throw new DMSBaseAPI.CustAppException('Invalid status code from DMSBaseAPI:login. (' + resp.getStatusCode() + ' [' + resp.getStatus() + '])\n' 
				+ 'Request: ' + JSON.serialize(login) + '\n'
				+ 'Response: ' + resp.getBody()
		);
	}


    public static void sendWebhook(String jsonBody) { 
        sendWebhook(jsonBody, '099'); 
    }

	public static void sendWebhook(String jsonBody, String cmp) {
        HttpRequest req ;      
        HttpResponse resp ;
        req = createRequest('POST', '/v1.0/webhook'); 
        req.setHeader('Content-Type', 'application/json;charset=UTF-8'); 
        req.setHeader('Authorization', 'Bearer ' + login(cmp));
        req.setTimeout(30000);
		req.setBody(jsonBody);
        resp = invokeWebService(req);

		api = new SQL_API_Base.API_DEBUG();
		api.parse(req, new string[] { 'Content-Type', 'Authorization' });

		api.parse(resp);
		System.debug(api.toString());
		if (resp == null || String.isBlank(resp.getBody())) {
			throw new CustAppException('Invalid response.');
		}
		WebhookResponse hookResp = (WebhookResponse) JSON.deserialize(resp.getBody(), WebhookResponse.class);
		if (resp.getStatusCode() != 200 && hookResp.httpStatus != 200) {
			String message = (hookResp.response == null || String.isBlank(hookResp.response.message)) ? 'Error from sending webhook' :
							hookResp.response.message;
			throw new CustAppException(message + '\n' + jsonBody);
		}
	}

    private static void getKey(String cmp) {
		if (String.isBlank(cmp)) { throw new CustAppException('Missing Company. Unable to get KEY.'); }
		if (cmp == '099') {
			KEY = IS_SANDBOX ? UAT_KEY : PRD_KEY;
		}
		
	}
    public virtual class APIResp {
		public Integer httpStatus;
	}

	public class WebhookResponse extends APIResp {
		public WebhookBody response;
	}

	public class WebhookBody {
		public String message;
	}

	public class LoginReq {
		public String appKey;
	}

	public class LoginResp extends APIResp {
		public LoginBody response;
	}

	public class LoginBody {
		public String message;
		public JWTBody data;
	}

	public class JWTBody {
		public String token;
	}



 
}