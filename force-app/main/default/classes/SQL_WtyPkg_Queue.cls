global class SQL_WtyPkg_Queue implements Queueable, Database.AllowsCallouts {
	private static String USERNAME = SQL_API_Base.USERNAME;
	private static String PASSWORD = SQL_API_Base.PASSWORD;
	private static String ENDPOINT = SQL_API_Base.ENDPOINT + 'v1/contract/get';
    private static string JOB_NAME = SQL_API_Base.QUEUE_PKGE;


	/** Mapping objects */
	private static Map<string, Company__c>			mapCompany;
	private static Map<string, WarrantyPackage__c>	mapWtyPkg;

	private static Integer[] recordId;
	private static CareWtyPkgRes[] respWtyPkgs;

	/** Email Diagnostic */
	private static SQL_API_Base.API_DEBUG api;
	private static string[] errEmail = new List<string>();

	public DateTime dateFrom;
	public DateTime dateTo;
	public Integer lastId = 0;
	public Integer rowCount = 1000;
	public final Integer minRowCount = 200;
	public Boolean followOnToVehWty = false;
	public Boolean sendCompletionEmail = false;
	public SQL_API_Base.RowTracking rt = new SQL_API_Base.RowTracking();

	public SQL_WtyPkg_Queue() { this.dateFrom = SQL_API_Base.getRunTime(JOB_NAME); }

	public void execute(QueueableContext context) {
		try {
			System.debug('Job: ' + JOB_NAME + ': ' + JSON.serialize(this));

			AsyncApexJob[] jobs = [
				SELECT Id FROM AsyncApexJob
				WHERE Status IN ('Queued', 'Processing')
					AND JobType = 'Queueable'
					AND CreatedDate > :SQL_API_Base.RETRY_LIMIT
					AND ApexClass.Name = :JOB_NAME
			];
			if ((lastId != null || lastId == 0) && jobs.size() > 1) { return; }

			respWtyPkgs = pullCareApi();
			if (respWtyPkgs.size() > 0) {
				upsertWtyPkg(respWtyPkgs);
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
				if (this.followOnToVehWty) {
					SQL_VehWty_Queue q = new SQL_VehWty_Queue();
					q.dateTo = this.dateTo;
					q.sendCompletionEmail = this.sendCompletionEmail;
					if (!Test.isRunningTest()) { System.enqueueJob(q); }
				}
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

	public CareWtyPkgRes[] pullCareApi() {
		Http http = new Http();
		HttpRequest hreq = new HttpRequest();
		hreq.setEndpoint(ENDPOINT);
		hreq.setMethod('POST');
		hreq.setHeader('Content-Type', 'application/json');
		CareWtyPkgReq req = new CareWtyPkgReq();
		req.Company = '028';
		req.UserName = USERNAME;
		req.Password = PASSWORD;
		req.DateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ'); // Timezone adjusted based on calling user profile
		req.DateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');	// Timezone adjusted based on calling user profile
		req.LastId = lastId;
		req.RowCount = rowCount;
		hreq.setBody(JSON.serialize(req, false));
		hreq.setTimeout(120000);
		
		/** Prep API request for exception email */
		api = new SQL_API_Base.API_DEBUG();
		api.parse(hreq, new string[] { 'Content-Type' });

		CareWtyPkgRes[] res = new CareWtyPkgRes[]{};
		HttpResponse hres;
		try {
			hres = http.send(hreq);
			api.parse(hres);
			if (hres.getStatusCode() == 200) {
				res = (CareWtyPkgRes[]) JSON.deserialize(hres.getBody(), CareWtyPkgRes[].class);
				api.parse(res);
			}
			else { throw new ExternalObjectException(api?.Response); }
		}
		catch (Exception e) { throw e; }
		finally { System.debug(api?.toString()); }

		return res;
	}

	public void upsertWtyPkg(CareWtyPkgRes[] wpos) {
		SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
		/** Initialises mapping */
		initMaps(wpos);

		WarrantyPackage__c[] upsertList = new WarrantyPackage__c[]{};
		for (CareWtyPkgRes wpo :wpos) {
			Id cmpId = mapCompany.get(wpo.CompanyCode)?.Id;
			
			if (mapWtyPkg.containsKey(wpo.ExternalId)) {
				WarrantyPackage__c wp = mapWtyPkg.get(wpo.ExternalId);
				if (wp.Description__c != wpo.ContractName || wp.Company__c != cmpId) {
					if (wp.Description__c != wpo.ContractName) 	{ wp.Description__c = wpo.ContractName; }
					if (cmpId != null && wp.Company__c != cmpId){ wp.Company__c = cmpId; }

					upsertList.add(wp);
					lt.UpdateOne(); rt.UpdateOne();
				}
				else { lt.MatchOne(); rt.MatchOne(); }
			}
			else {
				WarrantyPackage__c wp = new WarrantyPackage__c(
					Name = wpo.ContractCode
					, CompanyCode__c = wpo.CompanyCode
					, Company__c = cmpId
					, Description__c = wpo.ContractName
					, ExternalId__c = wpo.ExternalId
				);
				upsertList.add(wp);
				lt.AddOne(); rt.AddOne();
			}
		}

		if (upsertList.size() > 0) {
			Database.UpsertResult[] urs = Database.upsert(upsertList, false);
			String err = CommonMethodsLibrary.emailResultFailure(
							urs, upsertList, 'upsertWtyPkg (upsertList)'
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

	private void initMaps(CareWtyPkgRes[] wpos) {
		/** Gather all lookup list */
		Set<string> co = new Set<string>();
		Set<string> wpid = new Set<string>();
		recordId = new Integer[]{};
		for (CareWtyPkgRes wpo :wpos) {
			if (String.isNotBlank(wpo.CompanyCode)) { co.add(wpo.CompanyCode); }
			if (String.isNotBlank(wpo.ExternalId))	{ wpid.add(wpo.ExternalId); }
			recordId.add(wpo.Id);
		}
		/** CompanyCode => Company__r.Name */
		mapCompany = new Map<string, Company__c>();
		for (Company__c cmp :[SELECT Id, Name, Description__c FROM Company__c WHERE Name IN :co]) {
			if (!mapCompany.containsKey(cmp.Name)) { mapCompany.put(cmp.Name, cmp); }
		}
		/** ExternalId => WarrantyPackage__r.ExternalId__c */
		mapWtyPkg = new Map<string, WarrantyPackage__c>();
		for (WarrantyPackage__c wp :[SELECT Id, Name, CompanyCode__c, Description__c, Company__c, ExternalId__c FROM WarrantyPackage__c WHERE ExternalId__c IN :wpid]) {
			if (!mapWtyPkg.containsKey(wp.ExternalId__c)) { mapWtyPkg.put(wp.ExternalId__c, wp); }
		}
	}

	public class CareWtyPkgReq {
		public string Company;
		public string Username;
		public string Password;
		public Integer LastId;
		public Integer RowCount;
		public string DateFrom;
		public string DateTo;
	}

	public class CareWtyPkgRes {
		public Integer Id;
		public string Region;
		public Integer CompanyId;
		public string CompanyCode;
		public string CompanyName;
		public string ContractCode;
		public string ContractName;
		public string ExternalId;
	}

}