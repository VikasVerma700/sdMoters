public class SyncMoby05TestDrive implements Database.AllowsCallouts, Queueable {
	private static final string USERNAME = SyncMobyApiBase.USERNAME;
    private static final string PASSWORD = SyncMobyApiBase.PASSWORD;
    private static final string ENDPOINT = SyncMobyApiBase.ENDPOINT + 'mobysf/TestDrives';
    private static final string HEADER_AUTH = Util.genBasicAuthHeader(USERNAME, PASSWORD);
    private static final string JOB_NAME = SyncMobyApiBase.SYNC05TDRV;
	private static final string CREATEDFROM = 'Moby';

	public string[] company = SyncMobyApiBase.COMPANY_CODE;
    public DateTime dateFrom;
    public DateTime dateTo;
    public long[] testDriveId = null;
    public long lastId = 0;
    public long rowCount = 200;
    public final Integer minRowCount = 10;
    public Boolean followOnToNext = false;
    public SQL_API_BASE.RowTracking rt = new SQL_API_Base.RowTracking();

	private static MobyTestDriveRes respTDrv;

	/** Mapping objects */
	private static Map<string, Company__c> mapCompany;				// companyCode => Company__r.MobyCompanyCode__c
	private static Map<Integer, Showroom__c> mapBranchById;			// branchId => MobyBranchNumber__c
	private static Map<string, Showroom__c> mapBranchByCode;		// companyCode + branchCode => Company__r.MobyCompanyCode__c + MobyBranchCode__c
	private static Map<Integer, Employee_Master__c> mapEmployee;	// insertUserId, updateUserId => Employee_Master__r.MobyUserNumber__c
	private static Map<long, Account> mapAccount;					// contactId => Account.MobyContactNumber__c
	private static Map<long, Opportunity> mapOpportunity;			// id => Opportunity.MobyOpportunityNumber__c
	private static Map<string, Vehicle__c> mapVehicle;				// stockId => Vehicle__c.Name 
	private static Map<long, Test_Drive__c> mapTestDrive;			// id => MobyTestDriveNumber__c + MobyTestDriveDetailNumber__c;
	private static long[] testDriveIds;
	
	/** Email Diagnostic */
	private static SQL_API_Base.API_DEBUG api;
	private static string[] errEmail = new List<string>();
	
    public SyncMoby05TestDrive() {
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

            respTDrv = callMobyApi();
			if (respTDrv != null && respTDrv.testDrives != null && respTDrv.testDrives.size() > 0) {
                upsertTestDrive(respTDrv);
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
					SyncMoby06Booking q = new SyncMoby06Booking();
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

	public MobyTestDriveRes callMobyApi() {
        Http http = new Http();
        HttpRequest hreq = new HttpRequest();
        hreq.setEndpoint(ENDPOINT);
        hreq.setMethod('POST');
        hreq.setHeader('Content-Type', 'application/json');
        hreq.setHeader('Authorization', HEADER_AUTH);
        MobyTestDriveReq req = new MobyTestDriveReq();
        req.companyCode = this.company;
        // req.dateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
        // req.dateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
        req.dateFrom = this.dateFrom?.addHours(SQL_API_Base.TIMEZONE);
        req.dateTo = this.dateTo?.addHours(SQL_API_Base.TIMEZONE);
        req.id = this.testDriveId;
        req.lastKey = this.lastId;
        req.rowCount = this.rowCount;
        hreq.setBody(JSON.serialize(req, false));
        hreq.setTimeout(120000);

        /** Prep API request for exception email */
        api = new SQL_API_Base.API_DEBUG();
        api.parse(hreq, new string[] { 'Content-Type', 'Authorization' });

        MobyTestDriveRes res = new MobyTestDriveRes();
        HttpResponse hres;
        try {
            hres = http.send(hreq);
            api.parse(hres);
            if (hres.getStatusCode() == 200) {
                res = (MobyTestDriveRes) JSON.deserialize(hres.getBody(), MobyTestDriveRes.class);
                api.parse(res?.testDrives);
            }
            else { throw new ExternalObjectException(api?.Response); }
        }
        catch (Exception e) { throw e; }
        finally { System.debug(api?.toString()); }

        return res;
    }

    public Database.UpsertResult[] upsertTestDrive(MobyTestDriveRes res) {
        SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
        /** Initialises mapping */
        initMaps(res);
		/** Initialise dependency objects */
		initLookups(res);

        Test_Drive__c[] insertList = new List<Test_Drive__c>();
        Map<Id, Test_Drive__c> updateList = new Map<Id, Test_Drive__c>();
        // Match with order priortised
        Test_Drive__c tdrv;
        for (MobyTestDrive tdh :res.testDrives) {
			if (tdh.details == null) { continue; }
			for (MobyTestDriveDetail tdd :tdh.details) {
				tdrv = null;

				if (tdd.id != null) { tdrv = mapTestDrive.get(tdd.id); }
	
				/** still no match */
				if (tdrv == null) { tdrv = new Test_Drive__c(); }
				setValues(tdh, tdd, tdrv);
				if (tdrv.Id == null) {
					insertList.add(tdrv);
					lt.AddOne(); rt.AddOne();
				}
				else {
					if (updateList.containsKey(tdrv.Id)) {
						updateList.put(tdrv.Id, tdrv);
						lt.MatchOne(); rt.MatchOne();
					}
					else {
						updateList.put(tdrv.Id, tdrv);
						lt.UpdateOne(); rt.UpdateOne();
					}
				}
			}
		}
		Test_Drive__c[] upsertList = updateList.values();
		upsertList.addAll(insertList);

		Database.UpsertResult[] urs;
        if (upsertList.size() > 0) {
            urs = Database.upsert(upsertList, false);
			if (Test.isRunningTest() || Envir.isSandbox) {
				System.debug('upsertList: ' + JSON.serialize(upsertList));
				System.debug('urs: ' + JSON.serialize(urs));
			}
            String err = CommonMethodsLibrary.emailResultFailure(
                            urs, upsertList, 'upsertTestDrive (upsertList)'
                            , JOB_NAME, new User[] { SyncMobyApiBase.USER_CUR }, false);
            if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
        }
        /** Record lastId */
        if (testDriveIds.size() > 0) {
            testDriveIds.sort();
            this.lastId = testDriveIds[testDriveIds.size() - 1];
        }
    
        System.debug('Upsert Current: ' + JSON.serialize(lt));

		return urs;
    }

    private static void initMaps(MobyTestDriveRes res) {
        /** Gather all lookup list */
		Set<string>		setCompany				= new Set<string>();	// detail.companyCode
		Set<Integer>	setBranchId				= new Set<Integer>();	// detail.branchId
		Set<string>		setBranchCode			= new Set<string>();	// detail.branchCode
		Set<Integer>	setUser					= new Set<Integer>();	// detail.insertUserId, detail.updateUserId
		Set<long>		setContactId			= new Set<long>();		// detail.contactId
		Set<long>		setOpportunityId		= new Set<long>();		// opportunityId
		Set<String>		setStockId				= new Set<string>();	// detail.stockId
        Set<long>		setTestDriveDetailId	= new Set<long>();		// detail.id
        testDriveIds = new List<long>();
        for (MobyTestDrive tdh :res.testDrives) {
			if (String.isNotBlank(tdh.companyCode))	{ setCompany.add(tdh.companyCode); }
			if (String.isNotBlank(tdh.branchCode))	{ setBranchCode.add(tdh.branchCode); }
			if (tdh.details == null) { continue; }
			for (MobyTestDriveDetail tdd :tdh.details) {
				if (tdd.id != null)      				{ setTestDriveDetailId.add(tdd.id); }
				if (tdd.branchId != null)				{ setBranchId.add(tdd.branchId); }
				if (String.isNotBlank(tdd.stockId))		{ setStockId.add(tdd.stockId); }
				if (tdd.insertUserId != null)			{ setUser.add(tdd.insertUserId); }
				if (tdd.updateUserId != null)			{ setUser.add(tdd.updateUserId); }
				if (tdd.contactId != null)				{ setContactId.add(tdd.contactId); }
				if (tdh.opportunityId != null)			{ setOpportunityId.add(tdh.opportunityId); }
				testDriveIds.add(tdd.id);
			}
		}
		/** header.companyCode => Company__r.MobyCompanyCode__c */
		mapCompany = new Map<string, Company__c>();
		Company__c[] cmps = [SELECT Id, Name, Description__c, MobyCompanyCode__c FROM Company__c WHERE MobyCompanyCode__c IN :setCompany];
		for (Company__c cmp :cmps) {
			string key = cmp.MobyCompanyCode__c?.toUpperCase();
			if (String.isNotBlank(key)) { mapCompany.put(key, cmp); }
		}

		/** detail.branchId => MobyBranchNumber__c
			header.companyCode + header.branchCode => Company__r.Name + MobyBranchCode__c
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

		/** detail.insertUserId, detail.updateUserId => Employee_Master__r.MobyUserId__c */
		mapEmployee = new Map<Integer, Employee_Master__c>();
		Employee_Master__c[] emps = [SELECT Id, Name, MobyUserNumber__c FROM Employee_Master__c WHERE MobyUserNumber__c IN :setUser];
		for (Employee_Master__c emp :emps) {
			Integer key = emp.MobyUserNumber__c?.intValue();
			if (key != null) { mapEmployee.put(key, emp); }
		}
		
		/** detail.contactId => Account.MobyContactNumber__c */
		mapAccount = new Map<long, Account>();
		Account[] accs = [SELECT Id, Name, MobyContactNumber__c FROM Account WHERE MobyContactNumber__c IN :setContactId];
		for (Account acc :accs) {
			long key = acc.MobyContactNumber__c?.longValue();
			if (key != null) { mapAccount.put(key, acc); }
		}

		/** header.opportunityId => Opportunity.MobyOpportunityNumber__c */
        mapOpportunity = new Map<long, Opportunity>();
        Opportunity[] oppos = [SELECT Id, Name, MobyOpportunityNumber__c, MobyInsertDate__c, MobyInsertUser__c, MobyUpdateDate__c, MobyUpdateUser__c FROM Opportunity WHERE MobyOpportunityNumber__c IN :setOpportunityId];
		for (Opportunity tdh :oppos) {
			long key = tdh.MobyOpportunityNumber__c?.longValue();
			if (key != null) { mapOpportunity.put(key, tdh); }
		}

		/** detail.stockId => Test_Drive__c.Vehicle__c */
		mapVehicle = new Map<string, Vehicle__c>();
		Vehicle__c[] vehis = [SELECT Id, Name FROM Vehicle__c WHERE Name IN :setStockId];
		for (Vehicle__c vehi :vehis) {
			string key = vehi.Name;
			if (String.isNotEmpty(key)) { mapVehicle.put(key, vehi); }
		}

		/** detail.id => Test_Drive__c.MobyTestDriveDetailNumber__c */
		mapTestDrive = new Map<long, Test_Drive__c>();
		Test_Drive__c[] tdrvs = [SELECT Id, Name, CreatedFrom__c, MobyTestDriveDetailNumber__c, MobyInsertDate__c, MobyInsertUser__c, MobyUpdateDate__c, MobyUpdateUser__c FROM Test_Drive__c WHERE MobyTestDriveDetailNumber__c IN :setTestDriveDetailId];
		System.debug('setTestDriveDetailId: ' + JSON.serialize(setTestDriveDetailId));
		System.debug('tdrvs: ' + JSON.serialize(tdrvs));
		
		for (Test_Drive__c tdrv :tdrvs) {
			long key = tdrv.MobyTestDriveDetailNumber__c?.longValue();
			if (key != null) { mapTestDrive.put(key, tdrv); }
		}
    }

	public static void initLookups(MobyTestDriveRes res) {
		SObject[] tmpso;
		tmpso = genLookups('Showroom', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
	}

	public static SObject[] genLookups(String objType, MobyTestDriveRes res) {
		// Set<SObject> sObjSet = new Set<SObject>();
		SObject sObj;
		Map<string, SObject> mapRet = new Map<string, SObject>();
		for (MobyTestDrive tdh :res.testDrives) {
			if (objType == 'Showroom') {
				Integer key1 = tdh.branchId;
				string key2 = String.join(new string[] { tdh.companyCode, tdh.branchCode }, '_').toUpperCase();
				if (mapBranchById.containsKey(key1))		{
					sObj = mapBranchById.get(key1);
					sObj.put('MobyBranchCode__c', tdh.branchCode);
				}
				else if (mapBranchByCode.containsKey(key2))	{
					sObj = mapBranchByCode.get(key2);
					sObj.put('MobyBranchNumber__c', tdh.branchId);
				}
				else {
					sObj = new Showroom__c();
					sObj.put('Name', tdh.branchName);
					sObj.put('CreatedFrom__c', CREATEDFROM);
					sObj.put('MobyBranchNumber__c', tdh.branchId);
					sObj.put('MobyBranchCode__c', tdh.branchCode);
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
				// makeSet.add(tdh.makeCode);
				// sObj.put('Make__c', String.join((Iterable<string>) makeSet, ';'));
				
				string keyRet = String.join(new string[] { String.valueOf(key1), key2 }, '_').toUpperCase();
				if (!mapRet.containsKey(keyRet))	{ mapRet.put(keyRet, (Showroom__c) sObj); }
			}
			if (objType != 'Company' && sObj != null) {
				sObj.put('Company__c', mapCompany.get(tdh.companyCode)?.Id);
				// sObjSet.add(sObj);
			}
		}
		return new List<SObject>(mapRet.values());
	} 

    public static void setValues(MobyTestDrive objFrHdr, MobyTestDriveDetail objFrDet, Test_Drive__c objTo) {
		if (objTo.Id == null) {
			objTo.CreatedFrom__c = CREATEDFROM;
			objTo.MobyTestDriveDetailNumber__c = objFrDet.id;
		}
		else {

		}

		if (objTo.CreatedFrom__c == CREATEDFROM) {
			/** Insert/Update when Created From Moby */
			objTo.Company__c = mapCompany.get(objFrHdr.companyCode?.toUpperCase())?.Id;
			objTo.Opportunity__c = mapOpportunity.get(objFrHdr.opportunityId)?.Id;
			objTo.SalesAdvisor__c = mapEmployee.get(objFrDet.userId)?.Id;

			objTo.Account__c = mapAccount.get(objFrHdr.contactId)?.Id;
			objTo.DocumentNumber__c = objFrHdr.icNo;
			objTo.LicenseNumber__c = objFrHdr.licenseNo;
			objTo.LicenseExpiry__c = Util.validDate(objFrHdr.licenseExpiryDate?.date());
	
			objTo.Vehicle__c = mapVehicle.get(objFrDet.stockId)?.Id;
			objTo.ChassisNumber__c = objFrDet.stockId;
			objTo.RegistrationNumber__c = objFrDet.registrationNo;
			objTo.Condition__c = objFrDet.conditionCode;


			objTo.Showroom__c = mapBranchById.get(objFrHdr.branchId)?.Id;
			objTo.PlannedStartDate__c = objFrHdr.plannedDateStart;
			objTo.PlannedEndDate__c = objFrHdr.plannedDateEnd;
			objTo.ActualStartDate__c = objFrDet.actualDateStart;
			objTo.ActualEndDate__c = objFrDet.actualDateEnd;
			objTo.MileageStart__c = objFrDet.mileageStart;
			objTo.MileageEnd__c = objFrDet.mileageEnd;
			objTo.MileageGuardStart__c = objFrDet.guardMileageStart;
			objTo.MileageGuardEnd__c = objFrDet.guardMileageEnd;
		}
		objTo.MobyInsertDate__c = objFrDet.insertDate;
		objTo.MobyInsertUser__c = mapEmployee.get(objFrDet.insertUserId)?.Id;
		objTo.MobyUpdateDate__c = objFrDet.updateDate;
		objTo.MobyUpdateUser__c = mapEmployee.get(objFrDet.updateUserId)?.Id;
		// objTo.SalesCycleNumber__c = objFr.salescycleId;
		// objTo.Channel__c = objFr.sourceName;
		// objTo.Source__c = objFr.sourceName;
		// objTo.MobySforceParam__c = objFr.sforceParam;
		// objTo.MobyVariantText__c = objFr.variantText;
		// if (String.isBlank(objFr.type) || !objFr.type?.equalsIgnoreCase('TradeIn')) {
		// 	/** Sales Model of Interest */
		// 	string[] modelOfInterest = getModelOfInterest(objTo.MobyVariantText__c);
		// 	objTo.ModelOfInterest__c = String.join(modelOfInterest, ';');
		// }
		// else {
		// 	/** Trade In Model */
		// 	string[] tradeInModel = getModelOfInterest(objTo.MobyVariantText__c);
		// 	if (tradeInModel.size() > 0) { objTo.TradeInModel__c = tradeInModel[0]; }
		// }

		// /** Standard Opportunity fields */
		// objTo.LeadSource = objFr.sourceName;
		// objTo.Description = objFr.remarks;
		// objTo.Email = objFr.email;
		// objTo.opportunitieSource = objFr.source;
		// string mobilePhoneFr = UtilPhone.toE164(objFr.mobileCountry + objFr.mobileNo);
		// objTo.MobilePhone = mobilePhoneFr;
		// objTo.Salutation = objFr.title;
		// objTo.LastName = objFr.contactName;
		// objTo.StageName = objFr.statusName;
    }

    public class MobyTestDriveReq extends SyncMobyApiBase.MobyReq {
	}

    public class MobyTestDriveRes {
        public MobyTestDrive[] testDrives;
        public long lastKey;
    }
    public class MobyTestDrive {
		public long id;
		public Integer userId;
		public long contactId;
		public long opportunityId;
		public Integer companyId;
		public string companyCode;
		public string companyName;
		public Integer branchId;
		public string branchCode;
		public string branchName;
		public Integer makeId;
		public string makeCode;
		public string makeName;
		public long taskId;
		public string icNo;
		public long icDocId;
		public string licenseNo;
		public long icDocFrId;
		public long icDocRrId;
		public Datetime licenseExpiryDate;
		public long licenseDocFrId;
		public long licenseDocRrId;
		public long indemnityDocId;
		public long thankYouDocId;
		public Datetime plannedDateStart;
		public Datetime plannedDateEnd;
		public string remarks;
		public Integer sourceUserid;
		public Integer transferUserId;
		public DateTime insertDate;
		public Integer insertUserId;
		public DateTime updateDate;
		public Integer updateUserId;
		public MobyTestDriveDetail[] details;
	}
	public class MobyTestDriveDetail {
		public long id;
		public Integer userId;
		public long contactId;
		public long testDriveId;
		public Integer companyId;
		public Integer branchId;
		public Integer makeId;
		public Integer statusId;
		public string statusCode;
		public string statusName;
		public string stockId;
		public Integer categoryId;
		public string categoryCode;
		public string categoryName;
		public string colour;
		public Integer conditionId;
		public string conditionCode;
		public string conditionName;
		public Integer modelId;
		public string modelCode;
		public string modelName;
		public string modelAssemblyCode;
		public string modelBodyType;
		public string modelCylinder;
		public string modelDisplacement;
		public string modelFuelType;
		public Integer modelMakeId;
		public Integer modelYear;
		public string plateNo;
		public Datetime registrationDate;
		public string registrationNo;
		public Decimal sellingPrice;
		public string shortChassis;
		public Integer stockStatusId;
		public string stockStatusCode;
		public string stockStatusName;
		public string stockStatusNumber;
		public Integer stockSubMakeId;
		public string stockSubMakeCode;
		public string stockSubMakeName;
		public Integer variantId;
		public string variantCode;
		public string variantName;
		public string variantAssemblyCode;
		public string variantBodyType;
		public string variantCylinder;
		public string variantDisplacement;
		public string extVariantUid;
		public string variantFuelType;
		public Integer variantModelId;
		public Integer variantMakeId;
		public string variantSystem;
		public string tradePlateNo;
		public Datetime actualDateStart;
		public Datetime actualDateEnd;
		public Integer mileageStart;
		public Integer mileageEnd;
		public long mileageStartDocId;
		public long mileageEndDocId;
		public long odoStartDocId;
		public long odoEndDocId;
		public Integer guardMileageStart;
		public Integer guardMileageEnd;
		public string extTestDriveUid;
		public Datetime insertDate;
		public Integer insertUserId;
		public Datetime updateDate;
		public Integer updateUserId;
	}
}