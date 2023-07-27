@isTest
public class TestWSMock {
	
	@TestSetup
	static void makeData(){
		M3TechApiWrapper_Test.setup();
	}

	public class SQL_QUEUE_API implements HttpCalloutMock {
		Integer statusCode;
		string responseBody;
		string status { get {
			if (statusCode == null) { return 'Invalid'; }
			switch on statusCode {
				when 200 { return 'OK'; }
				when 400 { return 'Not Found'; }
				when else { return 'Undefined'; }
			}
		}}
		public SQL_QUEUE_API(Integer statusCode, string responseBody) {
			this.statusCode = statusCode;
			this.responseBody = responseBody;
		}
		public HttpResponse respond(HttpRequest request) {
			System.debug('SQL_QUEUE_API.request:' + request.getBody());
			HttpResponse response = new HttpResponse();
			response.setHeader('Content-Type', 'application/json');
			response.setStatusCode(this.statusCode);
			response.setStatus('OK');
			response.setBody(this.responseBody);
			System.debug('SQL_QUEUE_API.response: ' + response.getBody());
			return response;
		}
	}
//////////////////////////////////////////////////////////////////////////////////////////////////
	public class M3TechAPI_Mock implements WebServiceMock {
		public String res;
		public M3TechAPI_Mock(String res) {
			this.res = res;
		}

