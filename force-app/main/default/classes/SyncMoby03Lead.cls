public class SyncMoby03Lead implements Database.AllowsCallouts, Queueable {
    private static final string USERNAME = SyncMobyApiBase.USERNAME;
    private static final string PASSWORD = SyncMobyApiBase.PASSWORD;
    private static final string ENDPOINT = SyncMobyApiBase.ENDPOINT + 'mobysf/Leads';
    private static final string HEADER_AUTH = Util.genBasicAuthHeader(USERNAME, PASSWORD);
    private static final string JOB_NAME = SyncMobyApiBase.SYNC03LEAD;
	private static final string CREATEDFROM = 'Moby';
    private static final string EMAIL_REG = '^[a-z0-9!#$%&\'*+/=?^_`{|}~-]+(?:\\.[a-z0-9!#$%&\'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$';

    public string[] company = SyncMobyApiBase.COMPANY_CODE;
    public DateTime dateFrom;
    public DateTime dateTo;
    public long[] leadId = null;
    public long lastId = 0;
    public long rowCount = 500;
    public final Integer minRowCount = 10;
    public Boolean followOnToNext = false;
    public SQL_API_BASE.RowTracking rt = new SQL_API_Base.RowTracking();

    private static MobyLeadRes respLead;

    /** Mapping objects */
	private static Map<string, Company__c> mapComp;				// companyCode => Company__r.MobyCompanyCode__c
	private static Map<Integer, Showroom__c> mapBranchById;		// branchId => MobyBranchNumber__c
	private static Map<string, Showroom__c> mapBranchByCode;	// companyCode + branchCode => Company__r.MobyCompanyCode__c + MobyBranchCode__c
	private static Map<Integer, Employee_Master__c> mapEmpl;	// insertUserId, updateUserId => Employee_Master__r.MobyUserNumber__c
    private static Map<long, Lead> mapLead;						// Key 1: Leads.Id => Lead.MobyLeadNumber__c
	private static Map<long, Account> mapAccount;				// contactId => Account.MobyContactNumber__c
	private static Map<string, Vehicle_Make__c> mapMake;		// makeCode => Vehicle_Make__c.MobyMakeCode__c
	private static Map<string, Vehicle_Model__c> mapModel;		// modelCode => Vehicle_Model__c.Name
	private static Map<string, VehicleVariant__c> mapVariant;	// modelVariant => VehicleVariant__c.Name
    private static long[] leadIds;
    
    /** Email Diagnostic */
    private static SQL_API_Base.API_DEBUG api;
    private static string[] errEmail = new List<string>();
	private static Map<string, SQL_API_Base.ErrorTracking> errSobject = new Map<string, SQL_API_Base.ErrorTracking>();

    public SyncMoby03Lead() {
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

            respLead = callMobyApi();
			if (respLead != null && respLead.leads != null && respLead.leads.size() > 0) {
                upsertLead(respLead);
                System.debug('Upsert Total: ' + JSON.serialize(rt));
				if (errSobject.keySet().size() > 0) {
					string body = JSON.serialize(errSobject);
					Util.sendEmail(new User[] { SQL_API_Base.USER_CUR }, Envir.subject + ': SyncMoby03Lead Error!', body);
				}
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
                    SyncMoby04Opportunity q = new SyncMoby04Opportunity();
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

    public MobyLeadRes callMobyApi() {
        Http http = new Http();
        HttpRequest hreq = new HttpRequest();
        hreq.setEndpoint(ENDPOINT);
        hreq.setMethod('POST');
        hreq.setHeader('Content-Type', 'application/json');
        hreq.setHeader('Authorization', HEADER_AUTH);
        MobyLeadReq req = new MobyLeadReq();
        req.companyCode = this.company;
        // req.dateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
        // req.dateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
		req.dateFrom = this.dateFrom?.addHours(SQL_API_Base.TIMEZONE);
        req.dateTo = this.dateTo?.addHours(SQL_API_Base.TIMEZONE);
        req.id = this.leadId;
        req.lastKey = this.lastId;
        req.rowCount = this.rowCount;
        hreq.setBody(JSON.serialize(req, false));
        hreq.setTimeout(120000);

        /** Prep API request for exception email */
        api = new SQL_API_Base.API_DEBUG();
        api.parse(hreq, new string[] { 'Content-Type', 'Authorization' });

        MobyLeadRes res = new MobyLeadRes();
        HttpResponse hres;
        try {
            hres = http.send(hreq);
            api.parse(hres);
            if (hres.getStatusCode() == 200) {
                res = (MobyLeadRes) JSON.deserialize(hres.getBody(), MobyLeadRes.class);
                api.parse(res?.leads);
            }
            else { throw new ExternalObjectException(api?.Response); }
        }
        catch (Exception e) { throw e; }
        finally { System.debug(api?.toString()); }

        return res;
    }

	private static LeadModel__c[] deleteLm;
	private static LeadModel__c[] insertLm;
    public Database.UpsertResult[] upsertLead(MobyLeadRes res) {
        SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
        /** Initialises mapping */
        initMaps(res);
		/** Initialise dependency objects */
		initLookups(res);

        Lead[] insertList = new List<Lead>();
        Map<Id, Lead> updateList = new Map<Id, Lead>();
        // Match with order priortised
        Lead lead;
		deleteLm = new LeadModel__c[]{};
		insertLm = new LeadModel__c[]{};
        for (MobyLead ml :res.leads) {
            lead = null;

            if (ml.id != null) { lead = mapLead.get(ml.id); }

            /** still no match */
            if (lead == null) { lead = new Lead(); }
            setValues(ml, lead);
            if (lead.Id == null) {
                insertList.add(lead);
                lt.AddOne(); rt.AddOne();
            }
            else {
                if (updateList.containsKey(lead.Id)) {
                    updateList.put(lead.Id, lead);
                    lt.MatchOne(); rt.MatchOne();
                }
                else {
                    updateList.put(lead.Id, lead);
                    lt.UpdateOne(); rt.UpdateOne();
                }
            }
        }
        Lead[] upsertList = updateList.values();
        upsertList.addAll(insertList);

		Database.UpsertResult[] urs;
		if (deleteLm.size() > 0) {
			Database.DeleteResult[] drs = Database.delete(deleteLm, false);
			System.debug('deleteLm: ' + JSON.serialize(deleteLm));
			System.debug('deleteLm ret: ' + JSON.serialize(drs));
		}
        if (upsertList.size() > 0) {
            urs = Database.upsert(upsertList, false);
			System.debug('upsertList: ' + JSON.serialize(upsertList));
			System.debug('upsertList ret: ' + JSON.serialize(urs));
            String err = CommonMethodsLibrary.emailResultFailure(
                            urs, upsertList, 'upsertLead (upsertList)'
                            , JOB_NAME, new User[] { SyncMobyApiBase.USER_CUR }, false);
            if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
        }
		/** Execute after upsertList */
		setModel(res, upsertList);
		if (insertLm.size() > 0) {
			Database.SaveResult[] srs = Database.insert(insertLm, false);
			System.debug('insertLm: ' + JSON.serialize(insertLm));
			System.debug('insertLm ret: ' + JSON.serialize(srs));
            String err = CommonMethodsLibrary.emailResultFailure(
                            srs, insertLm, 'upsertLead (insertLm)'
                            , JOB_NAME, new User[] { SyncMobyApiBase.USER_CUR }, false);
            if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
        }
        /** Record lastId */
        if (leadIds.size() > 0) {
            leadIds.sort();
            this.lastId = leadIds[leadIds.size() - 1];
        }
    
        System.debug('Upsert Current: ' + JSON.serialize(lt));

		return urs;
    }

    private static void initMaps(MobyLeadRes res) {
        /** Gather all lookup list */
		Set<string>		setCompany		= new Set<string>();	// companyCode
		Set<Integer>	setBranchId		= new Set<Integer>();	// branchId
		Set<string>		setBranchCode	= new Set<string>();	// branchCode
		Set<Integer>	setUser			= new Set<Integer>();	// insertUserId, updateUserId
        Set<long>		setLeadId		= new Set<long>();		// id
		Set<long>		setContactId	= new Set<long>();		// contactId
		Set<string>		setMakeCode		= new Set<string>();	// makeCode
		Set<string>		setModelCode	= new Set<string>();	// modelCode
		Set<string>		setVariantCode	= new Set<string>();	// variantCode
        leadIds = new List<long>();
        for (MobyLead ml :res.leads) {
            if (ml.id != null)      				{ setLeadId.add(ml.id); }
			if (ml.contactId != null)				{ setContactId.add(ml.contactId); }
			if (String.isNotBlank(ml.companyCode))	{ setCompany.add(ml.companyCode); }
			if (String.isNotBlank(ml.makeCode))		{ setMakeCode.add(ml.makeCode); }
			if (ml.branchId != null)				{ setBranchId.add(ml.branchId); }
			if (String.isNotBlank(ml.branchCode))	{ setBranchCode.add(ml.branchCode); }
			if (ml.insertUserId != null)			{ setUser.add(ml.insertUserId); }
			if (ml.updateUserId != null)			{ setUser.add(ml.updateUserId); }
            leadIds.add(ml.id);
			if (ml.modelInterests != null) {
				for (MobyModel mm :ml.modelInterests) {
					if (String.isNotBlank(mm.modelCode))	{ setModelCode.add(mm.modelCode.toUpperCase()); }
					if (String.isNotBlank(mm.variantCode))	{ setVariantCode.add(mm.variantCode.toUpperCase()); }
				}
			}
        }
		/** companyCode => Company__r.MobyCompanyCode__c */
		mapComp = new Map<string, Company__c>();
		Company__c[] cmps = [SELECT Id, Name, Description__c, MobyCompanyCode__c FROM Company__c WHERE MobyCompanyCode__c IN :setCompany];
		for (Company__c cmp :cmps) {
			string key = cmp.MobyCompanyCode__c?.toUpperCase();
			if (String.isNotBlank(key)) { mapComp.put(key, cmp); }
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
		mapEmpl = new Map<Integer, Employee_Master__c>();
		Employee_Master__c[] emps = [SELECT Id, Name, MobyUserNumber__c FROM Employee_Master__c WHERE MobyUserNumber__c IN :setUser];
		for (Employee_Master__c emp :emps) {
			Integer key = emp.MobyUserNumber__c?.intValue();
			if (key != null) { mapEmpl.put(key, emp); }
		}
		
		/** id => Lead.MobyLeadNumber__c */
        mapLead = new Map<long, Lead>();
        Lead[] leads = [SELECT Id, Name, CreatedFrom__c, MobyLeadNumber__c, MobyInsertDate__c, MobyInsertUser__c, MobyUpdateDate__c, MobyUpdateUser__c, (SELECT Id, Name, VehicleModel__c, VehicleVariant__c FROM LeadModels__r) FROM Lead WHERE (MobyLeadNumber__c IN :setLeadId)];
		for (Lead lead :leads) {
			if (lead.MobyLeadNumber__c != null) {
				long key = lead.MobyLeadNumber__c?.longValue();
				mapLead.put(key, lead);
			}
		}

		/** contactId => Account.MobyContactNumber__c */
		mapAccount = new Map<long, Account>();
		Account[] accounts = [SELECT Id, MobyContactNumber__c FROM Account WHERE MobyContactNumber__c IN :setContactId];
		for (Account account :accounts) {
			if (account.MobyContactNumber__c != null) {
				long key = account.MobyContactNumber__c?.longValue();
				mapAccount.put(key, account);
			}
		}

		/** makeCode => Vehicle_Make__c.MobyMakeCode__c */
		mapMake = new Map<string, Vehicle_Make__c>();
		Vehicle_Make__c[] makes = [SELECT Id, Name, Company__r.MobyCompanyCode__c, MobyMakeCode__c FROM Vehicle_Make__c WHERE MobyMakeCode__c IN :setMakeCode];
		for (Vehicle_Make__c make :makes) {
			string key = String.join(new string[] { make.Company__r.MobyCompanyCode__c?.toUpperCase(), make.MobyMakeCode__c?.toUpperCase() }, '_');
			mapMake.put(key, make);
		}
		/** modelCode => Vehicle_Model__c.Name */
		mapModel = new Map<string, Vehicle_Model__c>();
		Vehicle_Model__c[] models = [SELECT Id, Name, Company__r.MobyCompanyCode__c, Vehicle_Make__r.MobyMakeCode__c FROM Vehicle_Model__c WHERE Name IN :setModelCode];
		for (Vehicle_Model__c model :models) {
			string key = String.join(new string[] {	model.Company__r.MobyCompanyCode__c?.toUpperCase(), model.Vehicle_Make__r?.MobyMakeCode__c?.toUpperCase(), model.Name }, '_');
			mapModel.put(key, model);
		}
		/** variantCode => VehicleVariant__c.Name */
		mapVariant = new Map<string, VehicleVariant__c>();
		VehicleVariant__c[] variants = [SELECT Id, Name, Company__r.MobyCompanyCode__c, Make__r.MobyMakeCode__c, Model__r.Name FROM VehicleVariant__c WHERE Name IN :setVariantCode];
		for (VehicleVariant__c variant :variants) {
			string key = String.join(new string[] { variant.Company__r.MobyCompanyCode__c?.toUpperCase(), variant.Make__r?.MobyMakeCode__c?.toUpperCase(), variant.Model__r?.Name.toUpperCase(), variant.Name.toUpperCase() }, '_'); 
			mapVariant.put(key, variant);
		}
    }

	public static void initLookups(MobyLeadRes res) {
		SObject[] tmpso;
		tmpso = genLookups('Showroom', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
	}

	public static SObject[] genLookups(String objType, MobyLeadRes res) {
		// Set<SObject> sObjSet = new Set<SObject>();
		SObject sObj;
		Map<string, SObject> mapRet = new Map<string, SObject>();
		for (MobyLead lead :res.leads) {
			if (objType == 'Showroom') {
				if (lead.branchId == null && String.isBlank(lead.branchCode)) { continue; }
				Integer key1 = lead.branchId;
				string key2 = String.join(new string[] { lead.companyCode, lead.branchCode }, '_').toUpperCase();
				if (mapBranchById.containsKey(key1))		{
					sObj = mapBranchById.get(key1);
					sObj.put('MobyBranchCode__c', lead.branchCode);
				}
				else if (mapBranchByCode.containsKey(key2))	{
					sObj = mapBranchByCode.get(key2);
					sObj.put('MobyBranchNumber__c', lead.branchId);
				}
				else {
					sObj = new Showroom__c();
					sObj.put('Name', lead.branchName);
					sObj.put('CreatedFrom__c', CREATEDFROM);
					sObj.put('MobyBranchNumber__c', lead.branchId);
					sObj.put('MobyBranchCode__c', lead.branchCode);
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
				// makeSet.add(lead.makeCode);
				// sObj.put('Make__c', String.join((Iterable<string>) makeSet, ';'));

				string keyRet = String.join(new string[] { String.valueOf(key1), key2 }, '_').toUpperCase();
				if (!mapRet.containsKey(keyRet))	{ mapRet.put(keyRet, (Showroom__c) sObj); }
			}
			if (objType != 'Company' && sObj != null) {
				sObj.put('Company__c', mapComp.get(lead.companyCode)?.Id);
				// sObjSet.add(sObj);
			}
		}
		return new List<SObject>(mapRet.values());
	} 

    public static void setValues(MobyLead objFr, Lead objTo) {
		if (objTo.Id == null) {
			objTo.CreatedFrom__c = CREATEDFROM;
		}
		else {

		}

		if (objTo.CreatedFrom__c == CREATEDFROM) {
			string email = objFr.email?.trim();
			UtilPhone up = new UtilPhone(objFr.mobileCountry + objFr.mobileNo);
			string mobileNoFr = up.toE164();
			Integer mobilePrefixFr = up.getCountryCode();
			string nationalNoFr = up.toNoPrefixNumber();
			string keyMake = string.join(new string[] { objFr.companyCode, objFr.makeCode }, '_');

			objTo.Company__c = mapComp.get(objFr.companyCode?.toUpperCase())?.Id;
			objTo.MobyLeadNumber__c = objFr.id;
			objTo.Account__c = mapAccount.get(objFr.contactId)?.Id;
			objTo.VehicleMake__c = mapMake.get(keyMake)?.Id;
			objTo.MobySforceParam__c = objFr.sforceParam;
			objTo.MobyVariantText__c = objFr.variantText;
			if (String.isBlank(objFr.type) || !objFr.type?.equalsIgnoreCase('TradeIn')) {
				/** Sales Model of Interest */
				string[] modelOfInterest = getModelOfInterest(objFr.variantText);
				if (modelOfInterest.size() == 0) { modelOfInterest = getModelOfInterest(objFr.modelInterests); }
				objTo.ModelOfInterest__c = String.join(modelOfInterest, ';');
			}
			else {
				/** Trade In Model */
				string[] tradeInModel = getModelOfInterest(objFr.variantText);
				if (tradeInModel.size() > 0) { objTo.TradeInModel__c = tradeInModel[0]; }
			}
			/** Standard Lead fields */
			objTo.Description = objFr.remarks;
			if (String.isNotBlank(email) && !Util.checkEmail(email)) {
				/** Invalid email */
				string key = String.valueOf(objFr.id);
				if (errSobject.containsKey(key)) {
					SQL_API_Base.ErrorTracking et = errSobject.get(key);
					et.message += ';Invalid email: ' + email;
				}
				else {
					errSobject.put(key, new SQL_API_Base.ErrorTracking(objFr, objTo, 'Invalid email: ' + email));
				}
			}
			if (Util.checkEmail(email))	{ objTo.Email = email; }
			objTo.LeadSource = objFr.source;
			objTo.MobilePhone = mobileNoFr;
			// objTo.MobilePhone = up.toInternational();
			objTo.Salutation = objFr.title;
			objTo.LastName = objFr.contactName;
			objTo.Status = objFr.leadStatus;
			/** Delete Model Interest child records */
			if (objTo.Id != null) { deleteLm.addAll(objTo.LeadModels__r); }
		}
		objTo.MobyInsertDate__c = objFr.insertDate;
		objTo.MobyInsertUser__c = mapEmpl.get(objFr.insertUserId)?.Id;
		objTo.MobyUpdateDate__c = objFr.updateDate;
		objTo.MobyUpdateUser__c = mapEmpl.get(objFr.updateUserId)?.Id;
    }

	public static void setModel(MobyLeadRes res, Lead[] leads) {
		Map<long, Lead> mapLead = new Map<long, Lead>();
		for (Lead lead :leads) {
			if (lead.MobyLeadNumber__c == null) { continue; }
			mapLead.put(lead.MobyLeadNumber__c.longValue(), lead);
		}

		for (MobyLead objFr :res.leads) {
			Lead objTo = mapLead.get(objFr.id);
			if (objFr.modelInterests == null) { continue; }
			for (MobyModel model :objFr.modelInterests) {
				if (!model.isActive) { continue; }
				LeadModel__c lm = new LeadModel__c();
				lm.Name = model.variantName;
				lm.Lead__c = objTo.Id;
				string keyModel = String.join(new string[] { objFr.companyCode, model.makeCode, model.modelCode }, '_');
				lm.VehicleModel__c = mapModel.get(keyModel)?.Id;
				string keyVariant = String.join(new string[] { objFr.companyCode, model.makeCode, model.modelCode, model.variantCode }, '_');
				lm.VehicleVariant__c = mapVariant.get(keyVariant)?.Id;
				insertLm.add(lm);
			}
		}
	}

	public static string[] getModelOfInterest(string variantText) {
		string[] ret = new string[]{};

		try {
			ret = (string[])JSON.deserialize(variantText, string[].class);
		}
		catch (Exception e) {
			/** Try comma delimited */
			try {
				string[] tmp = variantText.split(',');
				for (string t :tmp) { ret.add(t.trim()); }
			}
			catch (Exception f) {}
		}

		return ret;
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


    public class MobyLeadReq extends SyncMobyApiBase.MobyReq {
	}

    public class MobyLeadRes {
        public MobyLead[] leads;
        public long lastKey;
    }
    public class MobyLead {
        public long id;
        public Integer companyId;
        public string companyCode;
        public string companyName;
        public Integer makeId;
        public string makeCode;
        public string makeName;
        public Integer branchId;
        public string branchCode;
        public string branchName;
        public long contactId;
        public string title;
        public string contactName;
        public string mobileCountry;
        public string mobileNo;
        public string email;
        public string location;
        public string remarks;
        public string source;
        public string variantText;
        public DateTime branchAssignDate;
        public DateTime lastEmailDate;
        public string referenceText;
        public string sforceParam;
        public string extOpportunityUid; // UUID
        public long opportunityId;
        public string insertRemark;
        public string type;
        public DateTime insertDate;
        public Integer insertUserId;
        public DateTime updateDate;
        public Integer updateUserId;
        public Boolean isDeleted;
		public string leadStatus;
		public MobyModel[] modelInterests;
    }
	public class MobyModel {
		public long id;
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