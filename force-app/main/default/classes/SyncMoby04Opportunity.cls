public class SyncMoby04Opportunity implements Database.AllowsCallouts, Queueable {
    private static final string USERNAME = SyncMobyApiBase.USERNAME;
    private static final string PASSWORD = SyncMobyApiBase.PASSWORD;
    private static final string ENDPOINT = SyncMobyApiBase.ENDPOINT + 'mobysf/Opportunities';
    private static final string HEADER_AUTH = Util.genBasicAuthHeader(USERNAME, PASSWORD);
    private static final string JOB_NAME = SyncMobyApiBase.SYNC04OPPO;
	private static final string CREATEDFROM = 'Moby';

	public string[] company = SyncMobyApiBase.COMPANY_CODE;
    public DateTime dateFrom;
    public DateTime dateTo;
    public long[] opportunityId = null;
    public long lastId = 0;
    public long rowCount = 500;
    public final Integer minRowCount = 10;
    public Boolean followOnToNext = false;
    public SQL_API_BASE.RowTracking rt = new SQL_API_Base.RowTracking();

    private static MobyOpportunityRes respOppo;

    /** Mapping objects */	
	private static Map<string, Company__c>			mapCompany;			// companyCode => Company__r.MobyCompanyCode__c
	private static Map<Integer, Showroom__c>		mapBranchById;		// branchId => MobyBranchNumber__c
	private static Map<string, Showroom__c>			mapBranchByCode;	// companyCode + branchCode => Company__r.MobyCompanyCode__c + MobyBranchCode__c
	private static Map<Integer, Employee_Master__c> mapEmployee;		// insertUserId, updateUserId => Employee_Master__r.MobyUserNumber__c
	private static Map<long, Account>				mapAccount;			// contactId => Account.MobyContactNumber__c
	private static Map<string, Account>				mapAccountByDocNo;	// icNo => Account.NRIC_Number__c
    private static Map<long, Opportunity>			mapOpportunity;		// id => MobyOpportunityNumber__c
	private static Map<string, Vehicle_Make__c>		mapMake;			// makeCode => Vehicle_Make__c.MobyMakeCode__c
																		// modelInterests[].makeCode => Vehicle_Make__c.MobyMakeCode__c
	private static Map<string, Vehicle_Model__c>	mapModel;			// modelInterests[].makeCode + modelInterests[].modelCode => Vehicle_Model__r.Vehicle_Make__r.Name + Vehicle_Model__c.Name
	private static Map<string, VehicleVariant__c>	mapVariant;			// modelInterests[].makeCode + modelInterests[].modelCode + modelInterests[].modelVariant => VehicleVariant__r.Make__r.Name + VehicleVariant__r.Model__r.Name + VehicleVariant__c.Name
	private static Map<string, Vehicle_Type__c>		mapType;			// carTypeCode => Vehicle_Type__c.MobyTypeCode__c
    private static long[] opportunityIds;
    
    /** Email Diagnostic */
    private static SQL_API_Base.API_DEBUG api;
    private static string[] errEmail = new List<string>();

    public SyncMoby04Opportunity() {
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

            respOppo = callMobyApi();
			if (respOppo != null && respOppo.opportunities != null && respOppo.opportunities.size() > 0) {
                upsertOppo(respOppo);
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
					SyncMoby05TestDrive q = new SyncMoby05TestDrive();
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

	public MobyOpportunityRes callMobyApi() {
        Http http = new Http();
        HttpRequest hreq = new HttpRequest();
        hreq.setEndpoint(ENDPOINT);
        hreq.setMethod('POST');
        hreq.setHeader('Content-Type', 'application/json');
        hreq.setHeader('Authorization', HEADER_AUTH);
        MobyOpportunityReq req = new MobyOpportunityReq();
        req.companyCode = this.company;
        // req.dateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
        // req.dateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
		req.dateFrom = this.dateFrom?.addHours(SQL_API_Base.TIMEZONE);
        req.dateTo = this.dateTo?.addHours(SQL_API_Base.TIMEZONE);
        req.id = this.opportunityId;
        req.lastKey = this.lastId;
        req.rowCount = this.rowCount;
        hreq.setBody(JSON.serialize(req, false));
        hreq.setTimeout(120000);

        /** Prep API request for exception email */
        api = new SQL_API_Base.API_DEBUG();
        api.parse(hreq, new string[] { 'Content-Type', 'Authorization' });

        MobyOpportunityRes res = new MobyOpportunityRes();
        HttpResponse hres;
        try {
            hres = http.send(hreq);
            api.parse(hres);
            if (hres.getStatusCode() == 200) {
                res = (MobyOpportunityRes) JSON.deserialize(hres.getBody(), MobyOpportunityRes.class);
                api.parse(res?.opportunities);
            }
            else { throw new ExternalObjectException(api?.Response); }
        }
        catch (Exception e) { throw e; }
        finally { System.debug(api?.toString()); }

        return res;
    }

	private static OpportunityModel__c[] deleteOm;
	private static OpportunityModel__c[] insertOm;
    public Database.UpsertResult[] upsertOppo(MobyOpportunityRes res) {
        SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
        /** Initialises mapping */
        initMaps(res);
		/** Initialise dependency objects */
		initLookups(res);

        Opportunity[] insertList = new List<Opportunity>();
        Map<Id, Opportunity> updateList = new Map<Id, Opportunity>();
        // Match with order priortised
        Opportunity oppo;
		deleteOm = new OpportunityModel__c[]{};
		insertOm = new OpportunityModel__c[]{};
        for (MobyOpportunity mo :res.opportunities) {
            oppo = null;

            if (mo.id != null) { oppo = mapOpportunity.get(mo.id); }

            /** still no match */
            if (oppo == null) { oppo = new Opportunity(); }
            setValues(mo, oppo);
            if (oppo.Id == null) {
                insertList.add(oppo);
                lt.AddOne(); rt.AddOne();
            }
            else {
                if (updateList.containsKey(oppo.Id)) {
                    updateList.put(oppo.Id, oppo);
                    lt.MatchOne(); rt.MatchOne();
                }
                else {
                    updateList.put(oppo.Id, oppo);
                    lt.UpdateOne(); rt.UpdateOne();
                }
            }
        }
        Opportunity[] upsertList = updateList.values();
        upsertList.addAll(insertList);

		Database.UpsertResult[] urs;
		if (deleteOm.size() > 0) {
			Database.DeleteResult[] drs = Database.delete(deleteOm, false);
			System.debug('deleteOm: ' + JSON.serialize(deleteOm));
			System.debug('deleteOm ret: ' + JSON.serialize(drs));
		}
        if (upsertList.size() > 0) {
            urs = Database.upsert(upsertList, false);
			if (Test.isRunningTest() || Envir.isSandbox) {
				System.debug('SyncMoby04Opportunity.upsertList: ' + JSON.serialize(upsertList));
				System.debug('SyncMoby04Opportunity.urs: ' + JSON.serialize(urs));
			}
            String err = CommonMethodsLibrary.emailResultFailure(
                            urs, upsertList, 'upsertOppo (upsertList)'
                            , JOB_NAME, new User[] { SyncMobyApiBase.USER_CUR }, false);
            if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
        }
		/** Execute after upsertList */
		setModel(res, upsertList);
		if (insertOm.size() > 0) {
			Database.SaveResult[] srs = Database.insert(insertOm, false);
			System.debug('insertOm: ' + JSON.serialize(insertOm));
			System.debug('insertOm ret: ' + JSON.serialize(srs));
			String err = CommonMethodsLibrary.emailResultFailure(
							srs, insertOm, 'upsertOppo (insertOm)'
							, JOB_NAME, new User[] { SyncMobyApiBase.USER_CUR }, false);
			if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
		}
		
        /** Record lastId */
        if (opportunityIds.size() > 0) {
            opportunityIds.sort();
            this.lastId = opportunityIds[opportunityIds.size() - 1];
        }
    
        System.debug('Upsert Current: ' + JSON.serialize(lt));

		return urs;
    }

    private static void initMaps(MobyOpportunityRes res) {
        /** Gather all lookup list */
		Set<string>		setCompany			= new Set<string>();	// companyCode
		Set<Integer>	setBranchId			= new Set<Integer>();	// branchId
		Set<string>		setBranchCode		= new Set<string>();	// branchCode
		Set<Integer>	setUser				= new Set<Integer>();	// insertUserId, updateUserId
		Set<long>		setContactId		= new Set<long>();		// contactId
		Set<string>		setContactIcNo		= new Set<string>();	// icNo
        Set<long>		setOpportunityId	= new Set<long>();		// id
		Set<string>		setMakeCode			= new Set<string>();	// makeCode
		Set<string>		setModelCode		= new Set<string>();	// modelCode
		Set<string>		setVariantCode		= new Set<string>();	// variantCode
		Set<string>		setTypeCode			= new Set<string>();	// carTypeCode
        opportunityIds = new List<long>();
        for (MobyOpportunity mo :res.opportunities) {
			if (String.isNotBlank(mo.companyCode))	{ setCompany.add(mo.companyCode); }
			if (mo.branchId != null)				{ setBranchId.add(mo.branchId); }
			if (String.isNotBlank(mo.branchCode))	{ setBranchCode.add(mo.branchCode); }
			if (String.isNotBlank(mo.makeCode))		{ setMakeCode.add(mo.makeCode); }
			if (mo.insertUserId != null)			{ setUser.add(mo.insertUserId); }
			if (mo.updateUserId != null)			{ setUser.add(mo.updateUserId); }
			if (mo.contactId != null)				{ setContactId.add(mo.contactId); }
			if (String.isNotBlank(mo.icNo))			{ setContactIcNo.add(mo.icNo); }
            if (mo.id != null)      				{ setOpportunityId.add(mo.id); }
            opportunityIds.add(mo.id);
			if (mo.modelInterests != null) {
				for (MobyModel mm :mo.modelInterests) {
					if (String.isNotBlank(mm.makeCode))		{ setMakeCode.add(mm.makeCode); }
					if (String.isNotBlank(mm.modelCode))	{ setModelCode.add(mm.modelCode); }
					if (String.isNotBlank(mm.variantCode))	{ setVariantCode.add(mm.variantCode); }
				}
			}
			if (String.isNotBlank(mo.carTypeCode))	{ setTypeCode.add(mo.carTypeCode); }
        }
		/** companyCode => Company__r.MobyCompanyCode__c */
		mapCompany = new Map<string, Company__c>();
		Company__c[] cmps = [SELECT Id, Name, Description__c, MobyCompanyCode__c FROM Company__c WHERE MobyCompanyCode__c IN :setCompany];
		for (Company__c cmp :cmps) {
			string key = cmp.MobyCompanyCode__c?.toUpperCase();
			if (String.isNotBlank(key)) { mapCompany.put(key, cmp); }
		}

		/** branchId => MobyBranchNumber__c
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
		mapAccountByDocNo = new Map<string, Account>();
		Account[] accs = [SELECT Id, Name, NRIC_Number__c, MobyContactNumber__c FROM Account WHERE MobyContactNumber__c IN :setContactId OR NRIC_Number__c IN :setContactIcNo];
		for (Account acc :accs) {
			long key = acc.MobyContactNumber__c?.longValue();
			if (key != null) { mapAccount.put(key, acc); }
			// string key2 = acc.DocumentNumberAlphaN__c?.toUpperCase();
			string key2 = acc.NRIC_Number__c?.toUpperCase();
			if (String.isNotBlank(key2)) { mapAccountByDocNo.put(key2, acc); }
		}

		/** id => Opportunity.MobyOpportunityNumber__c */
        mapOpportunity = new Map<long, Opportunity>();
        Opportunity[] oppos = [SELECT Id, Name, CreatedFrom__c, MobyOpportunityNumber__c, MobyInsertDate__c, MobyInsertUser__c, MobyUpdateDate__c, MobyUpdateUser__c, (SELECT Id, Name, VehicleModel__c, VehicleVariant__c FROM OpportunityModels__r) FROM Opportunity WHERE (MobyOpportunityNumber__c IN :setOpportunityId)];
		for (Opportunity oppo :oppos) {
			long key = oppo.MobyOpportunityNumber__c?.longValue();
			if (key != null) { mapOpportunity.put(key, oppo); }
		}
		/** makeCode => Vehicle_Make__c.MobyMakeCode__c */
		mapMake = new Map<string, Vehicle_Make__c>();
		Vehicle_Make__c[] makes = [SELECT Id, Name, MobyMakeCode__c FROM Vehicle_Make__c WHERE MobyMakeCode__c IN :setMakeCode];
		for (Vehicle_Make__c make :makes) {
			string key = String.join(new string[] { make.MobyMakeCode__c }, '_').toUpperCase();
			mapMake.put(key, make);
		}
		/** modelCode => Vehicle_Model__c.Name */
		mapModel = new Map<string, Vehicle_Model__c>();
		Vehicle_Model__c[] models = [SELECT Id, Name, Company__r.MobyCompanyCode__c, Vehicle_Make__r.MobyMakeCode__c FROM Vehicle_Model__c WHERE Vehicle_Make__r.MobyMakeCode__c IN :setMakeCode AND Name IN :setModelCode];
		for (Vehicle_Model__c model :models) {
			string key = String.join(new string[] {	model.Vehicle_Make__r?.MobyMakeCode__c, model.Name }, '_').toUpperCase();
			mapModel.put(key, model);
		}
		/** variantCode => VehicleVariant__c.Name */
		mapVariant = new Map<string, VehicleVariant__c>();
		VehicleVariant__c[] variants = [SELECT Id, Name, Company__r.MobyCompanyCode__c, Make__r.MobyMakeCode__c, Model__r.Name FROM VehicleVariant__c WHERE Make__r.MobyMakeCode__c IN :setMakeCode AND Model__r.Name IN :setModelCode AND Name IN :setVariantCode];
		for (VehicleVariant__c variant :variants) {
			string key = String.join(new string[] { variant.Make__r?.MobyMakeCode__c, variant.Model__r?.Name, variant.Name }, '_').toUpperCase();
			mapVariant.put(key, variant);
		}
		/** carTypeCode => Vehicle_Type__c.MobyTypeCode__c */
		mapType = new Map<string, Vehicle_Type__c>();
		Vehicle_Type__c[] types = [SELECT Id, Name, Company__r.MobyCompanyCode__c, MobyTypeCode__c FROM Vehicle_Type__c WHERE MobyTypeCode__c IN :setTypeCode];
		for (Vehicle_Type__c type :types) {
			string key = String.join(new string[] { type.MobyTypeCode__c }, '_').toUpperCase();
			mapType.put(key, type);
		}
    }

	public static void initLookups(MobyOpportunityRes res) {
		SObject[] tmpso;
		tmpso = genLookups('Showroom', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
		tmpso = genLookups('Type', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
	}

	public static SObject[] genLookups(String objType, MobyOpportunityRes res) {
		// Set<SObject> sObjSet = new Set<SObject>();
		SObject sObj;
		Map<string, SObject> mapRet = new Map<string, SObject>();
		for (MobyOpportunity oppo :res.opportunities) {
			if (objType == 'Showroom') {
				Integer key1 = oppo.branchId;
				string key2 = String.join(new string[] { oppo.companyCode, oppo.branchCode }, '_').toUpperCase();
				if (mapBranchById.containsKey(key1))		{
					sObj = mapBranchById.get(key1);
					sObj.put('MobyBranchCode__c', oppo.branchCode);
				}
				else if (mapBranchByCode.containsKey(key2))	{
					sObj = mapBranchByCode.get(key2);
					sObj.put('MobyBranchNumber__c', oppo.branchId);
				}
				else {
					sObj = new Showroom__c();
					sObj.put('Name', oppo.branchName);
					sObj.put('CreatedFrom__c', CREATEDFROM);
					sObj.put('MobyBranchNumber__c', oppo.branchId);
					sObj.put('MobyBranchCode__c', oppo.branchCode);
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
				// makeSet.add(oppo.makeCode);
				// sObj.put('Make__c', String.join((Iterable<string>) makeSet, ';'));

				string keyRet = String.join(new string[] { String.valueOf(key1), key2 }, '_').toUpperCase();
				if (!mapRet.containsKey(keyRet))	{ mapRet.put(keyRet, (Showroom__c) sObj); }
			}
			if (objType == 'Type') {
				if (String.isBlank(oppo.carTypeCode)) { continue; }
				string keyType = String.join (new string[] { oppo.carTypeCode }, '_').toUpperCase();
				if (String.isNotBlank(keyType)) {
					if (mapType.containsKey(keyType)) { sObj = mapType.get(keyType); }
					else {
						sObj = new Vehicle_Type__c();
						sObj.put('Name', oppo.carTypeName);
						sObj.put('Description__c', oppo.carTypeName);
						sObj.put('MobyTypeCode__c', oppo.carTypeCode);
					}
					mapType.put(keyType, (Vehicle_Type__c) sObj);
					if (!mapRet.containsKey(keyType)) { mapRet.put(keyType, (Vehicle_Type__c) sObj); }
				}
			}
			if (objType != 'Company' && sObj != null) {
				sObj.put('Company__c', mapCompany.get(oppo.companyCode)?.Id);
				// sObjSet.add(sObj);
			}
		}
		return new List<SObject>(mapRet.values());
	} 

    public static void setValues(MobyOpportunity objFr, Opportunity objTo) {
		/** Key forming */
		string keyType			= String.join(new string[] { /* objFr.companyCode, */ objFr.carTypeCode }, '_').toUpperCase();

		string rtDevName = 'VehicleSales';
		Id recordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get(rtDevName).getRecordTypeId();

		if (objTo.Id == null) {
			objTo.Name = genOpportunityName(objFr);
			objTo.CreatedFrom__c = CREATEDFROM;
		}
		else {

		}

		if (objTo.CreatedFrom__c == CREATEDFROM) {
			objTo.Name = genOpportunityName(objFr);
			objTo.RecordTypeId = recordTypeId;
			objTo.Company__c = mapCompany.get(objFr.companyCode.toUpperCase())?.Id;
			objTo.VehicleMake__c = mapMake.get(objFr.makeCode.toUpperCase())?.Id;
			objTo.AccountId = mapAccount.get(objFr.contactId)?.Id;
			if (objTo.AccountId == null) { objTo.AccountId = mapAccountByDocNo.get(objFr.icNo)?.Id; }
			objTo.SalesAdvisor__c = mapEmployee.get(objFr.userId)?.Id;
			objTo.Source__c = objFr.sourceName;
			objTo.MobyRecordSource__c = objFr.recordSource;
			objTo.SalesCycleNumber__c = objFr.salescycleId;
			objTo.Status__c = objFr.statusName;
			objTo.LeadStatus__c = objFr.leadStatusName;
			objTo.Lost_Sales_Reason__c = objFr.statusReason;
			objTo.CloseDate = Util.validDate(objFr.updateDate?.date());
			objTo.Remarks__c = objFr.remarks;
			// objTo.Type = objFr.carTypeCode; // New, Used
			objTo.StageName = objFr.stage;
			objTo.Type = 'Vehicle Sales';
			string[] modelOfInterest = getModelOfInterest(objFr.modelInterests);
			objTo.Model_Interest__c = String.join(modelOfInterest, ';');
			/** Delete Model Interest child records */
			if (objTo.Id != null) { deleteOm.addAll(objTo.OpportunityModels__r); }
			objTo.VehicleType__c = mapType.get(keyType)?.Id;
		}
		objTo.MobyOpportunityNumber__c = objFr.id;
		objTo.Showroom__c = mapBranchById.get(objFr.branchId)?.Id;
		if (objTo.Showroom__c == null) {
			string keyBranch = String.join(new string[] { objFr.companyCode, objFr.branchCode }, '_').toUpperCase();
			objTo.Showroom__c = mapBranchByCode.get(objFr.branchCode)?.Id;
		}

		objTo.MobyInsertDate__c = objFr.insertDate;
		objTo.MobyInsertUser__c = mapEmployee.get(objFr.insertUserId)?.Id;
		objTo.MobyUpdateDate__c = objFr.updateDate;
		objTo.MobyUpdateUser__c = mapEmployee.get(objFr.updateUserId)?.Id;

    }

	public static void setModel(MobyOpportunityRes res, Opportunity[] oppos) {
		Map<long, Opportunity> mapOppo = new Map<long, Opportunity>();
		for (Opportunity oppo :oppos) {
			if (oppo.MobyOpportunityNumber__c == null) { continue; }
			mapOppo.put(oppo.MobyOpportunityNumber__c.longValue(), oppo);
		}

		for (MobyOpportunity objFr :res.opportunities) {
			Opportunity objTo = mapOppo.get(objFr.id);
			if (objFr.modelInterests == null) { continue; }
			for (MobyModel model :objFr.modelInterests) {
				if (!model.isActive) { continue; }
				OpportunityModel__c om = new OpportunityModel__c();
				om.Name = model.variantName;
				om.Opportunity__c = objTo.Id;
				string keyMake = String.join(new string[] { model.makeCode }, '_').toUpperCase();
				
				string keyModel = String.join(new string[] { /*objFr.companyCode,*/ model.makeCode, model.modelCode }, '_').toUpperCase();
				om.VehicleModel__c = mapModel.get(keyModel)?.Id;
				string keyVariant = String.join(new string[] { /*objFr.companyCode,*/ model.makeCode, model.modelCode, model.variantCode }, '_').toUpperCase();
				om.VehicleVariant__c = mapVariant.get(keyVariant)?.Id;
				insertOm.add(om);
			}
		}
	}

	public static string genOpportunityName(MobyOpportunity oppo) {
		System.debug('genOppoName: ' + JSON.serialize(oppo));
		/** Get contact name */
		Account ac = mapAccount?.get(oppo.contactId);
		string accountName = ac?.Name;
		/** Get start date */
		Datetime dt = oppo.insertDate;
		string dateYMD = dt.format('yyyy/MM/dd');
		/** Get model interest */
		string model = '';
		if (String.isNotBlank(oppo.variantText)) {
			String[] models = (string[])JSON.deserialize(oppo.variantText, string[].class);
			model = models[0];
		}
		else if (oppo.modelInterests != null) {
			model = oppo.modelInterests[0].modelName;
		}
		else {
			// model = oppo.remarks;
		}
		/** Get Employee Name */
		string employee = '';
		if (oppo.userId != null) {
			employee = mapEmployee.get(oppo.userId)?.Name;
		}

		/** Prep return string */
		string ret = '';
		if (String.isNotBlank(accountName)) {
			if (String.isNotBlank(ret)) { ret += '-'; }
			ret += accountName;
		}
		if (String.isNotBlank(dateYMD)) {
			if (String.isNotBlank(ret)) { ret += '-'; }
			ret += dateYMD;
		}
		// if (String.isNotBlank(model)) {
		// 	if (String.isNotBlank(ret)) { ret += '-'; }
		// 	ret += model;
		// }
		if (String.isNotBlank(employee)) {
			if (String.isNotBlank(ret)) { ret += '-'; }
			ret += employee;
		}
		return ret.left(120);
	}

	public static string[] getModelOfInterest(MobyModel[] models) {
		string[] ret = new string[]{};
		if (models == null || models.size() == 0) { return ret; }
		Set<string> setModel = new Set<string>();
		for (MobyModel model :models) {
			if (model.isActive) { setModel.add(model.variantName); }
		}
		ret.addAll(setModel);
		ret.sort();

		return ret;
	}

    public class MobyOpportunityReq extends SyncMobyApiBase.MobyReq {
	}

    public class MobyOpportunityRes {
        public MobyOpportunity[] opportunities;
        public long lastKey;
    }
    public class MobyOpportunity {
		public long id;
		public long leadId;
		public string opportunityType;
		public Integer userId;
		public Integer companyId;
		public string companyCode;
		public string companyName;
		public Integer branchId;
		public string branchCode;
		public string branchName;
		public string externalId;
		public string extDealerUid;
		public Integer makeId;
		public string makeCode;
		public string makeName;
		public long extMakeId;
		public Integer salescycleId;
		public long contactId;
		public string icNo;
		public Integer sourceId;
		public string sourceCode;
		public string sourceName;
		public string recordSource;
		public Integer eventId;
		public string eventCode;
		public string eventName;
		public string extUid;
		public Integer carTypeId;
		public string carTypeCode;
		public string carTypeName;
		public Integer statusId;
		public string statusCode;
		public string statusName;
		public string extStatusId;
		public string extStateId;
		public string extResponseId;
		public string extReasoncodeId;
		public string extLostReasonNo;
		public Integer prospectDocId;
		public Datetime deferredDate;
		public Integer warmth;
		public Integer leadStatusId;
		public string leadStatusCode;
		public string leadStatusName;
		public string variantText;
		public string remarks;
		public string stage;
		public string statusReason;
		public Integer sourceUserid;
		public Integer transferUserId;
		public string extLeadUid;
		public string extOpportunityUid;
		public string extCustomerUid;
		public Datetime insertDate;
		public Datetime updateDate;
		public Integer insertUserId;
		public Integer updateUserId;
		public MobyModel[] modelInterests;
	}
	public class MobyModel {
		public Integer id;
		public long headerId;
		public string variantCode;
		public string variantName;
		public string variantAssemblyCode;
		public string variantBodyType;
		public string variantCylinder;
		public string variantDisplacement;
		public string extVariantUid;
		public string variantFuelType;
		public Integer variantModelId;
		public string modelCode;
		public string modelName;
		public string modelAssemblyCode;
		public string modelBodyType;
		public string modelCylinder;
		public string modelDisplacement;
		public string modelFuelType;
		public Integer makeId;
		public string makeCode;
		public string makeName;
		public string variantSystem;
		public Boolean isActive;
	}
}