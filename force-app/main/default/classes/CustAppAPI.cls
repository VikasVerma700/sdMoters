global class CustAppAPI {
	public class CustAppException extends Exception {}
	public final static String CURRENCY_TYPE = 'MYR';
	public static Map<String, Company__c> CMP_MAP = new Map<String, Company__c>();
	public final static String INSTANCE_URL = URL.getSalesforceBaseUrl().toExternalForm();
	public final static Organization CUR_ORG = [SELECT Id, IsSandbox FROM Organization LIMIT 1];
	private final static String UAT_BASE = 'https://api.whipmobility.cloud';
	// private final static String UAT_KEY = 'e2aab24b351770c1dc84dca0f8fbdd7bcb826ad3da92d0c6ebb38bf5638f1aae0bc92bf755fdd508f7a7613a792913a9a36582c87372f65f48fc63c25edd1459368dda68afdceade8a5e5aebdfdd96ab6836d194d7d20cd55cf631fe846bd9eb68b21331d249d573d728c39dc09c632eb28d46c8a0c770be50a68952bb9e82514dd19ac01046ad189b15916bac9c62ceeb28901935a8126be44fa6526b2c39fb6f95f1255a4b3f7ca59a8fa9599f243f031791dfedc546797c3e281c03f38cbc7fc952102e2d9d6345211f82adf3eb5d2d4a65502536ed18c79481a6972a4eba59877e98fb459da30ff6f53780c7a47341d297168d2447ba77a52c7d3f9c4aed';
	private final static String UAT_KEY = '12840b231906a826ebcf2f707e26f83edcfa2319ee2d20dc2039ca002462fc148d522aa13977a37628c976a77d5eb1a9b7804785119054f766459bfcb8d20a91db36193c3365816a9b324c9702e914f77095b3419787c9db335b5a48dc840a674631a3bea35d38c49542e302e188a688a15669e3fc9041cfeeec9a96de88b96933a4eb73db76dc1d289174e0c428793ad4d3d9e57dd59d1b60ededcde70a073c6d9813b9dc65115cb9741d2f9f1226d8141b1b479111fce3a062b28fa1726d9546e93e53e032c8f8afb1296adba62face36fc91eade19c1185de7bffd026a7fd1b04919ec0c8aa0b832b734a65dab3d7a72cd74a83d2e1874d75c199dd68c1f2:ec7b2d01061bc7b6b8cd91b5fc0bf2df';
	
	private final static String PRD_BASE = 'https://api.whipmobility.com';
	// private final static String PRD_KEY = '1a5737a1a16b88a1ab44137a4e4e98a5e306504facfa25290f521d5590e44b6340efecd7d44282cff8b765a1a94c96f86ce1b105b92078d7f0042ee66c4adf6dad09506034aa0e826afe01b0dce7437502e70741a1a9b7f48bef5cd73b33a382cfcb0ec43539e94d08e993ec4dec4cfc00c337a815679b92926a33a4ed4497c58c73e8140d559c9b537f688cd6859622e4d4a606ef9e6346dad00345d1c2fa750482bbe33ac7edee7a78440b53761e990ee583b8f40776c302c428a99b92d66e4ff61dbdeadf9464b83a085d80f85a91456f097174193c0bd0bc379ba467bb4eacc117d707e92ba7cc25851770d6d605c9a5333292d073718708cec3b96ada01';
	private final static String PRD_KEY = 'a937e35176d07af119b7f8539875ece64c5a190c53aa6b0771f61278a490b0c67fe820b1f9582526fad7ef02c5c321d0a69cd5eee45998a0f19d34a4c6033f26c838c27844d63f3477f60758b097aee7381ce5edf400862409bef8cea8da184d310b08614d516d02d6166f534ee5966ecbf88a2f5d8a51a1e913ad4a54f5707ff145195ede0c0721bf74785772ca24b5680de7e8ed11d324edcce1f224ff5f49208a91d5fe8ce488e1dd543f390be2e853279df4deb1c2cc2341b033d908e7c0b997136d4c430a6b2c41024a72e15c38140a3ab142e245953fcb281780098a6b6eacda331ab197539e1e53c1ac2a4f6c2e6f9c48c20d45b88213dca3bb477c66:77c69d893a3f3bdc6074406d7af708fb';

	public final static List<User> EMAIL_LIST = new User[] { Envir.USER_ADMIN };
	public static String URL_BASE;
	public static String KEY;
	public static SQL_API_Base.API_DEBUG api;

	static {
		URL_BASE = (CUR_ORG.IsSandbox) ? UAT_BASE : PRD_BASE;
		KEY = (CUR_ORG.IsSandbox) ? UAT_KEY : PRD_KEY;
		for (Company__c cmp : [SELECT Id, Name, AbAppCompany__c FROM Company__c]) { CMP_MAP.put(cmp.Name, cmp); }
	}

	public static List<String> prefixFields(List<String> fields, String prefix) {
		List<String> res = new List<String>();
		for (String s : fields) { res.add(prefix + s); }
		return res;
	}

	public static String login(String cmp) {
		getKey(cmp);

		Http http = new Http();
		HttpRequest req = new HttpRequest();
		req.setEndpoint(URL_BASE + '/v1.0/app/auth');
		req.setMethod('POST');
		req.setHeader('Content-Type', 'application/json');
		req.setTimeout(30000);
		LoginReq login = new LoginReq();
		login.appKey = KEY;
		String loginBody = JSON.serialize(login);
		req.setBody(loginBody);
		HttpResponse resp = http.send(req);
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
		throw new CustAppAPI.CustAppException('Invalid status code from CustAppAPI:login. (' + resp.getStatusCode() + ' [' + resp.getStatus() + '])\n' 
				+ 'Request: ' + loginBody + '\n'
				+ 'Response: ' + resp.getBody()
		);
	}

	public static void sendWebhook(String jsonBody) { sendWebhook(jsonBody, '028'); }

	public static void sendWebhook(String jsonBody, String cmp) {
		// if (!Test.isRunningTest() && !CUR_ORG.IsSandbox) { return; }	// handled with CustAppHandler.
		Http http = new Http();
		HttpRequest req = new HttpRequest();
		req.setEndpoint(URL_BASE + '/v1.0/webhook');
		req.setMethod('POST');
		req.setHeader('Content-Type', 'application/json');
		req.setHeader('Authorization', 'Bearer ' + login(cmp));
		req.setTimeout(30000);
		req.setBody(jsonBody);
		System.debug('Webhook Body:' + jsonBody);

		api = new SQL_API_Base.API_DEBUG();
		api.parse(req, new string[] { 'Content-Type', 'Authorization' });

		HttpResponse resp = http.send(req);
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

		if (cmp == '028') {
			KEY = (CUR_ORG.IsSandbox) ? UAT_KEY : PRD_KEY;
		}
		else if (cmp == '03') {
			// KEY = (CUR_ORG.IsSandbox) ? VAL_UAT_KEY : VAL_PROD_KEY;
		}
	}

	global virtual class APIResp {
		public Integer httpStatus;
	}

	global class WebhookResponse extends APIResp {
		public WebhookBody response;
	}

	global class WebhookBody {
		public String message;
	}

	global class LoginReq {
		public String appKey;
	}

	global class LoginResp extends APIResp {
		public LoginBody response;
	}

	global class LoginBody {
		public String message;
		public JWTBody data;
	}

	global class JWTBody {
		public String token;
	}

	global class CurrencyCls {
		public String currencyType;
		public Decimal amount;
		global CurrencyCls(Decimal amount) {
			this.currencyType = CustAppAPI.CURRENCY_TYPE;
			this.amount = amount;
		}
		global CurrencyCls(String currencyType, Decimal amount) {
			this.currencyType = currencyType;
			this.amount = amount;
		}
	}

	// public class Webhook {
	// 	public string event;
	// }
}