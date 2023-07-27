global class MOBY_API_TestDrive {
	global class MobyTestDriveException extends Exception {}
	public static User[] ADMIN_USER = [SELECT Id, Name, Alias, Email, Profile.Name FROM User WHERE Alias = 'godlike' LIMIT 1];

	/** Replace: CustAppTD.processCallback(). */
	public static void processCallback() {
		System.debug('MOBY_API_TestDrive.processCallback()');
		RestRequest req = RestContext.request;

		string email = 'CustAppTD.processCallback()<br/><br/>Request:<br/>' + req.requestBody.toString();
		CommonMethodsLibrary.sendErrorEmail(ADMIN_USER, email);

		CustAppTD.TDReqCallback reqBody = (CustAppTD.TDReqCallback) JSON.deserialize(req.requestBody.toString(), CustAppTD.TDReqCallback.class);
		System.debug(reqBody.event);
		System.debug(req.requestBody.toString());
		if (reqBody == null || reqBody.payload == null || reqBody.payload.testDrive == null) { throw new CustAppAPI.CustAppException('Empty payload.'); }
		
		String uuid = reqBody.payload.testDrive.accountUuid;
		List<Customer_External_Account__c> custAccList = [
			SELECT
				Id, UUID__c, Type__c, Account__c, Account__r.Id
				, Account__r.Salutation, Account__r.LastName, Account__r.Account_Name__c
				, Account__r.Default_Email__c
				, Account__r.Mobile_Country_Code_1__pc, Account__r.Mobile_Preferred__pc
				, Account__r.Doc_Type__c, Account__r.NRIC_Number__c
				, Account__r.PersonContactId
			FROM Customer_External_Account__c
			WHERE UUID__c = :uuid
		];
		if (custAccList.size() <= 0) { 
			throw new CustAppAPI.CustAppException(
				string.format(
					'Unknown customer UUID ({0}) for request: {1}.'
					, new string[] { uuid, JSON.serialize(reqBody.payload.testDrive) }
				)
			); 
		}

		/** Compose MobyTestDrive request parameter */
		MobyTestDriveRequest reqTd = new MobyTestDriveRequest(reqBody.event);
		MobyInfoRequest reqInfo = new MobyInfoRequest();
		reqInfo.Company = reqBody.payload.testDrive.companyId;
		reqInfo.ReferenceNumber = reqBody.payload.testDrive.referenceNumber;
		reqInfo.Type = reqBody.payload.testDrive.type;
		reqInfo.Make = reqBody.payload.testDrive.unit.brand;
		reqInfo.Series = reqBody.payload.testDrive.unit.series;
		reqInfo.Model = reqBody.payload.testDrive.unit.model;
		reqInfo.Variant = reqBody.payload.testDrive.unit.variant;
		reqInfo.Account = new MobyUserRequest(custAccList[0].UUID__c, custAccList[0].Type__c, custAccList[0].Account__r);
		reqInfo.Remark = reqBody.payload.testDrive.remark;
		reqInfo.Location = new MobyLocationRequest(reqBody.payload.testDrive.location);
		reqInfo.Branch = new MobyBranchRequest(reqBody.payload.testDrive.branch);

		reqInfo.Slots = new string[] {}; // reqBody.payload.testDrive.selectedSlots;
		for (Datetime d :reqBody.payload.testDrive.selectedSlots) {
			string dt = d.format('yyyy-MM-dd\'T\'HH:mm:ss.sssZ', UserInfo.getTimeZone().getID());
			reqInfo.Slots.add(dt);
		}
		reqInfo.Answers = new List<MobyAnswerRequest>();
		if (reqBody.payload.testDrive.answers != null) {
			for (CustAppTD.AnsCls ans :reqBody.payload.testDrive.answers) {
				reqInfo.Answers.add(new MobyAnswerRequest(ans.question, ans.answer));
			}
		}
		reqTd.payload = reqInfo;
		string ret = RequestTestDrive(reqTd);
	}

	public static string RequestTestDrive(MobyTestDriveRequest param) {
		/** Login Moby */
		MOBY_API_Base.MobyLoginResponse resLogin = MOBY_API_Base.Login();
		if (!resLogin.IsAuthenticated) { throw new MOBY_API_Base.MobyAuthenticationException('Login to Moby failed.'); }
		param.TokenId = resLogin.TokenId;

		string path = 'api/sforce/v1.0/testdrive/request';

		Http http = new Http();
		HttpRequest req;
		HttpResponse res;
		req = new HttpRequest();
		req.setEndpoint(MOBY_API_Base.END_POINT + path);
		req.setMethod('POST');
		req.setHeader('Content-Type', 'application/json');
		req.setHeader('DeviceId', MOBY_API_Base.DEVICE_ID);
		req.setHeader('Version', MOBY_API_Base.VERSION_ID);
		req.setBody(JSON.serialize(param, false));

		system.debug('RequestTestDrive: ' + JSON.serialize(param));
		res = http.send(req);
		if (res.getStatusCode() == 200) { return res.getBody(); }
		else { throw new MOBY_API_TestDrive.MobyTestDriveException(res.getBody()); }
	}

	public class MobyTestDriveRequest extends MOBY_API_BASE.MobyAuthenticatedBaseRequest {
		public string Event;
		public MobyInfoRequest Payload;
		public MobyTestDriveRequest(string event) { this.Event = event; }
	}

	public class MobyInfoRequest {
		public string Company;
		public string ReferenceNumber;
		public string[] Slots;
		public string Type;
		public string Make;
		public string Series;
		public string Model;
		public string Variant;
		public MobyUserRequest Account;
		public MobyAnswerRequest[] Answers;
		public string Remark;
		public MobyLocationRequest Location;
		public MobyBranchRequest Branch;
	}
	public class MobyUserRequest {
		public string Uuid;
		public string SfId;
		public string Type;
		public string Title;
		public string Name;
		public string LastName;
		public string Email;
		public string Prefix;
		public string Phone;
		public string DocumentType;
		public string DocumentNo;
		public MobyUserRequest(string uuid, string sfId, string type, string title, string name, string lastName, string email, Decimal prefix, string phone, string docType, string nric) {
			this.Uuid = uuid;
			this.SfId = sfId;
			this.Type = type;
			this.Title = title;
			this.Name = name;
			this.LastName = lastName;
			this.Email = email;
			this.Prefix = String.valueOf(prefix);
			this.Phone = (phone != null && phone.isNumeric()) ? phone : null;
			this.DocumentType = docType;
			this.DocumentNo = nric;
		}
		public MobyUserRequest(string uuid, string type, Account account) {
			this(uuid, account.Id, type, account.Salutation, account.Account_Name__c, account.LastName, account.Default_Email__c, account.Mobile_Country_Code_1__pc, account.Mobile_Preferred__pc, account.Doc_Type__c, account.NRIC_Number__c);
		}
	}
	public class MobyAnswerRequest {
		public string Question;
		public string Answer;
		public MobyAnswerRequest(string question, string answer) {
			this.Question = question;
			this.Answer = answer;
		}
	}
	public class MobyLocationRequest {
		public String UnitNumber;
		public String BlockNumber;
		public string Address;
		public Decimal Latitude;
		public Decimal Longitude;
		public MobyLocationRequest(string unitNumber, string blockNumber, string address, Double latitude, Double longitude) {
			this.UnitNumber = unitNumber;
			this.blockNumber = blockNumber;
			this.Address = address;
			this.Latitude = latitude;
			this.Longitude = longitude;
		}
		public MobyLocationRequest(CustAppLocation.LocationCls location) {
			if (location != null) {
				this.UnitNumber = location.unitNumber;
				this.blockNumber = location.blockNumber;
				this.Address = location.address;
				this.Latitude = location.latitude;
				this.Longitude = location.longitude;
			}
		}
		public CustAppLocation.LocationCls toLocationCls() {
			return new CustAppLocation.LocationCls(this.UnitNumber, this.BlockNumber, this.Address, this.Latitude, this.Longitude);
		}
	}
	public class MobyBranchRequest {
		public string Name;
		public string Uuid;
		public MobyBranchRequest(string name, string uuid) {
			this.Name = name;
			this.Uuid = uuid;
		}
		public MobyBranchRequest(CustAppLocation.BranchCls branch) {
			if (branch != null) {
				this.Name = branch.name;
				this.Uuid = branch.uuid;
			}
		}
	}

	/** Replace: CustAppTD.sendWebhook(Customer_App_Callback__e callback). */
	public static CustAppTD.TDWebhook sendWebhook() {
		RestRequest req = RestContext.request;
		TDReqCallback reqBody = (TDReqCallback) JSON.deserialize(req.requestBody.toString(), TDReqCallback.class);
		if (reqBody == null || reqBody.payload == null) { throw new MobyTestDriveException('Empty payload.'); }
		system.debug(reqBody.event);
		system.debug(req.requestBody.toString());
		
		/** Convert TDReqCallback to CustAppTD.TDWebhook */
		String EVENT_NAME = 'UPSERT_TEST_DRIVE';
		CustAppTD.TDPayload payload = new CustAppTD.TDPayload();
		payload.testDrive = reqBody.payload.toTDSync();
		CustAppTD.TDWebhook hook = new CustAppTD.TDWebhook(EVENT_NAME, payload);
		
		system.debug('Webhook converted to TDWebhook');
		system.debug(hook);
		try {
			CustAppAPI.sendWebhook(JSON.serialize(hook));
			system.debug('TD webhook sent to WHIP');
		}
		catch (Exception e) {
			system.debug('webhook error:');
			system.debug(e);
		}
		return hook;
	}

	global class TDReqCallback {
		public string event;
		public MobyTestDrive payload;
	}
	global class MobyTestDrive {
		public string Id;
		public string ReferenceNumber;
		public string Company;
		public MobySalesperson SalesAdvisor;
		public MobyVehicle Vehicle;
		public MobyLocationRequest Location;
		public Datetime PlannedStart;
		public Datetime PlannedEnd;
		public Datetime ActualStart;
		public Datetime ActualEnd;
		public List<MobyFile> Documents;
		public string Status;	// NEW = SCHEDULED; START = VEHICLE_OUT; END = COMPLETED; CANCEL = CANCELLED
		public string Type;
		public string AccountId;
		public string AccountUuid;
		public CustAppTD.TDSync toTDSync() {
			CustAppTD.TDSync tds = new CustAppTD.TDSync();
			tds.id = this.Id;
			tds.referenceNumber = this.ReferenceNumber;
			tds.company = this.Company;
			tds.salesAdvisor = this.SalesAdvisor != null ? this.SalesAdvisor.toUserCls() : null;
			tds.unit = this.Vehicle != null ? this.Vehicle.toTDVehCls() : null;
			tds.location = this.Location != null ? this.Location.toLocationCls() : null;
			tds.scheduledDateAndTime = new CustAppTD.TDTimeCls(this.PlannedStart, this.PlannedEnd);
			tds.actualDateAndTime = new CustAppTD.TDTimeCls(this.ActualStart, this.ActualEnd);
			switch on this.Status {
				when 'New' { tds.status = 'SCHEDULED'; }
				when 'Started' { tds.status = 'VEHICLE_OUT'; }
				when 'Completed' { tds.status = 'COMPLETED'; }
				when else { tds.status = 'CANCELLED'; }
			}
			tds.type = this.Type;
			tds.accountUuid = this.AccountUuid;
			if (Documents != null && Documents.size() > 0) {
				tds.documents = new List<CustAppFile.FileCls>();
				for (MobyFile mf : this.Documents) { tds.documents.add(mf.toFileCls()); }
			}
			return tds;
		}
	}
	public class MobySalesperson {
		// public string Username;
		public string Fullname;
		public string MobileNo;
		public string Email;
		// public string SapId;
		public CustAppUser.UserCls toUserCls() {
			CustAppUser.UserCls usr = new CustAppUser.UserCls();
			usr.name = this.Fullname;
			usr.phone = new CustAppAccount.PhoneCls(this.MobileNo);
			usr.email = this.Email;
			return usr;
		}
	}
	global class MobyVehicle {
		public string TradePlate;
		public string PlateNo;
		public string ChassisNo;
		public string InVehicleUnit;
		public string Make;
        public string Model;
        public string Variant;
        public string Display;
        public string BodyStyle;
        public string ExteriorColour;
		public string InteriorColour;
		public CustAppTD.TDVehCls toTDVehCls() {
			CustAppTD.TDVehCls veh = new CustAppTD.TDVehCls();
			veh.tradePlate = this.TradePlate;
			veh.numberPlate = this.PlateNo;
			veh.identificationNumber = this.ChassisNo;
			veh.inVehicularUnit = this.InVehicleUnit;
			veh.brand = this.Make;
			veh.model = this.Model;
			veh.variant = this.Variant;
			veh.display = this.Display;
			veh.bodyStyle = this.BodyStyle;
			veh.exteriorColor = this.ExteriorColour;
			veh.interiorColor = this.InteriorColour;
			return veh;
		}
	}
	public class MobyFile {
		public string ContentType;
		public string Name;
		public string Url;
		public CustAppFile.FileCls toFileCls() {
			CustAppFile.FileCls fc = new CustAppFile.FileCls();
			// fc.type = this.ContentType;
			// fc.title = this.Name;
			fc.url = this.Url;
			return fc;
		}
	}

	public static List<CustAppTD.TDSync> retrieveTD(string uuid, string cmp) {
		try {
			Customer_External_Account__c cea = [
				SELECT
					Id, Name, UUID__c, Account__c
				FROM Customer_External_Account__c
				LIMIT 1
			];
			return retrieveTD(cea.Account__c, cmp);
		}
		catch (Exception e) {
			/** swallow */
			return null;
		}
	}
	/** Replace: CustAppTD.retrieveTD(Id accId, String cmp). */
	public static List<CustAppTD.TDSync> retrieveTD(Id accId, string cmp) {
		Set<String> allowedTD = CustAppTD.TD_CMP.get(cmp);
		if (allowedTD == null) {
			throw new CustAppAPI.CustAppException('TD CMP not mapped');
		}
		Set<String> disallowedStatus = new Set<String> { 'CANCELLED' };
		
		/** Login Moby */
		MOBY_API_Base.MobyLoginResponse resLogin = MOBY_API_Base.Login();
		if (!resLogin.IsAuthenticated) { throw new MOBY_API_Base.MobyAuthenticationException('Login to Moby failed.'); }
		RetrieveMobyTestDriveRequest param = new RetrieveMobyTestDriveRequest();
		param.TokenId = resLogin.TokenId;
		param.Company = cmp;
		param.AccountId = accId;

		string path = 'api/sforce/v1.0/testdrive/retrieve';

		Http http = new Http();
		HttpRequest req;
		HttpResponse res;
		req = new HttpRequest();
		req.setEndpoint(MOBY_API_Base.END_POINT + path);
		req.setMethod('POST');
		req.setHeader('Content-Type', 'application/json');
		req.setHeader('DeviceId', MOBY_API_Base.DEVICE_ID);
		req.setHeader('Version', MOBY_API_Base.VERSION_ID);
		req.setBody(JSON.serialize(param, false));

		res = http.send(req);
		List<CustAppTD.TDSync> ret = new List<CustAppTD.TDSync>();
		if (res.getStatusCode() == 200) { 
			List<MobyTestDrive> mobyTds = (List<MobyTestDrive>) JSON.deserialize(res.getBody(), List<MobyTestDrive>.class);
			for (MobyTestDrive td :mobyTds) {
				ret.add(td.toTDSync());
			}
		}
		else { throw new MOBY_API_TestDrive.MobyTestDriveException(res.getBody()); }

		return ret;
	}

	public class RetrieveMobyTestDriveRequest extends MOBY_API_Base.MobyAuthenticatedBaseRequest {
		public string Company;
		public string AccountId;
	}
}