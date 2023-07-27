public class SyncMoby06Booking implements Database.AllowsCallouts, Queueable {
	private static final string USERNAME = SyncMobyApiBase.USERNAME;
    private static final string PASSWORD = SyncMobyApiBase.PASSWORD;
    private static final string ENDPOINT = SyncMobyApiBase.ENDPOINT + 'mobysf/Bookings';
    private static final string HEADER_AUTH = Util.genBasicAuthHeader(USERNAME, PASSWORD);
    private static final string JOB_NAME = SyncMobyApiBase.SYNC06BOOK;
	private static final string CREATEDFROM = 'Moby';

	public string[] company = SyncMobyApiBase.COMPANY_CODE;
    public DateTime dateFrom;
    public DateTime dateTo;
    public long[] bookingId = null;
    public long lastId = 0;
    public long rowCount = 200;
    public final Integer minRowCount = 10;
    public Boolean followOnToNext = false;
    public SQL_API_BASE.RowTracking rt = new SQL_API_Base.RowTracking();

	private static MobyBookingRes respBook;

	/** Mapping objects */
	private static Map<string, Company__c> mapCompany;				// companyCode => Company__r.MobyCompanyCode__c
	private static Map<Integer, Showroom__c> mapBranchById;			// branchId => MobyBranchNumber__c
	private static Map<string, Showroom__c> mapBranchByCode;		// companyCode + branchCode => Company__r.MobyCompanyCode__c + MobyBranchCode__c
	private static Map<Integer, Employee_Master__c> mapEmployee;	// insertUserId, updateUserId => Employee_Master__r.MobyUserNumber__c
	private static Map<long, Account> mapAccount;					// contactId => Account.MobyContactNumber__c
	private static Map<long, Opportunity> mapOpportunity;			// id => Opportunity.MobyOpportunityNumber__c
	private static Map<string, Vehicle__c> mapVehicle;				// stockId => Vehicle__c.Name 
	private static Map<long, Booking__c> mapBooking;				// id => MobyBookingNumber__c;
	private static Map<string, VehicleVariant__c> mapVariant;		// modelVariant => VehicleVariant__c.Name
	private static long[] bookingIds;
	
	/** Email Diagnostic */
	private static SQL_API_Base.API_DEBUG api;
	private static string[] errEmail = new List<string>();
	
    public SyncMoby06Booking() {
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

            respBook = callMobyApi();
			if (respBook != null  && respBook.bookings != null && respBook.bookings.size() > 0) {
                upsertBooking(respBook);
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
                    SyncMoby08SalesOrder q = new SyncMoby08SalesOrder();
					q.company = this.company;
					if (this.dateFrom == null) { q.dateFrom = null; }
					q.dateTo = this.dateTo;
					q.followOnToNext = true;
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
                CommonMethodsLibrary.sendErrorEmail(new User[] { SyncMobyApiBase.USER_CUR }, String.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
            }
        }
    }

	public MobyBookingRes callMobyApi() {
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
        req.id = this.bookingId;
        req.lastKey = this.lastId;
        req.rowCount = this.rowCount;
        hreq.setBody(JSON.serialize(req, false));
        hreq.setTimeout(120000);

        /** Prep API request for exception email */
        api = new SQL_API_Base.API_DEBUG();
        api.parse(hreq, new string[] { 'Content-Type', 'Authorization' });

        MobyBookingRes res = new MobyBookingRes();
        HttpResponse hres;
        try {
            hres = http.send(hreq);
            api.parse(hres);
            if (hres.getStatusCode() == 200) {
                res = (MobyBookingRes) JSON.deserialize(hres.getBody(), MobyBookingRes.class);
                api.parse(res?.bookings);
            }
            else { throw new ExternalObjectException(api?.Response); }
        }
        catch (Exception e) { throw e; }
        finally { System.debug(api?.toString()); }

        return res;
    }

    public Database.UpsertResult[] upsertBooking(MobyBookingRes res) {
        SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
        /** Initialises mapping */
        initMaps(res);
		/** Initialise dependency objects */
		initLookups(res);

        Booking__c[] insertList = new List<Booking__c>();
        Map<Id, Booking__c> updateList = new Map<Id, Booking__c>();
        // Match with order priortised
        Booking__c book;
        for (MobyBooking booking :res.bookings) {
			book = null;

			if (booking.id != null) { book = mapBooking.get(booking.id); }

			/** still no match */
			if (book == null) { book = new Booking__c(); }
			setValues(booking, book);
			if (book.Id == null) {
				insertList.add(book);
				lt.AddOne(); rt.AddOne();
			}
			else {
				if (updateList.containsKey(book.Id)) {
					updateList.put(book.Id, book);
					lt.MatchOne(); rt.MatchOne();
				}
				else {
					updateList.put(book.Id, book);
					lt.UpdateOne(); rt.UpdateOne();
				}
			}
		}
		Booking__c[] upsertList = updateList.values();
		upsertList.addAll(insertList);

		Database.UpsertResult[] urs;
        if (upsertList.size() > 0) {
            urs = Database.upsert(upsertList, false);
			if (Test.isRunningTest() || Envir.isSandbox) {
				System.debug('upsertList: ' + JSON.serialize(upsertList));
				System.debug('urs: ' + JSON.serialize(urs));
			}
            String err = CommonMethodsLibrary.emailResultFailure(
                            urs, upsertList, 'upsertBooking (upsertList)'
                            , JOB_NAME, new User[] { SyncMobyApiBase.USER_CUR }, false);
            if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
        }
        /** Record lastId */
        if (bookingIds.size() > 0) {
            bookingIds.sort();
            this.lastId = bookingIds[bookingIds.size() - 1];
        }
    
        System.debug('Upsert Current: ' + JSON.serialize(lt));

		return urs;
    }

    private static void initMaps(MobyBookingRes res) {
        /** Gather all lookup list */
		Set<string>		setCompany			= new Set<string>();	// companyCode
		Set<Integer>	setBranchId			= new Set<Integer>();	// branchId
		Set<string>		setBranchCode		= new Set<string>();	// branchCode
		Set<Integer>	setUser				= new Set<Integer>();	// insertUserId, updateUserId
		Set<long>		setContact			= new Set<long>();		// contactId
		Set<long>		setOpportunityId	= new Set<long>();		// opportunityId
		Set<String>		setStockId			= new Set<string>();	// stockId
        Set<long>		setBookingId		= new Set<long>();		// id
		Set<string>		setVariantCode		= new Set<string>();	// variantCode
        bookingIds = new List<long>();
        for (MobyBooking booking :res.bookings) {
			if (String.isNotBlank(booking.companyCode))	{ setCompany.add(booking.companyCode); }
			if (String.isNotBlank(booking.branchCode))	{ setBranchCode.add(booking.branchCode); }
			if (booking.id != null)      				{ setBookingId.add(booking.id); }
			if (booking.branchId != null)				{ setBranchId.add(booking.branchId); }
			if (String.isNotBlank(booking.itemStockId))	{ setStockId.add(booking.itemStockId); }
			if (booking.insertUserId != null)			{ setUser.add(booking.insertUserId); }
			if (booking.updateUserId != null)			{ setUser.add(booking.updateUserId); }
			if (booking.contactId != null)				{ setContact.add(booking.contactId); }
			if (booking.opportunityId != null)			{ setOpportunityId.add(booking.opportunityId); }
			if (String.isNotBlank(booking.bookVariantCode))
														{ setVariantCode.add(booking.bookVariantCode); }
			bookingIds.add(booking.id);
		}
		/** companyCode => Company__r.MobyCompanyCode__c */
		mapCompany = new Map<string, Company__c>();
		Company__c[] cmps = [SELECT Id, Name, Description__c, MobyCompanyCode__c FROM Company__c WHERE MobyCompanyCode__c IN :setCompany];
		for (Company__c cmp :cmps) {
			string key = cmp.MobyCompanyCode__c?.toUpperCase();
			if (String.isNotBlank(key)) { mapCompany.put(key, cmp); }
		}

		/** Id => MobyBranchNumber__c
			companyCode + branchCode => Company__r.Name + MobyBranchCode__c
		 */
		Showroom__c[] srms = [SELECT Id, Name, Company__r.MobyCompanyCode__c, MobyBranchNumber__c, MobyBranchCode__c FROM Showroom__c WHERE MobyBranchNumber__c IN :setBranchId OR (Company__r.MobyCompanyCode__c IN :setCompany AND MobyBranchCode__c IN :setBranchCode)];
		mapBranchById = new Map<Integer, Showroom__c>();
		mapBranchByCode = new Map<string, Showroom__c>();
		for (Showroom__c srm :srms) {
			Integer key1 = srm.MobyBranchNumber__c?.intValue();
			string key2 = String.join(new string[] { srm.Company__r.MobyCompanyCode__c, srm.MobyBranchCode__c }, '_').toUpperCase();
			if (key1 != null) { mapBranchById.put(key1, srm); }
			mapBranchByCode.put(key2, srm);
		}

		/** insertUserId, updateUserId => Employee_Master__r.MobyUserId__c */
		mapEmployee = new Map<Integer, Employee_Master__c>();
		Employee_Master__c[] emps = [SELECT Id, Name, MobyUserNumber__c FROM Employee_Master__c WHERE MobyUserNumber__c IN :setUser];
		for (Employee_Master__c emp :emps) {
			Integer key = emp.MobyUserNumber__c?.intValue();
			if (key != null) { mapEmployee.put(key, emp); }
		}
		
		/** contactId => Account.MobyContactNumber__c */
		mapAccount = new Map<long, Account>();
		Account[] accs = [SELECT Id, Name, MobyContactNumber__c FROM Account WHERE MobyContactNumber__c IN :setContact];
		for (Account acc :accs) {
			long key = acc.MobyContactNumber__c?.longValue();
			if (key != null) { mapAccount.put(key, acc); }
		}

		/** opportunityId => Opportunity.MobyOpportunityNumber__c */
        mapOpportunity = new Map<long, Opportunity>();
        Opportunity[] oppos = [SELECT Id, Name, AccountId, MobyOpportunityNumber__c, MobyInsertDate__c, MobyInsertUser__c, MobyUpdateDate__c, MobyUpdateUser__c FROM Opportunity WHERE MobyOpportunityNumber__c IN :setOpportunityId];
		for (Opportunity booking :oppos) {
			long key = booking.MobyOpportunityNumber__c?.longValue();
			if (key != null) { mapOpportunity.put(key, booking); }
		}

		/** itemStockId => Booking__c.Vehicle__c */
		mapVehicle = new Map<string, Vehicle__c>();
		Vehicle__c[] vehis = [SELECT Id, Name FROM Vehicle__c WHERE Name IN :setStockId];
		for (Vehicle__c vehi :vehis) {
			string key = vehi.Name;
			if (String.isNotEmpty(key)) { mapVehicle.put(key, vehi); }
		}

		/** id => Booking__c.MobyBookingNumber__c */
		mapBooking = new Map<long, Booking__c>();
		Booking__c[] books = [SELECT Id, Name, CreatedFrom__c, MobyBookingNumber__c, MobyInsertDate__c, MobyInsertUser__c, MobyUpdateDate__c, MobyUpdateUser__c FROM Booking__c WHERE MobyBookingNumber__c IN :setBookingId];
		for (Booking__c book :books) {
			long key = book.MobyBookingNumber__c?.longValue();
			if (key != null) { mapBooking.put(key, book); }
		}

		/** variantCode => VehicleVariant__c.Name */
		mapVariant = new Map<string, VehicleVariant__c>();
		VehicleVariant__c[] variants = [SELECT Id, Name, Company__r.MobyCompanyCode__c, Make__r.MobyMakeCode__c, Model__r.Name FROM VehicleVariant__c WHERE Name IN :setVariantCode];
		for (VehicleVariant__c variant :variants) {
			string key = String.join(new string[] { variant.Company__r.MobyCompanyCode__c?.toUpperCase(), variant.Make__r?.MobyMakeCode__c?.toUpperCase(), variant.Model__r?.Name.toUpperCase(), variant.Name.toUpperCase() }, '_'); 
			mapVariant.put(key, variant);
		}
    }

	public static void initLookups(MobyBookingRes res) {
		SObject[] tmpso;
		tmpso = genLookups('Showroom', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
	}

	public static SObject[] genLookups(String objType, MobyBookingRes res) {
		// Set<SObject> sObjSet = new Set<SObject>();
		SObject sObj;
		Map<string, SObject> mapRet = new Map<string, SObject>();
		for (MobyBooking booking :res.bookings) {
			if (objType == 'Showroom') {
				Integer key1 = booking.branchId;
				string key2 = String.join(new string[] { booking.companyCode, booking.branchCode }, '_').toUpperCase();
				if (mapBranchById.containsKey(key1))		{ sObj = mapBranchById.get(key1); }
				else if (mapBranchByCode.containsKey(key2))	{ sObj = mapBranchByCode.get(key2); }
				else {
					sObj = new Showroom__c();
					sObj.put('Name', booking.branchName);
					sObj.put('MobyBranchCode__c', booking.branchCode);
					sObj.put('CreatedFrom__c', CREATEDFROM);
					mapBranchById.put(key1, (Showroom__c) sObj);
					mapBranchByCode.put(key2, (Showroom__c) sObj);
				}
				/** Consolidate Make list */
				// Set<string> makeSet = new Set<string>();
				// string makePicklist = (string) sObj.get('Make__c');
				// if (String.isNotBlank(makePicklist)) {
				// 	string[] makes = makePicklist.split(';');
				// 	makeSet.addAll(makes);
				// }
				// makeSet.add(booking.makeCode);
				// sObj.put('Make__c', String.join((Iterable<string>) makeSet, ';'));
				
				string keyRet = String.join(new string[] { String.valueOf(key1), key2 }, '_').toUpperCase();
				if (!mapRet.containsKey(keyRet))	{ mapRet.put(keyRet, (Showroom__c) sObj); }
			}
			if (objType != 'Company' && sObj != null) {
				sObj.put('Company__c', mapCompany.get(booking.companyCode)?.Id);
				// sObjSet.add(sObj);
			}
		}
		return new List<SObject>(mapRet.values());
	} 

    public static void setValues(MobyBooking objFr, Booking__c objTo) {

		if (objTo.Id == null) {
			objTo.CreatedFrom__c = CREATEDFROM;
			objTo.MobyBookingNumber__c = objFr.id;
		}
		else {

		}

		if (objTo.CreatedFrom__c == CREATEDFROM) {
			/** Insert/Update when Created From Moby */
			objTo.Company__c = mapCompany.get(objFr.companyCode?.toUpperCase())?.Id;
			System.debug('objFr.contactId: ' + objFr.contactId);
			System.debug(JSON.serialize(mapAccount));
			objTo.Account__c = mapAccount.get(objFr.contactId)?.Id;
			if (objTo.Account__c == null) { objTo.Account__c = mapOpportunity.get(objFr.opportunityId)?.AccountId; }
			objTo.Vehicle__c = mapVehicle.get(objFr.itemStockId)?.Id;
			string keyVariant = String.join(new string[] { objFr.companyCode, objFr.makeCode?.toUpperCase(), objFr.bookModelCode?.toUpperCase(), objFr.bookVariantCode?.toUpperCase() }, '_');
			// System.debug('keyVar: ' + keyVariant);
			// System.debug('mapVar: ' + JSON.serialize(mapVariant));
			objTo.VehicleVariant__c = mapVariant.get(keyVariant)?.Id;
			objTo.VariantCode__c = objFr.bookVariantCode;
			objTo.VariantDescription__c = objFr.bookVariantName;
			objTo.Opportunity__c = mapOpportunity.get(objFr.opportunityId)?.Id;
			objTo.SalesAdvisor__c = mapEmployee.get(objFr.userId)?.Id;
			objTo.Showroom__c = mapBranchById.get(objFr.branchId)?.Id;
			objTo.MobyRcoNumber__c = objFr.rcoNo;
			objTo.InsuranceCompanyName__c = objFr.insuranceCompanyName;
			objTo.FinanceCompanyName__c = objFr.financeCompanyName;
			objTo.Tenure__c = objFr.tenure;
			objTo.TenureUnit__c = objFr.monthYear;
			objTo.InterestRate__c = objFr.interestRate;
			objTo.LoanAmount__c = objFr.loanAmount; 
			objTo.BookingDate__c = Util.validDate(objFr.bookingDate?.date());
			objTo.PaymentDate__c = Util.validDate(objFr.paymentDate?.date());
			objTo.StatusCode__c = objFr.statusCode;
		}
		
		objTo.MobyInsertDate__c = objFr.insertDate;
		objTo.MobyInsertUser__c = mapEmployee.get(objFr.insertUserId)?.Id;
		objTo.MobyUpdateDate__c = objFr.updateDate;
		objTo.MobyUpdateUser__c = mapEmployee.get(objFr.updateUserId)?.Id;
    }

    public class MobyBookingReq extends SyncMobyApiBase.MobyReq {
	}

    public class MobyBookingRes {
        public MobyBooking[] bookings;
        public long lastKey;
    }
	public class MobyBooking {
		public long id;
		public Integer companyId;
		public string companyCode;
		public string companyName;
		public Integer branchId;
		public string branchCode;
		public string branchName;
		public Integer makeId;
		public string makeCode;
		public string makeName;
		public long opportunityId;
		public Integer userId;
		public long contactId;
		public string bookingNo;
		public Datetime bookingDate;
		public string rcoNo;
		public long offerId;
		public Integer bookVariantId;
		public string bookVariantCode;
		public string bookVariantName;
		public string bookVariantAssemblyCode;
		public string bookVariantBodyType;
		public string bookVariantCylinder;
		public string bookVariantDisplacement;
		public string bookExtVariantUid;
		public string bookVariantFuelType;
		public Integer bookVariantModelId;
		public string bookModelCode;
		public string bookModelName;
		public string bookModelAssemblyCode;
		public string bookModelBodyType;
		public string bookModelCylinder;
		public string bookModelDisplacement;
		public string bookModelFuelType;
		public Integer bookVariantMakeId;
		public string bookVariantMakeCode;
		public string bookVariantMakeName;
		public string bookVariantSystem;
		public Boolean bookVariantIsActive;
		public Integer bookVariantCarTypeId;
		public string bookCarTypeCode;
		public string bookCarTypeName;
		public long bookingDocId;
		public long bookingImgId;
		public string paymentType;
		public Integer insuranceCompanyId;
		public string insuranceCompanyCode;
		public string insuranceCompanyName;
		public string insuranceCompanyAddress;
		public string insuranceCompanyFaxNo;
		public string insuranceCompanyEmail;
		public string insuranceCompanyPhoneNo;
		public Boolean insuranceCompanyIsActive;
		public Integer insuranceCompanyIndustryId;
		public string insuranceCompanyIndustryCode;
		public string insuranceCompanyIndustryName;
		public Boolean insuranceCompanyIndustryIsActive;
		public Integer financeCompanyId;
		public string financeCompanyCode;
		public string financeCompanyName;
		public string financeCompanyAddress;
		public string financeCompanyFaxNo;
		public string financeCompanyEmail;
		public string financeCompanyPhoneNo;
		public Boolean financeCompanyIsActive;
		public Integer financeCompanyIndustryId;
		public string financeCompanyIndustryCode;
		public string financeCompanyIndustryName;
		public Boolean financeCompanyIndustryIsActive;
		public Decimal tenure;
		public string monthYear;
		public Decimal loanAmount;
		public Decimal interestRate;
		public Integer statusId;
		public string statusCode;
		public string statusName;
		public string remarks;
		public Integer sourceUserid;
		public Integer transferUserId;
		public string sellingPrice;
		public Integer colourId;
		public string colourCode;
		public string colourName;
		public string dpPct;
		public string dpAmt;
		public string hpPct;
		public string hpAmt;
		public string interestPct;
		public string interestAmt;
		public string installMonths;
		public string sumInsured;
		public string insurancePremium;
		public string redPlateDeposit;
		public string otherFees;
		public string deductDeposit;
		public string spoiler;
		public string mpiInsurance;
		public string solarFilm;
		public string carCover;
		public string doorVisor;
		public string licensePlate;
		public string hasRegFee;
		public string regFee;
		public long attachmentId;
		public string registrationNo;
		public string itemStockId;
		public Integer categoryId;
		public string categoryCode;
		public string categoryName;
		public string colour;
		public Integer conditionId;
		public string conditionCode;
		public string conditionName;
		public Integer stockModelId;
		public string stockModelCode;
		public string stockModelName;
		public string stockModelAssemblyCode;
		public string stockModelBodyType;
		public string stockModelCylinder;
		public string stockModelDisplacement;
		public string stockModelFuelType;
		public Integer stockModelMakeId;
		public string stockModelYear;
		public string stockPlateNo;
		public string stockRegistrationDate;
		public string stockRegistrationNo;
		public string stockSellingPrice;
		public string stockShortChassis;
		public Integer stockStatusId;
		public string stockStatusCode;
		public string stockStatusName;
		public string stockStatusNumber;
		public Integer stockSubMakeId;
		public string stockSubMakeCode;
		public string stockSubMakeName;
		public Integer stockVariantId;
		public string stockVariantCode;
		public string stockVariantName;
		public string stockVariantAssemblyCode;
		public string stockVariantBodyType;
		public string stockVariantCylinder;
		public string stockVariantDisplacement;
		public string stockExtVariantUid;
		public string stockVariantFuelType;
		public Integer stockVariantModelId;
		public Integer stockVariantMakeId;
		public string stockVariantSystem;
		public string receiptNo;
		public Datetime paymentDate;
		public string paymentAmt;
		public string extBookingUid;
		public Datetime insertDate;
		public Integer insertUserId;
		public Datetime updateDate;
		public Integer updateUserId;
	}
}