		public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName,
							String responseWS, String responseName, String responseType) {
			M3TechAPI.deliverMessageResponse_element resElem = new M3TechAPI.deliverMessageResponse_element();
			resElem.deliverMessageResult = this.res;
			response.put('response_x', resElem);
		}
	}

	public class M3TechAPI2_Mock implements WebServiceMock {
		public String res;
		public M3TechAPI2_Mock(String res) {
			this.res = res;
		}
		public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName,
							String responseWS, String responseName, String responseType) {
			M3TechAPI2.deliverMessageResponse_element resElem = new M3TechAPI2.deliverMessageResponse_element();
			resElem.deliverMessageResult = this.res;
			response.put('response_x', resElem);
		}
	}

	public class M3TechApiService_Mock implements webServiceMock{
		public string res;
		public M3TechApiService_Mock (string yes){
			this.res = res;
		}
		public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName,
		String responseWS, String responseName, String responseType){
			M3TechApiService.deliverMessageResponse_element resElem = new M3TechApiService.deliverMessageResponse_element();
			resElem.deliverMessageResult = this.res;
			response.put('response_x', resElem);
		}
	}

	public class M3TechAPI2_SUCC implements WebServiceMock {
		string ret = '00';
		public M3TechAPI2_SUCC() {}
		public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName,
							String responseWS, String responseName, String responseType) {
			M3TechAPI2.deliverMessageResponse_element resp_x = new M3TechAPI2.deliverMessageResponse_element();
			resp_x.deliverMessageResult = this.ret;
			response.put('response_x', resp_x);
		}
	}
	public class M3TechAPI2_FAIL implements WebServiceMock {
		string ret = '12'; // any number except 00.
		string svcId;
		public M3TechAPI2_FAIL(string serviceId) { this.svcId = serviceId; }
		public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName,
							String responseWS, String responseName, String responseType) {
			M3TechAPI2.deliverMessageResponse_element resp_x = new M3TechAPI2.deliverMessageResponse_element();
			resp_x.deliverMessageResult = String.format('{0},{1}', new string[] { this.ret, this.svcId });
			response.put('response_x', resp_x);
		}
	}

	public class M3TechApiService_SUCC implements WebServiceMock{
		string returnCode;
		string msgId;
		public M3TechApiService_SUCC(){}
		public M3TechApiService_SUCC (string messageId, string ret){
			this.msgId = messageId;
			this.returnCode = ret;
		}
		public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName,
							String responseWS, String responseName, String responseType) {
								M3TechApiService.deliverMessageResponse_element resp_x = new M3TechApiService.deliverMessageResponse_element();
								resp_x.deliverMessageResult = String.format('{0},{1}', new string[] { this.returnCode, this.msgId });
								response.put('response_x', resp_x);
							}
	}

	public class M3TechApiService_FAIL implements WebServiceMock{
		string ret = '12';
		string svcId;
		public M3TechApiService_FAIL (string serviceId){this.svcId=serviceId;}
		public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName,
							String responseWS, String responseName, String responseType) {
								M3TechApiService.deliverMessageResponse_element resp_x = new M3TechApiService.deliverMessageResponse_element();
								resp_x.deliverMessageResult = String.format('{0},{1}', new string[] { this.ret, this.svcId });
								response.put('response_x', resp_x);

							}

	}


	//////////////////////////////////////////////////////////////

	public class CustAppHook implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setHeader('Content-Type', 'application/json');
			if (req.getEndpoint().contains('auth')) {
				CustAppAPI.LoginResp key = new CustAppAPI.LoginResp();
				key.httpStatus = 200;
				key.response = new CustAppAPI.LoginBody();
				key.response.data = new CustAppAPI.JWTBody();
				key.response.data.token = 'test';
				res.setBody(JSON.serialize(key));
				res.setStatusCode(200);
			} else {
				CustAppAPI.WebhookResponse key = new CustAppAPI.WebhookResponse();
				key.httpStatus = 200;
				res.setBody(JSON.serialize(key));
				res.setStatusCode(200);
			}
			return res;
		}
	}

	public class CustAppHookLoginResEmpty implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setHeader('Content-Type', 'application/json');
			if (req.getEndpoint().contains('auth')) {
				res.setBody('');
				res.setStatusCode(200);
			}
			return res;
		}
	}

	public class CustAppHookLoginInvalidJWT implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setHeader('Content-Type', 'application/json');
			if (req.getEndpoint().contains('auth')) {
				CustAppAPI.LoginResp key = new CustAppAPI.LoginResp();
				key.httpStatus = 200;
				key.response = new CustAppAPI.LoginBody();
				key.response.data = new CustAppAPI.JWTBody();
				key.response.data.token = '';
				res.setBody(JSON.serialize(key));
				res.setStatusCode(200);
			}
			return res;
		}
	}

	public class CustAppHookLoginInvalid implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setHeader('Content-Type', 'application/json');
			if (req.getEndpoint().contains('auth')) {
				CustAppAPI.LoginResp key = new CustAppAPI.LoginResp();
				key.httpStatus = 500;
				key.response = new CustAppAPI.LoginBody();
				key.response.data = new CustAppAPI.JWTBody();
				key.response.data.token = '';
				res.setBody(JSON.serialize(key));
				res.setStatusCode(500);
			}
			return res;
		}
	}

	public class CustAppHookResEmpty implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setHeader('Content-Type', 'application/json');
			if (req.getEndpoint().contains('auth')) {
				CustAppAPI.LoginResp key = new CustAppAPI.LoginResp();
				key.httpStatus = 200;
				key.response = new CustAppAPI.LoginBody();
				key.response.data = new CustAppAPI.JWTBody();
				key.response.data.token = 'test';
				res.setBody(JSON.serialize(key));
				res.setStatusCode(200);
			} else {
				CustAppAPI.WebhookResponse key = new CustAppAPI.WebhookResponse();
				key.httpStatus = 200;
				res.setBody('');
				res.setStatusCode(200);
			}
			return res;
		}
	}

	public class CustAppHookNot200 implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setHeader('Content-Type', 'application/json');
			if (req.getEndpoint().contains('auth')) {
				CustAppAPI.LoginResp key = new CustAppAPI.LoginResp();
				key.httpStatus = 200;
				key.response = new CustAppAPI.LoginBody();
				key.response.data = new CustAppAPI.JWTBody();
				key.response.data.token = 'test';
				res.setBody(JSON.serialize(key));
				res.setStatusCode(200);
			} else {
				CustAppAPI.WebhookResponse key = new CustAppAPI.WebhookResponse();
				key.httpStatus = 500;
				key.response = new CustAppAPI.WebhookBody();
				key.response.message = '';
				res.setBody(JSON.serialize(key));
				res.setStatusCode(500);
			}
			return res;
		}
	}

	

		

	public class CustAppNotification implements HttpCalloutMock {
		Integer statusCode;
		String uuid;
		public CustAppNotification(String uuid, Integer statusCode) {
			this.statusCode = statusCode;
			this.uuid = uuid;
		}

		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setHeader('Content-Type', 'application/json');
			if (req.getEndpoint().contains('auth')) {
				CustAppAPI.LoginResp key = new CustAppAPI.LoginResp();
				key.httpStatus = 200;
				key.response = new CustAppAPI.LoginBody();
				key.response.data = new CustAppAPI.JWTBody();
				key.response.data.token = 'test';
				res.setBody(JSON.serialize(key));
				res.setStatusCode(200);
			} else {
				CustAppNotification.Response resp = new CustAppNotification.Response();
				if (this.statusCode == 200) {
					resp.response = new CustAppNotification.NotificationResp();
					resp.response.message = 'yay';
					resp.response.data = new CustAppNotification.NotificationData();
					resp.response.data.account = new CustAppNotification.AccountData();
					resp.response.data.account.uuid = this.uuid;
					CustAppNotification.DeliveryStatus status = new CustAppNotification.DeliveryStatus();
					status.deliveryStatus = 'Sent';
					status.device = new CustAppNotification.DeviceInfo();
					resp.response.data.account.devices = new List<CustAppNotification.DeliveryStatus>{ status };
				}
				resp.httpStatus = this.statusCode;
				res.setBody(JSON.serialize(resp));
				res.setStatusCode(this.statusCode);
			}
			return res;
		}
	}

	public class CustAppInvite implements HttpCalloutMock {
		CustAppAccountAPI.InviteResp inviteResp;
		public CustAppInvite(CustAppAccountAPI.InviteResp resp) {
			this.inviteResp = resp;
		}
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setHeader('Content-Type', 'application/json');
			if (req.getEndpoint().contains('auth')) {
				CustAppAPI.LoginResp key = new CustAppAPI.LoginResp();
				key.httpStatus = 200;
				key.response = new CustAppAPI.LoginBody();
				key.response.data = new CustAppAPI.JWTBody();
				key.response.data.token = 'test';
				res.setBody(JSON.serialize(key));
				res.setStatusCode(200);
			} else {
				res.setBody(JSON.serialize(this.inviteResp));
				res.setStatusCode(201);
			}
			return res;
		}
	}

	/** Added: 2020-08-25 - MOBY API Interface Mock */
	public class MOBY_API_Mock implements HttpCalloutMock {
		Integer StatusCode;
		public MOBY_API_Mock(Integer statusCode) { this.StatusCode = statusCode; }
		public HttpResponse respond(HttpRequest req) {
			system.debug('MOBY_API_Mock Request (' + this.StatusCode + ')');
			system.debug('POST /' + req.getEndpoint());
			system.debug('Request: ' + req.getBody());
			HttpResponse res = new HttpResponse();
			res.setHeader('Content-Type', 'application/json');
			res.setStatusCode(this.StatusCode);
			if (req.getEndpoint().contains('/login')) {
				if (this.StatusCode == 200) {
					MOBY_API_BASE.MobyLoginResponse loginRes = new MOBY_API_BASE.MobyLoginResponse();
					loginRes.IsAuthenticated = true;
					loginRes.TokenId = 'TokenId';
					MOBY_API_BASE.MobyAppUser user = new MOBY_API_BASE.MobyAppUser();
					user.UserId = 1;
					user.Username = 'MockUsername';
					user.DisplayName = 'MockUDisplayName';
					user.Email = 'email@mock.com';
					user.CompanyId = 1;
					user.CompanyCode = '028';
					user.CompanyName = 'ZeroTwoEight';
					user.IsActive = true;
					loginRes.AppUser = user;

					res.setBody(JSON.serialize(loginRes));
				}
				else {
					MOBY_API_BASE.MobyLoginResponse loginRes = new MOBY_API_BASE.MobyLoginResponse();
					loginRes.IsAuthenticated = false;
					res.setBody(JSON.serialize(loginRes));
				}
			}
			else if (req.getEndpoint().contains('/testdrive/request')) {
				MOBY_API_TestDrive.MobyTestDriveRequest reqBody = (MOBY_API_TestDrive.MobyTestDriveRequest) JSON.deserialize(req.getBody(), MOBY_API_TestDrive.MobyTestDriveRequest.class);
				system.debug('/testdrive/request');
				system.debug(JSON.serialize(res.getBody()));
				String uuid = reqBody.Payload.Account.Uuid;
				if (this.StatusCode == 200) { res.setBody(JSON.serialize('ok')); }
				else { res.setBody(JSON.serialize('ko')); }
			}
			else if (req.getEndpoint().contains('/testdrive/retrieve')) {
				if (this.StatusCode == 200) {
					List<MOBY_API_TestDrive.MobyTestDrive> mobytds = new List<MOBY_API_TestDrive.MobyTestDrive>();
					MOBY_API_TestDrive.MobyTestDrive mtd = new MOBY_API_TestDrive.MobyTestDrive();
					mtd.Id = 'id';
					mtd.ReferenceNumber = 'ref';
					mtd.Company = '028';
					MOBY_API_TestDrive.MobySalesperson sa = new MOBY_API_TestDrive.MobySalesperson();
					sa.Fullname = 'salesperson fullname';
					sa.MobileNo = '+60123456789';
					sa.Email = 'sales@email.com';
					mtd.SalesAdvisor = sa;
					MOBY_API_TestDrive.MobyVehicle ve = new MOBY_API_TestDrive.MobyVehicle();
					ve.TradePlate = 'tradeplate';
					ve.PlateNo = 'plateno';
					ve.ChassisNo = 'chassisno';
					ve.InVehicleUnit = 'ivu';
					ve.Make = 'make';
					ve.Model = 'model';
					ve.Variant = 'variant';
					ve.Display = 'display';
					ve.BodyStyle = 'bodystyle';
					ve.ExteriorColour = 'ext color';
					ve.InteriorColour = 'int color';
					mtd.Vehicle = ve;
					mtd.Location = new MOBY_API_TestDrive.MobyLocationRequest('No1', 'B1', 'address', 0, 1);
					mtd.PlannedStart = mtd.PlannedEnd = Datetime.now();
					mtd.ActualStart = mtd.ActualEnd = Datetime.now();
					MOBY_API_TestDrive.MobyFile file = new MOBY_API_TestDrive.MobyFile();
					file.ContentType = 'content';
					file.Name = 'name';
					file.Url = 'url';
					mtd.Documents = new List<MOBY_API_TestDrive.MobyFile>{ file };
					mtd.status = 'NEW';
					mtd.Type = 'type';
					mtd.AccountId = 'accId';
					mtd.AccountUuid = 'uuid';
					mobytds.add(mtd);
					res.setBody(JSON.serialize(mobytds));
				}
			}

			system.debug('MOBY_API_Mock Response');
			system.debug(res.getStatusCode() + ' /' + req.getEndpoint());
			system.debug(res.getBody());
			return res;
		}
	}
	public class MOBY_API_BASE_CE implements HttpCalloutMock {
		Integer StatusCode;
		public MOBY_API_BASE_CE(Integer statusCode) { this.StatusCode = statusCode; }
		public HttpResponse respond(HttpRequest req) {
			throw new CalloutException('Mock CalloutException for MOBY_API_BASE');
		}
	}
	public class MOBY_API_BASE_EX implements HttpCalloutMock {
		Integer StatusCode;
		public MOBY_API_BASE_EX(Integer statusCode) { this.StatusCode = statusCode; }
		public HttpResponse respond(HttpRequest req) {
			Exception e;
			e.setMessage('Mock Exception for MOBY_API_BASE');
			throw e;
		}
	}
	public class MOBY_API_TestDrive_CE implements HttpCalloutMock {
		Integer StatusCode;
		public MOBY_API_TestDrive_CE(Integer statusCode) { this.StatusCode = statusCode; }
		public HttpResponse respond(HttpRequest req) {
			throw new CalloutException('Mock CalloutException for MOBY_API_TestDrive');
		}
	}
	public class MOBY_API_TestDrive_EX implements HttpCalloutMock {
		Integer StatusCode;
		public MOBY_API_TestDrive_EX(Integer statusCode) { this.StatusCode = statusCode; }
		public HttpResponse respond(HttpRequest req) {
			throw new CalloutException('Mock Exception for MOBY_API_TestDrive');
		}
	}

	public class MobyApiBase_Mock implements HttpCalloutMock {
		/** Mapping: Endpoint:StatusCode */
		Map<string, integer> mapApiStatus = new Map<string, integer>();
		integer statusCode;
		public MobyApiBase_Mock(integer statusCode) { this.statusCode = statusCode; }
		public MobyApiBase_Mock(Map<string, integer> mapping) {
			/** default status code */
			this(200);
			mapApiStatus = mapping;
		}
		public HttpResponse respond(HttpRequest req) {
			system.debug('MobyApiBase_Mock Request (' + this.StatusCode + ')');
			system.debug('POST /' + req.getEndpoint());
			system.debug('Request: ' + req.getBody());
			HttpResponse res = new HttpResponse();
			res.setHeader('Content-Type', 'application/json');
			/** Read mapping */
			if (mapApiStatus.containsKey(req.getEndpoint())) { 
				this.statusCode = mapApiStatus.get(req.getEndpoint()); 
			}
			res.setStatusCode(this.statusCode);
			if (req.getEndpoint().contains('/login')) {
				if (this.statusCode == 200) {
					MobyApiBase.MobyAuthResponse response = new MobyApiBase.MobyAuthResponse();
					response.IsAuthenticated = true;
					response.TokenId = 'TokenId';
					MobyApiBase.MobyAppUser user = new MobyApiBase.MobyAppUser();
					user.UserId = 1;
					user.Username = 'MockUsername';
					user.DisplayName = 'MockUDisplayName';
					user.Email = 'email@mock.com';
					user.CompanyId = 1;
					user.CompanyCode = '028';
					user.CompanyName = 'ZeroTwoEight';
					user.IsActive = true;
					response.AppUser = user;

					res.setBody(JSON.serialize(response));
				}
				else {
					MobyApiBase.MobyAuthResponse response = new MobyApiBase.MobyAuthResponse();
					response.IsAuthenticated = false;
					res.setBody(JSON.serialize(response));
				}
			}
			else if (req.getEndpoint().contains('/v1.0/lead/set')) {
				MobyApiBase.MobyLeadSetRequest request = (MobyApiBase.MobyLeadSetRequest) JSON.deserialize(req.getBody(), MobyApiBase.MobyLeadSetRequest.class);
				MobyApiTestDrive.TDReqCallback cb = (MobyApiTestDrive.TDReqCallback) JSON.deserialize(request.SforceParam, MobyApiTestDrive.TDReqCallback.class);
				system.debug('/v1.0/lead/set');
				system.debug(JSON.serialize(res.getBody()));
				String uuid = cb.payload.testDrive.accountUuid;
				if (this.statusCode == 200) { res.setBody(JSON.serialize('ok')); }
				else { res.setBody(JSON.serialize('ko')); }
			}
			else if (req.getEndpoint().contains('/testdrive/retrieve')) {
				if (this.statusCode == 200) {
					List<MOBY_API_TestDrive.MobyTestDrive> mobytds = new List<MOBY_API_TestDrive.MobyTestDrive>();
					MOBY_API_TestDrive.MobyTestDrive mtd = new MOBY_API_TestDrive.MobyTestDrive();
					mtd.Id = 'id';
					mtd.ReferenceNumber = 'ref';
					mtd.Company = '028';
					MOBY_API_TestDrive.MobySalesperson sa = new MOBY_API_TestDrive.MobySalesperson();
					sa.Fullname = 'salesperson fullname';
					sa.MobileNo = '+60123456789';
					sa.Email = 'sales@email.com';
					mtd.SalesAdvisor = sa;
					MOBY_API_TestDrive.MobyVehicle ve = new MOBY_API_TestDrive.MobyVehicle();
					ve.TradePlate = 'tradeplate';
					ve.PlateNo = 'plateno';
					ve.ChassisNo = 'chassisno';
					ve.InVehicleUnit = 'ivu';
					ve.Make = 'make';
					ve.Model = 'model';
					ve.Variant = 'variant';
					ve.Display = 'display';
					ve.BodyStyle = 'bodystyle';
					ve.ExteriorColour = 'ext color';
					ve.InteriorColour = 'int color';
					mtd.Vehicle = ve;
					mtd.Location = new MOBY_API_TestDrive.MobyLocationRequest('No1', 'B1', 'address', 0, 1);
					mtd.PlannedStart = mtd.PlannedEnd = Datetime.now();
					mtd.ActualStart = mtd.ActualEnd = Datetime.now();
					MOBY_API_TestDrive.MobyFile file = new MOBY_API_TestDrive.MobyFile();
					file.ContentType = 'content';
					file.Name = 'name';
					file.Url = 'url';
					mtd.Documents = new List<MOBY_API_TestDrive.MobyFile>{ file };
					mtd.status = 'NEW';
					mtd.Type = 'type';
					mtd.AccountId = 'accId';
					mtd.AccountUuid = 'uuid';
					mobytds.add(mtd);
					res.setBody(JSON.serialize(mobytds));
				}
			}

			system.debug('MobyApiBase_Mock Response');
			system.debug(res.getStatusCode() + ' /' + req.getEndpoint());
			system.debug(res.getBody());
			return res;
		}
	}


	public class QrServer implements HttpCalloutMock {
		public QrServer() {

		}
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setHeader('Content-Type', 'image/png');
			res.setBody(JSON.serialize('QrImage.png'));
			res.setStatusCode(200);
			return res;
		}
	}

	public class WebServiceThrowE implements WebServiceMock {
		public WebServiceThrowE() {}
		public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName,
							String responseWS, String responseName, String responseType) {
			Exception e;
			e.setMessage('WebServiceMock: Throw System.Exception.');
			throw e;
		}
	}
	public class WebServiceThrowECallout implements WebServiceMock {
		public WebServiceThrowECallout() {}
		public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName,
							String responseWS, String responseName, String responseType) {
			throw new CalloutException('WebServiceMock: Throw System.CalloutException.');
		}
	}

	public class HttpThrowE implements HttpCalloutMock {
		public HttpThrowE() {}
		public HttpResponse respond(HttpRequest request) {
			Exception e;
			e.setMessage('HttpCalloutMock: Throw System.Exception.');
			throw e;
		}
	}
	public class HttpThrowECallout implements HttpCalloutMock {
		public HttpThrowECallout() {}
		public HttpResponse respond(HttpRequest request) {
			throw new CalloutException('HttpCalloutMock: Throw System.CalloutException.');
		}
	}


}