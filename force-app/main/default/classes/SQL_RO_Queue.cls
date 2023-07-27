global class SQL_RO_Queue implements Queueable, Database.AllowsCallouts {
	private static final string USERNAME = SQL_API_Base.USERNAME;
	private static final string PASSWORD = SQL_API_Base.PASSWORD;
	private static final string ENDPOINT = SQL_API_Base.ENDPOINT + 'v1/ro/list';
	private static final string JOB_NAME = SQL_API_Base.QUEUE_RORD;

	/** Mapping objects */
	private static Map<string, Company__c> 				mapCompany;
	private static Map<string, Workshop__c> 			mapWorkshop;
	private static Map<string, Account> 				mapAccount;
	private static Map<string, Vehicle__c> 				mapVehicle;
	private static Map<string, Vehicle_Ownership__c[]> 	mapVehOwner;
	private static Map<string, ServiceOrder__c> 		mapRepairOrder;
	private static Map<string, Service_Appointment__c> 	mapSvcAppt;
	private static Map<string, Employee_Master__c> 		mapSvcAdvisor;

	private static string[] roKeys;
	private static RepairOrderRes[] respRord;

	/** Email Diagnostic */
	private static SQL_API_Base.API_DEBUG api;
	private static string[] errEmail = new List<string>();

	public DateTime dateFrom;
	public DateTime dateTo;
	public string roKey = null;
	public string chassisNo = null;
	public string lastKey = null;
	public Long rowCount = 500;
	public final Integer minRowCount = 10;
	public Boolean followOnToSvcInv = false;
	public SQL_API_Base.RowTracking rt = new SQL_API_Base.RowTracking();

	public SQL_RO_Queue() { this.dateFrom = SQL_API_Base.getRunTime(JOB_NAME); }

	public void execute(QueueableContext context) {
		try {
			System.debug('Job: ' + JOB_NAME + ': ' + JSON.serialize(this));

			AsyncApexJob[] jobs = [
				SELECT Id FROM AsyncApexJob
				WHERE Status IN ('Queued', 'Processing')
					AND JobType = 'Queueable'
					AND ApexClass.Name = :JOB_NAME
			];
			// AND CreatedDate > :SQL_API_Base.RETRY_LIMIT
            if (String.isBlank(lastKey) && jobs.size() > 1) { return; }
			// if (lastKey != null && jobs.size() > 1) {
			// 	System.debug('Skipping ' + JOB_NAME + ' queue.');
			// 	if (this.followOnToSvcInv) {
			// 		SQL_SvcInv_Queue q = new SQL_SvcInv_Queue();
			// 		q.dateTo = this.dateTo;
			// 		q.followOnToFile = true;
			// 		if (!Test.isRunningTest()) { System.enqueueJob(q); }
			// 	}
			// 	return;
			// }

			respRord = callCareApi();
			if (respRord.size() > 0) {
				upsertRo(respRord);
				if (!Test.isRunningTest()) { System.enqueueJob(this); }
			}
			else {
				/** 0 (zero) record, send completion message */
				if (this.dateFrom == null && this.dateTo == null) {
					string subject = Envir.subject + ': Job complete!';
					string body = (JOB_NAME + '\n\n' + JSON.serialize(this) + '\n\nJob completed!').replace('\n', '<br />');
					Util.sendEmail(subject, body);
				}
				if (this.dateTo != null) { SQL_API_Base.updateRun(JOB_NAME, this.dateTo); }
				if (this.followOnToSvcInv) {
					SQL_SvcInv_Queue q = new SQL_SvcInv_Queue();
					q.dateFrom = (this.dateFrom == null ? null : q.dateFrom); // indicative if full pull is requested.
					q.dateTo = this.dateTo;
					q.followOnToFile = true;
					if (!Test.isRunningTest()) { System.enqueueJob(q); }
				}
			}
		}
		catch (CalloutException e) {
			if (minRowCount < rowCount) {
				/** Half rowCount and re-queue job. */
				this.rowCount = Math.max(this.rowCount / 2, this.minRowCount);
				if (!Test.isRunningTest()) { System.enqueueJob(this); }
			}
			else if (minRowCount >= rowCount) {
				/** Probably server offline / error. */
				string header = JOB_NAME;
				string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
				string error = String.format(
					'Query row count: {0} is less than default minimum: {1}.\n\n{2}'
					, new string[] {
						String.valueOf(rowCount)
						, String.valueOf(minRowCount) 
						, JSON.Serialize(this)
					}
				) + '\n\nAPI:\n' + api?.toString();
				String emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
				errEmail.add(emailBody);
			}
		}
		catch (Exception e) {
			string header = JOB_NAME;
			string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
			string error = JSON.serialize(this) + '\n\nAPI:\n' + api?.toString();
			String emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
			errEmail.add(emailBody);
		}
		finally {
			if (errEmail != null && errEmail.size() > 0) {
				CommonMethodsLibrary.sendErrorEmail(new User[] { SQL_API_Base.USER_CUR }, String.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
			}
		}
	}

	public RepairOrderRes[] callCareApi() {
		Http http = new Http();
		HttpRequest hreq = new HttpRequest();
		hreq.setEndpoint(ENDPOINT);
		hreq.setMethod('POST');
		hreq.setHeader('Content-Type', 'application/json');
		RepairOrderReq req = new RepairOrderReq();
		req.Company = '028';
		req.UserName = USERNAME;
		req.Password = PASSWORD;
		req.DateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ'); // Timezone adjusted based on calling user profile
		req.DateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');	// Timezone adjusted based on calling user profile
		req.RoKey = this.roKey;
		req.ChassisNo = this.chassisNo;
		req.LastKey = this.lastKey;
		req.RowCount = this.rowCount;
		hreq.setBody(JSON.serialize(req, false));
		hreq.setTimeout(120000);

		/** Prep API request for exception email */
		api = new SQL_API_Base.API_DEBUG();
		api.parse(hreq, new string[] { 'Content-Type' });

		RepairOrderRes[] res = new RepairOrderRes[]{};
		HttpResponse hres;
		try {
			hres = http.send(hreq);
			api.parse(hres);
			if (hres.getStatusCode() == 200) {
				res = (RepairOrderRes[]) JSON.deserialize(hres.getBody(), RepairOrderRes[].class);
				api.parse(res);
			}
			else { throw new ExternalObjectException(api?.Response); }
	
		}
		catch (Exception e) { throw e; }
		finally { System.debug(api?.toString()); }

		return res;
	}

	public void upsertRo(RepairOrderRes[] ros) {
		/** Initialises mapping */
		initMaps(ros);

		// ServiceOrder__c[] insertRo = new List<ServiceOrder__c>();
		// ServiceOrder__c[] updateRo = new List<ServiceOrder__c>();
		Map<string, ServiceOrder__c> mapUpsertRo = new Map<string, ServiceOrder__c>();
		ServiceOrder__c so;
		for (RepairOrderRes ro :ros) {
			so = mapRepairOrder.get(ro.externalId);
			if (so == null) { so = new ServiceOrder__c(); }
			setValues(ro, so);
			/** skip record upsert if VO not found */
			if (so.VehicleOwnership__c == null) { continue; }
			if (so.Id == null) { so.CreatedFrom__c = 'Autoline'; }
			if (!mapUpsertRo.containsKey(ro.wipKey)) {
				mapUpsertRo.put(ro.wipKey, so);

				/** Determine if insert or update */
				if (so.Id == null)	{ rt.AddOne(); }
				else				{ rt.UpdateOne(); }
			}

			// if (mapRepairOrder.containsKey(ro.externalId)) {
			// 	/** Update existing repair order */
			// 	so = mapRepairOrder.get(ro.externalId);
			// 	setValues(ro, so);
			// 	// updateRo.add(so);
			// 	if (!mapUpsertRo.containsKey(ro.wipKey)) {

			// 		mapUpsertRo.put(ro.wipKey, so); 
			// 		// rt.RepairOrders.get('Updated').add(so);
			// 	}
			// 	else {
			// 		// rt.RepairOrders.get('Matched').add(so);
			// 	}
			// 	rt.UpdateOne(); //Updated++;
			// }
			// else {
			// 	/** Insert new repair order */
			// 	so = new ServiceOrder__c();
			// 	setValues(ro, so);
			// 	// insertRo.add(so);
			// 	if (!mapUpsertRo.containsKey(ro.wipKey)) { 
			// 		so.CreatedFrom__c = 'Autoline';
			// 		if (so.VehicleOwnership__c != null) { mapUpsertRo.put(ro.wipKey, so); }
			// 		// rt.RepairOrders.get('Added').add(so);
			// 	}
			// 	else {
			// 		// rt.RepairOrders.get('Matched').add(so);
			// 	}
			// 	rt.AddOne(); //Added++;
			// }
			// rt.Total++;
		}

		// ServiceOrder__c[] upsertRo = updateRo;
		// upsertRo.addAll(insertRo);
		ServiceOrder__c[] upsertRo = mapUpsertRo.values();
		if (upsertRo.size() > 0) {
			Database.UpsertResult[] urs = Database.upsert(upsertRo, false);
			String err = CommonMethodsLibrary.emailResultFailure(
							urs, upsertRo, 'upsertRo(RepairOrderRes[])'
							, JOB_NAME, new User[] { SQL_API_Base.USER_CUR }, false);
			if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
		}
		/** Record lastKey */
		if (roKeys.size() > 0) {
			roKeys.sort();
			this.lastKey = roKeys[roKeys.size() - 1];
		}
	}

	private void initMaps(RepairOrderRes[] ros) {
		/** Gather all lookup list */
		Set<date> rd = new Set<date>(); // ro date
		Set<string> co = new Set<string>();	// company
		Set<string> ws = new Set<string>();	// workshop
		Set<string> dn = new Set<string>(); // doc. no.
		Set<string> ve = new Set<string>();	// vehicle
		Set<string> rn = new Set<string>(); // reg. no.
		Set<string> so = new Set<string>(); // repair order
		Set<string> cs = new Set<string>(); // cso
		roKeys = new List<string>();
		for (RepairOrderRes ro :ros) {
			if (ro.checkIn != null)						{ rd.add(ro.checkIn.date()); }
			if (String.isNotBlank(ro.companyCode))		{ co.add(ro.companyCode); }
			if (String.isNotBlank(ro.branchCode))		{ ws.add(ro.branchCode); }
			if (String.isNotBlank(ro.custDocNo))		{ dn.add(ro.custDocNo); }
			if (String.isNotBlank(ro.vehChassisNo))		{ ve.add(ro.vehChassisNo); }
			if (String.isNotBlank(ro.vehRegNo))			{ rn.add(ro.vehRegNo); }
			if (String.isNotBlank(ro.externalId))		{ so.add(ro.externalId); }
			if (String.isNotBlank(ro.csoSapId))			{ cs.add(ro.csoSapId); }
			roKeys.add(ro.roKey);
		}
		/** companyCode => Company__r.Name */
		mapCompany = new Map<string, Company__c>();
		for (Company__c c :[SELECT Id, Name FROM Company__c WHERE Name IN :co]) {
			mapCompany.put(c.Name, c);
		}
		/** branchCode => Workshop__r.Name */
		mapWorkshop = new Map<string, Workshop__c>();
		for (Workshop__c w: [SELECT Id, Name, Company__r.Name FROM Workshop__c WHERE Name IN :ws AND Company__r.Name IN :co]) {
			string keyWs = String.format('{0}_{1}', new string[] { w.Company__r.Name, w.Name });
			mapWorkshop.put(keyWs, w);
		}
		/** custDocNo => Account__r.NRIC_Number__c */
		mapAccount = new Map<string, Account>();
		for (Account ac :[SELECT Id, Name, NRIC_Number__c FROM Account WHERE NRIC_Number__c IN :dn]) {
			mapAccount.put(ac.NRIC_Number__c, ac);
		}
		/** vehChassisNo => Vehicle__r.Name */
		mapVehicle = new Map<string, Vehicle__c>();
		for (Vehicle__c v :[SELECT Id, Name FROM Vehicle__c WHERE Name IN :ve]) {
			mapVehicle.put(v.Name, v);
		}
		/** vehChassisNo + vehRegNo => Vehicle_Ownership__r.Vehicle__r.Name + .Registration_No__c */
		mapVehOwner = new Map<string, Vehicle_Ownership__c[]>();
		Vehicle_Ownership__c[] vos = [
			SELECT
				Id, Chassis_No__c, Registration_No__c, Customer__c, Customer__r.Id, Start_Date__c, End_Date__c
			FROM Vehicle_Ownership__c
			WHERE (Chassis_No__c IN :ve	AND Registration_No__c IN :rn)
			OR (Chassis_No__c IN :ve AND Customer__r.NRIC_Number__c IN :dn)
			ORDER BY Chassis_No__c, Registration_No__c, Start_Date__c, End_Date__c NULLS LAST
		];
		for (Vehicle_Ownership__c vo :vos) {
			string voKey = String.format('{0}_{1}', new string[] { vo.Chassis_No__c, vo.Registration_No__c });
			if (!mapVehOwner.containsKey(voKey))	{ mapVehOwner.put(voKey, new Vehicle_Ownership__c[] { vo }); }
			else { 
				Vehicle_Ownership__c[] lvos = mapVehOwner.get(voKey);
				lvos.add(vo);
			}
		}
		/** externalId => ServiceOrder__c.ExternalId__c */
		mapRepairOrder = new Map<string, ServiceOrder__c>();
		ServiceOrder__c[] sos = [
			SELECT
				Id, Name, ExternalId__c, CheckIn__c, CheckOut__c, VehicleOwnership__c, CreatedFrom__c
			FROM ServiceOrder__c
			WHERE ExternalId__c IN :so
		];
		for (ServiceOrder__c ro :sos) {
			mapRepairOrder.put(ro.ExternalId__c, ro);
		}
		/** vehChassisNo + vehRegNo + checkIn => Service_Appointment__r.Chassis__r.Name + .Registration_No__c + .Appointment_Date__c.format() */
		mapSvcAppt = new Map<string, Service_Appointment__c>();
		Service_Appointment__c[] sas = [
			SELECT
				Id, Workshop__r.Name, Chassis__r.Name, Registration_No__c
				, Appointment_Date__c
			FROM Service_Appointment__c
			WHERE Workshop__r.Name IN :ws
			AND Chassis__r.Name IN :ve
			AND Registration_No__c IN :rn
			AND Appointment_Date_Only__c IN :rd
			ORDER BY CreatedDate DESC
		];
		for (Service_Appointment__c sa :sas) {
			string saKey = String.format('{0}_{1}_{2}_{3}', new string[] { sa.Workshop__r.Name, sa.Chassis__r.Name, sa.Registration_No__c, sa.Appointment_Date__c.format('yyyy-MM-dd') });
			if (!mapSvcAppt.containsKey(saKey)) { mapSvcAppt.put(saKey, sa); }
		}
		/** csoUserId => Employee_Master__r.Employee_Reference__c */
		mapSvcAdvisor = new Map<string, Employee_Master__c>();
		for (Employee_Master__c em :[SELECT Id, Name, Employee_Reference__c FROM Employee_Master__c WHERE Employee_Reference__c IN :cs]) {
			mapSvcAdvisor.put(em.Employee_Reference__c, em);
		}
	}
	private void setValues(RepairOrderRes objFr, ServiceOrder__c objTo) {
		/** Fix for dirty phone number. */
		string regex = '[^+0-9]';

		if (objTo == null) { objTo = new ServiceOrder__c(); }
		objTo.Name = String.format('{0} {1}', new string[] { objFr.branchCode, objFr.wipNo });

		/** Populate lookups. */
		if (mapCompany.containsKey(objFr.companyCode))	{ objTo.Company__c = mapCompany.get(objFr.companyCode).Id; }
		string keyWs = String.format('{0}_{1}', new string[] { objFr.companyCode, objFr.branchCode });
		if (mapWorkshop.containsKey(keyWs))				{ objTo.Workshop__c = mapWorkshop.get(keyWs).Id; }
		if (mapVehicle.containsKey(objFr.vehChassisNo))	{ objTo.Vehicle__c = mapVehicle.get(objFr.vehChassisNo).Id; }
		string voKey = String.format('{0}_{1}', new string[] { objFr.vehChassisNo, objFr.vehRegNo });
		if (mapVehOwner.containsKey(voKey)) {
			/** Only link VO where CheckIn__c > vo.Start_Date__c */
			Vehicle_Ownership__c[] lvos = mapVehOwner.get(voKey);
			for (Vehicle_Ownership__c vo :lvos) {
				if (vo.Start_Date__c < objFr.checkIn && objFr.checkIn <= (vo.End_Date__c != null ? vo.End_Date__c :  objFr.checkIn)) {
					objTo.VehicleOwnership__c = vo.Id;
					continue;
				}
				else { objTo.VehicleOwnership__c = null; }
			}
		}
		if (mapAccount.containsKey(objFr.custDocNo))	{ objTo.Account__c = mapAccount.get(objFr.custDocNo).Id; }
		else if (mapVehOwner.containsKey(voKey)) 		{
			/** Only link VO.Account where CheckIn__c > vo.Start_Date__c */
			Vehicle_Ownership__c[] lvos = mapVehOwner.get(voKey);
			for (Vehicle_Ownership__c vo :lvos) {
				if (vo.Start_Date__c < objFr.checkIn && objFr.checkIn <= (vo.End_Date__c != null ? vo.End_Date__c :  objFr.checkIn)) {
					objTo.Account__c = vo.Customer__c;
					continue;
				}
				else { objTo.Account__c = null; }
			}
		}
		string saKey = String.format('{0}_{1}_{2}_{3}', new string[] { objFr.branchCode, objFr.vehChassisNo, objFr.vehRegNo, objFr.checkIn.format('yyyy-MM-dd') });
		if (mapSvcAppt.containsKey(saKey))				{ objTo.ServiceAppointment__c = mapSvcAppt.get(saKey).Id; }
		if (mapSvcAdvisor.containsKey(objFr.csoSapId))	{ objTo.CSA__c = mapSvcAdvisor.get(objFr.csoSapId).Id; }

		objTo.ExternalId__c = objFr.externalId;
		objTo.RoKey__c = objFr.roKey;
		objTo.WipKey__c = objFr.wipKey;
		objTo.RepairOrderNo__c = objFr.wipNo;
		objTo.CompanyCode__c = objFr.companyCode;
		objTo.WorkshopCode__c = objFr.branchCode;
		objTo.CsaName__c = objFr.csoUsername;
		objTo.ChassisNo__c = objFr.vehChassisNo;
		objTo.RegistrationNo__c = objFr.vehRegNo;
		objTo.ContactAccNumber__c = objFr.custAccNo;
		objTo.ContactName__c = objFr.custName;
		string phoneClean = objFr.custPhone != null ? objFr.custPhone.replaceAll(regex, '') : null;
		UtilPhone upContact = new UtilPhone(phoneClean);
		objTo.ContactPhone__c = upContact.toE164();
		objTo.PhoneNumber__c = objFr.custPhone;

		if (objFr.checkIn == null) {
			objTo.CheckIn__c = null;
			objTo.Service_Order_Date__c = null;
		}
		else if (objTo.CheckIn__c == null) {
			objTo.CheckIn__c = objFr.checkIn;
			objTo.Service_Order_Date__c = objFr.checkIn.date();
		}
		objTo.Mileage__c = objFr.mileage;
		// if (objFr.checkOut == null) {
		// 	objTo.CheckOut__c = null;
		// 	objTo.Car_Released_Date__c = null;
		// 	objTo.Closed_Date__c = null;
		// }
		// else
		if (objTo.CheckOut__c == null && objFr.checkOut != null) {
			objTo.CheckOut__c = objFr.checkOut;
			objTo.Car_Released_Date__c = Util.validDate(objFr.checkOut.date());
			objTo.Closed_Date__c = Util.validDate(objFr.checkOut.date());
		}
		objTo.StatusNumber__c = objFr.status;
		objTo.Status__c = objFr.statusText;
		objTo.LastStatus__c = objFr.statusText;
		objTo.StatusRemarks__c = objFr.statusRemark;
	}

	/** Button: Pull from Care API (ServiceOrder__c) */
	Webservice static string refreshRO(Id roId) {
		try {
			ServiceOrder__c so = [SELECT Id, Name, RoKey__c FROM ServiceOrder__c WHERE Id = :roId];
			if (String.isBlank(so?.RoKey__c)) { return 'Error: Unable to refresh RO (w/o RO Key).'; }
			SQL_RO_Queue q = new SQL_RO_Queue();
			q.dateFrom = q.dateTo = null;
			q.roKey = so?.RoKey__c;
			RepairOrderRes[] hres = q.callCareApi();
			if (hres == null || hres.size() == 0) { return 'Error: Unable to find RO for refresh.'; }
			q.upsertRo(hres);
			return 'Refreshed successfully.';
		}
		catch (QueryException e) { return 'Error: No record found with id: \'' + roId + '\''; }
		catch (Exception e) { return 'Error: ' + e.getMessage() + (SQL_API_Base.ISSANDBOX ? '\n\n' + e.getStackTraceString() : ''); }
	}

	/** Button: Pull from Care API (ServiceOrder__c) */
	Webservice static string refreshRoByVin(string vin) {
		try {
			if (String.isBlank(vin)) { return 'Error: Unable to refresh RO with blank VIN.'; }
			SQL_RO_Queue q = new SQL_RO_Queue();
			q.dateFrom = q.dateTo = null;
			q.chassisNo = vin;
			RepairOrderRes[] hres = q.callCareApi();
			if (hres == null || hres.size() <= 0) { return 'Error: Unable to find RO for VIN: \'' + vin + '\'.'; }
			q.upsertRo(hres);
			return 'Refreshed successfully.';
		}
		catch (Exception e) { return 'Error: ' + e.getMessage() + (SQL_API_Base.ISSANDBOX ? '\n\n' + e.getStackTraceString() : ''); }
	}

	public virtual class RepairOrderReq {
		public string RoKey;
		public string ChassisNo;
		public string LastKey;
		public Long RowCount;
		public string DateFrom;
		public string DateTo;
		public string Company;
		public String Username;
		public String Password;
	}

	public virtual class RepairOrderRes {
		public string companyCode;
		public string roKey;
		public string externalId;
		public string branchCode;
		public string wipNo;
		public string wipKey;
		public Datetime createDate;
		public Datetime checkIn;
		public Datetime checkOut;
		public string csoUserId;
		public string csoSapId;
		public string csoUsername;
		public string techCode;
		public string status;
		public string statusText;
		public string statusRemark;
		public Datetime lastUpdate;
		public string custAccNo;
		public string custName;
		public string custPhone;
		public string custDocNo;
		public string vehChassisNo;
		public string vehMakeModel;
		public string vehModelCode;
		public string vehRegNo;
		public Decimal mileage;
	}

}