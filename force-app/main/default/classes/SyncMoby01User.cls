global class SyncMoby01User implements Database.AllowsCallouts, Queueable {
    private static final String USERNAME = SyncMobyApiBase.USERNAME;
    private static final String PASSWORD = SyncMobyApiBase.PASSWORD;
    private static final String ENDPOINT = SyncMobyApiBase.ENDPOINT + 'mobysf/Users';
    private static final string HEADER_AUTH = Util.genBasicAuthHeader(USERNAME, PASSWORD);
    private static final string JOB_NAME = SyncMobyApiBase.SYNC01USER;
	private static final string CREATEDFROM = 'Moby';

    public string[] company = SyncMobyApiBase.COMPANY_CODE;
    public DateTime dateFrom;
    public DateTime dateTo;
    public string roleCode;
    public Integer[] userId = null;
    public string adUsername = null;
    public string sapId = null;
    public Integer lastId = 0;
    public Integer rowCount = 100;
    public final Integer minRowCount = 10;
    public Boolean followOnToNext = false;
    public SQL_API_Base.RowTracking rt = new SQL_API_Base.RowTracking();

    private static MobyUserRes respUser;
    
    /** Mapping objects */
    private static Map<string, Company__c>			mapCompany;			// companyCode => Company__r.MobyCompanyCode__c
    private static Map<Integer, Showroom__c>		mapBranchById;		// branchId => MobyBranchNumber__c
    private static Map<string, Showroom__c>			mapBranchByCode;	// companyCode + branchCode => Company__r.Name + MobyBranchCode__c
	private static Map<string, Vehicle_Make__c>		mapMakeByCode;		// makeCode => Vehicle_Make__r.Name
    /** Key 1: Users.UserId => Employee_Master__c.MobyUserNumber__c */
    private static Map<integer, Employee_Master__c>	mapEmpByNo;
    /** Key 2: Users.AdUsername => Employee_Master__c.ActiveDirectoryUsername__c */
    private static Map<string, Employee_Master__c>	mapEmpByAd;
    /** Key 3: Users.SapId => Employee_Master__c.Employee_Reference__c (8 chars, 0 padded) */
    private static Map<Integer, Employee_Master__c>	mapEmpBySap;

	/** Key 1: Users.Email => User.Email */
	private static Map<String, User> mapUsrByEmail;

    private static integer[] userIds;
    
    /** Email Diagnostic */
    private static SQL_API_Base.API_DEBUG api;
    private static string[] errEmail = new List<string>();

    public SyncMoby01User() {
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

            respUser = callMobyApi();
            if (respUser != null && respUser.users != null && respUser.users.size() > 0) {
                upsertUser(respUser);
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
                    SyncMoby02Contact q = new SyncMoby02Contact();
					q.company = this.company;
					if (this.dateFrom == null) { q.dateFrom = null; }
                    q.dateTo = this.dateTo;
                    q.followOnToNext = true;
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
                CommonMethodsLibrary.sendErrorEmail(new User[] { SyncMobyApiBase.USER_CUR }, String.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
            }
        }
    }

    public MobyUserRes callMobyApi() {
        Http http = new Http();
        HttpRequest hreq = new HttpRequest();
        hreq.setEndpoint(ENDPOINT);
        hreq.setMethod('POST');
        hreq.setHeader('Content-Type', 'application/json');
        hreq.setHeader('Authorization', HEADER_AUTH);
        MobyUserReq req = new MobyUserReq();
        req.companyCode = this.company;
        // req.dateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
        // req.dateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
        req.dateFrom = this.dateFrom?.addHours(SQL_API_Base.TIMEZONE);
        req.dateTo = this.dateTo?.addHours(SQL_API_Base.TIMEZONE);
        req.id = (long[])this.userId;
        req.sapId = this.sapId;
        req.adUsername = this.adUsername;
        req.lastKey = this.lastId;
        req.rowCount = this.rowCount;
        hreq.setBody(JSON.serialize(req, false));
        hreq.setTimeout(120000);

        /** Prep API request for exception email */
        api = new SQL_API_Base.API_DEBUG();
        api.parse(hreq, new string[] { 'Content-Type', 'Authorization' });

        MobyUserRes res = new MobyUserRes();
        HttpResponse hres;
        try {
            hres = http.send(hreq);
            api.parse(hres);
            if (hres.getStatusCode() == 200) {
                res = (MobyUserRes) JSON.deserialize(hres.getBody(), MobyUserRes.class);
                api.parse(res?.users);
            }
            else { throw new ExternalObjectException(api?.Response); }
        }
        catch (Exception e) { throw e; }
        finally { System.debug(api?.toString()); }

        return res;
    }

    public Database.UpsertResult[] upsertUser(MobyUserRes res) {
        SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
        /** Initialises mapping */
        initMaps(res);
		/** Initialise dependency objects */
		initLookups(res);

        Employee_Master__c[] insertList = new Employee_Master__c[]{};
        Map<Id, Employee_Master__c> updateList = new Map<Id, Employee_Master__c>();
        // Match with order priortised
        Employee_Master__c em;
        Boolean hasEmpMasNo;

        for (MobyUser mu :res.users) {
            em = null;
            hasEmpMasNo = false;

            /** Key 1: Users.UserId => Employee_Master__c.MobyUserNumber__c */
            if (em == null && mu.userId != null) {
                Integer key1 = mu.userId;
                if (mapEmpByNo.containsKey(key1)) {
                    em = mapEmpByNo.get(key1);
                    hasEmpMasNo = true;
                }
            }

            /** Key 2: Users.Username => Employee_Master__r.ActiveDirectoryUsername__c */
            if (em == null && String.isNotBlank(mu.username)) {
                string key2 = mu.username.toUpperCase();
				em = mapEmpByAd.get(key2);
            }

            /** Key 3: Users.SapId => Employee_Master__c.Employee_Reference__c */
            if (em == null && String.isNotBlank(mu.sapId)) {
                Integer key3 = Util.getSapId(mu.sapId);
				em = mapEmpBySap.get(key3);
            }
            
            /** still no match */
            if (em == null) { em = new Employee_Master__c(); }
            boolean isChanged = setValues(mu, em);
            if (em.Id == null) {
                insertList.add(em);
                lt.AddOne(); rt.AddOne();
            }
            else {
                updateList.put(em.Id, em);
                if (isChanged)  { lt.UpdateOne(); rt.UpdateOne(); }
                else            { lt.MatchOne(); rt.MatchOne(); }
            }
        }
        Employee_Master__c[] upsertList = updateList.values();
        upsertList.addAll(insertList);

		Database.UpsertResult[] urs;
        if (upsertList.size() > 0) {
            urs = Database.upsert(upsertList, false);
			if (Test.isRunningTest() || Envir.isSandbox) {
				System.debug('SyncMoby01User.upsertList: ' + JSON.serialize(upsertList));
				System.debug('SyncMoby01User.urs: ' + JSON.serialize(urs));
			}
            String err = CommonMethodsLibrary.emailResultFailure(
                            urs, upsertList, 'upsertEmp (upsertList)'
                            , JOB_NAME, new User[] { SyncMobyApiBase.USER_CUR }, false);
            if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
        }
        /** Record lastId */
        if (userIds.size() > 0) {
            userIds.sort();
            this.lastId = userIds[userIds.size() - 1];
        }
        
        System.debug('Upsert Current: ' + JSON.serialize(lt));

		return urs;
    }

    private static void initMaps(MobyUserRes res) {
        /** Gather all lookup list */
        Set<string>		setCompany		= new Set<string>();	// companyCode
        Set<Integer>	setBranchId		= new Set<Integer>();	// branchId
        Set<string>		setBranchCode	= new Set<string>();	// branchCode
        Set<integer>	setUser			= new Set<integer>();	// userId
        Set<string>		setUsername		= new Set<string>();	// username (Active Directory username)
        Set<string>		setUserBySap	= new Set<string>();	// sapId
		Set<string>		setUserByEmail	= new Set<string>();
        userIds = new List<integer>();
        for (MobyUser mu :res.users) {
            if (String.isNotBlank(mu.companyCode))	{ setCompany.add(mu.companyCode); }
            if (mu.branchId != null)				{ setBranchId.add(mu.branchId); }
            if (String.isNotBlank(mu.branchCode))	{ setBranchCode.add(mu.branchCode); }
            /** Key 1: Users.UserId => Employee_Master__c.MobyUserNumber__c */
            if (mu.userId != null)					{ setUser.add(mu.userId); }
            /** Key 2: Users.Username => Employee_Master__r.ActiveDirectoryUsername__c */
            if (String.isNotBlank(mu.username))		{ setUsername.add(mu.username); }
            /** Key 3: Users.SapId => Employee_Master__c.Employee_Reference__c */
            if (String.isNotBlank(mu.sapId))		{
                try {
                    Integer sapIdNo = Integer.valueOf(mu.sapId);
                    setUserBySap.add(String.valueOf(sapIdNo));
                    setUserBySap.add(Util.padSapId(sapIdNo));
                }
                catch (Exception e) {}
            }
			/** Key 1: Users.email => User.Email__c */
			if (String.isNotBlank(mu.email)) 		{ setUserByEmail.add(mu.email); }
            userIds.add(mu.userId);
        }
		/** companyCode => Company__r.MobyCompanyCode__c */
        mapCompany = new Map<string, Company__c>();
		Company__c[] cmps = [SELECT Id, Name, Description__c, MobyCompanyCode__c FROM Company__c WHERE MobyCompanyCode__c IN :setCompany];
        for (Company__c cmp :cmps) {
            string key = cmp.MobyCompanyCode__c?.toUpperCase();
            mapCompany.put(key, cmp);
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

		/** Employee Master */
        string queryEmp = Database.getQueryLocator([
            SELECT
                Id, Name, CreatedFrom__c, Company__r.Name, Workshop__r.Name
                , MobyUserNumber__c, ActiveDirectoryUsername__c, Employee_Reference__c
                , Email__c, Mobile_Number__c, Team_Code__c, IsActive__c
				, MobyInsertDate__c, MobyUpdateDate__c
            FROM Employee_Master__c
            LIMIT 10
        ]).getQuery().Replace('LIMIT 10', ' ');
		queryEmp += 'WHERE (MobyUserNumber__c IN :setUser) ';
		if (setUsername.size() > 0) { queryEmp += 'OR (ActiveDirectoryUsername__c IN :setUsername) '; }
        if (setUserBySap.size() > 0) { queryEmp += 'OR (Employee_Reference__c IN :setUserBySap) '; }

		System.debug('queryEmp: ' + queryEmp
			.replace(':setUser', JSON.serialize(setUser).replace('[', '(').replace(']', ')').replace('"', '\''))
			.replace(':setUsername', JSON.serialize(setUsername).replace('[', '(').replace(']', ')').replace('"', '\''))
			.replace(':setUserBySap', JSON.serialize(setUserBySap).replace('[', '(').replace(']', ')').replace('"', '\''))
		);

        Employee_Master__c[] ems = Database.query(queryEmp);

        /** Key 1: Users.UserId => Employee_Master__c.MobyUserNumber__c */
        mapEmpByNo = new Map<integer, Employee_Master__c>();
        /** Key 2: Users.Username => Employee_Master__r.ActiveDirectoryUsername__c */
        mapEmpByAd = new Map<string, Employee_Master__c>();
        /** Key 3: Users.SapId => Employee_Master__c.Employee_Reference__c */
        mapEmpBySap = new Map<Integer, Employee_Master__c>();
        
        for (Employee_Master__c em :ems) {
            /** Key 1: Users.UserId => Employee_Master__c.MobyUserNumber__c */
            if (em.MobyUserNumber__c != null) {
                Integer key1 = em.MobyUserNumber__c?.intValue();
                mapEmpByNo.put(key1, em);
            }
            /** Key 2: Users.Username => Employee_Master__r.ActiveDirectoryUsername__c */
            if (String.isNotBlank(em.ActiveDirectoryUsername__c)) {
                string key2 = em.ActiveDirectoryUsername__c.toUpperCase();
                mapEmpByAd.put(key2, em);
            }
            /** Key 3: Users.SapId => Employee_Master__c.Employee_Reference__c */
            if (String.isNotBlank(em.Employee_Reference__c)) {
                Integer key3 = Util.getSapId(em.Employee_Reference__c);
				if (key3 != null) { mapEmpBySap.put(key3, em); }
            }
        }

		/** User */
		string queryUsr = Database.getQueryLocator([
			SELECT
				Id, Name, Department, Email, MobilePhone, Phone, Title
			FROM User
			LIMIT 10
		]).getQuery().Replace('LIMIT 10', ' ');
		if (setUserByEmail.size() > 0) { queryUsr += 'WHERE (Email IN :setUserByEmail) '; }

		System.debug('queryUsr: ' + queryUsr.replace(':setUserByEmail'
									, JSON.serialize(setUserByEmail)
										  .replace('[', '(')
										  .replace(']', ')')
										  .replace('"', '\''))
		);

		User[] usr = Database.query(queryUsr);

		/** Key 1: Users.Email => User.Email */
		mapUsrByEmail = new Map<string, User>();

		for (User us :usr) {
			/** Key 1: Users.Email => User.Email */
			if (String.isNotBlank(us.Email)) {
				string key1 = us.Email.toUpperCase();
				mapUsrByEmail.put(key1, us);
			}
		}
    }

	public static void initLookups(MobyUserRes res) {
		SObject[] tmpso;
		tmpso = genLookups('Showroom', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
	}

	public static SObject[] genLookups(String objType, MobyUserRes res) {
		// Set<SObject> sObjSet = new Set<SObject>();
		SObject sObj;
		Map<string, SObject> mapRet = new Map<string, SObject>();
		for (MobyUser user :res.users) {
			if (objType == 'Showroom') {
				if (user.branchId == null && String.isBlank(user.branchCode)) { continue; }
				Integer key1 = user.branchId;
				string key2 = String.join(new string[] { user.companyCode, user.branchCode }, '_').toUpperCase();
				if (mapBranchById.containsKey(key1))		{
					sObj = mapBranchById.get(key1);
					sObj.put('MobyBranchCode__c', user.branchCode);
				}
				else if (mapBranchByCode.containsKey(key2))	{
					sObj = mapBranchByCode.get(key2);
					sObj.put('MobyBranchNumber__c', user.branchId);
				}
				else {
					sObj = new Showroom__c();
					sObj.put('Name', user.branchName);
					sObj.put('MobyBranchNumber__c', user.branchId);
					sObj.put('MobyBranchCode__c', user.branchCode);
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
				// makeSet.add(user.makeCode);
				// sObj.put('Make__c', String.join((Iterable<string>) makeSet, ';'));

				string keyRet = String.join(new string[] { String.valueOf(key1), key2 }, '_').toUpperCase();
				if (!mapRet.containsKey(keyRet))	{ mapRet.put(keyRet, (Showroom__c) sObj); }
			}
			if (objType != 'Company' && sObj != null) {
				sObj.put('Company__c', mapCompany.get(user.companyCode)?.Id);
				// sObjSet.add(sObj);
			}
		}
		return new List<SObject>(mapRet.values());
	} 

    public static boolean setValues(MobyUser objFr, Employee_Master__c objTo) {
        Boolean hasChanged = false;

        if (objTo.Name != objFr.fullName || objTo.Name != objFr.displayName) {
			if (String.isNotBlank(objFr.fullName)) {
				hasChanged = true;
				objTo.Name = objFr.fullName;
			}
			else if (String.isNotBlank(objFr.displayName)) { 
				hasChanged = true;
				objTo.Name = objFr.displayName;
			}
        }
		if (objTo.Id == null) {
			objTo.CreatedFrom__c = CREATEDFROM;
		}
		else {

		}

		Integer sapIdFr = Util.getSapId(objFr.sapId);
		Integer sapIdTo = Util.getSapId(objTo?.Employee_Reference__c);
		System.debug('objFr.mobileNo: ' + objFr.mobileNo);
		string mobilePhone = UtilPhone.toE164(objFr.mobileNo);
		string homePhone = UtilPhone.toE164(objFr.homePhoneNo);
		string officePhone = UtilPhone.toE164(objFr.officePhoneNo);

		// if (objTo.CreatedFrom__c == CREATEDFROM) {
		objTo.Company__c = mapCompany.get(objFr.CompanyCode?.toUpperCase())?.Id;
		// objTo.MobyUserNumber__c = objFr.UserId;
		objTo.ActiveDirectoryUsername__c = objFr.Username;
		objTo.Employee_Reference__c = String.valueOf(sapIdFr);
		objTo.Email__c = objFr.Email;
		objTo.Mobile_Number__c = mobilePhone;
		objTo.Team_Code__c = objFr.teamCode;
		objTo.IsActive__c = objFr.IsActive;
		if (String.isNotBlank(objFr?.businessRole) && objFr?.businessRole.equalsIgnoreCase('SALESPERSON')) {
			objTo.Employee_Status_Code__c = 'SC';
			objTo.Showroom__c = mapBranchById.get(objFr.branchId).Id;
			if (objTo.Showroom__c == null) {
				objTo.Showroom__c = mapBranchByCode.get(objFr.branchCode).Id;
			}
		}
		// }
		// else {
		// 	if (objTo.Company__c == null)				{ objTo.Company__c = mapCompany.get(objFr.CompanyCode?.toUpperCase())?.Id; }
        //     // objTo.MobyUserNumber__c = objFr.UserId;
		// 	if (objTo.ActiveDirectoryUsername__c == '')	{ objTo.ActiveDirectoryUsername__c = objFr.Username; }
		// 	if (objTo.Employee_Reference__c == '')		{ objTo.Employee_Reference__c = String.valueOf(sapIdFr); }
		// 	if (objTo.Email__c == '')					{ objTo.Email__c = objFr.Email; }
        //     if (objTo.Mobile_Number__c == '')			{ objTo.Mobile_Number__c = mobilePhone; }
		// 	if (objTo.Team_Code__c == '')				{ objTo.Team_Code__c = objFr.teamCode; }
		// }
		objTo.MobyUserNumber__c = objFr.userId;
		objTo.MobyInsertDate__c = objFr.insertDate;
		objTo.MobyUpdateDate__c = objFr.updateDate;

        return hasChanged;
    }

	/** Button: Pull from Care API (Employee_Master__c) */
    Webservice static String refreshUser(Id id) {
        try {
            Employee_Master__c em = [SELECT Id, MobyUserNumber__c FROM Employee_Master__c WHERE Id = :id];
            if (em?.MobyUserNumber__c == null) { return 'Error: Unable to refresh employee record (w/o Employee Number).'; }
            SyncMoby01User q = new SyncMoby01User();
            q.dateFrom = q.dateTo = null;
            q.userId = new Integer[] { em?.MobyUserNumber__c.intValue() };
            MobyUserRes res = q.callMobyApi();
            if (res == null) { return 'Error: Unable to find employee record for refresh.'; }
            q.upsertUser(res);
            return 'Refreshed successfully!';
        }
        catch (QueryException e) { return 'Error: No record found with id: \'' + id + '\''; }
        catch (Exception e) { return 'Error: ' + e.getMessage() + (SyncMobyApiBase.isSandbox ? '\n\n' + e.getStackTraceString() : ''); }
    }

    public class MobyUserReq extends SyncMobyApiBase.MobyReq {
        public string roleCode;
        public string adUsername;
        public string sapId;
    }
	public class MobyUserRes {
		public MobyUser[] users;
		public Integer lastKey;
	}

    public virtual class MobyUser {
		public Integer userId;
		public string username;
		public string displayName;
		public string fullName;
		public string extEmailAddress;
		public string extFullName;
		public string extGuid;
		public string email;
		public string sapId;
		public string mobileNo;
		public string homePhoneNo;
		public string officePhoneNo;
		public string faxNo;
		public string source;
		public Integer companyId;
		public string companyCode;
		public string companyName;
		public Integer branchId;
		public string branchCode;
		public string branchName;
		public Integer makeId;
		public string makeCode;
		public string makeName;
		public Integer teamId;
		public string teamCode;
		public string teamName;
		public string domain;
		public string businessRole;
		public string lastDirectoryUpdate;
		public string timeZone;
		public Boolean claimReward;
		public string countryCode;
		public string country;
		public string userCompanyName;
		public string department;
		public string title;
		public Boolean isActive;
        public DateTime insertDate;
        public Integer insertUserId;
        public DateTime updateDate;
        public Integer updateUserId;
    }

}