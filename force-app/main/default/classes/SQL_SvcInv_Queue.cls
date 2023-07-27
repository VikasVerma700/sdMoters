global class SQL_SvcInv_Queue implements Queueable, Database.AllowsCallouts {
    private static final string USERNAME = SQL_API_Base.USERNAME;
    private static final string PASSWORD = SQL_API_Base.PASSWORD;
    private static final string ENDPOINT = SQL_API_Base.ENDPOINT + 'v1/ro/invoice/list';
    private static final string JOB_NAME = SQL_API_Base.QUEUE_INVO;

    /** Mapping objects */
	private static Map<string, Company__c> mapCompany;
	private static Map<string, Workshop__c> mapWorkshop;
	private static Map<string, Account> mapAccount;
	private static Map<string, Vehicle__c> mapVehicle;
	private static Map<string, ServiceOrder__c> mapRepairOrder;
	private static Map<string, ServiceInvoice__c> mapSvcInv;

	private static string[] invKeys;
    private static ServiceInvoiceRes[] respSvcInv;

	/** Email Diagnostic */
	private static SQL_API_Base.API_DEBUG api;
	private static string[] errEmail = new List<string>();

    public DateTime dateFrom;
    public DateTime dateTo;
    public string[] roKey = null;
    public string[] chassisNo = null;
    public string[] invKey = null;
    public string lastKey = null;
    public Long rowCount = 1000;
    public final Integer minRowCount = 10;
    public Boolean followOnToFile = false;
    public SQL_API_Base.RowTracking rt = new SQL_API_Base.RowTracking();


    public SQL_SvcInv_Queue() { this.dateFrom = SQL_API_Base.getRunTime(JOB_NAME); }

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
            if (String.isBlank(lastKey) && jobs.size() > 1) { return; }
            // if (lastKey != null && jobs.size() > 1) {
			// 	System.debug('Skipping ' + JOB_NAME + ' queue.');
			// 	if (this.followOnToFile) {
            //         SQL_File_Queue f = new SQL_File_Queue();
            //         f.dateTo = this.dateTo;
			// 		f.followOnToBatch = true;
			// 		f.followOnToPayment = true;
            //         if (!Test.isRunningTest()) { System.enqueueJob(f); }
            //     }
			// 	return;
			// }
            
			respSvcInv = callCareApi();
            if (respSvcInv.size() > 0) {
                upsertSi(respSvcInv);
				System.debug('Upsert Total: ' + JSON.serialize(rt));
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
                if (this.followOnToFile) {
                    SQL_File_Queue q = new SQL_File_Queue();
					q.dateFrom = (this.dateFrom == null ? null : q.dateFrom); // indicative if full pull is requested.
                    q.dateTo = this.dateTo;
					q.followOnToBatch = true;
					q.followOnToPayment = true;
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
    
    public ServiceInvoiceRes[] callCareApi() {
        Http http = new Http();
        HttpRequest hreq = new HttpRequest();
        hreq.setEndpoint(ENDPOINT);
        hreq.setMethod('POST');
        hreq.setHeader('Content-Type', 'application/json');
        ServiceInvoiceReq req = new ServiceInvoiceReq();
        req.Company = '028';
        req.UserName = USERNAME;
        req.Password = PASSWORD;
        // req.DateFrom = (fromDT == null ? fromDT : fromDT.addHours(SQL_API_Base.TIMEZONE));
        // req.DateTo = (toDT == null ? toDT : toDT.addHours(SQL_API_Base.TIMEZONE));
		req.DateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ'); // Timezone adjusted based on calling user profile
		req.DateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');	// Timezone adjusted based on calling user profile
        req.RoKey = this.roKey;
        req.ChassisNo = this.chassisNo;
        req.InvKey = this.invKey;
        req.LastKey = this.lastKey;
		req.RowCount = this.rowCount;
        hreq.setBody(JSON.serialize(req, false));
        hreq.setTimeout(120000);

		/** Prep API request for exception email */
		api = new SQL_API_Base.API_DEBUG();
		api.parse(hreq, new string[] { 'Content-Type' });

        ServiceInvoiceRes[] ret = new ServiceInvoiceRes[]{};
        HttpResponse hres;
		try {
			hres = http.send(hreq);
			api.parse(hres);
			if (hres.getStatusCode() == 200) {
				ret = (ServiceInvoiceRes[]) JSON.deserialize(hres.getBody(), ServiceInvoiceRes[].class);
				api.parse(ret);
			}
			else { throw new ExternalObjectException(api?.Response); }
		}
		catch (Exception e) { throw e; }
		finally { System.debug(api?.toString()); }
		
		return ret;
    }

    public void upsertSi(ServiceInvoiceRes[] rois) {
		SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
        /** Initialises mapping */
        initMaps(rois);

        Map<string, ServiceInvoice__c> mapUpsertSi = new Map<string, ServiceInvoice__c>();
        ServiceInvoice__c si;
        for (ServiceInvoiceRes roi :rois) {
            if (mapSvcInv.containsKey(roi.externalId)) {
                /** Update existing service invoice */
                si = mapSvcInv.get(roi.externalId);
				if (String.isBlank(si.CreatedFrom__c)) { si.CreatedFrom__c = 'Autoline'; }
				Boolean matched = setValues(roi, si);
				if (si.RepairOrder__c == null || si.Vehicle__c == null || si.Workshop__c == null) {
					lt.SkipOne(); rt.SkipOne();
					continue;
				}
				if (!mapUpsertSi.containsKey(roi.externalId)) { 
					mapUpsertSi.put(roi.externalId, si); 
				}
				if (matched) { lt.MatchOne(); rt.MatchOne(); }
				else { lt.UpdateOne(); rt.UpdateOne(); }
            }
            else {
                /** Insert new repair order */
                si = new ServiceInvoice__c();
                setValues(roi, si);
				System.debug('roi to si: ' + JSON.serialize(si));
				if (si.RepairOrder__c == null || si.Vehicle__c == null || si.Workshop__c == null) {
					lt.SkipOne(); rt.SkipOne();
					continue;
				}
                if (!mapUpsertSi.containsKey(roi.externalId)) { 
					si.CreatedFrom__c = 'Autoline';
                    mapUpsertSi.put(roi.externalId, si); 
					lt.AddOne(); rt.AddOne();
                }
                else {
                    // rt.RepairOrders.get('Matched').add(so);
                }
            }
        }

        ServiceInvoice__c[] upsertRoi = mapUpsertSi.values();
        if (upsertRoi.size() > 0) {
            Database.UpsertResult[] ur = Database.upsert(upsertRoi, false);
            String err = CommonMethodsLibrary.emailResultFailure(
							ur, upsertRoi, 'upsertSi(ServiceInvoiceRes[])'
							, JOB_NAME, new User[] { SQL_API_Base.USER_CUR }, false);
            if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
        }
        /** Record lastKey */
        if (invKeys.size() > 0) {
            invKeys.sort();
            this.lastKey = invKeys[invKeys.size() - 1];
        }

		System.debug('Upsert Current: ' + JSON.serialize(lt));
    }

    private void initMaps(ServiceInvoiceRes[] rois) {
        /** Gather all lookup list */
        Set<string> co = new Set<string>(); // company
        Set<string> ws = new Set<string>(); // workshop
        Set<string> so = new Set<string>(); // repair order
        Set<string> ve = new Set<string>(); // vehicle
        Set<string> svh = new Set<string>(); // service history
        invKeys = new List<string>();
        for (ServiceInvoiceRes roi :rois) {
            if (String.isNotBlank(roi.companyCode))      { co.add(roi.companyCode); }
            if (String.isNotBlank(roi.branchCode))       { ws.add(roi.branchCode); }
            if (String.isNotBlank(roi.roKey))            { so.add(roi.roKey); }
            if (String.isNotBlank(roi.chassisNo))        { ve.add(roi.chassisNo); }
            if (String.isNotBlank(roi.externalId))       { svh.add(roi.externalId); }
            invKeys.add(roi.invKey);
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
        /** vehChassisNo => Vehicle__r.Name */
        mapVehicle = new Map<string, Vehicle__c>();
        for (Vehicle__c v :[SELECT Id, Name FROM Vehicle__c WHERE Name IN :ve]) {
            mapVehicle.put(v.Name, v);
        }
        /** roKey => ServiceOrder__c.roKey__c */
        mapRepairOrder = new Map<string, ServiceOrder__c>();
        ServiceOrder__c[] sos = [
            SELECT
                Id, RoKey__c, Company__c, Workshop__c, Account__c, Vehicle__c, VehicleOwnership__c
            FROM ServiceOrder__c
            WHERE Company__r.Name IN :co
            AND RoKey__c IN :so
		];
		for (ServiceOrder__c sor :sos) { mapRepairOrder.put(sor.RoKey__c, sor); }
        /** externalId => ServiceInvoice__c.ExternalId__c */
        mapSvcInv = new Map<string, ServiceInvoice__c>();
        ServiceInvoice__c[] sis = [
            SELECT
				Id, Name, AccountNumber__c, Company__c, Company__r.Name
				, Workshop__c, Workshop__r.Name, RepairOrder__c, RepairOrder__r.Name
				, Vehicle__c, Vehicle__r.Name
				, InvoiceNumber__c, InvoiceDate__c, InvoiceKey__c
				, InvoiceValue__c, ServiceDetails__c, ExternalId__c, RoKey__c
				, CreatedFrom__c
            FROM ServiceInvoice__c
            WHERE ExternalId__c IN :svh
			FOR UPDATE
        ];
        for (ServiceInvoice__c si :sis) { mapSvcInv.put(si.ExternalId__c, si); }
    }

    private Boolean setValues(ServiceInvoiceRes objFr, ServiceInvoice__c objTo) {
        /** Fix for dirty phone number. */
        string regex = '[^+0-9]';

		// Following line won't return ref obj.
        // if (objTo == null) { objTo = new ServiceInvoice__c(); }
        objTo.Name = String.format('{0} {1}', new string[] { objFr.branchCode, objFr.invoiceNo });

        /** Populate lookups. */
        if (mapCompany.containsKey(objFr.companyCode))  { objTo.Company__c = mapCompany.get(objFr.companyCode).Id; }
        string keyWs = String.format('{0}_{1}', new string[] { objFr.companyCode, objFr.branchCode });
        if (mapWorkshop.containsKey(keyWs))             { objTo.Workshop__c = mapWorkshop.get(keyWs).Id; }
		if (mapVehicle.containsKey(objFr.chassisNo))    { objTo.Vehicle__c = mapVehicle.get(objFr.chassisNo).Id; }
        if (mapRepairOrder.containsKey(objFr.roKey))    {
			ServiceOrder__c ro = mapRepairOrder.get(objFr.roKey);
			// objTo.Company__c = ro.Company__c;
			// objTo.Workshop__c = ro.Workshop__c;
			objTo.RepairOrder__c = ro.Id;
			objTo.Account__c = ro.Account__c;
			objTo.Vehicle__c = ro.Vehicle__c;
			objTo.VehicleOwnership__c = ro.VehicleOwnership__c;
		}

		if (objTo.AccountNumber__c == objFr.accountNo && objTo.InvoiceDate__c == Date.valueOf(objFr.invoiceDate)
				&& objTo.InvoiceKey__c == objFr.invKey && objTo.InvoiceValue__c == objFr.invoiceValue
				&& objTo.ServiceDetails__c == objFr.serviceDetails && objTo.ExternalId__c == objFr.externalId
				&& objTo.RoKey__c == objFr.roKey) {
			return true;
		}
        objTo.AccountNumber__c = objFr.accountNo;
        objTo.InvoiceDate__c = Date.valueOf(objFr.invoiceDate);
		objTo.InvoiceNumber__c = Integer.valueOf(objFr.invoiceNo);
        objTo.InvoiceKey__c = objFr.invKey;
        objTo.InvoiceValue__c = objFr.invoiceValue;
        objTo.ServiceDetails__c = objFr.serviceDetails;
        objTo.ExternalId__c = objFr.externalId;
        objTo.RoKey__c = objFr.roKey;
		return false;
	}

	/** Button: Pull from Care API (ServiceInvoice__c) */
	Webservice static string refreshSI(Id invoiceId) {
		try {
			ServiceInvoice__c si = [SELECT Id, Name, InvoiceKey__c FROM ServiceInvoice__c WHERE Id = :invoiceId];
			if (String.isBlank(si?.InvoiceKey__c)) { return 'Error: Unable to refresh invoice (w/o Invoice Key).'; }

			SQL_SvcInv_Queue s = new SQL_SvcInv_Queue();
			s.dateFrom = s.dateTo = null;
			s.rowCount = 1;
			s.invKey = new string[] { si.InvoiceKey__c };
			ServiceInvoiceRes[] hres = s.callCareApi();
			if (hres == null || hres.size() == 0) { return 'Error: Unable to find invoice for refresh.'; }
			s.upsertSi(hres);

			/** Pull Service Invoice file */
			SQL_File_Queue f = new SQL_File_Queue();
			f.dateFrom = f.dateTo = null;
			f.wipKey = hres[0].roKey.replaceAll(hres[0].branchCode, '');
			System.enqueueJob(f);
			return 'Refreshed successfully.';
		}
		catch (QueryException e) { return 'Error: No record found with id: \'' + invoiceId + '\''; }
		catch (Exception e) { return 'Error: ' + e.getMessage() + (Envir.isSandbox ? '\n\n' + e.getStackTraceString() : ''); }
	}

    public virtual class ServiceInvoiceReq {
        public string[] RoKey;
        public string[] ChassisNo;
        public string[] InvKey;
        public string LastKey;
        public Long RowCount;
        public string DateFrom;
        public string DateTo;
        public string Company;
        public String Username;
        public String Password;
    }

    public virtual class ServiceInvoiceRes {
        public string invKey;
        public string externalId;
        public string companyCode;
        public string roKey;
        public string branchCode;
        public string accountNo;
        public string chassisNo;
        public string wipNo;
        public string serviceDetails;
        public string invoiceNo;
        public DateTime invoiceDate;
        public Decimal invoiceValue;
    }

}