global class SyncMoby08SalesOrder implements Database.AllowsCallouts, Queueable {
	private static final string USERNAME = SyncMobyApiBase.USERNAME;
    private static final string PASSWORD = SyncMobyApiBase.PASSWORD;
    private static final string ENDPOINT = SyncMobyApiBase.ENDPOINT + 'mobysf/SalesOrders';
    private static final string HEADER_AUTH = Util.genBasicAuthHeader(USERNAME, PASSWORD);
    private static final string JOB_NAME = SyncMobyApiBase.SYNC08SORD;
	private static final string CREATEDFROM = 'Autoline';
	private static final Map<string, string> SORDSTAT = new Map<string, string>{
		'A' => 'Adopted', 'B' => 'BMW Car', 'C' => 'Consigned'
		, 'D' => 'Deallocated', 'F' => 'Finished', 'I' => 'Invoice'
		, 'M' => 'Memorandum', 'O' => 'Ordered', 'R' => 'Reserved'
		, 'S' => 'Showroom', 'X' => 'Record Closed'
	};

	public string[] company = SyncMobyApiBase.COMPANY_CODE;
    public DateTime dateFrom;
    public DateTime dateTo;
    public long[] deliveryId = null;
    public long lastId = 0;
    public long rowCount = 200;
    public final Integer minRowCount = 10;
    public Boolean followOnToNext = false;
    public SQL_API_BASE.RowTracking rt = new SQL_API_Base.RowTracking();

	private static MobySalesOrderRes respSOrd;

	/** Mapping objects */
	// private static Map<string, Company__c> mapCompany;				// companyCode => Company__r.MobyCompanyCode__c
	// private static Map<Integer, Showroom__c> mapBranchById;			// branchId => MobyBranchNumber__c
	// private static Map<string, Showroom__c> mapBranchByCode;		// companyCode + branchCode => Company__r.MobyCompanyCode__c + MobyBranchCode__c
	// private static Map<Integer, Employee_Master__c> mapEmployee;	// insertUserId, updateUserId => Employee_Master__r.MobyUserNumber__c
	// private static Map<long, Account> mapAccount;					// contactId => Account.MobyContactNumber__c
	// private static Map<long, Opportunity> mapOpportunity;			// id => Opportunity.MobyOpportunityNumber__c
	private static Map<long, Booking__c> mapBooking;				// id => MobyBookingNumber__c;
	private static Map<string, Vehicle__c> mapVehicle;				// stockId => Vehicle__c.Name 
	private static Map<long, Sales_Order__c> mapSalesOrder;			// id => MobySalesOrderNumber__c;
	private static Map<string, Account> mapAccount;				// crmCustomerMagic => Account__c.DMS_Number__c
	private static long[] deliveryIds;
	
	/** Email Diagnostic */
	private static SQL_API_Base.API_DEBUG api;
	private static string[] errEmail = new List<string>();
	
    public SyncMoby08SalesOrder() {
		this.dateFrom = SQL_API_Base.getRunTime(JOB_NAME);
    }

    public void execute(QueueableContext context) {
		try {
            System.debug('Job: ' + JOB_NAME + ': ' + JSON.serialize(this));

            AsyncApexJob[] jobs = [
                SELECT Id FROM AsyncApexJob
                WHERE Status IN ('Queued', 'Processing')
                    AND JobType = 'Queueable'
                    AND ApexClass.Name = :JOB_NAME
            ];
            if ((lastId == null || lastId == 0) && jobs.size() > 1) { return; }

            respSOrd = callMobyApi();
			if (respSOrd != null  && respSOrd.salesOrders != null && respSOrd.salesOrders.size() > 0) {
                upsertSalesOrder(respSOrd);
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
                if (this.followOnToNext) {
                    // SyncMoby09 q = new SyncMoby09();
					// q.company = this.company;
					// if (this.dateFrom == null) { q.dateFrom = null; }
					// q.dateTo = this.dateTo;
					// q.followOnToNext = true;
					// if (!Test.isRunningTest()) { System.enqueueJob(q); }
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
                CommonMethodsLibrary.sendErrorEmail(new User[] { SyncMobyApiBase.USER_CUR }, String.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
            }
        }
    }

	public MobySalesOrderRes callMobyApi() {
        Http http = new Http();
        HttpRequest hreq = new HttpRequest();
        hreq.setEndpoint(ENDPOINT);
        hreq.setMethod('POST');
        hreq.setHeader('Content-Type', 'application/json');
        hreq.setHeader('Authorization', HEADER_AUTH);
        MobyBookingReq req = new MobyBookingReq();
        req.companyCode = this.company;
        // req.dateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
        // req.dateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
		req.dateFrom = this.dateFrom?.addHours(SQL_API_Base.TIMEZONE);
        req.dateTo = this.dateTo?.addHours(SQL_API_Base.TIMEZONE);
        req.id = this.deliveryId;
        req.lastKey = this.lastId;
        req.rowCount = this.rowCount;
        hreq.setBody(JSON.serialize(req, false));
        hreq.setTimeout(120000);

        /** Prep API request for exception email */
        api = new SQL_API_Base.API_DEBUG();
        api.parse(hreq, new string[] { 'Content-Type', 'Authorization' });

        MobySalesOrderRes res = new MobySalesOrderRes();
        HttpResponse hres;
        try {
            hres = http.send(hreq);
            api.parse(hres);
            if (hres.getStatusCode() == 200) {
                res = (MobySalesOrderRes) JSON.deserialize(hres.getBody(), MobySalesOrderRes.class);
                api.parse(res?.salesOrders);
            }
            else { throw new ExternalObjectException(api?.Response); }
        }
        catch (Exception e) { throw e; }
        finally { System.debug(api?.toString()); }

        return res;
    }

    public Database.UpsertResult[] upsertSalesOrder(MobySalesOrderRes res) {
        SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
        /** Initialises mapping */
        initMaps(res);
		/** Initialise dependency objects */
		initLookups(res);

        Sales_Order__c[] insertList = new List<Sales_Order__c>();
        Map<Id, Sales_Order__c> updateList = new Map<Id, Sales_Order__c>();
        // Match with order priortised
        Sales_Order__c sord;
        for (MobySalesOrder salesOrder :res.salesOrders) {
			sord = null;

			if (salesOrder.deliveryId != null) { sord = mapSalesOrder.get(salesOrder.deliveryId); }

			/** still no match */
			if (sord == null) { sord = new Sales_Order__c(); }
			setValues(salesOrder, sord);
			if (sord.Id == null) {
				insertList.add(sord);
				lt.AddOne(); rt.AddOne();
			}
			else {
				if (updateList.containsKey(sord.Id)) {
					updateList.put(sord.Id, sord);
					lt.MatchOne(); rt.MatchOne();
				}
				else {
					updateList.put(sord.Id, sord);
					lt.UpdateOne(); rt.UpdateOne();
				}
			}
		}
		Sales_Order__c[] upsertList = updateList.values();
		upsertList.addAll(insertList);

		Database.UpsertResult[] urs;
        if (upsertList.size() > 0) {
            urs = Database.upsert(upsertList, false);
			if (Test.isRunningTest() || Envir.isSandbox) {
				System.debug('upsertList: ' + JSON.serialize(upsertList));
				System.debug('urs: ' + JSON.serialize(urs));
			}
            String err = CommonMethodsLibrary.emailResultFailure(
                            urs, upsertList, 'upsertSalesOrder (upsertList)'
                            , JOB_NAME, new User[] { SyncMobyApiBase.USER_CUR }, false);
            if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
        }
        /** Record lastId */
        if (deliveryIds.size() > 0) {
            deliveryIds.sort();
            this.lastId = deliveryIds[deliveryIds.size() - 1];
        }
    
        System.debug('Upsert Current: ' + JSON.serialize(lt));

		return urs;
    }

    private static void initMaps(MobySalesOrderRes res) {
        /** Primary layer lookup */
        Set<long>		setBookingId		= new Set<long>();		// bookingid
		Set<String>		setChassis			= new Set<string>();	// fullChassis
		Set<long>		setDeliveryId		= new Set<long>();		// deliveryId
		Set<string>		setCustomerDmsNo	= new Set<string>();	// crmCustomerMagic
		/** Secondary lookup via Booking__c */
		// Set<Id>		setCompany			= new Set<Id>();		// companyCode
		// Set<Id>		setShowroom			= new Set<Id>();		// branchId
		// Set<Id>		setAccount			= new Set<Id>();		// contactId
		// Set<Id>		setOpportunity		= new Set<Id>();		// opportunityId
        deliveryIds = new List<long>();
        for (MobySalesOrder salesOrder :res.salesOrders) {
			if (salesOrder.bookingId != null)				{ setBookingId.add(salesOrder.bookingId); }
			if (String.isNotBlank(salesOrder.fullChassis))	{ setChassis.add(salesOrder.fullChassis); }
			if (salesOrder.deliveryId != null)				{ setDeliveryId.add(salesOrder.deliveryId); }
			if (salesOrder.crmCustomerMagic != null && salesOrder.crmCustomerMagic != 0)
															{ setCustomerDmsNo.addAll(dmsMatch(String.valueOf(salesOrder.crmCustomerMagic))); }
			if (salesOrder.companyMagicNumber != null && salesOrder.companyMagicNumber != 0)
															{ setCustomerDmsNo.addAll(dmsMatch(String.valueOf(salesOrder.companyMagicNumber))); }
			// if (String.isNotBlank(salesOrder.companyCode))	{ setCompany.add(salesOrder.companyCode); }
			// if (salesOrder.branchId != null)				{ setBranchId.add(salesOrder.branchId); }
			// if (salesOrder.contactId != null)				{ setContact.add(salesOrder.contactId); }
			// if (salesOrder.opportunityId != null)			{ setOpportunityId.add(salesOrder.opportunityId); }
			// if (String.isNotBlank(salesOrder.fullChassis))	{ setChassis.add(salesOrder.fullChassis); }
			// if (salesOrder.deliveryId != null)				{ setDeliveryId.add(salesOrder.deliveryId); }
			deliveryIds.add(salesOrder.deliveryId);
		}

		/** bookingId => Booking__c.MobyBookingNumber__c */
		mapBooking = new Map<long, Booking__c>();
		Booking__c[] books = [SELECT Id, Name, Company__c, Account__c, Opportunity__c, Showroom__c, CreatedFrom__c, MobyBookingNumber__c, MobyInsertDate__c, MobyInsertUser__c, MobyUpdateDate__c, MobyUpdateUser__c FROM Booking__c WHERE MobyBookingNumber__c IN :setBookingId];
		for (Booking__c book :books) {
			long key = book.MobyBookingNumber__c?.longValue();
			if (key != null) { mapBooking.put(key, book); }
		}

		/** fullChassis => Booking__c.Vehicle__c */
		mapVehicle = new Map<string, Vehicle__c>();
		Vehicle__c[] vehis = [SELECT Id, Name FROM Vehicle__c WHERE Name IN :setChassis];
		for (Vehicle__c vehi :vehis) {
			string key = vehi.Name;
			if (String.isNotEmpty(key)) { mapVehicle.put(key, vehi); }
		}

		/** deliveryId => Sales_Order__c.MobyDeliveryNumber__c */
		mapSalesOrder = new Map<long, Sales_Order__c>();
		Sales_Order__c[] sords = [SELECT Id, Name, CreatedFrom__c, MobyDeliveryNumber__c, AutolineInsertDate__c, AutolineUpdateDate__c FROM Sales_Order__c WHERE MobyDeliveryNumber__c IN :setDeliveryId];
		for (Sales_Order__c sord :sords) {
			long key = sord.MobyDeliveryNumber__c?.longValue();
			if (key != null) { mapSalesOrder.put(key, sord); }
		}

		/** crmCustomerMagic => Account__c.DMS_Number__c */
		mapAccount = new Map<string, Account>();
		Account[] accs = [SELECT Id, Name, IsPersonAccount, DMS_Number__c FROM Account WHERE DMS_Number__c LIKE :setCustomerDmsNo];
		System.debug('setDmsNo: ' + JSON.serialize(setCustomerDmsNo));
		System.debug('init: accs: ' + JSON.serialize(accs));
		for (Account acc :accs) {
			if (String.isNotBlank(acc.DMS_Number__c)) {
				string[] dmses = acc.DMS_Number__c.split('\\|');
				for (string dms :dmses) {
					string key = String.join(new string[] { String.valueOf(acc.IsPersonAccount), dms }, '_').toUpperCase();
					mapAccount.put(key, acc);
				}
			}
		}		
		/** companyCode => Company__r.MobyCompanyCode__c */
		// mapCompany = new Map<string, Company__c>();
		// Company__c[] cmps = [SELECT Id, Name, Description__c, MobyCompanyCode__c FROM Company__c WHERE MobyCompanyCode__c IN :setCompany];
		// for (Company__c cmp :cmps) {
		// 	string key = cmp.MobyCompanyCode__c?.toUpperCase();
		// 	if (String.isNotBlank(key)) { mapCompany.put(key, cmp); }
		// }

		/** Id => MobyBranchNumber__c
			companyCode + branchCode => Company__r.Name + MobyBranchCode__c
		 */
		// Showroom__c[] srms = [SELECT Id, Name, Company__r.MobyCompanyCode__c, MobyBranchNumber__c, MobyBranchCode__c FROM Showroom__c WHERE MobyBranchNumber__c IN :setBranchId OR (Company__r.MobyCompanyCode__c IN :setCompany AND MobyBranchCode__c IN :setBranchCode)];
		// mapBranchById = new Map<Integer, Showroom__c>();
		// mapBranchByCode = new Map<string, Showroom__c>();
		// for (Showroom__c srm :srms) {
		// 	Integer key1 = srm.MobyBranchNumber__c?.intValue();
		// 	string key2 = String.join(new string[] { srm.Company__r.MobyCompanyCode__c, srm.MobyBranchCode__c }, '_').toUpperCase();
		// 	if (key1 != null) { mapBranchById.put(key1, srm); }
		// 	mapBranchByCode.put(key2, srm);
		// }

		/** insertUserId, updateUserId => Employee_Master__r.MobyUserId__c */
		// mapEmployee = new Map<Integer, Employee_Master__c>();
		// Employee_Master__c[] emps = [SELECT Id, Name, MobyUserNumber__c FROM Employee_Master__c WHERE MobyUserNumber__c IN :setUser];
		// for (Employee_Master__c emp :emps) {
		// 	Integer key = emp.MobyUserNumber__c?.intValue();
		// 	if (key != null) { mapEmployee.put(key, emp); }
		// }
		
		/** contactId => Account.MobyContactNumber__c */
		// mapAccount = new Map<long, Account>();
		// Account[] accs = [SELECT Id, Name, MobyContactNumber__c FROM Account WHERE MobyContactNumber__c IN :setContact];
		// for (Account acc :accs) {
		// 	long key = acc.MobyContactNumber__c?.longValue();
		// 	if (key != null) { mapAccount.put(key, acc); }
		// }

		/** opportunityId => Opportunity.MobyOpportunityNumber__c */
        // mapOpportunity = new Map<long, Opportunity>();
        // Opportunity[] oppos = [SELECT Id, Name, MobyOpportunityNumber__c, MobyInsertDate__c, MobyInsertUser__c, MobyUpdateDate__c, MobyUpdateUser__c FROM Opportunity WHERE MobyOpportunityNumber__c IN :setOpportunityId];
		// for (Opportunity booking :oppos) {
		// 	long key = booking.MobyOpportunityNumber__c?.longValue();
		// 	if (key != null) { mapOpportunity.put(key, booking); }
		// }
    }

	public static void initLookups(MobySalesOrderRes res) {
		// SObject[] tmpso;
		// tmpso = genLookups('Showroom', res);
		// if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
	}

    public static void setValues(MobySalesOrder objFr, Sales_Order__c objTo) {
		if (objTo.Id == null) {
			objTo.CreatedFrom__c = createdFrom;
			objTo.MobyDeliveryNumber__c = objFr.deliveryId;
		}
		else {

		}

		if (objTo.CreatedFrom__c == CREATEDFROM) {
			/** Insert/Update when Created From Moby */
			objTo.Booking__c = mapBooking.get(objFr.bookingId)?.Id;
			objTo.Vehicle__c = mapVehicle.get(objFr.fullChassis)?.Id;

			objTo.Company__c = mapBooking.get(objFr.bookingId)?.Company__c;
			objTo.Showroom__c = mapBooking.get(objFr.bookingId)?.Showroom__c;
			objTo.Account__c = null; // nullify all Accounts by default.
			/** Lookup via crmCustomerMagic */
			System.debug('Cust/Comp: ' + objFr.crmCustomerMagic + ' / ' + objFr.companyMagicNumber);
			if (objFr.crmCustomerMagic != null) {
				boolean isPerson = null;	// force null
				string magic = null;
				if (objFr.whereAddressFrom001 == 'C') {
					isPerson = false;
					magic = String.valueOf(objFr.companyMagicNumber);
				}
				else if (objFr.whereAddressFrom001 == 'T') {
					isPerson = true;
					magic = String.valueOf(objFr.crmCustomerMagic);
				}
				string key = String.join(new string[] { String.valueOf(isPerson), magic }, '_').toUpperCase();
				objTo.Account__c = mapAccount.get(key)?.Id;
				System.debug('mapAcc: ' + key + ': ' + JSON.serialize(mapAccount.get(key)));
			}
			/** Use Booking's Account if still empty */
			// if (objTo.Account__c == null) { objTo.Account__c = mapBooking.get(objFr.bookingId)?.Account__c; }
			objTo.Opportunity__c = mapBooking.get(objFr.bookingId)?.Opportunity__c;
			objTo.eVSA_Status__c = SORDSTAT.get(objFr.progressCode);

			objTo.CustomerName__c = objFr.customerName;
			objTo.CustomerAddress001__c = objFr.customerAddress001;
			objTo.CustomerAddress002__c = objFr.customerAddress002;
			objTo.CustomerAddress003__c = objFr.customerAddress003;
			objTo.CustomerAddress004__c = objFr.customerAddress004;
			objTo.CustomerAddress005__c = objFr.customerAddress005;
			objTo.CustomerPostcode__c = objFr.cusAddressPostcode;

			objTo.InvoiceName__c = objFr.invoiceName;
			objTo.InvoiceAddress001__c = objFr.invoiceAddress001;
			objTo.InvoiceAddress002__c = objFr.invoiceAddress002;
			objTo.InvoiceAddress003__c = objFr.invoiceAddress003;
			objTo.InvoiceAddress004__c = objFr.invoiceAddress004;
			objTo.InvoiceAddress005__c = objFr.invoiceAddress005;
			objTo.InvoicePostcode__c = objFr.invAddressPostcode;

			objTo.ChassisNumber__c = objFr.fullChassis;
			objTo.RegistrationNumber__c = objFr.registrationNumber;
			objTo.RegistrationDate__c = Util.validDate(objFr.regDate?.date());
			objTo.OrderDate__c = Util.validDate(objFr.orderDate?.date());
			objTo.DeliveryDate__c = Util.validDate(objFr.deliveryDate?.date());
			objTo.InvoiceDate__c = Util.validDate(objFr.invoicedProfitDate?.date());
			objTo.LoanAmount__c = objFr.customerACAmount;
			objTo.SalesType__c = objFr.soTypeName;
			objTo.InvoiceTotal__c = objFr.invoiceTotal;
			objTo.DepositTotal__c = objFr.depositTotal;
			objTo.AcsStatus__c = objFr.acsStatus;
		}

		objTo.AutolineInsertDate__c = objFr.insertDate;
		// objTo.MobyInsertUser__c = mapEmployee.get(objFr.insertUserId)?.Id;
		objTo.AutolineUpdateDate__c = objFr.updateDate;
		// objTo.MobyUpdateUser__c = mapEmployee.get(objFr.updateUserId)?.Id;
    }

	private static String[] dmsMatch(String dmsNo) {
		String[] rv = new List<String>();
		if (String.isBlank(dmsNo)) { return rv; }
		for (String s : dmsNo.split('\\|')) {
			rv.add(s);
			rv.add('%|' + s + '|%');
			rv.add(s + '|%');
			rv.add('%|' + s);
		}
		return rv;
	}

	/** Button: Pull from Moby API (SalesOrders) */
	Webservice static string refreshSOrd(Id salesOrderId) {
		try {
			Sales_Order__c sos = [SELECT Id, MobyDeliveryNumber__c FROM Sales_Order__c WHERE Id = :salesOrderId];
			if (sos?.MobyDeliveryNumber__c == null) { return 'Error: Unable to refresh Sales Order (w/o Delivery No. (Moby)).'; }
			SyncMoby08SalesOrder q = new SyncMoby08SalesOrder();
			q.dateFrom = q.dateTo = null;
			q.deliveryId = new long[] { sos.MobyDeliveryNumber__c?.longValue() };
			SyncMoby08SalesOrder.MobySalesOrderRes res = q.callMobyApi();
			if (res == null || res.salesOrders.size() <= 0) { return 'Error: Unable to find Sales Order for refresh.'; }
			q.upsertSalesOrder(res);
			return 'Refreshed successfully!';
		}
		catch (QueryException e) { return 'Error: No record found with id: \'' + salesOrderId + '\''; }
		catch (Exception e) { return 'Error: ' + e.getMessage() + (SQL_API_Base.ISSANDBOX ? '\n\n' + e.getStackTraceString() : ''); }
	}
	

    public class MobyBookingReq extends SyncMobyApiBase.MobyReq {
	}

    public class MobySalesOrderRes {
        public MobySalesOrder[] salesOrders;
        public long lastKey;
    }
	public class MobySalesOrder {
		public string companyCode;
		public Integer branchId;
		public long deliveryId;
		public long bookingId;
		public long opportunityId;
		public Datetime insertDate;
		public Datetime updateDate;
		public long stockbookNumber;
		public string franchise;
		public string modelCode;
		public string acsStatus;
		public string variantCode;
		public string vehicleDescriptio001;
		public string colourWheelbaseDesc;
		public string trimCabtypeDesc;
		public string physicalBranch;
		public string progressCode;
		public string engineNumber;
		public string supplierName;
		public string supplierAddress001;
		public string supplierAddress002;
		public string supplierAddress003;
		public string supplierAddress004;
		public string supplierAddress005;
		public string registrationNumber;
		public Datetime regDate;
		public Decimal inputVAT;
		public string customerName;
		public string customerAddress001;
		public string customerAddress002;
		public string customerAddress003;
		public string customerAddress004;
		public string customerAddress005;
		public string cusAddressPostcode;
		public string telephoneNumber;
		public string invoiceName;
		public string invoiceAddress001;
		public string invoiceAddress002;
		public string invoiceAddress003;
		public string invoiceAddress004;
		public string invoiceAddress005;
		public string invAddressPostcode;
		public string customerOrderNo;
		public Datetime orderDate;
		public string sOrderType;
		public string salesExecutive001;
		public string salesExecutive002;
		public string salesExecutive003;
		public string salesExecutive004;
		public Datetime deliveryDate;
		public Decimal salesInvoiceNumber;
		public Datetime dateTaxPoint;
		public Decimal nettTotal;
		public Decimal salesDiscount;
		public Decimal vatTotal;
		public Decimal cost;
		public Decimal grossTotal;
		public string whereAddressFrom001;
		public string whereAddressFrom002;
		public string fullChassis;
		public Decimal nonRecoverableCos001;
		public Decimal nonRecoverableCos002;
		public Decimal nonRecoverableCos003;
		public Decimal financeDue;
		public Decimal customerDue;
		public Decimal otherCosts001;
		public Decimal otherCosts002;
		public Decimal otherCosts003;
		public Decimal otherCosts004;
		public Decimal otherCosts005;
		public Decimal otherCosts006;
		public Decimal otherCosts007;
		public Decimal otherCosts008;
		public Decimal otherCosts009;
		public Decimal otherCosts010;
		public Decimal otherCosts011;
		public Decimal otherCosts012;
		public Decimal otherCosts013;
		public Decimal otherCosts014;
		public Decimal otherCosts015;
		public Decimal totalNRCosts;
		public Decimal overAllowance001;
		public Decimal overAllowance002;
		public Decimal overAllowance003;
		public Decimal latestProfitValue;
		public Decimal invoicedProfitValu;
		public Datetime invoicedProfitDate;
		public Decimal profitLastVSBPend;
		public Datetime dateLastVSBPEnd;
		public Decimal profitLastNLPEnd;
		public Datetime dateLastNLPEnd;
		public Decimal estimatedCosts;
		public Decimal lateCosts;
		public string locator;
		public string defaultPictureCode;
		public string preReserveProgress;
		public Datetime dateReserved;
		public Decimal timeReserved;
		public string reservedBy;
		public string supplierAccount;
		public string invoiceAccount;
		public string customerAccount;
		public Decimal invoiceTotal;
		public Decimal customerACAmount;
		public Decimal depositTotal;
		public Decimal invoiceACAmount;
		public Decimal netAllowanceTotal;
		public Decimal netAllowances001;
		public Decimal netAllowances002;
		public Decimal netAllowances003;
		public Decimal overallowanceTotal;
		public Decimal supplYValueTotal;
		public Decimal mainInvoiceTotal;
		public string invoiceVATCodes001;
		public string invoiceVATCodes002;
		public string invoiceVATCodes003;
		public string invoiceVATCodes004;
		public string invoiceVATCodes005;
		public string invoiceVATCodes006;
		public string invoiceVATCodes007;
		public string invoiceVATCodes008;
		public string invoiceVATCodes009;
		public string invoiceVATCodes010;
		public Decimal toAtThisCode001;
		public Decimal toAtThisCode002;
		public Decimal toAtThisCode003;
		public Decimal toAtThisCode004;
		public Decimal toAtThisCode005;
		public Decimal toAtThisCode006;
		public Decimal toAtThisCode007;
		public Decimal toAtThisCode008;
		public Decimal toAtThisCode009;
		public Decimal toAtThisCode010;
		public Decimal vatAtThisCode001;
		public Decimal vatAtThisCode002;
		public Decimal vatAtThisCode003;
		public Decimal vatAtThisCode004;
		public Decimal vatAtThisCode005;
		public Decimal vatAtThisCode006;
		public Decimal vatAtThisCode007;
		public Decimal vatAtThisCode008;
		public Decimal vatAtThisCode009;
		public Decimal vatAtThisCode010;
		public Integer lastPLMagicNo;
		public Integer lastSLMagicNo;
		public Integer invoiceProduced;
		public Decimal carTaxCost;
		public string warrantyReference;
		public Decimal carTaxSale;
		public Decimal overallSaleNet;
		public Decimal overallSaleDisc;
		public Decimal overallSaleVat;
		public Decimal overallSaleGross;
		public string cdSecurityCode;
		public string fleetnetCode;
		public Integer fleetnetID;
		public Integer autosellLotNumber;
		public Datetime stockCheckDate;
		public string interCoTransRef;
		public string stockCheckPerson;
		public string stockCheckRef;
		public string buyingBranch;
		public string usTaxCodes001;
		public string usTaxCodes002;
		public string sellingBranch;
		public Integer crmCustomerMagic;
		public Integer crmVehicleMagic;
		public string vsPostingCode;
		public Decimal stockSuspenseAC;
		public string recalculateVehicle;
		public Decimal taxOnVehicleList;
		public Decimal carTaxAdjustment;
		public Decimal taxAllInvoices;
		public string currentPrevPrice;
		public Datetime datePriceEffective;
		public Decimal estimatedSalesVal;
		public Decimal estActCosts;
		public Decimal unit10;
		public string lifetimeCare;
		public string shortChassis;
		public string heavyLightCommercl;
		public Decimal discountValues001;
		public Decimal discountValues002;
		public Decimal discountValues003;
		public Decimal discountValues004;
		public Decimal discountValues005;
		public Decimal discountValues006;
		public Decimal discountValues007;
		public Decimal discountValues008;
		public Decimal discountValues009;
		public Decimal discountValues010;
		public Decimal discountValues011;
		public Decimal discountValues012;
		public Decimal discountValues013;
		public Decimal discountValues014;
		public Decimal discountValues015;
		public string currencyCode;
		public Decimal exchangeRate;
		public Integer bulkInvoice;
		public string modelYear;
		public string modelAnalysisCode;
		public string genericColourCode;
		public string genericTrimCode;
		public Datetime creditNoteDate;
		public string capKey;
		public string capYear;
		public string fuelType;
		public Decimal pxhpSettlements001;
		public Decimal pxhpSettlements002;
		public Decimal pxhpSettlements003;
		public Decimal totalPXSettlements;
		public string deliveryTime;
		public string transmissionType;
		public Decimal saleCarTaxVAT;
		public Decimal totalCarTaxVAT;
		public string glassCode;
		public string supplierVATNo;
		public string reservedUntil;
		public Decimal co2Emissions;
		public string localDescription;
		public string trimDescription;
		public Datetime complianceDate;
		public Integer brakeHorsePower;
		public string showroomCompany;
		public Integer srQuoteMagic;
		public string accidentDamage;
		public string governmentNumber;
		public Decimal mileageOnSale;
		public Integer finallyPriced;
		public string immobiliserCode;
		public string driverSide;
		public Integer totalAllowedWeight;
		public string previousICTRef;
		public string subModelGroup;
		public string vehicleHasVideo;
		public string keyNumber;
		public string altKeyNumber;
		public Integer slDepositMagic001;
		public Integer slDepositMagic002;
		public Integer slDepositMagic003;
		public Integer slDepositMagic004;
		public Integer slDepositMagic005;
		public Integer slDepositMagic006;
		public Integer slDepositMagic007;
		public Integer slDepositMagic008;
		public Integer slDepositMagic009;
		public Integer slDepositMagic010;
		public Integer slDepositMagic011;
		public Integer slDepositMagic012;
		public Integer slDepositMagic013;
		public Integer slDepositMagic014;
		public Integer slDepositMagic015;
		public Integer slDepositMagic016;
		public Integer slDepositMagic017;
		public Integer slDepositMagic018;
		public Integer slDepositMagic019;
		public Integer slDepositMagic020;
		public Decimal depositVAT001;
		public Decimal depositVAT002;
		public Decimal depositVAT003;
		public Decimal depositVAT004;
		public Decimal depositVAT005;
		public Decimal depositVAT006;
		public Decimal depositVAT007;
		public Decimal depositVAT008;
		public Decimal depositVAT009;
		public Decimal depositVAT010;
		public Decimal depositVAT011;
		public Decimal depositVAT012;
		public Decimal depositVAT013;
		public Decimal depositVAT014;
		public Decimal depositVAT015;
		public Decimal depositVAT016;
		public Decimal depositVAT017;
		public Decimal depositVAT018;
		public Decimal depositVAT019;
		public Decimal depositVAT020;
		public string colourWheelbase;
		public string trimCabtype;
		public string soTypeName;
		public Integer companyMagicNumber;
	}
}