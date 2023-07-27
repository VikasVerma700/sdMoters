global class SQL_Payment_Queue implements Database.Batchable<SObject>, Queueable, Database.AllowsCallouts {
    private static final string USERNAME = SQL_API_Base.USERNAME;
    private static final string PASSWORD = SQL_API_Base.PASSWORD;
    private static final string ENDPOINT = SQL_API_Base.ENDPOINT + 'v1/ro/invoice/payment/list';
    private static final string JOB_NAME = SQL_API_Base.QUEUE_PAYM;
	private static final Id rtCounter = Schema.SObjectType.PaymentDetail__c.getRecordTypeInfosByName().get('Service Invoice (counter)').getRecordTypeId();

	/** Mapping objects */
	private static Map<string, Company__c>			mapCompany;
	private static Map<string, Workshop__c>			mapWorkshop;
	private static Map<string, Account>				mapAccount;
	private static Map<string, ServiceInvoice__c>	mapSvcInv;
	private static Map<string, PaymentDetail__c>	mapPayment;

	private static string[] paymentKeys;
	private static PaymentRes[] respPaym;

	/** Email Diagnostic */
	private static SQL_API_Base.API_DEBUG api;
	private static string[] errEmail = new string[]{};
	private static PaymentRes[] skipRecords = new PaymentRes[]{};

    public string[] paymentKey = null;
    public string[] invKey = null;
    public string[] roKey = null;
	public DateTime dateFrom;
    public DateTime dateTo;
    public string lastKey = null;
    public Long rowCount = 1000;
    public final Integer minRowCount = 10;
	public Boolean followOnToBatch = false;
    public Boolean followOnToNext = false; // no next process in queue
	public Boolean sendCompletionEmail = false;
    public SQL_API_Base.RowTracking rt = new SQL_API_Base.RowTracking();

	public SQL_Payment_Queue() { this.dateFrom = SQL_API_Base.getRunTime(JOB_NAME); }

	/** Apex Job PULL Payments by payment date */
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
			if (String.isBlank(lastKey) && jobs.size() > 1) {
				if (this.followOnToNext) {
					// no next job to queue
				}
				if (this.followOnToBatch) {
					/** Skip batch job when it still processing. */
					jobs = [
						SELECT Id, ApexClass.Name, JobType, Status, CreatedDate
						FROM AsyncApexJob
						WHERE Status IN ('Queued', 'Processing')
							AND JobType IN ('BatchApex', 'BatchApexWorker')
							AND ApexClass.Name = :JOB_NAME
					];
					if (jobs?.size() > 0) {	return;	}
					/**
					 * SQL_Payment_Queue batch job to pull Payments for Service Invoice where:
					 * - Invoice amount > 0
					 * - Invoice payment status != SUCCESS
					 * - Account No = C0000002
					 */
					// SQL_Payment_Queue q = new SQL_Payment_Queue();
					// q.dateTo = this.dateTo;
					// q.sendCompletionEmail = this.sendCompletionEmail;
					if (!Test.isRunningTest()) { Database.executeBatch(this, 200); }
				}
				return;
			}

			respPaym = callCareApi();
			if (respPaym.size() > 0) {
				upsertPaym(respPaym);
				System.debug('Upsert Total: ' + JSON.serialize(rt));
				if (!Test.isRunningTest()) { System.enqueueJob(this); }
			}
			else {
				/** 0 (zero) record, send completion message */
				if (this.dateFrom == null && this.dateTo == null && sendCompletionEmail) {
					string subject = Envir.subject + ': Job complete!';
					string body = (JOB_NAME + '\n\n' + JSON.serialize(this) + '\n\nJob completed!').replace('\n', '<br />');
					Util.sendEmail(subject, body);
				}
				if (this.dateTo != null) { SQL_API_Base.updateRun(JOB_NAME, this.dateTo); }
				if (this.followOnToNext) {
					// no next job to queue
				}
				if (this.followOnToBatch) {
					/** Skip batch job when it still processing. */
					jobs = [
						SELECT Id, ApexClass.Name, JobType, Status, CreatedDate
						FROM AsyncApexJob
						WHERE Status IN ('Queued', 'Processing')
							AND JobType IN ('BatchApex', 'BatchApexWorker')
							AND ApexClass.Name = :JOB_NAME
					];
					if (jobs?.size() > 0) {	return;	}
					/**
					 * SQL_Payment_Queue batch job to pull Payments for Service Invoice where:
					 * - Invoice amount > 0
					 * - Invoice payment status != SUCCESS
					 * - Account No = C0000002
					 */
					// SQL_Payment_Queue q = new SQL_Payment_Queue();
					// q.dateTo = this.dateTo;
					// q.sendCompletionEmail = this.sendCompletionEmail;
					if (!Test.isRunningTest()) { Database.executeBatch(this, 200); }
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
				String body = CommonMethodsLibrary.constructErrEmail(header, footer, error);
                errEmail.add(body);
            }
        }
		catch (Exception e) {
			string header = JOB_NAME;
			string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
			string error = JSON.serialize(this) + '\n\nAPI:\n' + api?.toString();
			String body = CommonMethodsLibrary.constructErrEmail(header, footer, error);
			errEmail.add(body);
		}
		finally {
			if (errEmail != null && errEmail.size() > 0) {
				CommonMethodsLibrary.sendErrorEmail(new User[] { SQL_API_Base.USER_CUR }, String.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
			}
			if (skipRecords != null && skipRecords.size() > 0) {
				String subject = Envir.subject + ' Skipped Payments.';
				String body = CommonMethodsLibrary.constructErrEmail(JOB_NAME, 'Job completed!', JSON.serialize(this) + '\n\n' + JSON.serialize(skipRecords));
				// CommonMethodsLibrary.sendErrorEmail(new User[] { SQL_API_Base.CUR_USER }, body, true, subject);					
			}
		}
	}

	public PaymentRes[] callCareApi() {
		Http http = new Http();
        HttpRequest hreq = new HttpRequest();
        hreq.setEndpoint(ENDPOINT);
        hreq.setMethod('POST');
        hreq.setHeader('Content-Type', 'application/json');
        PaymentReq req = new PaymentReq();
        req.Company = '028';
        req.UserName = USERNAME;
        req.Password = PASSWORD;
		req.DateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ'); // Timezone adjusted based on calling user profile
		req.DateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');	// Timezone adjusted based on calling user profile
        req.paymentKey = paymentKey;
        req.InvKey = invKey;
        req.RoKey = roKey;
        req.LastKey = lastKey;
		req.RowCount = rowCount;
        hreq.setBody(JSON.serialize(req, false));
        hreq.setTimeout(120000);

		/** Prep API request for exception email */
		api = new SQL_API_Base.API_DEBUG();
		api.parse(hreq, new string[] { 'Content-Type' });

		PaymentRes[] res = new PaymentRes[]{};
        HttpResponse hres;
		try {
			hres = http.send(hreq);
			api.parse(hres);
			if (hres.getStatusCode() == 200) {
				res = (PaymentRes[]) JSON.deserialize(hres.getBody(), PaymentRes[].class);
				api.parse(res);
			}
			else { throw new ExternalObjectException(api?.Response); }
		}
		catch (Exception e) { throw e; }
		finally { System.debug(api?.toString()); }

		return res;	
	}

	public void upsertPaym(PaymentRes[] pos) {
		SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
        /** Initialises mapping */
        initMaps(pos);

        Map<string, PaymentDetail__c> mapUpsertPo = new Map<string, PaymentDetail__c>();
		for (PaymentRes po :pos) {
	        PaymentDetail__c pd;
			if (mapPayment.containsKey(po.paymentKey)) {
				/** Update existing payment detail */
				pd = mapPayment.get(po.paymentKey);
				// if (String.isBlank(pd.CreatedFrom__c)) { pd.CreatedFrom__c = 'Autoline'; }
				setValues(po, pd);
				if (pd.PayForServiceInvoice__c == null) {
					// skip record creation when no associated invoice found in SF.
					if (po.accountNo == 'C0000002') { skipRecords.add(po); }
					lt.SkipOne(); rt.SkipOne();
					continue;
				}
				if (!mapUpsertPo.containsKey(po.paymentKey)) {
					mapUpsertPo.put(po.paymentKey, pd);
					lt.UpdateOne(); rt.UpdateOne();
				}
			}
			else {
				/** Insert new Payment Detail with Record Type = Service Invoice (counter) */
				pd = new PaymentDetail__c(RecordTypeId = rtCounter);
				setValues(po, pd);
				if (pd == null || pd.PayForServiceInvoice__c == null) { 
					// skip record creation when no associated invoice found in SF.
					if (po.accountNo == 'C0000002') { skipRecords.add(po); }
					lt.SkipOne(); rt.SkipOne();
					continue;
				}
				if (!mapUpsertPo.containsKey(po.paymentKey)) {
					mapUpsertPo.put(po.paymentKey, pd);
					lt.AddOne(); rt.AddOne();
				}
			}
        }

        PaymentDetail__c[] upsertPaym = mapUpsertPo.values();
        if (upsertPaym.size() > 0) {
			Database.UpsertResult[] ur = Database.upsert(upsertPaym, false);
            String err = CommonMethodsLibrary.emailResultFailure(
							ur, upsertPaym, 'upsertPaym(PaymentRes[])'
							, JOB_NAME, new User[] { SQL_API_Base.USER_CUR }, false);
            if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
        }
        /** Record lastKey */
        if (paymentKeys.size() > 0) {
            paymentKeys.sort();
            this.lastKey = paymentKeys[paymentKeys.size() - 1];
        }

		System.debug('Upsert Current: ' + JSON.serialize(lt));
	}

	private void initMaps(PaymentRes[] pos) {
        /** Gather all lookup list */
        Set<string> comp = new Set<string>(); // company
        Set<string> wshp = new Set<string>(); // workshop
		Set<string> paym = new Set<string>(); // payment details
        Set<string> sinv = new Set<string>(); // service invoice
		Set<string> rord = new Set<string>(); // repair order
        paymentKeys = new List<string>();
        for (PaymentRes po :pos) {
            if (String.isNotBlank(po.companyCode))      { comp.add(po.companyCode); }
            if (String.isNotBlank(po.branchCode))       { wshp.add(po.branchCode); }
            if (String.isNotBlank(po.paymentKey))       { paym.add(po.paymentKey); }
			if (String.isNotBlank(po.invKey))			{ sinv.add(po.invKey); }
            if (String.isNotBlank(po.roKey))            { rord.add(po.roKey); }
            paymentKeys.add(po.paymentKey);
        }
        /** companyCode => Company__r.Name */
        mapCompany = new Map<string, Company__c>();
        for (Company__c c :[SELECT Id, Name FROM Company__c WHERE Name IN :comp]) {
            mapCompany.put(c.Name, c);
        }
        /** branchCode => Workshop__r.Name */
        mapWorkshop = new Map<string, Workshop__c>();
        for (Workshop__c w: [SELECT Id, Name, Company__r.Name FROM Workshop__c WHERE Name IN :wshp AND Company__r.Name IN :comp]) {
            string keyWs = String.format('{0}_{1}', new string[] { w.Company__r.Name, w.Name });
            mapWorkshop.put(keyWs, w);
        }
		/** paymentKey => PaymentDetail__c.Name */
		mapPayment = new Map<string, PaymentDetail__c>();
		for (PaymentDetail__c pd :[SELECT Id, Name, Timestamp__c, CreatedFrom__c FROM PaymentDetail__c WHERE RecordTypeId = :rtCounter AND Name IN :paym FOR UPDATE]) {
			mapPayment.put(pd.Name, pd);
		}
		/** invKey => ServiceInvoice__c.invKey__c */
		mapSvcInv = new Map<string, ServiceInvoice__c>();
		for (ServiceInvoice__c si :[SELECT Id, Name, InvoiceKey__c, Account__c, PaymentTimestamp__c FROM ServiceInvoice__c WHERE InvoiceKey__c IN :sinv]) {
			mapSvcInv.put(si.InvoiceKey__c, si);
		}
    }

	private Boolean setValues(PaymentRes objFr, PaymentDetail__c objTo) {
		if (objTo == null) { return false; }
		objTo.Name = objFr.paymentKey;

		/** Populate lookups */
		if (mapCompany.containsKey(objFr.companyCode))	{ objTo.Company__c = mapCompany.get(objFr.companyCode).Id; }
        string keyWs = String.format('{0}_{1}', new string[] { objFr.companyCode, objFr.branchCode });
        if (mapWorkshop.containsKey(keyWs))             { objTo.Workshop__c = mapWorkshop.get(keyWs).Id; }
		ServiceInvoice__c si;
		if (mapSvcInv.containsKey(objFr.invKey)) { 
			si = mapSvcInv.get(objFr.invKey);
			objTo.PayForServiceInvoice__c = si.Id;
			objTo.Account__c = si.Account__c;
		}

		objTo.Amount__c = objFr.paymentValue;
		objTo.AmountVat__c = objFr.paymentVatValue;
		objTo.BankRefNumber__c = String.valueOf(objFr.bankAccount);
		objTo.CurrencyCode__c = 'MYR'; // assume
		objTo.HashValue1__c = String.valueOf(objFr.referenceNumber);
		objTo.HashValue2__c = String.valueOf(objFr.matchNumber);
		objTo.PaymentMethod__c = objFr.paymentType;
		objTo.RespTime__c = String.valueOf(objFr.paymentDate.date());
		if (objTo.Timestamp__c == null) { objTo.Timestamp__c = Datetime.newInstance(objFr.paymentDate.date(), Datetime.now().time()); }
		objTo.SequenceNumber__c = objFr.seq;
		objTo.OrderNumber__c = objFr.referenceName;
		if (String.isBlank(objTo.CreatedFrom__c)) { objTo.CreatedFrom__c = 'Autoline'; }

		return true;
	}

	/** Batchable PULL Payments where invoice value > 0 && payment status != SUCCESS */
	public Database.QueryLocator start(Database.BatchableContext BC) {
		System.debug('Batch: SQL_Payment_Queue.start()');

		/** Pull: retrieve payment by affected service invoice */
		String query = Database.getQueryLocator([
			SELECT Id, Name, InvoiceKey__c
			FROM ServiceInvoice__c
			WHERE InvoiceValue__c > 0
				AND AccountNumber__c = 'C0000002'
				AND PaymentStatus__c != 'SUCCESS'
			LIMIT 200
		]).getQuery().Replace('LIMIT 200', ' ');
		if (invKey != null && invKey.size() > 0) {
			query += 'AND InvoiceKey__c IN :invKey ';
		}
		if (roKey != null && roKey.size() > 0) {
			query += 'AND RoKey__c IN :roKey ';
		}
		query += 'ORDER BY LastModifiedDate';

		return Database.getQueryLocator(query);
	}
	public void execute(Database.BatchableContext BC, List<SObject> scope) {
		System.debug('Job: ' + JOB_NAME + ' (' + scope.size() + '): ' + JSON.serialize(this));
		try {
			if (scope.size() > 0) {
				SQL_Payment_Queue q = new SQL_Payment_Queue();
				q.dateFrom = q.dateTo = null;
				q.sendCompletionEmail = false;
				q.followOnToNext = false;	// do not follow up to batch job, otherwise this is a !! cyclic execution.
				q.invKey = new string[]{};
				for (SObject sc :scope) {
					ServiceInvoice__c si = (ServiceInvoice__c)sc;
					if (String.isNotBlank(si.InvoiceKey__c)) { q.invKey.add(si.InvoiceKey__c); }
				}
				/** Queue job to retrieve from API */
				// if (!Test.isRunningTest()) { System.enqueueJob(q); }
				// OR
				respPaym = q.callCareApi();
				if (respPaym.size() > 0) { upsertPaym(respPaym); }
			}
		}
		catch (Exception e) {
			string header = JOB_NAME;
			string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
			string error = JSON.serialize(this) + '\n\nAPI:\n' + api?.toString();
			String body = CommonMethodsLibrary.constructErrEmail(header, footer, error);
			errEmail.add(body);
		}
	}
	public void finish(Database.BatchableContext BC) {
		System.debug('Batch: SQL_Payment_Queue.finish()');
		if (errEmail != null && errEmail.size() > 0) {
			CommonMethodsLibrary.sendErrorEmail(new User[] { SQL_API_Base.USER_CUR }, String.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
		}
		if (sendCompletionEmail) {
			string subject = Envir.subject + ': Job complete!';
			string body = (JOB_NAME + '\n\n' + JSON.serialize(this) + '\n\nJob completed!').replace('\n', '<br />');
			Util.sendEmail(subject, body);
		}
	}

	public virtual class PaymentReq {
		public string[] paymentKey;
		public string[] invKey;
		public string[] roKey;
		public string LastKey;
		public Long RowCount;
		public string DateFrom;
		public string DateTo;
		public string Company;
		public string Username;
		public string Password;
	}

	public virtual class PaymentRes {
		public string paymentKey;
		public string invKey;
		public string roKey;
		public string externalId;
		public string companyCode;
		public string branchCode;
		public Integer wipNo;
		public Integer invNo;
		public Integer seq;
		public string accountNo;
		public Long bankAccount;
		public DateTime paymentDate;
		public string paymentInvoiceStatus;
		public string paymentType;
		public string paymentPostStatus;
		public string referenceName;
		public Long referenceNumber;
		public Decimal paymentValue;
		public Decimal paymentVatValue;
		public string paymentVatCode;
		public Long matchNumber;
	}

}