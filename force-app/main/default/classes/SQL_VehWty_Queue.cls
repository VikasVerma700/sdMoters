global class SQL_VehWty_Queue implements Queueable, Database.AllowsCallouts {
	private static final String USERNAME = SQL_API_Base.USERNAME;
	private static final String PASSWORD = SQL_API_Base.PASSWORD;
	private static final String ENDPOINT = SQL_API_Base.ENDPOINT + 'v2/vehicle/contract/get';
    private static final string JOB_NAME = SQL_API_Base.QUEUE_WRTY;

	/** Mapping objects */
	private static Map<string, Company__c>			mapCompany;
	private static Map<string, Vehicle__c>			mapVehicle;
	private static Map<string, WarrantyPackage__c>	mapWtyPkg;
	private static Map<string, VehicleWarranty__c>	mapVehWty;

	private static Long[] recordId;
	private static CareVehWtyRes[] respVehWty;

	/** Email Diagnostic */
	private static SQL_API_Base.API_DEBUG api;
	private static string[] errEmail = new List<string>();

	public DateTime dateFrom;
	public DateTime dateTo;
	public Long lastId = 0;
	public string[] vin = null;
	public Long rowCount = 2000;
	public final Long minRowCount = 1000;
	public Boolean sendCompletionEmail = false;
	public SQL_API_Base.RowTracking rt = new SQL_API_Base.RowTracking();

	public SQL_VehWty_Queue() { this.dateFrom = SQL_API_Base.getRunTime(JOB_NAME); }

	public void execute(QueueableContext context) {
		try {
			System.debug('Job: ' + JOB_NAME + ': ' + JSON.serialize(this));

			AsyncApexJob[] jobs = [
				SELECT Id FROM AsyncApexJob
				WHERE Status IN ('Queued', 'Processing')
					AND JobType = 'Queueable'
					// AND CreatedDate > :SQL_API_Base.RETRY_LIMIT
					AND ApexClass.Name = :JOB_NAME
			];
			if ((lastId != null || lastId == 0) && jobs.size() > 1) { return; }

			respVehWty = pullCareApi();
			if (respVehWty.size() > 0) {
				upsertVehWty(respVehWty);
				System.debug('Upsert Total: ' + JSON.serialize(rt));
				if (!Test.isRunningTest()) { System.enqueueJob(this); }
			}
			else {
				/** 0 (zero) record, send completion message */
				if (sendCompletionEmail) {
					string subject = Envir.subject + ': Job complete!';
					string body = (JOB_NAME + '\n\n' + JSON.serialize(this) + '\n\nJob completed!').replace('\n', '<br />');
					Util.sendEmail(subject, body);
				}
				if (this.dateTo != null) { SQL_API_Base.updateRun(JOB_NAME, this.dateTo); }
			}
		}
		catch (CalloutException e) {
			/** Offline or timed out. */
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

	public CareVehWtyRes[] pullCareApi() { //DateTime fromDT, Datetime toDT, string vin, Long lastId, Long rowCount) {
		Http http = new Http();
		HttpRequest hreq = new HttpRequest();
		hreq.setEndpoint(ENDPOINT);
		hreq.setMethod('POST');
		hreq.setHeader('Content-Type', 'application/json');
		CareVehWtyReq req = new CareVehWtyReq();
		req.Company = '028';
		req.UserName = USERNAME;
		req.Password = PASSWORD;
		req.DateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ'); // Timezone adjusted based on calling user profile
		req.DateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');	// Timezone adjusted based on calling user profile
		req.ChassisNo = this.vin;
		req.LastId = this.lastId;
		req.RowCount = this.rowCount;
		hreq.setBody(JSON.serialize(req, false));
		hreq.setTimeout(120000);

		/** Prep API request for exception email */
		api = new SQL_API_Base.API_DEBUG();
		api.parse(hreq, new string[] { 'Content-Type' });

		CareVehWtyRes[] res = new CareVehWtyRes[]{};
		HttpResponse hres;
		try {
			hres = http.send(hreq);
			api.parse(hres);
			if (hres.getStatusCode() == 200) {
				res = (CareVehWtyRes[]) JSON.deserialize(hres.getBody(), CareVehWtyRes[].class);
				api?.parse(res);
			}
			else { throw new ExternalObjectException(api?.Response); }
		}
		catch (Exception e) { throw e; }
		finally { System.debug(api?.toString()); }

		return res;
	}

	public void upsertVehWty(CareVehWtyRes[] vwos) {
		SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
		/** Initialises mapping */
		initMaps(vwos);

		Map<string, VehicleWarranty__c> upsertList = new Map<string, VehicleWarranty__c>();
		// VehicleWarranty__c[] upsertList = new VehicleWarranty__c[]{};
		for (CareVehWtyRes vwo :vwos) {
			string name = string.format('{0}-{1}', new string[] { vwo.ChassisNo, vwo.ContractCode });
			Id cmpId = mapCompany.get(vwo.CompanyCode)?.Id;
			string keyWtyPkg = String.format('{0}-{1}', new string[] { vwo.CompanyCode, vwo.ContractCode });
			Id wpId = mapWtyPkg.get(keyWtyPkg)?.Id;
			Id vehId = mapVehicle.get(vwo.ChassisNo)?.Id;
			string keyVehWty = String.join(new string[] { vwo.CompanyCode, vwo.ChassisNo, vwo.ContractCode }, '-');

			if (mapVehWty.containsKey(keyVehWty)) {
				System.debug('contains: ' + keyVehWty);
				VehicleWarranty__c vw = mapVehWty.get(keyVehWty);
				if (vw.Distance__c != vwo.Distance || vw.Duration__c != vwo.Duration
						|| vw.DateStart__c != Util.validDate(vwo.StartDate.date())
						|| vw.DateEnd__c != Util.validDate(vwo.EndDate.date())
						|| vw.Company__c != cmpId
						|| vw.Vehicle__c != vehId || vw.WarrantyPackage__c != wpId) {

					if (vw.Distance__c != vwo.Distance)		{ vw.Distance__c = vwo.Distance; }
					if (vw.Duration__c != vwo.Duration)		{ vw.Duration__c = vwo.Duration; }
					if (vw.DateStart__c != Util.validDate(vwo.StartDate.date()))
															{ vw.DateStart__c = vwo.StartDate.date(); }
					if (vw.DateEnd__c != Util.validDate(vwo.EndDate.date()))
															{ vw.DateEnd__c = vwo.EndDate.date(); }
					if (cmpId != null && vw.Company__c != cmpId)
															{ vw.Company__c = cmpId; }
					if (vehId != null && vw.Vehicle__c != vehId)
															{ vw.Vehicle__c = vehId; }
					if (wpId != null && vw.WarrantyPackage__c != wpId)
															{ vw.WarrantyPackage__c = wpId; }
					vw.ExternalId__c = keyVehWty;
					
					// upsertList.add(vw);
					upsertList.put(keyVehWty, vw);
					lt.UpdateOne(); rt.UpdateOne();
				}
				else { lt.MatchOne(); rt.MatchOne(); }
			}
			else { 
				System.debug('new: ' + keyVehWty);
				VehicleWarranty__c vw = new VehicleWarranty__c(
					Name = name
					, ChassisNo__c = vwo.ChassisNo
					, CompanyCode__c = vwo.CompanyCode
					, Company__c = cmpId
					, ContractCode__c = vwo.ContractCode
					, WarrantyPackage__c = wpId
					, Distance__c = vwo.Distance
					, Duration__c = vwo.Duration
					, DateEnd__c = Util.validDate(vwo.EndDate?.date())
					, DateStart__c = Util.validDate(vwo.StartDate?.date())
					, Vehicle__c = vehId
					, ExternalId__c = keyVehWty
				);
				// upsertList.add(vw);
				upsertList.put(keyVehWty, vw);
				lt.AddOne(); rt.AddOne();
			}
		}
		System.debug('upsertList: ' + JSON.serialize(upsertList));
		if (upsertList.values().size() > 0) {
			Database.UpsertResult[] urs = Database.upsert(upsertList.values(), false);
			string err = CommonMethodsLibrary.emailResultFailure(
							urs, upsertList.values(), 'upsertVehWty (upsertList)'
							, JOB_NAME, new User[] { SQL_API_Base.USER_CUR }, false);
			if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
		}
		/** Record lastId */
		if (recordId.size() > 0) {
			recordId.sort();
			this.lastId = recordId[recordId.size() - 1];
		}

		System.debug('Upsert Current: ' + JSON.serialize(lt));
	}

	private void initMaps(CareVehWtyRes[] vwos) {
		/** Gather all lookup list */
		Set<string> co = new Set<string>();
		Set<string> vin = new Set<string>();
		Set<string> wpid = new Set<string>();
		Set<string> vwid = new Set<string>();

		recordId = new Long[]{};
		for (CareVehWtyRes vwo :vwos) {
			if (String.isNotBlank(vwo.CompanyCode)) { co.add(vwo.CompanyCode); }
			if (String.isNotBlank(vwo.ChassisNo))	{ vin.add(vwo.ChassisNo); }
			string wpKey = String.format('{0}-{1}', new string[] { vwo.CompanyCode, vwo.ContractCode });
			if (String.isNotBlank(wpKey))			{ wpid.add(wpKey); }
			/** Self forming key + % until API is updated */
			string vwKey = String.join(new string[] { vwo.CompanyCode, vwo.ChassisNo, vwo.ContractCode }, '-') + '%';
			// if (String.isNotBlank(vwo.ExternalId))	{ vwid.add(vwo.ExternalId); }
			if (String.isNotBlank(vwKey))			{ vwid.add(vwKey); }
			recordId.add(vwo.Id);
		}
		/** CompanyCode => Company__r.Name */
		mapCompany = new Map<string, Company__c>();
		for (Company__c cmp :[SELECT Id, Name, Description__c FROM Company__c WHERE Name IN :co]) {
			if (!mapCompany.containsKey(cmp.Name)) { mapCompany.put(cmp.Name, cmp); }
		}
		/** ChassisNo => Vehicle__r.Name */
		mapVehicle = new Map<string, Vehicle__c>();
		for (Vehicle__c v :[SELECT Id, Name FROM Vehicle__c WHERE Name IN :vin]) {
			if (!mapVehicle.containsKey(v.Name)) { mapVehicle.put(v.Name, v); }
		}
		/** CompanyCode + '-' + ContractCode => WarrantyPackage__r.ExternalId__c */
		mapWtyPkg = new Map<string, WarrantyPackage__c>();
		for (WarrantyPackage__c wp :[SELECT Id, Name, CompanyCode__c, Description__c, ExternalId__c FROM WarrantyPackage__c WHERE ExternalId__c IN :wpid]) {
			if (!mapWtyPkg.containsKey(wp.ExternalId__c)) { mapWtyPkg.put(wp.ExternalId__c, wp); }
		}
		/** ExternalId => VehicleWarranty__r.ExternalId__c */
		mapVehWty = new Map<string, VehicleWarranty__c>();
		VehicleWarranty__c[] vws = [
			SELECT Id, Name, ChassisNo__c, Company__c, CompanyCode__c
				, ContractCode__c, Distance__c, Duration__c, DateEnd__c
				, DateStart__c, ExternalId__c, Vehicle__c, WarrantyPackage__c
			FROM VehicleWarranty__c WHERE ExternalId__c LIKE :vwid
		];
		for (VehicleWarranty__c vw :vws) {
			string vwKey = String.join(new string[] { vw.CompanyCode__c, vw.ChassisNo__c, vw.ContractCode__c }, '-');
			// if (!mapVehWty.containsKey(vwKey)) { mapVehWty.put(vwKey, vw); }
			System.debug('put: ' + vw.ExternalId__c);
			mapVehWty.put(vwKey, vw);
		}
		System.debug('mapVehWty: ' + JSON.serialize(mapVehWty));
	}


	public class CareVehWtyReq {
		public string Company;
		public string Username;
		public string Password;
		public Long LastId;
		public Long RowCount;
		public string DateFrom;
		public string DateTo;
		public string[] ChassisNo;
		public string ContractCode;
	}

	public class CareVehWtyRes {
		public Long Id;
		public string Region;
		public Integer CompanyId;
		public string CompanyCode;
		public string CompanyName;
		public string Source;
		public string ChassisNo;
		public string ContractId;
		public string ContractCode;
		public string ContractName;
		public Integer Duration;
		public Integer Distance;
		public Datetime StartDate;
		public Datetime EndDate;
		public string ExternalId;
	}


}