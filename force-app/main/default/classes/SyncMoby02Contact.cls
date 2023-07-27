global class SyncMoby02Contact implements Database.AllowsCallouts, Queueable {
	private static final String USERNAME = SyncMobyApiBase.USERNAME;
    private static final String PASSWORD = SyncMobyApiBase.PASSWORD;
    private static final String ENDPOINT = SyncMobyApiBase.ENDPOINT + 'mobysf/Contacts';
    private static final string HEADER_AUTH = Util.genBasicAuthHeader(USERNAME, PASSWORD);
    private static final string JOB_NAME = SyncMobyApiBase.SYNC02CONT;
	private static final string CREATEDFROM = 'Moby';

	public string[] company = SyncMobyApiBase.COMPANY_CODE;
    public DateTime dateFrom;
    public DateTime dateTo;
    public long[] contactId = null;
    public long lastId = 0;
    public long rowCount = 100;
    public final Integer minRowCount = 10;
    public Boolean followOnToNext = false;
    public SQL_API_Base.RowTracking rt = new SQL_API_Base.RowTracking();

	private static MobyContactRes respCont;

	/** Mapping objects */
	private static Map<string, Company__c> mapCompany;			// companyCode => Company__r.MobyCompanyCode__c
	private static Map<Integer, Employee_Master__c> mapEmpl;	// insertUserId, updateUserId => Employee_Master__r.MobyUserNumber__c
	private static Map<long, Account> mapAccByMobyNo;			// id => MobyAccountNumber__c
	private static Map<string, Account> mapAccByDocNo;			// icNo => NRIC_Number__c
	private static Map<string, Account> mapAccByNpe;			// Name + Phone + Email
	private static Map<string, Account> mapAccByNp;				// Name + Phone
	private static Map<string, Account> mapAccByPe;				// Phone + Email
	
	private static long[] contactIds;
    
    /** Email Diagnostic */
    private static SQL_API_Base.API_DEBUG api;
    private static string[] errEmail = new List<string>();
	private static Map<string, SQL_API_Base.ErrorTracking> errSobject = new Map<string, SQL_API_Base.ErrorTracking>();

    public SyncMoby02Contact() {
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

            respCont = callMobyApi();
			if (respCont != null && respCont.contacts != null && respCont.contacts.size() > 0) {
                upsertContact(respCont);
                System.debug('Upsert Total: ' + JSON.serialize(rt));
				if (errSobject.keySet().size() > 0) {
					string body = JSON.serialize(errSobject);
					Util.sendEmail(new User[] { SQL_API_Base.USER_CUR }, Envir.subject + ': SyncMoby02Contact Error!', body);
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
                    SyncMoby03Lead q = new SyncMoby03Lead();
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

	public MobyContactRes callMobyApi() {
        Http http = new Http();
        HttpRequest hreq = new HttpRequest();
        hreq.setEndpoint(ENDPOINT);
        hreq.setMethod('POST');
        hreq.setHeader('Content-Type', 'application/json');
        hreq.setHeader('Authorization', HEADER_AUTH);
        MobyContactReq req = new MobyContactReq();
        req.companyCode = this.company;
        // req.dateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
        // req.dateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
		req.dateFrom = this.dateFrom?.addHours(SQL_API_Base.TIMEZONE);
        req.dateTo = this.dateTo?.addHours(SQL_API_Base.TIMEZONE);
        req.id = this.contactId;
        req.lastKey = this.lastId;
        req.rowCount = this.rowCount;
        hreq.setBody(JSON.serialize(req, false));
        hreq.setTimeout(120000);

        /** Prep API request for exception email */
        api = new SQL_API_Base.API_DEBUG();
        api.parse(hreq, new string[] { 'Content-Type', 'Authorization' });

        MobyContactRes res = new MobyContactRes();
        HttpResponse hres;
        try {
            hres = http.send(hreq);
            api.parse(hres);
            if (hres.getStatusCode() == 200) {
                res = (MobyContactRes) JSON.deserialize(hres.getBody(), MobyContactRes.class);
                api.parse(res?.contacts);
            }
            else { throw new ExternalObjectException(api?.Response); }
        }
        catch (Exception e) { throw e; }
        finally { System.debug(api?.toString()); }

        return res;
    }


	private static Account[] insertAccs;
	private static Contact[] insertCons;
	private static Account[] updateAcRt;
	private static Account[] updateAccs;
	private static Map<Id, Hobby__c> deleteHobbies;
	private static Hobby__c[] insertHobbies;
    public void upsertContact(MobyContactRes res) {
        SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
        /** Initialises mapping */
        initMaps(res);

		// Deletion list
		insertAccs = new Account[]{};
		insertCons = new Contact[]{};
		updateAcRt = new Account[]{};
		updateAccs = new Account[]{};
		deleteHobbies = new Map<Id, Hobby__c>();
		insertHobbies = new Hobby__c[]{};

        // Match with order priortised
        Account account;
		Boolean hasContactNo, hasDocNo, hasNpe, hasNp, hasPe;
        for (MobyContact mc :res.contacts) {
            account = null;
			hasContactNo = false;
			hasDocNo = false;
			hasNpe = false;

			/** Key 1: Contacts.Id => Account.MobyContactNumber__c */
            if (account == null && mc.id != null) {
				long key1 = mc.id;
				System.debug('Try key1/mapAccByMobyNo: ' + key1 + ' : ' + JSON.serialize(mapAccByMobyNo));
				if (mapAccByMobyNo.containsKey(key1)) {
					account = mapAccByMobyNo.get(key1);
					hasContactNo = true;
					if (account != null) {
						account.MobyMatchKey__c = '[' + JSON.serialize(Datetime.now()).replace('"', '') + '] Key 1: ' + String.valueOf(key1);
						System.debug('Match Key 1 : ' + JSON.serialize(account));
					}
				}
			}

			/** Key 2: Contacts.icNo => Account.NRIC_Number__c */
			if (account == null && String.isNotBlank(mc.icNo)) {
				Util.Identification id = Util.getIdent(mc.icNo);
				string key2 = id.DocNumber.toUpperCase();
				System.debug('Try key2/mapAccByDocNo: ' + key2 + ' : ' + JSON.serialize(mapAccByDocNo));
				if (mapAccByDocNo.containsKey(key2)) {
					account = mapAccByDocNo.get(key2);
					hasDocNo = true;
					if (account != null) {
						account.MobyMatchKey__c = '[' + JSON.serialize(Datetime.now()).replace('"', '') + '] Key 2: ' + key2;
						System.debug('Match Key 2 : ' + JSON.serialize(account));
					}
				}
			}
			
			string mobileNo = UtilPhone.toE164(mc.mobileNo);
			/** Key 3: contactName + mobileNo + email => Account.Name + Account.PersonMobilePhone/(Account.Mobile_Country_Code_1__pc + Account.Mobile_Preferred__pc) + Account.Default_Email__c */
			if (account == null && String.isNotBlank(mc.contactName?.trim()) && String.isNotBlank(mobileNo) && String.isNotBlank(mc.email?.trim())) {
				string key3 = String.join(new string[] { mc.contactName?.trim(), mobileNo, mc.email?.trim() }, '_').toUpperCase();
				System.debug('Try key3/mapAccByNpe: ' + key3 + ' : ' + JSON.serialize(mapAccByNpe));
				if (mapAccByNpe.containsKey(key3)) {
					account = mapAccByNpe.get(key3);
					hasNpe = true;
					if (account != null) {
						account.MobyMatchKey__c = '[' + JSON.serialize(Datetime.now()).replace('"', '') + '] Key 3: ' + key3;
						System.debug('Match Key 3 : ' + JSON.serialize(account));
					}
				}
			}

			/** Key 4: contactName + mobileNo => Account.Name + Account.PersonMobilePhone/(Account.Mobile_Country_Code_1__pc + Account.Mobile_Preferred__pc) */
			if (account == null && String.isNotBlank(mc.contactName?.trim()) && String.isNotBlank(mobileNo)) {
				string key4 = String.join(new string[] { mc.contactName?.trim(), mobileNo }, '_').toUpperCase();
				System.debug('Try key4/mapAccByNp: ' + key4 + ' : ' + JSON.serialize(mapAccByNp));
				if (mapAccByNp.containsKey(key4)) {
					System.debug('match key4: ' + key4);
					account = mapAccByNp.get(key4);
					hasNp = true;
					if (account != null) {
						account.MobyMatchKey__c = '[' + JSON.serialize(Datetime.now()).replace('"', '') + '] Key 4: ' + key4;
						System.debug('Match Key 4 : ' + JSON.serialize(account));
					}
				}
			}

			/** weak & probably dangerous match. */
			/** Key 5: mobileNo + email => Account.PersonMobilePhone/(Account.Mobile_Country_Code_1__pc + Account.Mobile_Preferred__pc) + Account.Default_Email__c */
			if (account == null && String.isNotBlank(mobileNo) && String.isNotBlank(mc.email?.trim())) {
				string key5 = String.join(new string[] { mobileNo, mc.email?.trim() }, '_').toUpperCase();
				System.debug('Try key5/mapAccByPe: ' + key5 + ' : ' + JSON.serialize(mapAccByPe));
				if (mapAccByPe.containsKey(key5)) {
					account = mapAccByPe.get(key5);
					hasPe = true;
					if (account != null) {
						account.MobyMatchKey__c = '[' + JSON.serialize(Datetime.now()).replace('"', '') + '] Key 5: ' + key5;
						System.debug('Match Key 5 : ' + JSON.serialize(account));
					}
				}
			}

            /** still no match */
            if (account == null) {
				System.debug('match failed.');
				account = new Account();
				account.MobyMatchKey__c = '[' + JSON.serialize(Datetime.now()).replace('"', '') + '] Created';
			}
            // setValuesOld(mc, account, insertCons, updateAcRt, hasContactNo, hasDocNo, hasNpe, hasNp, hasPe);
			setValues(mc, account);
			if (account.Id == null)	{ lt.AddOne(); rt.AddOne(); }
			else					{ lt.UpdateOne(); rt.UpdateOne(); }
        }
		// Database.UpsertResult[] urs;
		Database.SaveResult[] srs;
		String err;
		/** Delete Hobbies first */
		if (deleteHobbies.size() > 0) {
			System.debug('deleteHobbies: ' + JSON.serialize(deleteHobbies));
			Database.DeleteResult[] drs = Database.delete(deleteHobbies.values(), false);
			System.debug('deleteHobbies drs: ' + JSON.serialize(drs));
			// err = CommonMethodsLibrary.emailResultFailure(
			// 			drs, deleteHobbies, 'insertAccount (deleteHobbies)'
			// 			, JOB_NAME, new User[] { SyncMobyApiBase.USER_CUR }, false);
			// if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
		}
		if (insertAccs.size() > 0) {
			/** Insert new Accounts */
			System.debug('insertAccs: ' + JSON.serialize(insertAccs));
			srs = Database.insert(insertAccs, false);
			System.debug('insertAccs srs: ' + JSON.serialize(srs));
			err = CommonMethodsLibrary.emailResultFailure(
						srs, insertAccs, 'insertAccount (insertAccs)'
						, JOB_NAME, new User[] { SyncMobyApiBase.USER_CUR }, false);
			if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
		}
		if (insertCons.size() > 0) {
			/** Inject new Contacts before RecordType updates */
			for (Contact cont :insertCons) { if (cont.AccountId == null) { cont.AccountId = cont.Account.Id; }}
			System.debug('insertCons: ' + JSON.serialize(insertCons));
			srs = Database.insert(insertCons, false);
			System.debug('insertCons srs: ' + JSON.serialize(srs));
		}
		if (updateAcRt.size() > 0) {
			/** Update Account's RecordTypes */
			System.debug('updateAcRt: ' + JSON.serialize(updateAcRt));
			srs = Database.update(updateAcRt, false);
			System.debug('updateAcRt srs: ' + JSON.serialize(srs));
		}
		if (updateAccs.size() > 0) {
			/** Remove Duplicate item in list */
			Map<Id, Account> mapAccs = new Map<Id, Account>();
			for (Account acc :updateAccs) { mapAccs.put(acc.Id, acc); }
			System.debug('mapAccs.values(): ' + JSON.serialize(mapAccs.values()));
			srs = Database.update(mapAccs.values(), false);
			System.debug('mapAccs.values() srs: ' + JSON.serialize(srs));
			err = CommonMethodsLibrary.emailResultFailure(
					srs, mapAccs.values(), 'updateAccount (mapAccs.values())'
					, JOB_NAME, new User[] { SyncMobyApiBase.USER_CUR }, false);
			if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
		}
		/** Insert Hobbies */
		Account[] upsertList = new Account[]{};
		upsertList.addAll(insertAccs);
		upsertList.addAll(updateAccs);
		setHobby(res, upsertList);
		if (insertHobbies.size() > 0) {
			System.debug('insertHobbies: ' + JSON.serialize(insertHobbies));
			srs = Database.insert(insertHobbies, false);
			System.debug('insertHobbies srs: ' + JSON.serialize(srs));
			err = CommonMethodsLibrary.emailResultFailure(
						srs, insertHobbies, 'insertAccount (insertHobbies)'
						, JOB_NAME, new User[] { SyncMobyApiBase.USER_CUR }, false);
			if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
		}
        /** Record lastId */
        if (contactIds.size() > 0) {
            contactIds.sort();
            this.lastId = contactIds[contactIds.size() - 1];
        }
    
        System.debug('Upsert Current: ' + JSON.serialize(lt));

		// return srs;
    }

    private static void initMaps(MobyContactRes res) {
        /** Gather all lookup list */
		Set<string>		setCompany				= new Set<string>();	// companyCode
        Set<long>		setContactId			= new Set<long>();		// id
		Set<string>		setContactIcNo			= new Set<string>();	// icNo
		Set<string>		setContactName			= new Set<string>();	// contactName
		Set<string>		setContactMobileNo		= new Set<string>();	// mobileNo
		Set<String>		setContactMobileNoWc	= new Set<string>();	// % + mobileNo
		Set<string>		setContactEmail			= new Set<string>();	// email
		Set<Integer>	setUser					= new Set<Integer>();	// insertUserId, updateUserId
        contactIds = new List<long>();
        for (MobyContact mc :res.contacts) {
			if (String.isNotBlank(mc.companyCode))	{ setCompany.add(mc.companyCode); }
			/** Key 1: Contacts.Id => Account.MobyContactNumber__c */
            if (mc.id != null)      				{ setContactId.add(mc.id); }
			/** Key 2: Contacts.icNo => Account.NRIC_Number__c */
			Util.Identification id = Util.getIdent(mc.icNo);
			System.debug('mc.icNo: ' + mc.icNo + ': ' + JSON.serialize(id));
			if (String.isNotBlank(id.DocNumber))	{ setContactIcNo.add(id.DocNumber); }
			if (String.isNotBlank(mc.contactName?.trim()))	{ setContactName.add(mc.contactName?.trim()); }
			if (String.isNotBlank(mc.mobileNo))		{
				UtilPhone uphone = new UtilPhone(mc.mobileNo);
				string natNo = '%' + uphone.toNoPrefixNumber();
				if (String.isNotBlank(uphone.toE164()))				{ setContactMobileNo.add(uphone.toE164()); }
				if (String.isNotBlank(uphone.toNoPrefixNumber()))	{ setContactMobileNoWc.add(natNo); }
			}
			if (String.isNotBlank(mc.email?.trim()))		{
				mc.email = mc.email?.trim().replace(' ', '');
				setContactEmail.add(mc.email?.trim());
			}
			if (mc.insertUserId != null)			{ setUser.add(mc.insertUserId); }
			if (mc.updateUserId != null)			{ setUser.add(mc.updateUserId); }

            contactIds.add(mc.id);
			System.debug('mc co code: ' + mc.companyCode);
        }
		/** companyCode => Company__r.MobyCompanyCode__c */
		mapCompany = new Map<string, Company__c>();
		System.debug('setCompany: ' + JSON.serialize(setCompany));
		Company__c[] cmps = [SELECT Id, Name, Description__c, MobyCompanyCode__c FROM Company__c WHERE MobyCompanyCode__c IN :setCompany];
		System.debug('cmps: ' + JSON.serialize(cmps));
		for (Company__c cmp :cmps) {
			string key = cmp.MobyCompanyCode__c?.toUpperCase();
			if (String.isNotBlank(key)) { mapCompany.put(key, cmp); }
		}

		/** insertUserId, updateUserId => Employee_Master__r.MobyUserId__c */
		mapEmpl = new Map<Integer, Employee_Master__c>();
		Employee_Master__c[] emps = [SELECT Id, Name, MobyUserNumber__c FROM Employee_Master__c WHERE MobyUserNumber__c IN :setUser];
		for (Employee_Master__c emp :emps) {
			Integer key = emp.MobyUserNumber__c?.intValue();
			if (key != null) { mapEmpl.put(key, emp); }
		}

		string queryAcc = Database.getQueryLocator([
			SELECT
				Id, Name, DisplayName__c, OfficialName__c, IsPersonAccount
				, Customer_Number__c, MobyContactNumber__c, CompanyName__pc
				, Doc_Type__c, NRIC_Number__c, DocumentNumberAlphaN__c, License__pc
				, PersonMobilePhone, PersonEmail, Phone
				, Mobile_Country_Code_1__pc, Mobile_Preferred__pc
				, Office_Email__c, Home_Email__c, Other_Email__c, Default_Email__c
				, Active_Work__c, Active_Home__c, Active_Other__c
				, CustomerExternalAccounts__c
				, Created_From__c, RecordTypeId
				, (SELECT Id, Name FROM Contacts)
				, (SELECT Id, Name, Hobby__c, Code__c, Type__c, IsActive__c, MobyHobbyNumber__c FROM Hobbies__r)
			FROM Account
			LIMIT 200
		]).getQuery().Replace('LIMIT 200', ' ');
		queryAcc += 'WHERE (MobyContactNumber__c IN :setContactId) ';
		if (setContactIcNo.size() > 0) {
			queryAcc += 'OR (NRIC_Number__c IN :setContactIcNo) ';
			// queryAcc += 'OR (DocumentNumberAlphaN__c IN :setContactIcNo) ';
		}
		if (setContactName.size() > 0) {
			queryAcc += 'OR (Name != null AND Name IN :setContactName) ';
			// queryAcc += 'OR (OfficialName__c != null AND OfficialName__c LIKE :setContactName) ';
		}
		if (setContactMobileNo.size() > 0) {
			queryAcc += 'OR (PersonMobilePhone != null AND PersonMobilePhone IN :setContactMobileNo) ';
		}
		if (setContactMobileNoWc.size() > 0) {
			queryAcc += 'OR (Mobile_Preferred__pc != null AND Mobile_Preferred__pc LIKE :setContactMobileNoWc) ';
		}
		if (setContactEmail.size() > 0) {
			queryAcc += 'OR ((Office_Email__c != null AND Office_Email__c IN :setContactEmail) ' +
						'OR (Home_Email__c != null AND Home_Email__c IN :setContactEmail) ' +
						'OR (Other_Email__c != null AND Other_Email__c IN :setContactEmail)) ';
			queryAcc += 'OR (PersonEmail != null AND PersonEmail IN :setContactEmail) ';
		}
		/** Order By */
		queryAcc += 'ORDER BY CreatedDate DESC ';
		
		System.debug('queryAcc: ' + queryAcc
			.replace(':setContactId', JSON.serialize(setContactId).replace('[', '(').replace(']', ')').replace('"', '\''))
			.replace(':setContactIcNo', JSON.serialize(setContactIcNo).replace('[', '(').replace(']', ')').replace('"', '\''))
			.replace(':setContactName', JSON.serialize(setContactName).replace('[', '(').replace(']', ')').replace('"', '\''))
			.replace(':setContactMobileNoWc', JSON.serialize(setContactMobileNoWc).replace('[', '(').replace(']', ')').replace('"', '\''))
			.replace(':setContactMobileNo', JSON.serialize(setContactMobileNo).replace('[', '(').replace(']', ')').replace('"', '\''))
			.replace(':setContactEmail', JSON.serialize(setContactEmail).replace('[', '(').replace(']', ')').replace('"', '\''))
		);

		Account[] accs = Database.query(queryAcc);

		mapAccByMobyNo = new Map<long, Account>();
		mapAccByDocNo = new Map<string, Account>();
		mapAccByNpe = new Map<string, Account>();
		mapAccByNp = new Map<string, Account>();
		mapAccByPe = new Map<string, Account>();

		for (Account acc :accs) {
			if (acc.MobyContactNumber__c != null) {
				/** Key 1: id => Account.MobyContactNumber__c */
				long key = acc.MobyContactNumber__c.longValue();
				System.debug('Init Key 1 (Moby.Id => MobyContactNumber__c): ' + key);
				mapAccByMobyNo.put(key, acc);
			}

			/** TODO: DocumentNumberAlphaN__c */
			if (String.isNotBlank(acc.NRIC_Number__c)) {
				/** Key 2: icNo => Account.NRIC_Number__c */
				string key = acc.NRIC_Number__c.trim().toUpperCase();
				System.debug('Init Key 2 (icNo => NRIC_Number__c): ' + key);
				mapAccByDocNo.put(key, acc);
			}

			/** Key 3: Name + Mobile (Country + Preferred) + Default Email */
			if (String.isNotBlank(acc.Name) && acc.Mobile_Country_Code_1__pc != null && String.isNotBlank(acc.Mobile_Preferred__pc) && String.isNotBlank(acc.Default_Email__c)) {
				/** Key 3: contactName + mobileNo + email => Account.Name + Account.Mobile_Country_Code_1__pc + Account.Mobile_Preferred__pc + Account.Default_Email__c */
				string phone = UtilPhone.toE164(String.valueOf(acc.Mobile_Country_Code_1__pc) + acc.Mobile_Preferred__pc);
				string name = acc.Name.trim();
				string key;
				key = String.join(new string[] { name, phone, acc.Default_Email__c }, '_').toUpperCase();
				System.debug('Init Key 3 (country+preferred): ' + key);
				mapAccByNpe.put(key, acc);
				name = Util.purifyName(name);
				key = String.join(new string[] { name, phone, acc.Default_Email__c }, '_').toUpperCase();
				mapAccByNpe.put(key, acc);
			}

			/** Key 3: Name + PersonMobilePhone + Default Email */
			if (String.isNotBlank(acc.Name) && String.isNotBlank(acc.PersonMobilePhone) && String.isNotBlank(acc.Default_Email__c)) {
				/** Key 3: contactName + mobileNo + email => Account.Name + Account.PersonMobilePhone + Account.Default_Email__c */
				string phone = UtilPhone.toE164(acc.PersonMobilePhone); // always format phone
				string name = acc.Name.trim();
				string key;
				key = String.join(new string[] { name, phone, acc.Default_Email__c }, '_').toUpperCase();
				System.debug('Init Key 3: ' + key);
				mapAccByNpe.put(key, acc);
				name = Util.purifyName(name);
				key = String.join(new string[] { name, phone, acc.Default_Email__c }, '_').toUpperCase();
				mapAccByNpe.put(key, acc);
			}

			/** Key 4: Name + Mobile (Country + Preferred) */
			if (String.isNotBlank(acc.Name) && acc.Mobile_Country_Code_1__pc != null && String.isNotBlank(acc.Mobile_Preferred__pc)) {
				/** Key 4: contactName + mobileNo => Account.Name + Acount.Mobile_Country_Code_1__pc + Account.Mobile_Preferred__pc */
				string phone = UtilPhone.toE164(String.valueOf(acc.Mobile_Country_Code_1__pc) + acc.Mobile_Preferred__pc);
				string name = acc.Name.trim();
				string key;
				key = String.join(new string[] { name, phone }, '_').toUpperCase();
				System.debug('Init Key 4 (country+preferred): ' + key);
				mapAccByNp.put(key, acc);
				name = Util.purifyName(name);
				key = String.join(new string[] { name, phone }, '_').toUpperCase();
				mapAccByNp.put(key, acc);
			}

			/** Key 4: Name + PersonMobilePhone */
			if (String.isNotBlank(acc.Name) && String.isNotBlank(acc.PersonMobilePhone)) {
				/** Key 4: contactName + mobileNo => Account.Name + Account.PersonMobilePhone */
				string phone = UtilPhone.toE164(acc.PersonMobilePhone); // always format phone
				string name = acc.Name.trim();
				string key;
				key = String.join(new string[] { name, phone }, '_').toUpperCase();
				System.debug('Init Key 4: ' + key);
				mapAccByNp.put(key, acc);
				name = Util.purifyName(name);
				key = String.join(new string[] { name, phone }, '_').toUpperCase();
				mapAccByNp.put(key, acc);
			}

			/** Key 5: Mobile (Country + Preferred) + Default Email */
			if (acc.Mobile_Country_Code_1__pc != null && String.isNotBlank(acc.Mobile_Preferred__pc) && String.isNotBlank(acc.Default_Email__c)) {
				/** Key 5: mobileNo + email => Account.Mobile_Country_Code_1__pc + Account.Mobile_Preferred__pc + Account.Default_Email__c */
				string phone = UtilPhone.toE164(String.valueOf(acc.Mobile_Country_Code_1__pc) + acc.Mobile_Preferred__pc);
				string key = String.join(new string[] { phone, acc.Default_Email__c }, '_').toUpperCase();
				System.debug('Init Key 5 (country+preferred): ' + key);
				mapAccByPe.put(key, acc);
			}

			/** Key 5: PersonMobilePhone + Default Email */
			if (String.isNotBlank(acc.PersonMobilePhone) && String.isNotBlank(acc.Default_Email__c)) {
				/** Key 5: mobileNo + email => Account.PersonMobilePhone + Account.Default_Email__c */
				string phone = UtilPhone.toE164(acc.PersonMobilePhone); // always format phone
				string key = String.join(new string[] { phone, acc.Default_Email__c }, '_').toUpperCase();
				System.debug('Init Key 5: ' + key);
				mapAccByPe.put(key, acc);
			}
		}
	}

	public static void setValues(MobyContact objFr, Account objCur) {
		Util.Identification id = Util.getIdent(objFr.icNo);
		string rtDevName = id.DocType.equalsIgnoreCase('Company Reg No.') ? 'Business_Account' : 'PersonAccount';
		Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(rtDevName).getRecordTypeId();
		RecordType rt = Envir.recordTypeById.get(recordTypeId);
		UtilPhone up = new UtilPhone(objFr.mobileNo);
		string mobileNoFr = up.toE164();
		Integer mobilePrefixFr = up.getCountryCode();
		string nationalNoFr = up.toNoPrefixNumber();
		string email = objFr.email?.trim();
		string[] hobbies = getHobby(objFr.hobbies);

		/** Capture erroneous email */
		if (String.isNotBlank(email) && !Util.checkEmail(email)) {
			/** Invalid email */
			string key = String.valueOf(objFr.id);
			if (errSobject.containsKey(key)) {
				SQL_API_Base.ErrorTracking et = errSobject.get(key);
				et.message += ';Invalid email: ' + email;
			}
			else {
				errSobject.put(key, new SQL_API_Base.ErrorTracking(objFr, 'Invalid email: ' + email));
			}
		}
		/** Capture erroneous birthday */
		if (objFr.birthday != null && Util.validDate(objFr.birthday.date()) == null) {
			/** Invalid date range */
			string key = String.valueOf(objFr.id);
			string message = 'Invalid birthday: ' + objFr.birthday;
			if (errSobject.containsKey(key)) {
				SQL_API_Base.ErrorTracking et = errSobject.get(key);
				et.message += ';' + message;
			}
			else {
				errSobject.put(key, new SQL_API_Base.ErrorTracking(objFr, message));
			}
		}
		
		if (objCur.Id == null) {
			/** New Account */
			System.debug('Name: ' + objFr.contactName + ' / moby no: ' + objFr.id);
			Account objTo = new Account();
			objTo.RecordTypeId = recordTypeId;
			objTo.Created_From__c = CREATEDFROM;
			objTo.Doc_Type__c = id.DocType;
			objTo.NRIC_Number__c = id.Original;
			objTo.DocumentNumberAlphaN__c = id.DocNumber;
			if (id.DocType == 'Malaysian NRIC') { objTo.Verified_with_NRIC__c = true; }
			objTo.MobyContactNumber__c = objFr.id;
			objTo.MobyMatchKey__c = objCur.MobyMatchKey__c;
			objTo.AccountSource = objFr.source;
			objTo.Income_Group__c = objFr.incomeGroupName;
			objTo.Hobby__c = String.join(hobbies, ';');

			/** Sync flags */
			objTo.MobyInsertDate__c = objFr.insertDate;
			objTo.MobyInsertUser__c = mapEmpl.get(objFr.insertUserId)?.Id;
			objTo.MobyUpdateDate__c = objFr.updateDate;
			objTo.MobyUpdateUser__c = mapEmpl.get(objFr.updateUserId)?.Id;
			
			if (rt.IsPersonType) {
				/** New Person Account */
				System.debug('New Person Account: ' + JSON.serialize(objFr));
				objTo.Salutation = objFr.title?.trim();
				objTo.LastName = objFr.contactName?.trim();
				objTo.Account_Name__c = objFr.contactName?.trim();
				// objTo.OfficialName__c = objFr.contactName?.trim();
				objTo.DisplayName__c = objFr.nickname?.trim();
				objTo.Prefer_Name__pc = objFr.nickname?.trim();
				objTo.Marital_Status__pc = objFr.maritalStatusName;
				objTo.CompanyName__pc = objFr.contactCompanyName?.trim();
				objTo.License__pc = objFr.licenseNo;
				if (String.isNotBlank(mobileNoFr))	{
					objTo.PersonMobilePhone = mobileNoFr;
					objTo.Mobile_Country_Code_1__pc = mobilePrefixFr;
					objTo.Mobile_Preferred__pc = nationalNoFr;
				}
				if (Util.checkEmail(email))	{
					objTo.PersonEmail = email;
					objTo.Home_Email__c = email;
					objTo.Active_Home__c = true;
				}
				if (objTo.Doc_Type__c == 'Malaysian NRIC' && (objFr.birthday == null || Date.valueOf(objFr.birthday) == Date.newInstance(1900, 1, 1))) {
					/** Calculate Birthdate from IC if API date is not set (Unset: 1900-01-01) */
					objTo.PersonBirthdate = u.getBirthdate(objTo.NRIC_Number__c);
				}
				else {
					objTo.PersonBirthdate = Util.validDate(objFr.birthday?.date());
				}
				objTo.PersonMailingStreet = objFr.address?.trim();
				objTo.PersonMailingCity = objFr.city?.trim();
				objTo.PersonMailingPostalCode = objFr.postCode?.trim();
				objTo.PersonMailingState = objFr.state?.trim();
			}
			else {
				/** New Business Account */
				System.debug('New Business Account: ' + JSON.serialize(objFr));
				objTo.Name = String.isNotBlank(objFr.contactCompanyName?.trim()) ? objFr.contactCompanyName?.trim() : objFr.contactName?.trim();
				if (String.isNotBlank(mobileNoFr))	{ objTo.Phone = mobileNoFr; }
				if (Util.checkEmail(email))	{
					objTo.Office_Email__c = email;
					objTo.Active_Work__c = true;
				}
				objTo.ShippingStreet = objFr.address?.trim();
				objTo.ShippingCity = objFr.city?.trim();
				objTo.ShippingPostalCode = objFr.postCode?.trim();
				objTo.ShippingState = objFr.state?.trim();

				/** Do not created Contact for Business Account
				 * so no duplicate is being created when
				 * Business Account creation failed and retried.
				 */
				// insCons.add(new Contact(
				// 	Salutation = objFr.title?.trim()
				// 	, LastName = objFr.contactName?.trim()
				// 	, Account = objTo
				// 	, CreatedFrom__c = CREATEDFROM
				// ));
			}

			insertAccs.add(objTo);
		}
		else {
			/** Existing Account */
			Account objTo = new Account();
			// objTo = objCur;
			// objTo.RecordTypeId = null;
			objTo.Id = objCur.Id;
			objTo.Created_From__c = objCur.Created_From__c;
			objTo.Home_Email__c = objCur.Home_Email__c;
			objTo.Active_Home__c = objCur.Active_Home__c;
			objTo.Other_Email__c = objCur.Other_Email__c;
			objTo.Active_Other__c = objCur.Active_Other__c;
			objTo.Office_Email__c = objCur.Office_Email__c;
			objTo.Active_Work__c = objCur.Active_Work__c;
			/** Capture erroneous email */
			if (String.isNotBlank(email) && !Util.checkEmail(email)) {
				/** Invalid email */
				string key = String.valueOf(objFr.id);
				string message = 'Invalid email: ' + objFr.email;
				if (errSobject.containsKey(key)) {
					SQL_API_Base.ErrorTracking et = errSobject.get(key);
					et.message += ';' + message;
				}
				else {
					errSobject.put(key, new SQL_API_Base.ErrorTracking(objFr, objTo, message));
				}
			}
			/** Capture erroneous birthday */
			if (objFr.birthday != null && Util.validDate(objFr.birthday.date()) == null) {
				/** Invalid date range */
				string key = String.valueOf(objFr.id);
				string message = 'Invalid birthday: ' + objFr.birthday;
				if (errSobject.containsKey(key)) {
					SQL_API_Base.ErrorTracking et = errSobject.get(key);
					et.message += ';' + message;
				}
				else {
					errSobject.put(key, new SQL_API_Base.ErrorTracking(objFr, objTo, message));
				}
			}
			if (objCur.Customer_Number__c == null && objCur.CustomerExternalAccounts__c == 0) {
				System.debug('Unlinked existing account . . .');
				/** Update RecordType - only when not linked to AL */
				if (objCur.RecordTypeId != recordTypeId) {
					System.debug('Change RecordType:');
					System.debug('IsPerson: ' + objCur?.RecordTypeId + ' (' + Envir.recordTypeById.get(objCur.RecordTypeId)?.IsPersonType + ') -> ' + recordTypeId + ' (' + Envir.recordTypeById.get(recordTypeId)?.IsPersonType + ')');
					/** Insert Contact if RecordType Business -> Person */
					if (rt.IsPersonType) {
						System.debug('objCur.Contacts: ' + objCur.Contacts);
						System.debug('objCur.Contacts.size(): ' + objCur.Contacts?.size());
						if (objCur.Contacts == null || objCur.Contacts.size() == 0) {
							insertCons.add(new Contact(
								Salutation = objFr.title?.trim()
								, LastName = objFr.contactName?.trim()
								, AccountId = objCur.Id
								, CreatedFrom__c = CREATEDFROM
							));
						}
					}
					/** Account.RecordTypeId changed */
					updateAcRt.add(new Account(Id = objCur.Id, RecordTypeId = recordTypeId));
					rt = Envir.recordTypeById.get(recordTypeId);
				}
				/** Exclude RecordTypeId from fields update SOQL */
				// objTo.MobyContactNumber__c = objCur.MobyContactNumber__c;
				if (id.DocType?.equalsIgnoreCase('Invalid')) {
					if (String.isBlank(objCur.Doc_Type__c))		{ objTo.Doc_Type__c = id.DocType; }
					if (String.isBlank(objCur.NRIC_Number__c))	{ objTo.NRIC_Number__c = id.Original; }
					if (String.isBlank(objTo.DocumentNumberAlphaN__c))
															{ objTo.DocumentNumberAlphaN__c = id.DocNumber; }
				}
				else {
					objTo.Doc_Type__c = id.DocType;
					objTo.NRIC_Number__c = id.Original;
					objTo.DocumentNumberAlphaN__c = id.DocNumber;
				}
				objTo.Income_Group__c = objFr.incomeGroupName;
				objTo.Hobby__c = String.join(hobbies, ';');
				if (rt.IsPersonType) {
					System.debug('Unlinked existing Person Account: ' + JSON.serialize(objCur.Id));
					/** Unlinked existing Person Account */
					objTo.Salutation = objFr.title?.trim();
					objTo.LastName = objFr.contactName?.trim();
					objTo.DisplayName__c = objFr.nickname?.trim();
					objTo.Prefer_Name__pc = objFr.nickname?.trim();
					objTo.Marital_Status__pc = objFr.maritalStatusName;
					objTo.CompanyName__pc = objFr.contactCompanyName?.trim();
					objTo.License__pc = objFr.licenseNo;
					if (String.isNotBlank(mobileNoFr))	{
						objTo.PersonMobilePhone = mobileNoFr;
						objTo.Mobile_Country_Code_1__pc = mobilePrefixFr;
						objTo.Mobile_Preferred__pc = nationalNoFr;
					}
					if (Util.checkEmail(email))	{
						objTo.PersonEmail = email;
						CommonMethodsLibrary.setEmail(objTo, email);
					}
					objTo.PersonBirthdate = Util.validDate(objFr.birthday?.date());
					objTo.PersonMailingStreet = objFr.address?.trim();
					objTo.PersonMailingCity = objFr.city?.trim();
					objTo.PersonMailingPostalCode = objFr.postCode?.trim();
					objTo.PersonMailingState = objFr.state?.trim();
				}
				else {
					System.debug('Unlinked existing Business Account: ' + JSON.serialize(objCur.Id));
					/** Unlinked existing Business Account */
					objTo.Name = String.isNotBlank(objFr.contactCompanyName?.trim()) ? objFr.contactCompanyName?.trim() : objFr.contactName?.trim();
					if (String.isNotBlank(mobileNoFr))	{ objTo.Phone = mobileNoFr; }
					if (Util.checkEmail(email))	{
						objTo.Office_Email__c = email;
						objTo.Active_Work__c = true;
						if (objTo.Home_Email__c == email)	{ objTo.Home_Email__c = ''; }
						if (objTo.Other_Email__c == email) { objTo.Other_Email__c = ''; }
						objTo.Active_Home__c = objTo.Active_Other__c = false;
					}
					objTo.ShippingStreet = objFr.address?.trim();
					objTo.ShippingCity = objFr.city?.trim();
					objTo.ShippingPostalCode = objFr.postCode?.trim();
					objTo.ShippingState = objFr.state?.trim();
	
					// System.debug('objCur.Contacts: ' + objCur.Contacts);
					// System.debug('objCur.Contacts.size(): ' + objCur.Contacts?.size());
					// if (objCur.Contacts == null || objCur.Contacts.size() == 0) {
					// 	insertCons.add(new Contact(
					// 		Salutation = objFr.title?.trim()
					// 		, LastName = objFr.contactName?.trim()
					// 		, AccountId = objTo.Id
					// 		, CreatedFrom__c = CREATEDFROM
					// 	));
					// }
				}

			}
			else {
				/** Account already linked to Autoline/Whip */
				rt = Envir.recordTypeById.get(objCur.RecordTypeId);
				// rt = Envir.recordTypeById.get(recordTypeId);
				if (rt.IsPersonType) {
					/** Linked Autoline/Whip Person Account */
					System.debug('Linked Person Account: ' + JSON.serialize(objTo.Id));
					if (String.isNotBlank(email) && String.isBlank(objTo.Default_Email__c))	{
						if (objTo.Office_Email__c != email && objTo.Other_Email__c != email && objTo.Home_Email__c != email) { // find a space to put the new email
							if (String.isBlank(objTo.Home_Email__c))		{ objTo.Home_Email__c = email; }
							else if (String.isBlank(objTo.Office_Email__c))	{ objTo.Office_Email__c = email; }
							else											{ objTo.Other_Email__c = email; }
						}
						if (!(objTo.Active_Work__c && objTo.Active_Home__c && objTo.Active_Other__c)) {
							if (objTo.Office_Email__c == email)		{ objTo.Active_Work__c = true; objTo.Active_Home__c = objTo.Active_Other__c = false; }
							else if (objTo.Home_Email__c == email)	{ objTo.Active_Home__c = true; objTo.Active_Work__c = objTo.Active_Other__c = false; }
							else if (objTo.Other_Email__c == email)	{ objTo.Active_Other__c = true; objTo.Active_Work__c = objTo.Active_Home__c = false; }
						}
					}
					if (objFr.birthday != null && objTo.PersonBirthdate == null) { objTo.PersonBirthdate = Util.validDate(objFr.birthday?.date()); }
				}
				else {
					/** Linked Autoline Business Account */
					System.debug('Linked Business Account: ' + JSON.serialize(objTo.Id));
					if (String.isNotBlank(mobileNoFr) && String.isBlank(objTo.Phone)) { objTo.Phone = mobileNoFr; }
					if (Util.checkEmail(email))	{
						if (String.isBlank(objTo.Office_Email__c)) {
							objTo.Office_Email__c = email;
							objTo.Active_Work__c = true;
						}
					}
				}
			}
			/** Always update these */
			if (rt.IsPersonType) {
				// if (String.isBlank(objCur.CompanyName__pc)) 	{ objTo.CompanyName__pc = objFr.contactCompanyName?.trim(); }
				// if (String.isBlank(objCur.License__pc)) 		{ objTo.License__pc = objFr.licenseNo; }
				// if (String.isBlank(objCur.PersonEmail) && Util.checkEmail(email))
				// 												{ objTo.PersonEmail = email; }
				// if (String.isBlank(objCur.PersonMobilePhone))	{ objTo.PersonMobilePhone = mobileNoFr; }
				if (String.isBlank(objTo.CompanyName__pc)) 		{ objTo.CompanyName__pc = objFr.contactCompanyName?.trim(); }
				if (String.isBlank(objTo.License__pc)) 			{ objTo.License__pc = objFr.licenseNo; }
				if (String.isBlank(objTo.PersonEmail) && Util.checkEmail(email))
																{ objTo.PersonEmail = email; }
				if (String.isBlank(objTo.PersonMobilePhone))	{ objTo.PersonMobilePhone = mobileNoFr; }
			}
			// if (String.isBlank(objCur.OfficialName__c))			{ objTo.OfficialName__c = objFr.contactName; }
			// if (String.isBlank(objCur.DisplayName__c))			{ objTo.DisplayName__c = objFr.nickname; }
			// if (String.isBlank(objCur.Doc_Type__c) || objCur.Doc_Type__c?.equalsIgnoreCase('Invalid'))
			// 													{ objTo.Doc_Type__c = id.DocType; }
			// if (String.isBlank(objCur.NRIC_Number__c))			{ objTo.NRIC_Number__c = id.Original; }
			// if (String.isBlank(objCur.DocumentNumberAlphaN__c))	{ objTo.DocumentNumberAlphaN__c = id.DocNumber; }
			// if (objCur.MobyContactNumber__c == null)			{ objTo.MobyContactNumber__c = objFr.id; }
			// objTo.MobyMatchKey__c = objCur.MobyMatchKey__c;
			if (String.isBlank(objTo.OfficialName__c))			{ objTo.OfficialName__c = objFr.contactName; }
			if (String.isBlank(objTo.DisplayName__c))			{ objTo.DisplayName__c = objFr.nickname; }
			if (String.isBlank(objTo.Doc_Type__c) || objTo.Doc_Type__c?.equalsIgnoreCase('Invalid'))
																{ objTo.Doc_Type__c = id.DocType; }
			if (String.isBlank(objTo.NRIC_Number__c))			{ objTo.NRIC_Number__c = id.Original; }
			if (String.isBlank(objTo.DocumentNumberAlphaN__c))	{ objTo.DocumentNumberAlphaN__c = id.DocNumber; }
			objTo.MobyContactNumber__c = objFr.id;
			objTo.MobyInsertDate__c = objFr.insertDate;
			objTo.MobyInsertUser__c = mapEmpl.get(objFr.insertUserId)?.Id;
			objTo.MobyUpdateDate__c = objFr.updateDate;
			objTo.MobyUpdateUser__c = mapEmpl.get(objFr.updateUserId)?.Id;

			/** Existing Account - Hobbies */
			Hobby__c[] objToHobbies = objCur.Hobbies__r;
			if (objToHobbies != null && objToHobbies.size() > 0) {
				// deleteHobbies.addAll(objToHobbies);
				for (Hobby__c hobby :objToHobbies) {
					deleteHobbies.put(hobby.Id, hobby);
				}
			}

			updateAccs.add(objTo);
		}
	}

	public static void setHobby(MobyContactRes res, Account[] accounts) {
		Map<long, Account> mapAccount = new Map<long, Account>();
		for (Account account :accounts) {
			if (account.MobyContactNumber__c == null) { continue; }
			mapAccount.put(account.MobyContactNumber__c.longValue(), account);
		}

		for (MobyContact objFr :res.contacts) {
			Account objTo = mapAccount.get(objFr.id);
			if (objFr.hobbies == null || objTo == null ) { continue; }
			for (MobyHobby hobby :objFr.hobbies) {
				if (!hobby.isActive) { continue; }
				Hobby__c ah = new Hobby__c();
				ah.Name = hobby.hobbyName;
				ah.Account__c = objTo.Id;
				ah.Company__c = mapCompany.get(objFr.companyCode)?.Id;
				ah.Code__c = hobby.hobbyCode;
				ah.Type__c = hobby.hobbyType;
				ah.Hobby__c = hobby.hobbyName;
				ah.Remarks__c = hobby.remarks;
				ah.IsActive__c = hobby.isActive;
				ah.MobyHobbyNumber__c = hobby.id;
				// ah.MobyInsertDate__c = hobby.insertDate;
				// ah.MobyUpdateDate__c = hobby.updateDate;
				insertHobbies.add(ah);
			}
		}
	}

	public static string[] getHobby(MobyHobby[] hobbies) {
		string[] ret = new string[]{};
		if (hobbies == null) { return ret; }
		Set<string> setHobby = new Set<string>();
		for (MobyHobby hobby :hobbies) { 
			if (String.isNotBlank(hobby.hobbyName)) { setHobby.add(hobby.hobbyName); }
		}
		ret.addAll(setHobby);
		ret.sort();

		return ret;
	}


	
	public class MobyContactReq extends SyncMobyApiBase.MobyReq {
    }
	public class MobyContactRes {
		public MobyContact[] contacts;
		public Integer lastKey;
	}

    public virtual class MobyContact {
		public long id;
        public Integer companyId;
        public string companyCode;
        public string companyName;
        public Integer branchId;
        public string branchCode;
        public string branchName;
		public string title;
		public string gender;
		public string contactName;
		public string nickname;
		public Datetime birthday;
		public string unit;
		public string address;
		public string postCode;
		public string city;
		public string state;
		public string email;
		public string mobileNo;
		public string documentType;
		public string icNo;
		public string licenseNo;
		public Integer maritalStatus;
		public string maritalStatusName;
		public string maritalStatusDescription;
		public Integer incomeGroup;
		public string incomeGroupName;
		public string incomeGroupDescription;
		public string interests;
		public string contactCompanyName;
		public string source;
		public string extContactUid;
		public Boolean isActive;
        public DateTime insertDate;
        public Integer insertUserId;
        public DateTime updateDate;
        public Integer updateUserId;
		public MobyHobby[] hobbies;
    }

	public virtual class MobyHobby {
		public Integer id;
		public Integer headerId;
		public Integer hobbyId;
		public string hobbyCode;
		public string hobbyType;
		public string hobbyName;
		public Integer extStateCode;
		public string extUId;
		public Boolean isActive;
		public Datetime insertDate;
		public Datetime updateDate;
		public string remarks;
	}

}