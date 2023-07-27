public class MobyApiTestDrive {
	public class MobyTestDriveException extends Exception {}

	private final static Map<string, string> mapLocation;
	public static string SOURCE_CODE;
	public static string VERSION_ID;
	static {
		mapLocation = new Map<string, string>{ 'LOCATION' => 'Location', 'SHOW_ROOM' => 'Showroom', null => 'Unspecified' };
		SOURCE_CODE = 'ABCustApp';
		VERSION_ID = MobyApiBase.VERSION_ID;
	}

/** Incoming Webhook from WHIP: (replaces) CustAppTD.processCallback(). */
	public static void processWhipCallback() {
		RestRequest req = RestContext.request;
		CustAppTD.TDReqCallback reqBody = (CustAppTD.TDReqCallback) JSON.deserialize(req.requestBody.toString(), CustAppTD.TDReqCallback.class);
		if (reqBody == null || reqBody.payload == null || reqBody.payload.testDrive == null) {
			throw new CustAppAPI.CustAppException('Empty payload.');
		}
		MobyApiBase.MobyLeadSetRequest request = genRequest(reqBody);
		string response = LeadSetTestDrive(request);
		System.debug('Moby Resp: ' + response);
	}
	public static MobyApiBase.MobyLeadSetRequest genRequest(CustAppTD.TDReqCallback body) {
		TDReqCallback sfparam = (TDReqCallback) JSON.deserialize(JSON.serialize(body), TDReqCallback.class);
		TDRequest td = sfparam.payload.testDrive;

		/** Before TZ adjustment */
		string selslot = '';
		for (Datetime dt :sfparam.payload.testDrive.selectedSlots) {
			selslot += dt.format('E, dd MMM yyyy @ hh:mm a', UserInfo.getTimeZone().getID())
					+ ' (GMT' + dt.format('Z', UserInfo.getTimeZone().getID()) + ')';
			if (td.selectedSlots.indexOf(dt) < (td.selectedSlots.size()-1)) { selslot += ' / '; }
		}

		TimeZone tz = UserInfo.getTimeZone();
		Datetime[] gmtSlots = new List<Datetime>();
		for (Datetime dt :sfparam.payload.testDrive.selectedSlots) {
			gmtSlots.add(dt.addSeconds(tz.getOffSet(dt)/1000));
		}
		sfparam.payload.testDrive.selectedSlots = gmtSlots;
		Customer_External_Account__c[] caes = [
			SELECT
				Id, UUID__c, Type__c, Name__c
				, Account__c, Account__r.Id, Account__r.Name
				, Account__r.Salutation, Account__r.LastName, Account__r.Account_Name__c
				, Account__r.Default_Email__c
				, Account__r.Mobile_Country_Code_1__pc, Account__r.Mobile_Preferred__pc
				, Account__r.Doc_Type__c, Account__r.NRIC_Number__c
				, Account__r.PersonContactId
			FROM Customer_External_Account__c
			WHERE UUID__c = :td.accountUuid
		];
		if (caes.size() <= 0) { 
			throw new CustAppAPI.CustAppException('Unknown customer UUID (' + td.accountUuid + ') for test drive request');
			// JSON.serialize(body.payload.testDrive)
		}
		Customer_External_Account__c cae = caes[0];
		td.account = new TDAccount();
		td.account.id = cae.Account__c;
		td.account.name = cae.Account__r.Name;
		td.account.lastName = cae.Account__r.LastName;
		td.account.docType = cae.Account__r.Doc_Type__c;
		td.account.docNumber = cae.Account__r.NRIC_Number__c;

		/** Prep Moby api/v1.0/lead/set */
		string location = mapLocation.get(td.type) == null ? td.type : mapLocation.get(td.type);
		string vartext = String.format('{0} {1} {2}', new string[] { td.unit.brand, td.unit.model, td.unit.variant });
		string remarks = String.format(
			'Remarks: {0}\n\nModel Variant: {1}\nSelected Slots: {2}\nType: {3}',
			new string[] {
				td.remark == null ? '' : td.remark
				, vartext
				, selslot
				, location
			}
		);
		switch on td.type {
			when 'LOCATION' {
				CustAppLocation.LocationCls loc = td.location;
				remarks += String.format('\nLocation:\n\tUnit: {0}\n\tBlock: {1}\n\tAddress: {2}\n\tLat / Long: {3} / {4}', new string[] {
					loc.unitNumber, loc.blockNumber, loc.address
					, loc.latitude == null ? '' : String.valueOf(loc.latitude.setScale(9))
					, loc.longitude == null ? '' : String.valueOf(loc.longitude.setScale(9))
				});
			}
			when 'SHOW_ROOM' {}
			when else {}
		}

		MobyApiBase.MobyLeadSetRequest request = new MobyApiBase.MobyLeadSetRequest();
		request.ExtCompanyCode = td.companyId;
		request.MakeCode = td.unit.brand;
		request.Title = cae.Account__r.Salutation;
		request.ContactName = cae.Name__c;
		request.MobileCountry = String.valueOf(cae.Account__r.Mobile_Country_Code_1__pc);
		request.MobileNo = cae.Account__r.Mobile_Preferred__pc;
		request.Email = cae.Account__r.Default_Email__c;
		request.Location = location;
		request.Remarks = remarks;
		request.Source = SOURCE_CODE;
		request.VariantText = new List<string>{ vartext };
		request.ReferenceText = td.referenceNumber;
		request.SforceParam = JSON.serialize(sfparam);

		return request;
	}
	private static string LeadSetTestDrive(MobyApiBase.MobyLeadSetRequest request) {
		/** Moby: authentication */
		MobyApiBase.MobyAuthResponse loginResponse = MobyApiBase.Login();
		if (!loginResponse.IsAuthenticated) { throw new MobyApiBase.MobyAuthException('Moby: Authentication failure.'); }
		request.TokenId = loginResponse.TokenId;

		string path = 'api/v1.0/lead/set';
		Http http = new Http();
		HttpRequest req;
		HttpResponse res;
		req = new HttpRequest();
		req.setEndpoint(MOBY_API_Base.END_POINT + path);
		req.setMethod('POST');
		req.setHeader('Content-Type', 'application/json');
		req.setHeader('DeviceId', MobyApiBase.DEVICE_ID);
		req.setHeader('Version', MobyApiBase.VERSION_ID);
		req.setBody(JSON.serialize(request, false));

		System.debug('LeadSetTestDrive(): ' + JSON.serialize(request));
		res = http.send(req);
		if (res.getStatusCode() == 200) { return res.getBody(); }
		else { throw new MobyTestDriveException('Moby: Test Drive request failure.\nResponse: ' + res.getBody()); }
	}

	public class TDReqCallback {
		public string event;
		public TDReqPayload payload;
	}
	public class TDReqPayload {
		public TDRequest testDrive;
	}
	public class TDRequest extends CustAppTD.TDRequest {
		public TDAccount account;
	}
	public class TDAccount {
		public string id;
		public string name;
		public string lastName;
		public string docType;
		public string docNumber;
	}

/** Outgoing webhook to WHIP: (replaces) CustAppTD.sendWebhook(). */
	public static void processMobyCallback() {
		RestRequest req = RestContext.request;
		CustAppTD.TDWebhook reqBody = (CustAppTD.TDWebhook) JSON.deserialize(req.requestBody.toString(), CustAppTD.TDWebhook.class);
		if (reqBody == null || reqBody.payload == null) {
			throw new CustAppAPI.CustAppException('Empty payload.');
		}
		System.debug(reqBody.event);
		System.debug(req.requestBody.toString());
		
		CustAppAPI.sendWebhook(JSON.serialize(reqBody));
	}

/** Request from WHIP: (replaces) CustAppTD.retrieveTD  */
	public static List<CustAppTD.TDSync> retrieveTD(string uuid, string cmp) {
		try {
			Customer_External_Account__c cea = [
				SELECT Id, Name, UUID__c, Account__c
				FROM Customer_External_Account__c
				LIMIT 1
			];
			return retrieveTD(cea.Account__c, cmp);
		}
		catch (Exception e) { return null; }
	}
	public static List<CustAppTD.TDSync> retrieveTD(Id accId, string cmp) {
		Set<String> allowedTD = CustAppTD.TD_CMP.get(cmp);
		if (allowedTD == null) { throw new CustAppAPI.CustAppException('TD CMP not mapped'); }
		Set<String> disallowedStatus = new Set<String> { 'CANCELLED' };

		List<CustAppTD.TDSync> ret = new List<CustAppTD.TDSync>();
		string path = 'api/sforce/v1.0/testdrive/retrieve';
		Http http = new Http();
		HttpRequest req;
		HttpResponse res;
		req = new HttpRequest();

		// try {
		/** Login Moby */
		MobyApiBase.MobyAuthResponse resLogin = MobyApiBase.Login();
		if (!resLogin.IsAuthenticated) { throw new MOBY_API_Base.MobyAuthenticationException('Login to Moby failed.'); }
		SalesforceTestDriveRequest request = new SalesforceTestDriveRequest();
		request.TokenId = resLogin.TokenId;
		request.company = cmp;
		request.accountId = accId;

		req.setEndpoint(MOBY_API_Base.END_POINT + path);
		req.setMethod('POST');
		req.setHeader('Content-Type', 'application/json');
		req.setHeader('DeviceId', MOBY_API_Base.DEVICE_ID);
		req.setHeader('Version', MOBY_API_Base.VERSION_ID);
		req.setTimeout(60000);
		req.setBody(JSON.serialize(request, false));

		res = http.send(req);
		if (res.getStatusCode() == 200) { 
			System.debug('Moby Td response: ' + res.getBody());
			List<CustAppTD.TDSync> mobyTds = (List<CustAppTD.TDSync>) JSON.deserialize(res.getBody(), List<CustAppTD.TDSync>.class);
			ret.addAll(mobyTds);
		}
			// else {
			// 	string mailBody =	'retrieveTD(Id: ' + accId + ', string ' + cmp + '):\n' +
			// 						'req.getBody(): ' + req.getBody() + '\n' +
			// 						'response: ' + JSON.serialize(res);
			// 	// CommonMethodsLibrary.sendErrorEmail(SQL_API_Base.ADMIN_USER, mailBody.replace('\n', '<br>'));
			// 	// throw new MobyTestDriveException(res.getBody());
			// }
		// }
		// catch (CalloutException e) { 
		// 	string mailBody =	'retrieveTD(Id: ' + accId + ', string ' + cmp + '):\n' +
		// 						'req.getBody(): ' + req.getBody() + '\n' +
		// 						'CalloutException: ' + e.getMessage() + '\n' + e.getStackTraceString();
		// 	// CommonMethodsLibrary.sendErrorEmail(SQL_API_Base.ADMIN_USER, mailBody.replace('\n', '<br>'));
		// }

		return ret;
	}

	public class SalesforceTestDriveRequest extends MobyApiBase.MobyAuthBaseRequest {
		public string company;
		public string accountId;
	}
}