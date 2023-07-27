global class SQL_Appt_Queue implements Database.AllowsCallouts, Database.Batchable<SObject>, Queueable {
	private static final String USERNAME = SQL_API_Base.USERNAME;
	private static final String PASSWORD = SQL_API_Base.PASSWORD;
	private static final String ENDPOINT_PULL = SQL_API_Base.ENDPOINT + 'v3/appointment/sf/list';
	private static final String ENDPOINT_PUSH = SQL_API_Base.ENDPOINT + 'v2/appointment/sf/set';
	private static final string JOB_NAME = SQL_API_Base.QUEUE_APPT;

	/** Mapping objects */
	private static Map<string, Company__c>				mapCompany;
	private static Map<string, Workshop__c>				mapWorkshop;
	private static Map<long, Account>					mapAccount;
	private static Map<long, Vehicle__c>				mapVehicle;
	private static Map<long, Vehicle_Ownership__c> 		mapVehOwner;
	private static Map<string, Employee_Master__c> 		mapSvcAdvisor;
	private static Map<string, Service_Appointment__c>	mapSvcAppt;

	private static long[] apptIds;
	private static string[] apptSfIds;
	private static CareApptRes[] respAppt;

	/** Email Diagnostic */
	private static SQL_API_Base.API_DEBUG api;
	private static string[] errEmail = new List<string>();

	// public Set<Id> saIdss;
	public string[] salesforceId;
	public long lastId;
	public DateTime dateFrom;
	public DateTime dateTo;
	public string[] company = SQL_API_Base.COMPANY_CODE;
	public long rowCount = 1000;
	public final Integer minRowCount = 10;
	public boolean followOnToPull = false;
	public boolean followOnToRO = false;
	public SQL_API_Base.RowTracking rt = new SQL_API_Base.RowTracking();
	
	/** Default constructor - PUSH */
	public SQL_Appt_Queue() { this.dateFrom = SQL_API_Base.getRunTime(JOB_NAME); }

	/** List of SalesforceId - PUSH or PULL */
	// public SQL_Appt_Queue(Set<Id> ids) {
	// 	this();
	// 	saIds = ids;
	// }

	/** Batchable PUSH */
	public Database.QueryLocator start(Database.BatchableContext BC) {
		System.debug('Batch: SQL_Appt_Queue.start()');
		/** Push: send service appointment records to Care API */
		String query = Database.getQueryLocator([
			SELECT
				Id, Appointment_Date__c, Service_Request__c, Account__r.Customer_Number__c, Company__r.Name
				, Workshop__r.Name, Vehicle_Make__c, Vehicle_Ownership__r.VehicleOwnershipNumber__c
				, Chassis__r.Vehicle_Number__c, Employee_Master__r.Employee_Reference__c, Contact_Name__c
				, Contact_No__c, Email_Address_Notification__c, Apppointment_Status__c, Customer_Comment__c
				, Remarks__c, CreatedDate, CreatedBy.Name, Employee_Master__c, Employee_Master__r.Name
				, Employee_Master__r.Employee_Number__c, Vehicle_Ownership__r.Customer__c
				, Vehicle_Ownership__r.Registration_No__c, Vehicle_Ownership__r.Vehicle__r.Name
				, Created_From__c
			FROM Service_Appointment__c
			LIMIT 200
		]).getQuery().Replace('LIMIT 200', ' ');
		query += 'WHERE (SFDC_Transfer_Flag__c != true) ';
		// if (dateFrom != null) { query += 'AND LastModifiedDate >= :dateFrom '; }
		// if (dateTo != null) { query += 'AND LastModifiedDate <= :dateTo '; }
		// query += ') ';
		// if (saIds != null && !saIds.isEmpty()) { query += 'OR (Id IN :saIds) '; }
		Set<Id> saIds = new Set<Id>();
		if (salesforceId?.size() > 0) {
			for (string sfId :salesforceId) { saIds.add(sfId); }
			query += 'OR (Id IN :saIds) ';
		}
		query += 'ORDER BY LastModifiedDate ';

		/** Skip batch job when it still processing. */
		AsyncApexJob[] jobs = [
			SELECT Id, ApexClass.Name, JobType, Status, CreatedDate
			FROM AsyncApexJob
			WHERE Status IN ('Queued', 'Processing')
				AND JobType IN ('BatchApex', 'BatchApexWorker')
				AND ApexClass.Name = :JOB_NAME
		];
		if (jobs != null && jobs.size() > 0) {
			System.debug('Skipping ' + JOB_NAME + ' batch.');
			query += 'LIMIT 0';
		}

		System.debug('query: ' + query.replace(':dateFrom', JSON.serialize(dateFrom).replace('"', ''))
									  .replace(':dateTo', JSON.serialize(dateTo).replace('"', ''))
									  .replace(':saIds', JSON.serialize(saIds).replace('[', '(').replace(']', ')').replace('"', '\''))
		);

		return Database.getQueryLocator(query);
	}
	public void execute(Database.BatchableContext BC, List<SObject> scope) {
		System.debug('Job: ' + JOB_NAME + ': ' + JSON.serialize(this));

		try {
			if (scope.size() > 0) {
				CareApptSetRes res = callCarePushApi(scope);
				upsertAppt(res, scope);
				// if (res == null) { return; }
				// /** Loop through scope and update. */
				// System.debug('Scanning callCarePushApi response: ' + JSON.serialize(res));
				// for (SObject s :scope) {
				// 	Service_Appointment__c sa = (Service_Appointment__c)s;
				// 	if (res.success != null && res.success.containsKey(sa.Id)) {
				// 		sa.SFDC_Transfer_Datetime__c = Datetime.now();
				// 		sa.SFDC_Transfer_Flag__c = true;
				// 		sa.SFDC_Transfer_Remarks__c = null;
				// 	}
				// 	else if (res.failure != null && res.failure.containsKey(sa.Id)) {
				// 		string remark = String.isNotBlank(res.failure.get(sa.Id)) ? res.failure.get(sa.Id) : 'Error not logged by Care API!';
				// 		sa.SFDC_Transfer_Datetime__c = DateTime.now();
				// 		sa.SFDC_Transfer_Flag__c = false;
				// 		sa.SFDC_Transfer_Remarks__c = remark;
				// 	}
				// }
				// /** Update scope */
				// System.debug('Pre-updating scope: ' + JSON.serialize(scope));
				// Database.SaveResult[] sr = Database.update(scope, false);
				// System.debug('Post updating scope: Triggered?');
			}
		}
		// catch (CalloutException e) {
		// 	string header = JOB_NAME + '_PUSH';
		// 	string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
		// 	string error = JSON.serialize(this) + '\n\nAPI:\n' + API_REQUEST;
		// 	String emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
		// 	errEmail.add(emailBody);
		// }
		catch (Exception e) {
			string header = JOB_NAME + '_PUSH';
			string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
			string error = JSON.serialize(this) + '\n\nAPI:\n' + api?.toString();
			String emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
			errEmail.add(emailBody);
		}
	}
	public void finish(Database.BatchableContext BC) {
		System.debug('Batch: SQL_Appt_Queue.finish()');

		if (errEmail != null && errEmail.size() > 0) {
			CommonMethodsLibrary.sendErrorEmail(new User[] { SQL_API_Base.USER_CUR }, String.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
		}
		/** Execute PULL job. */
		if (followOnToPull) { 
			errEmail = new List<string>();
			this.followOnToRO = true;
			if (!Test.isRunningTest()) { System.enqueueJob(this); }
		}
	}

	public CareApptSetRes callCarePushApi(Service_Appointment__c[] sas) {
		if (sas?.size() == 0) { return null; }
		Http http = new Http();
		HttpRequest hreq = new HttpRequest();
		hreq.setEndpoint(ENDPOINT_PUSH);
		hreq.setMethod('POST');
		hreq.setHeader('Content-Type', 'application/json');
		CareApptSetReq req = new CareApptSetReq();
		req.UserName = USERNAME;
		req.Password = PASSWORD;
		req.appointments = new CareApptRes[]{};
		for (Service_Appointment__c sa :sas) {
			CareApptRes reqSa = new CareApptRes();
			setValues(sa, reqSa);
			req.appointments.add(reqSa);
		}
		hreq.setBody(JSON.serialize(req, false));
		hreq.setTimeout(120000);

		/** Prep API request for exception email */
		api = new SQL_API_Base.API_DEBUG();
		api.parse(hreq, new string[] { 'Content-Type' });

		CareApptSetRes ret;
		HttpResponse hres;
		try {
			hres = http.send(hreq);
			api.parse(hres);
			if (hres.getStatusCode() == 200) {
				/** Update back to the scope. */
				ret = (CareApptSetRes) JSON.deserialize(hres.getBody(), CareApptSetRes.class);
				api.setRows(ret.success.size() + ret.failure.size());
			}
			else { throw new ExternalObjectException(api?.Response); }
		}
		catch (Exception e) { throw e; }
		finally { System.debug(api?.toString()); }

		return ret;
	}

	public void upsertAppt(CareApptSetRes objFr, Service_Appointment__c[] objTo) {
		if (objFr == null) { return; }
		/** Loop through scope and update. */
		System.debug('Scanning callCarePushApi response: ' + JSON.serialize(objFr));
		for (SObject s :objTo) {
			Service_Appointment__c sa = (Service_Appointment__c)s;
			if (objFr.success != null && objFr.success.containsKey(sa.Id)) {
				sa.SFDC_Transfer_Datetime__c = Datetime.now();
				sa.SFDC_Transfer_Flag__c = true;
				sa.SFDC_Transfer_Remarks__c = null;
			}
			else if (objFr.failure != null && objFr.failure.containsKey(sa.Id)) {
				string remark = String.isNotBlank(objFr.failure.get(sa.Id)) ? objFr.failure.get(sa.Id) : 'Error not logged by Care API!';
				sa.SFDC_Transfer_Datetime__c = DateTime.now();
				sa.SFDC_Transfer_Flag__c = false;
				sa.SFDC_Transfer_Remarks__c = remark;
			}
		}
		/** Update objTo */
		System.debug('Pre-updating objTo: ' + JSON.serialize(objTo));
		Database.SaveResult[] sr = Database.update(objTo, false);
		System.debug('Post updating objTo: Triggered?');
	}

	@TestVisible
	private void setValues(Service_Appointment__c objFr, CareApptRes objTo) {
		// objTo.UserName = USERNAME;
		// objTo.Password = PASSWORD;
		// objTo.Company = '028';
		objTo.cmp = objFr.Company__r.Name;
		objTo.workshop = objFr.Workshop__r.Name;
		objTo.csa = SQL_API_Base.ORG.IsSandbox ? 'CSA1' : objFr.Employee_Master__r.Name;
		objTo.csaSapId = objFr.Employee_Master__r.Employee_Reference__c;
		objTo.csaAutolineId = objFr.Employee_Master__r.Employee_Number__c;
		objTo.csaSalesforceId = objFr.Employee_Master__c;

		objTo.vehOwnId = objFr.Vehicle_Ownership__r.VehicleOwnershipNumber__c != null ? objFr.Vehicle_Ownership__r.VehicleOwnershipNumber__c.longValue() : null;
		objTo.vehNo = objFr.Chassis__r.Vehicle_Number__c != null ? objFr.Chassis__r.Vehicle_Number__c.longValue() : null;
		objTo.make = objFr.Vehicle_Make__c;
		objTo.custNo = objFr.Account__r.Customer_Number__c != null ? objFr.Account__r.Customer_Number__c.longValue() : null;
		objTo.contactName = objFr.Contact_Name__c;
		objTo.contactNumber = objFr.Contact_No__c;
		objTo.contactEmail = objFr.Email_Address_Notification__c;

		objTo.salesforceId = objFr.Id;
		objTo.apptDate = objFr.Appointment_Date__c;
		objTo.apptSource = objFr.Created_From__c;
		objTo.serviceTypes = String.isBlank(objFr.Service_Request__c) ? '' : objFr.Service_Request__c;
		objTo.serviceRemarks = objFr.Customer_Comment__c;
		objTo.status = objFr.Apppointment_Status__c;
		objTo.cancelRemarks = objFr.Remarks__c;
		string[] qrStr = ServiceApptBooking.getApptQR(new List<Service_Appointment__c> { objFr });
		objTo.qrCode = qrStr.size() > 0 ? qrStr[0] : '';
		//objTo.isVip = false; // DEFAULT SET TO FALSE IN SQL
		//objTo.isPriorityPlus = false; // DEFAULT SET TO FALSE IN SQL
		objTo.createDate = objFr.CreatedDate;
		objTo.createBy = objFr.CreatedBy.Name;
	}

	/** Apex Job PULL */
	public void execute(QueueableContext context) {
		try {
			string jobMsg = string.format('Job: {0} ({1}): from: {2}, to: {3}, lastId: {4}, rowCount: {5}',
				new string[] { 
					JOB_NAME
					, 'PULL'
					, (this.dateFrom == null ? '' : this.dateFrom.format('yyyy-MM-dd HH:mm:ss'))
					, (this.dateTo == null ? '' : this.dateTo.format('yyyy-MM-dd HH:mm:ss'))
					, String.valueOf(lastId)
					, String.valueOf(rowCount)
				}
			);
			System.debug(jobMsg);

			AsyncApexJob[] jobs = [
				SELECT Id FROM AsyncApexJob
				WHERE Status IN ('Queued', 'Processing')
					AND JobType = 'Queueable'
					// AND CreatedDate > :SQL_API_Base.RETRY_LIMIT
					AND ApexClass.Name = :JOB_NAME
			];
            if ((lastId == null || lastId == 0) && jobs.size() > 1) { return; }
			// if (lastId != null && jobs.size() > 1) {
			// 	System.debug('Skipping ' + JOB_NAME + ' queue.');
			// 	if (this.followOnToRO) {
			// 		SQL_RO_Queue q = new SQL_RO_Queue();
			// 		q.dateTo = this.dateTo;
			// 		q.followOnToSvcInv = true;
			// 		if (!Test.isRunningTest()) { System.enqueueJob(q); }
			// 	}
			// 	return;
			// }
			
			/** Pull: retrieve service appointment records from Care API */
			respAppt = callCarePullApi();
			if (respAppt.size() > 0) {
				upsertApptStatus(respAppt);
				if (!Test.isRunningTest()) { System.enqueueJob(this); }
			}
			else {
				/** 0 (zero) record, send completion message */
				if ((this.dateFrom == null && this.dateTo == null)) {
					string subject = Envir.subject + ': Job complete!';
					string body = (JOB_NAME + '\n\n' + JSON.serialize(this) + '\n\nJob completed!').replace('\n', '<br />');
					Util.sendEmail(subject, body);
				}
				if (this.dateTo != null) { SQL_API_Base.updateRun(SQL_API_Base.getRun(JOB_NAME), this.dateTo); }
				if (this.followOnToRO) {
					SQL_RO_Queue q = new SQL_RO_Queue();
					q.dateFrom = (this.dateFrom == null ? null : q.dateFrom); // indicative if full pull is requested.
					q.dateTo = this.dateTo;
					q.followOnToSvcInv = true;
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
				string header = JOB_NAME + '_PULL';
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
			string header = JOB_NAME + '_PULL';
			string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
			string error = JSON.serialize(this) + '\n\nAPI:\n' + api?.toString();
			String emailBody = CommonMethodsLibrary.constructErrEmail(JOB_NAME, e.getStackTraceString(), e.getMessage());
			errEmail.add(emailBody);
		}
		finally {
			if (errEmail != null && errEmail.size() > 0) {
				CommonMethodsLibrary.sendErrorEmail(new User[] { SQL_API_Base.USER_CUR }, String.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
			}
		}
	}
	public CareApptRes[] callCarePullApi() {
		Http http = new Http();
		HttpRequest hreq = new HttpRequest();
		hreq.setEndpoint(ENDPOINT_PULL);
		hreq.setMethod('POST');
		hreq.setHeader('Content-Type', 'application/json');
		CareApptReq req = new CareApptReq();
		req.Company = this.company;
		req.Username = USERNAME;
		req.Password = PASSWORD;
		req.DateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
		req.DateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
		req.SalesforceId = this.salesforceId;
		req.LastId = this.lastId;
		req.RowCount = this.rowCount;
		hreq.setBody(JSON.serialize(req, false));
		hreq.setTimeout(120000);

		/** Prep API request for exception email */
		api = new SQL_API_Base.API_DEBUG();
		api.parse(hreq, new string[] { 'Content-Type' });

		CareApptRes[] res = new CareApptRes[]{};
		HttpResponse hres;
		try {
			hres = http.send(hreq);
			api.parse(hres);
			if (hres.getStatusCode() == 200) {
				res = (CareApptRes[]) JSON.deserialize(hres.getBody(), CareApptRes[].class);
				api.parse(res);
			}
			else { throw new ExternalObjectException(api?.Response); }
		}
		catch (Exception e) { throw e; }
		finally { System.debug(api?.toString()); }
		
		return res;
	}
	public void upsertApptStatus(CareApptRes[] appts) {
		SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
		/** Initialises mapping */
		initMaps(appts);

		Service_Appointment__c[] updateSa = new Service_Appointment__c[]{};
		Service_Appointment__c sa;
		for (CareApptRes appt :appts) {
			string keyAppt = String.join(new string[] { appt.cmp, appt.salesforceId }, '_').toUpperCase();

			if (mapSvcAppt.containsKey(keyAppt)) {
				sa = mapSvcAppt.get(keyAppt);
				/** Only update Statuses. */
				if (sa.Apppointment_Status__c.equalsIgnoreCase(appt.status)) {
					lt.MatchOne(); rt.MatchOne();
				}
				else {
					sa.Apppointment_Status__c = appt.status.toUpperCase();
					updateSa.add(sa);
					lt.UpdateOne(); rt.UpdateOne();
				}
			}
			else { lt.SkipOne(); rt.SkipOne(); }
		}

		Service_Appointment__c[] upsertSa = updateSa;
		if (upsertSa.size() > 0) {
			if (Test.isRunningTest() || Envir.isSandbox) { System.debug('upsertSa: ' + JSON.serialize(upsertSa)); }
			Database.UpsertResult[] urs = Database.upsert(upsertSa, false);
			if (Test.isRunningTest() || Envir.isSandbox) { System.debug('urs: ' + JSON.serialize(urs)); }
			String err = CommonMethodsLibrary.emailResultFailure(
							urs, upsertSa, 'upsertSa(CareApptRes[])'
							, JOB_NAME, new User[] { SQL_API_Base.USER_CUR }, false);
			if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
		}
		/** Record lastId */
		if (apptIds.size() > 0) {
			apptIds.sort();
			this.lastId = apptIds[apptIds.size() - 1];
		}
		if (apptSfIds.size() > 0) {
			apptSfIds.sort();
			// this.lastId = apptSfIds[apptSfIds.size() - 1];
		}

		System.debug('Upsert Current: ' + JSON.serialize(lt));
	}
	@TestVisible
	private void initMaps(CareApptRes[] appts) {
		/** Gather all lookup list */
		Set<string>	co		= new Set<string>();	// company
		Set<string> ws		= new Set<string>();	// workshop
		Set<long>	ac		= new Set<long>();		// account
		Set<long>	ve		= new Set<long>();		// vehicle
		Set<long>	veo		= new Set<long>();		// vehicle ownership
		Set<string> csa		= new Set<string>();	// csa
		apptIds = new long[]{};
		apptSfIds = new string[]{};
		for (CareApptRes appt :appts) {
			if (String.isNotBlank(appt.cmp))		{ co.add(appt.cmp); }
			if (String.isNotBlank(appt.workshop))	{ ws.add(appt.workshop); }
			if (appt.custNo != null)				{ ac.add(appt.custNo); }
			if (appt.vehNo != null)					{ ve.add(appt.vehNo); }
			if (appt.vehOwnId != null)				{ veo.add(appt.vehOwnId); }
			if (String.isNotBlank((appt.csaSapId)))	{ csa.add(appt.csaSapId); }
			apptIds.add(appt.apptId);
			apptSfIds.add(appt.salesforceId);
		}
		/** cmp => Company__r.Name */
		mapCompany = new Map<string, Company__c>();
		for (Company__c c :[SELECT Id, Name FROM Company__c WHERE Name IN :co]) {
			mapCompany.put(c.Name, c);
		}
		/** workshop => Workshop__r.Name */
		mapWorkshop = new Map<string, Workshop__c>();
		for (Workshop__c w: [SELECT Id, Name, Company__r.Name FROM Workshop__c WHERE Name IN :ws AND Company__r.Name IN :co]) {
			string keyWs = String.format('{0}_{1}', new string[] { w.Company__r.Name, w.Name });
			mapWorkshop.put(keyWs, w);
		}
		/** custNo => Account.Customer_Number__c */
		mapAccount = new Map<long, Account>();
		for (Account a: [SELECT Id, Customer_Number__c FROM Account WHERE Customer_Number__c IN :ac]) {
			if (!mapAccount.containsKey(a.Customer_Number__c.longValue())) { mapAccount.put(a.Customer_Number__c.longValue(), a); }
		}
		/** vehNo => Vehicle__r.Vehicle_Number__c */
		mapVehicle = new Map<long, Vehicle__c>();
		for (Vehicle__c v :[SELECT Id, Vehicle_Number__c FROM Vehicle__c WHERE Vehicle_Number__c IN :ve]) {
			if (!mapVehicle.containsKey(v.Vehicle_Number__c.longValue())) { mapVehicle.put(v.Vehicle_Number__c.longValue(), v); }
		}
		/** vehOwnId => Vehicle_Ownership__r.VehicleOwnershipNumber__c */
		mapVehOwner = new Map<long, Vehicle_Ownership__c>();
		for (Vehicle_Ownership__c vo :[SELECT Id, VehicleOwnershipNumber__c FROM Vehicle_Ownership__c WHERE VehicleOwnershipNumber__c IN :veo]) {
			if (!mapVehOwner.containsKey(vo.VehicleOwnershipNumber__c.longValue()))	{ mapVehOwner.put(vo.VehicleOwnershipNumber__c.longValue(), vo); }
		}
		/** csaSapId => Employee_Master__r.Employee_Reference__c */
		mapSvcAdvisor = new Map<string, Employee_Master__c>();
		for (Employee_Master__c em :[SELECT Id, Name, Employee_Reference__c FROM Employee_Master__c WHERE Employee_Reference__c IN :csa]) {
			if (!mapSvcAdvisor.containsKey(em.Employee_Reference__c)) { mapSvcAdvisor.put(em.Employee_Reference__c, em); }
		}
		/** cmp + salesforceId => Company__r.Name + Service_Appointment__c.Id */
		mapSvcAppt = new Map<string, Service_Appointment__c>();
		Service_Appointment__c[] sas = [SELECT Id, Name, Company__r.Name, Apppointment_Status__c FROM Service_Appointment__c WHERE Id IN :apptSfIds];
		for (Service_Appointment__c sa :sas) {
			string key = String.join(new string[] { sa.Company__r.Name, sa.Id }, '_').toUpperCase();
			mapSvcAppt.put(key, sa);
		}
	}

	/** Button: Push to Care API (Appointment) */
	Webservice static string pushToCare(Id apptId) {
		try {
			Service_Appointment__c[] sas = [
				SELECT
					Id, Appointment_Date__c, Service_Request__c, Account__r.Customer_Number__c, Company__r.Name
					, Workshop__r.Name, Vehicle_Make__c, Vehicle_Ownership__r.VehicleOwnershipNumber__c
					, Chassis__r.Vehicle_Number__c, Employee_Master__r.Employee_Reference__c, Contact_Name__c
					, Contact_No__c, Email_Address_Notification__c, Apppointment_Status__c, Customer_Comment__c
					, Remarks__c, CreatedDate, CreatedBy.Name, Employee_Master__c, Employee_Master__r.Name
					, Employee_Master__r.Employee_Number__c, Vehicle_Ownership__r.Customer__c
					, Vehicle_Ownership__r.Registration_No__c, Vehicle_Ownership__r.Vehicle__r.Name
					, Created_From__c
				FROM Service_Appointment__c
				WHERE CreatedDate != null
				AND Id = :apptId
			];
			if (sas == null || sas.size() <= 0) { return 'Error. Unable to find appointment record with id \'' + apptId + '\'.'; }
			SQL_Appt_Queue q = new SQL_Appt_Queue();
			CareApptSetRes res = q.callCarePushApi(sas);
			if (res == null) { return 'Care API responded with empty response.'; }
			/** Loop through scope and update. */
			string ret;
			try {
				q.upsertAppt(res, sas);
				System.debug('res: ' + JSON.serialize(res));
				System.debug('sas: ' + JSON.serialize(sas));
				update sas;
				ret = 'Done.';
			}
			catch (Exception e) { ret = 'Error.'; }
			// for (Service_Appointment__c sa :sas) {
			// 	if (res.success != null && res.success.containsKey(sa.Id)) {
			// 		sa.SFDC_Transfer_Datetime__c = Datetime.now();
			// 		sa.SFDC_Transfer_Flag__c = true;
			// 		sa.SFDC_Transfer_Remarks__c = null;
			// 		ret = 'Success.';
			// 	}
			// 	else if (res.failure != null && res.failure.containsKey(sa.Id)) {
			// 		string remark = String.isNotBlank(res.failure.get(sa.Id)) ? res.failure.get(sa.Id) : 'Error not logged by Care API!';
			// 		sa.SFDC_Transfer_Datetime__c = DateTime.now();
			// 		sa.SFDC_Transfer_Flag__c = false;
			// 		sa.SFDC_Transfer_Remarks__c = remark;
			// 		ret = 'Error: ' + remark;
			// 	}
			// }
			// /** Update scope */
			// Database.SaveResult[] sr = Database.update(sas, false);
			return ret;
		}
		catch (Exception e) {
			return 'Error: ' + e.getMessage() + (SQL_API_Base.ISSANDBOX ? '\n\n' + e.getStackTraceString() : '');
		}
	}

	public class CareApptReq extends SQL_API_Base.CareReq {
		public long[] ApptId;
		public string[] SalesforceId;
		public long LastId;
	}

	public class CareApptRes {
		public string cmp;
		public string workshop;
		public string csa;
		public string csaSapId;
		public String csaAutolineId;
		public String csaSalesforceId;
		/** Vehicle */
		public long vehOwnId;
		public long vehNo;
		public string make;
		/** Customer */
		public long custNo;
		public string contactName;
		public string contactNumber;
		public string contactEmail;
		public boolean isVIP;
		public boolean isPriorityPlus;
		/** Service Record */
		public long apptId;
		public string solKey;
		public string salesforceId;
		public Datetime apptDate;
		public string serviceTypes;
		public string apptSource;
		public string serviceRemarks;
		public string status;
		public string cancelRemarks;
		public string qrCode;
		public Datetime createDate;
		public string createBy;
	}

	public class CareApptSetReq {
		public String Username;
		public String Password;
		public CareApptRes[] appointments;
	}
	
	public class CareApptSetRes {
		public Map<String, String> success;
		public Map<String, String> failure;
	}

}