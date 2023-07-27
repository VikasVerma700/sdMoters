global class SQL_Acc_Queue implements Database.AllowsCallouts, Queueable {
    private static final string USERNAME = SQL_API_Base.USERNAME;
    private static final string PASSWORD = SQL_API_Base.PASSWORD;
    private static final string ENDPOINT = SQL_API_Base.ENDPOINT + 'v3/customer/list';
    private static final string JOB_NAME = SQL_API_Base.QUEUE_ACCO;
    private static final string CREATEDFROM = 'Autoline';

    /** Mapping objects */
    private static Map<long, Account>   mapAccByCareNo;     // Key 1: Id
    private static Map<string, Account> mapAccByDocKey;     // Key 2: !isBusiness + '_' + docNum
    private static Map<string, Account> mapAccByDocNo;      // Key 3: docNum
    private static Map<string, Account> mapAccByDmsNo;      // Key 4: !isBusiness + '_' + dmsNo (Autoline Magic No.)
    private static Map<string, Account> mapAccByNpe;        // Key 5: Name + phone#raw + Email
    private static Map<string, Account> mapAccByPe;         // Key 6: phone#raw + Email - AB app users

    /** new lookup list for subscription */
    private static Map<string, Company__c>  mapCompany;     // companyCode -> Company__c.Name

    private static long[] custNos;
    private static CareContactRes[] respAcc;
    
    /** Email Diagnostic */
    private static SQL_API_Base.API_DEBUG api;
    private static string[] errEmail = new List<string>();
    private static Map<string, SQL_API_Base.ErrorTracking> errSobject = new Map<string, SQL_API_Base.ErrorTracking>();

    public string[] company = SQL_API_Base.COMPANY_CODE;
    public DateTime dateFrom;
    public DateTime dateTo;
    public long[] custNo;
    public long lastId;
    public long rowCount = 50;
    public final Integer minRowCount = 10;
    public boolean followOnToVeh = false;
    public SQL_API_Base.RowTracking rt = new SQL_API_Base.RowTracking();

    public SQL_Acc_Queue() { this.dateFrom = SQL_API_Base.getRunTime(JOB_NAME); }

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
            if ((lastId == null || lastId == 0) && jobs.size() > 1) { return; }

            respAcc = callCareApi();
            if (respAcc.size() > 0) {
                upsertAccount(respAcc);
                System.debug('Upsert Total: ' + JSON.serialize(rt));
                if (errSobject.keySet().size() > 0) {
                    string body = JSON.serialize(errSobject);
                    Util.sendEmail(SQL_API_Base.USER_ADMINS, Envir.subject + ': SQL_Acc_Queue Error!', body);
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
                if (this.followOnToVeh) {
                    SQL_Veh_Queue q = new SQL_Veh_Queue();
                    q.company = this.company;
                    if (this.dateFrom == null) { q.dateFrom = null; }
                    q.dateTo = this.dateTo;
                    q.followOnToVO = true;
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
                string emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
                errEmail.add(emailBody);
            }
        }
        catch (Exception e) {
            string header = JOB_NAME;
            string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
            string error = JSON.serialize(this) + '\n\nAPI:\n' + api?.toString();
            string emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
            errEmail.add(emailBody);
        }
        finally {
            if (errEmail != null && errEmail.size() > 0) {
                CommonMethodsLibrary.sendErrorEmail(new User[] { SQL_API_Base.USER_CUR }, String.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
            }
        }
    }

    public CareContactRes[] callCareApi() {
        Http http = new Http();
        HttpRequest hreq = new HttpRequest();
        hreq.setEndpoint(ENDPOINT);
        hreq.setMethod('POST');
        hreq.setHeader('Content-Type', 'application/json');
        CareContactReq req = new CareContactReq();
        req.Company = this.company;
        req.UserName = USERNAME;
        req.Password = PASSWORD;
        req.DateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ'); // Timezone adjusted based on calling user profile
        req.DateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ'); // Timezone adjusted based on calling user profile
        req.CustomerNo = this.custNo;
        req.LastId = this.lastId;
        req.RowCount = this.rowCount;
        hreq.setBody(JSON.serialize(req, false));
        hreq.setTimeout(120000);
        System.debug(Json.serialize(req));
        /** Prep API request for exception email */
        api = new SQL_API_Base.API_DEBUG();
        api.parse(hreq, new string[] { 'Content-Type' });

        CareContactRes[] res = new CareContactRes[]{};
        HttpResponse hres;
        try {
            hres = http.send(hreq);
            api.parse(hres);
            if (hres.getStatusCode() == 200) {
                res = (CareContactRes[]) JSON.deserialize(hres.getBody(), CareContactRes[].class);
                api.parse(res);
            }
            else { throw new ExternalObjectException(api?.Response); }
        }
        catch (Exception e) { throw e; }
        finally { System.debug(api?.toString()); }

        return res;
    }

    /** for DML operation of handling Business/Person account switching */
    private static Account[] insertAccs;
    private static Contact[] insertCons;
    private static Account[] updateAcRt;
    private static Account[] updateAccs;
    private static Subscription__c[] insertSubs;
    private static Subscription__c[] updateSubs;

    public void upsertAccount(CareContactRes[] res) {
        SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
        /** Initialises mapping */
        initMaps(res);

        insertAccs = new Account[]{};
        insertCons = new Contact[]{};
        updateAcRt = new Account[]{};
        updateAccs = new Account[]{};
        insertSubs = new Subscription__c[]{};
        updateSubs = new Subscription__c[]{};

        Map<Id, Account> updateAcc = new Map<Id, Account>();
        // Match with order priortised
        Account account;
        boolean hasCustNo, hasDocNo, hasNpe;
        for (CareContactRes aco :res) {
            account = null;
            hasCustNo = false;
            hasDocNo = false;

            System.debug('seeking matching Account with: ' + JSON.serialize(aco));

            /** Key 1: Care DB AccountDetails.Id == ac.custNo */
            if (account == null && aco.custNo != null) {
                long key1 = aco.custNo;
                if (mapAccByCareNo.containsKey(key1)) {
                    account = mapAccByCareNo.get(key1);
                    hasCustNo = true;
                    System.debug('Match key1: ' + key1 + ' / ' + JSON.serialize(account));
                }
            }

            /** Key 2: !isBusiness + '_' + DocNo == account.IsPersonAccount + '_' + account.DocumentNumberAlphaN__c */
            if (account == null && String.isNotBlank(aco.docNum)) {
                string key2 = String.join(new string[] { String.valueOf(!aco.isBusiness), aco.docNum }, '_').toUpperCase();
                if (mapAccByDocKey.containsKey(key2)) {
                    account = mapAccByDocKey.get(key2);
                    hasDocNo = true;
                    System.debug('Match key2: ' + key2 + ' / ' + JSON.serialize(account));
                }
            }

            /** Key 3: DocNo == account.DocumentNumberAlphaN__c */
            if (account == null && String.isNotBlank(aco.docNum)) {
                string key3 = aco.docNum.toUpperCase();
                if (mapAccByDocNo.containsKey(key3)) {
                    account = mapAccByDocNo.get(key3);
                    hasDocNo = true;
                    System.debug('Match key3: ' + key3 + ' / ' + JSON.serialize(account));
                }
            }

            /** Key 4: Autoline Magic No. == account.DmsNumber__c */
            // Do not match by DMS key ATM
            if (account == null && String.isNotBlank(aco.dmsNo)) {
                for (string dmsNo :aco.dmsNo.split('\\|')) {
                    string key4 = String.join(new string[] { String.valueOf(!aco.isBusiness), dmsNo }, '_').toUpperCase();
                    if (mapAccByDmsNo.containsKey(key4)) {
                        account = mapAccByDmsNo.get(key4);
                        break;
                    }
                }
            }
            
            /** Key 5: name + phone#raw + email == OfficialName + PersonMobilePhone + Office_Email__c/Home_Email__c/Other_Email__c */
            /** Include OfficialName__c as comparison. We don't want to overwrite other accounts when phone + email coincides. */
            if (account == null && String.isNotBlank(aco.phone1raw) && String.isNotBlank(aco.email)) {
                UtilPhone up = new UtilPhone(aco.phone1raw);
                string nameSrc = Util.purifyName(aco.fullName);
                string key5 = String.join(new string[] { nameSrc, up.toE164(), aco.email }, '_').toUpperCase();
                Account acc = mapAccByNpe.get(key5);
                string nameDst = Util.purifyName(acc?.OfficialName__c);
                if (nameSrc.equalsIgnoreCase(nameDst)) { account = acc; }
                System.debug('Match key5 phone1raw: ' + key5 + ' / ' + JSON.serialize(account));
            }
            if (account == null && String.isNotBlank(aco.phone2raw) && String.isNotBlank(aco.email)) {
                UtilPhone up = new UtilPhone(aco.phone2raw);
                string nameSrc = Util.purifyName(aco.fullName);
                string key5 = String.join(new string[] { nameSrc, up.toE164(), aco.email }, '_').toUpperCase();
                Account acc = mapAccByNpe.get(key5);
                string nameDst = Util.purifyName(acc?.OfficialName__c);
                if (nameSrc.equalsIgnoreCase(nameDst)) { account = acc; }
                System.debug('Match key5 phone2raw: ' + key5 + ' / ' + JSON.serialize(account));
            }
            if (account == null && String.isNotBlank(aco.phone3raw) && String.isNotBlank(aco.email)) {
                UtilPhone up = new UtilPhone(aco.phone3raw);
                string nameSrc = Util.purifyName(aco.fullName);
                string key5 = String.join(new string[] { nameSrc, up.toE164(), aco.email }, '_').toUpperCase();
                Account acc = mapAccByNpe.get(key5);
                string nameDst = Util.purifyName(acc?.OfficialName__c);
                if (nameSrc.equalsIgnoreCase(nameDst)) { account = acc; }
                System.debug('Match key5 phone3raw: ' + key5 + ' / ' + JSON.serialize(account));
            }

            /** Key 6: phone#raw + email == PersonMobilePhone + Office_Email__c/Home_Email__c/Other_Email__c */
            // if (account == null && String.isNotBlank(aco.phone1raw) && String.isNotBlank(aco.email)) {
            //  UtilPhone up = new UtilPhone(aco.phone1raw);
            //  string key6 = String.join(new string[] { up.toE164(), aco.email }, '_').toUpperCase();
            //  account = mapAccByPe.get(key6);
            //  System.debug('Match key6 phone1raw: ' + key6 + ' / ' + JSON.serialize(account));
            // }
            // if (account == null && String.isNotBlank(aco.phone2raw) && String.isNotBlank(aco.email)) {
            //  UtilPhone up = new UtilPhone(aco.phone2raw);
            //  string key6 = String.join(new string[] { up.toE164(), aco.email }, '_').toUpperCase();
            //  account = mapAccByPe.get(key6);
            //  System.debug('Match key6 phone2raw: ' + key6 + ' / ' + JSON.serialize(account));
            // }
            // if (account == null && String.isNotBlank(aco.phone3raw) && String.isNotBlank(aco.email)) {
            //  UtilPhone up = new UtilPhone(aco.phone3raw);
            //  string key6 = String.join(new string[] { up.toE164(), aco.email }, '_').toUpperCase();
            //  account = mapAccByPe.get(key6);
            //  System.debug('Match key6 phone3raw: ' + key6 + ' / ' + JSON.serialize(account));
            // }

            /** still no match */
            if (account == null) { 
                System.debug('no match found');
                account = new Account();
            }
            setValues(aco, account);
            if (account.Id == null) { lt.AddOne(); rt.AddOne(); }
            else                    { lt.UpdateOne(); rt.UpdateOne(); }
        }
        Database.SaveResult[] srs;
        Database.UpsertResult[] urs;
        string err;
        if (insertAccs.size() > 0) {
            /** Insert new Accounts */
            AccountHandler.preventDefaultSubs = true;
            srs = Database.insert(insertAccs, false);
            AccountHandler.preventDefaultSubs = false;
            System.debug('insertAccs: ' + JSON.serialize(insertAccs));
            System.debug('insertAccs ret: ' + JSON.serialize(srs));
            err = CommonMethodsLibrary.emailResultFailure(
                        srs, insertAccs, 'insertAccount (insertAccs)'
                        , JOB_NAME, new User[] { SQL_API_Base.USER_CUR }, false);
            if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }

            /** Insert subscriptions */
            Subscription__c[] upsertSubs = prepSubscriptions(res, insertAccs);
            if (upsertSubs.size() > 0) {
                urs = Database.upsert(upsertSubs, Subscription__c.UniqueKey__c, false);
                System.debug('insertAccount upsertSubs: ' + JSON.serialize(upsertSubs));
                System.debug('insertAccount upsertSubs ret: ' + JSON.serialize(urs));
                err = CommonMethodsLibrary.emailResultFailure(
                    urs, upsertSubs, 'insertAccount (upsertSubs)'
                    , JOB_NAME, new User[] { SQL_API_Base.USER_CUR }, false);
                if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
            }
        }
        if (insertCons.size() > 0) {
            /** Inject new Contacts before RecordType updates */
            for (Contact cont :insertCons) { if (cont.AccountId == null) { cont.AccountId = cont.Account.Id; }}
            srs = Database.insert(insertCons, false);
            System.debug('insertCons: ' + JSON.serialize(insertCons));
            System.debug('insertCons ret: ' + JSON.serialize(srs));
        }
        if (updateAcRt.size() > 0) {
            /** Update Account's RecordTypes */
            srs = Database.update(updateAcRt, false);
            System.debug('updateAcRt: ' + JSON.serialize(updateAcRt));
            System.debug('updateAcRt ret: ' + JSON.serialize(srs));
        }
        if (updateAccs.size() > 0) {
            /** Remove Duplicate item in list */
            Map<Id, Account> mapAccs = new Map<Id, Account>();
            for (Account acc :updateAccs) { mapAccs.put(acc.Id, acc); }

            srs = Database.update(mapAccs.values(), false);
            System.debug('mapAccs.values(): ' + JSON.serialize(mapAccs.values()));
            System.debug('mapAccs.values() ret: ' + JSON.serialize(srs));
            err = CommonMethodsLibrary.emailResultFailure(
                    srs, mapAccs.values(), 'updateAccount (mapAccs.values())'
                    , JOB_NAME, new User[] { SQL_API_Base.USER_CUR }, false);
            if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }

            /** Upsert subscriptions */
            Subscription__c[] upsertSubs = prepSubscriptions(res, updateAccs);
            System.debug('upsertSubs: ' + JSON.serialize(upsertSubs));
            if (upsertSubs.size() > 0) {
                urs = Database.upsert(upsertSubs, Subscription__c.UniqueKey__c, false);
                System.debug('updateAccount upsertSubs: ' + JSON.serialize(upsertSubs));
                System.debug('updateAccount upsertSubs ret: ' + JSON.serialize(urs));
                err = CommonMethodsLibrary.emailResultFailure(
                    urs, upsertSubs, 'updateAccount (upsertSubs)'
                    , JOB_NAME, new User[] { SQL_API_Base.USER_CUR }, false);
                if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
            }

        }
        
        /** Record lastId */
        if (custNos.size() > 0) {
            custNos.sort();
            this.lastId = custNos[custNos.size() - 1];
        }
    
        System.debug('Upsert Current: ' + JSON.serialize(lt));
    }

    public Subscription__c[] prepSubscriptions(CareContactRes[] objFr, Account[] objAccs) {
        Subscription__c[] subs = new Subscription__c[]{};

        Map<long, Account> mapAccByCustNo = new Map<long, Account>();
        Map<string, Subscription__c> mapSubByKey = new Map<string, Subscription__c>();
        for (Account acc: objAccs) {
            mapAccByCustNo.put(acc.Customer_Number__c.longValue(), acc);
            for (Subscription__c sub :acc.Subscriptions__r) {
                mapSubByKey.put(string.join(new string[] { sub?.Company__c, sub?.Account__c, sub?.Channel__c?.toUpperCase() }, '_'), sub);
            }
        }
        for (CareContactRes aco :objFr) {
            Account acc = mapAccByCustNo.get(aco.custNo);
            Company__c com = mapCompany.get(aco.companyCode);
            /** Only proceed with Subscription creation when Company & Account found. */
            if (acc?.Id != null && com?.Id != null) {
                List<SubsRepository.Subchannel> channels = SubsRepository.SubChannel.values();
                Map<SubsRepository.SubChannel,boolean> channel2OptOut = new Map<SubsRepository.SubChannel,boolean>{
                    SubsRepository.SubChannel.Email => aco.emailOptOut,
                    SubsRepository.SubChannel.SMS => aco.smsOptOut,
                    SubsRepository.SubChannel.Letter => aco.letterOptOut
                };
                Map<SubsRepository.SubChannel, string> uniqueKeys = new Map<SubsRepository.SubChannel, string>();

                for (SubsRepository.SubChannel channel :channels) {
                    uniqueKeys.put(channel, string.join(new string[] { mapCompany.get(aco.companyCode)?.Id, mapAccByCustNo.get(aco.custNo)?.Id, channel.name().toUpperCase() }, '_'));
                }
                
                for (SubsRepository.SubChannel channel :channels) {
                    string uniqueKey = uniqueKeys.get(channel);
                    Subscription__c sub = mapSubByKey.get(uniqueKey);
                    boolean optOut = channel2OptOut.get(channel);
                    if (sub == null) {
                        /** Create new subscription record */
                        
                        sub = SubsRepository.create(mapAccByCustNo.get(aco.custNo)?.Id,mapCompany.get(aco.companyCode)?.Id,
                            uniqueKey,channel,optOut,false);
                        /*
                        sub = new Subscription__c();
                        sub.UniqueKey__c = uniqueKey; // required for upsert operation
                        sub.Company__c = mapCompany.get(aco.companyCode)?.Id;
                        sub.Account__c = mapAccByCustNo.get(aco.custNo)?.Id;
                        sub.Channel__c = channel;
                        sub.EventOptOut__c = false;
                        sub.NewsletterOptOut__c = false;
                        sub.SalesPromoOfferOptOut__c = false;
                        sub.ApsPromoOfferOptOut__c = false;
                        
                        switch on sub.Channel__c {
                            when 'Email'    { sub.OptOut__c = aco.emailOptOut == null ? sub.OptOut__c : aco.emailOptOut; }
                            when 'Letter'   { sub.OptOut__c = aco.letterOptOut == null ? sub.OptOut__c : aco.letterOptOut; }
                            when 'SMS'      { sub.OptOut__c = aco.smsOptOut == null ? sub.OptOut__c : aco.smsOptOut; }
                            when else {
                                // won't execute here unless new channel(s) being added.
                            }
                        }
                        */
                    }
                    else {
                        /** Only update existing subscription when Response is NOT null */
                        switch on sub.Channel__c {
                            when 'Email'    { sub.OptOut__c = aco.emailOptOut == null ? sub.OptOut__c : aco.emailOptOut; }
                            when 'Letter'   { sub.OptOut__c = aco.letterOptOut == null ? sub.OptOut__c : aco.letterOptOut; }
                            when 'SMS'      { sub.OptOut__c = aco.smsOptOut == null ? sub.OptOut__c : aco.smsOptOut; }
                            when else {
                                // won't execute here unless new channel(s) being added.
                            }
                        }
                    }
                    subs.add(sub);
                }
            }
        }
        return subs;
    }

    private void initMaps(CareContactRes[] res) {       
        /** Gather all lookup list */
        Set<long>       setCustomer     = new Set<long>();      // customer no.
        Set<string>     setDocument     = new Set<string>();    // document no.
        Set<string>     setDms          = new Set<string>();    // dms no.
        // Set<decimal> setMobPre       = new Set<decimal>();   // mobile prefix
        // Set<string>  setMobNo        = new Set<string>();    // mobile no.
        Set<String>     setMobileNo     = new Set<string>();    // phone#raw, # = 1, 2, 3
        Set<String>     setMobileNoWc   = new Set<string>();    // % + phone#raw, # = 1, 2, 3
        Set<string>     setEmail        = new Set<string>();    // email
        /** new lookup list for subscription */
        Set<string>     setCompany      = new Set<string>();    // companyCode
        
        custNos = new List<long>();
        UtilPhone uphone = new UtilPhone();
        string natNo;
        for (CareContactRes acc :res) {
            if (acc.custNo != null)                 { setCustomer.add(acc.custNo); }
            if (String.isNotBlank(acc.docNum))      { setDocument.add(acc.docNum); }
            if (String.isNotBlank(acc.dmsNo))       { setDms.addAll(dmsMatch(acc.dmsNo)); }
            // if (String.isNotBlank(acc.prefix))       { try { setMobPre.add(Decimal.valueOf(acc.prefix)); } finally {} }
            // if (String.isNotBlank(acc.mobile))       { setMobNo.addAll(phoneMatch(acc.mobile)); }
            if (String.isNotBlank(acc.phone1raw))   {
                uphone.input = acc.phone1raw;
                natNo = '%' + uphone.toNoPrefixNumber();
                if (String.isNotBlank(uphone.toE164()))             { setMobileNo.add(uphone.toE164()); }
                if (String.isNotBlank(uphone.toNoPrefixNumber()))   { setMobileNoWc.add(natNo); }
            }
            if (String.isNotBlank(acc.phone2raw))   {
                uphone.input = acc.phone2raw;
                natNo = '%' + uphone.toNoPrefixNumber();
                if (String.isNotBlank(uphone.toE164()))             { setMobileNo.add(uphone.toE164()); }
                if (String.isNotBlank(uphone.toNoPrefixNumber()))   { setMobileNoWc.add(natNo); }
            }
            if (String.isNotBlank(acc.phone3raw))   {
                uphone.input = acc.phone3raw;
                natNo = '%' + uphone.toNoPrefixNumber();
                if (String.isNotBlank(uphone.toE164()))             { setMobileNo.add(uphone.toE164()); }
                if (String.isNotBlank(uphone.toNoPrefixNumber()))   { setMobileNoWc.add(natNo); }
            }
            if (Util.checkEmail(acc.email))         { setEmail.add(acc.email); }
            if (String.isNotBlank(acc.companyCode)) { setCompany.add(acc.companyCode); }
            custNos.add(acc.custNo);
        }

        string queryAcc = Database.getQueryLocator([
            SELECT
                Id, Name, DisplayName__c, OfficialName__c, IsPersonAccount
                , Customer_Number__c
                , Doc_Type__c, NRIC_Number__c, DocumentNumberAlphaN__c, License__pc
                , PersonMobilePhone, PersonEmail, Phone
                , PersonBirthdate, DMS_Number__c
                , Office_Email__c, Home_Email__c, Other_Email__c, Default_Email__c
                , Active_Work__c, Active_Home__c, Active_Other__c
                , Created_From__c, RecordTypeId
                , Mobile_Country_Code_1__pc, Mobile_Preferred__pc
                , (SELECT Id, Name FROM Contacts)
                , (SELECT Id, Company__c, Account__c, Channel__c, OptOut__c, EventOptOut__c, NewsletterOptOut__c, SalesPromoOfferOptOut__c, ApsPromoOfferOptOut__c, UniqueKey__c FROM Subscriptions__r)
            FROM Account
            LIMIT 200
        ]).getQuery().replace('LIMIT 200', ' ');
        queryAcc += 'WHERE (Customer_Number__c IN :setCustomer) ';
        if (setDocument.size() > 0) {
            queryAcc += 'OR (DocumentNumberAlphaN__c IN :setDocument) ';
        }
        if (setDms.size() > 0) {
            queryAcc += 'OR (DMS_Number__c != null AND DMS_Number__c LIKE :setDms) ';
        }
        if (setMobileNo.size() > 0) {
            queryAcc += 'OR (PersonMobilePhone != null AND PersonMobilePhone IN :setMobileNo) ';
        }
        if (setMobileNoWc.size() > 0) {
            queryAcc += 'OR (PersonMobilePhone != null AND PersonMobilePhone LIKE :setMobileNoWc) ';
            queryAcc += 'OR (Mobile_Preferred__pc != null AND Mobile_Preferred__pc LIKE :setMobileNoWc) ';
        }
        if (setEmail.size() > 0) {
            queryAcc += 'OR ((Office_Email__c != null AND Office_Email__c IN :setEmail) ' +
                        'OR (Home_Email__c != null AND Home_Email__c IN :setEmail) ' +
                        'OR (Other_Email__c != null AND Other_Email__c IN :setEmail)) ';
            queryAcc += 'OR (PersonEmail != null AND PersonEmail IN :setEmail) ';
        }
        /** Order By */
        queryAcc += 'ORDER BY CreatedDate DESC ';

        Account[] accs = Database.query(queryAcc);

        mapAccByCareNo = new Map<long, Account>();
        mapAccByDocKey = new Map<string, Account>();
        mapAccByDocNo = new Map<string, Account>();
        mapAccByDmsNo = new Map<string, Account>();
        mapAccByNpe = new Map<string, Account>();
        mapAccByPe = new Map<string, Account>();

        mapCompany = new Map<string, Company__c>();
        Company__c[] comps = [SELECT Id, Name FROM Company__c WHERE Name IN :setCompany];
        for (Company__c comp :comps) { mapCompany.put(comp.Name, comp); }

        /** Key creation: AccountDetails => Account */
        for (Account acc :accs) {
            if (acc.Customer_Number__c != null) {
                /** Key 1: Id == Customer_Number__c */
                long key = acc.Customer_Number__c?.longValue();
                mapAccByCareNo.put(key, acc);
            }
            if (String.isNotBlank(acc.NRIC_Number__c)) {
                /** Key 2.1: !isBusiness + '_' + docNum => IsPersonAccount + '_' + NRIC_Number__c */
                string key2 = String.join(new string[] { String.valueOf(acc.IsPersonAccount), acc.NRIC_Number__c }, '_').toUpperCase();
                mapAccByDocKey.put(key2, acc);

                /** Key 3.1: docNum => NRIC_Number__c */
                string key3 = acc.NRIC_Number__c.toUpperCase();
                mapAccByDocNo.put(key3, acc);
            }
            if (String.isNotBlank(acc.DocumentNumberAlphaN__c)) {
                /** Key 2.2: !isBusiness + '_' + docNum => IsPersonAccount + '_' + DocumentNumberAlphaN__c */
                string key2 = String.join(new string[] { String.valueOf(acc.IsPersonAccount), acc.DocumentNumberAlphaN__c }, '_').toUpperCase();
                mapAccByDocKey.put(key2, acc);

                /** Key 3.2: docNum => DocumentNumberAlphaN__c */
                string key3 = acc.DocumentNumberAlphaN__c.toUpperCase();
                mapAccByDocNo.put(key3, acc);
            }
            if (String.isNotBlank(acc.DMS_Number__c)) {
                /** Key 4: !isBusiness + '_' + dmsNo => IsPersonAccount + '_' + acc.DMS_Number__c.split() */
                string[] dmsNos = acc.DMS_Number__c.split('\\|');
                for (string dmsNo :dmsNos) {
                    string key3 = String.join(new string[] { String.valueOf(acc.IsPersonAccount), dmsNo }, '_').toUpperCase();
                    mapAccByDmsNo.put(key3, acc);
                }
            }
            if (acc.IsPersonAccount) {
                System.debug('acc.Mobile_Preferred__pc: ' + acc.Mobile_Preferred__pc);
                if (String.isNotBlank(acc.Mobile_Preferred__pc)) {
                    /** Key 5.1: name + phone#raw + email == Name + '_' + Mobile_Country_Code_1__pc + Mobile_Preferred__pc + '_' + Office_Email__c/Home_Email__c/Other_Email__c */
                    string phone = UtilPhone.toE164(String.valueOf(acc.Mobile_Country_Code_1__pc) + acc.Mobile_Preferred__pc);
        
                    if (String.isNotBlank(acc.Name) && String.isNotBlank(acc.Office_Email__c) && Util.checkEmail(acc.Office_Email__c)) {
                        string key = String.join(new string[] { acc.Name, phone, acc.Office_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                        /** Key 5.2: remove ' b ', ' bin ', ' bt ', ' binti ', ' a/l ', ' a/p ', ' al ', ' ap ' from name */
                        key = String.join(new string[] { Util.purifyName(acc.Name), phone, acc.Office_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                    }
                    if (String.isNotBlank(acc.Name) && String.isNotBlank(acc.Home_Email__c) && Util.checkEmail(acc.Home_Email__c)) {
                        string key = String.join(new string[] { acc.Name, phone, acc.Home_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                        /** Key 5.2: remove ' b ', ' bin ', ' bt ', ' binti ', ' a/l ', ' a/p ', ' al ', ' ap ' from name */
                        key = String.join(new string[] { Util.purifyName(acc.Name), phone, acc.Home_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                    }
                    if (String.isNotBlank(acc.Name) && String.isNotBlank(acc.Other_Email__c) && Util.checkEmail(acc.Other_Email__c)) {
                        string key = String.join(new string[] { acc.Name, phone, acc.Other_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                        /** Key 5.2: remove ' b ', ' bin ', ' bt ', ' binti ', ' a/l ', ' a/p ', ' al ', ' ap ' from name */
                        key = String.join(new string[] { Util.purifyName(acc.Name), phone, acc.Other_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                    }

                }
                System.debug('acc.PersonMobilePhone: ' + acc.PersonMobilePhone);
                if (String.isNotBlank(acc.PersonMobilePhone)) {
                    /** Key 5.2: name + phone#raw + email == Name + '_' + PersonMobilePhone + '_' + Office_Email__c/Home_Email__c/Other_Email__c */
                    string phone = UtilPhone.toE164(acc.PersonMobilePhone);
    
                    if (String.isNotBlank(acc.Name) && String.isNotBlank(acc.Office_Email__c) && Util.checkEmail(acc.Office_Email__c)) {
                        string key = String.join(new string[] { acc.Name, phone, acc.Office_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                        /** Key 5.2: remove ' b ', ' bin ', ' bt ', ' binti ', ' a/l ', ' a/p ', ' al ', ' ap ' from name */
                        key = String.join(new string[] { Util.purifyName(acc.Name), phone, acc.Office_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                    }
                    if (String.isNotBlank(acc.Name) && String.isNotBlank(acc.Home_Email__c) && Util.checkEmail(acc.Home_Email__c)) {
                        string key = String.join(new string[] { acc.Name, phone, acc.Home_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                        /** Key 5.2: remove ' b ', ' bin ', ' bt ', ' binti ', ' a/l ', ' a/p ', ' al ', ' ap ' from name */
                        key = String.join(new string[] { Util.purifyName(acc.Name), phone, acc.Home_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                    }
                    if (String.isNotBlank(acc.Name) && String.isNotBlank(acc.Other_Email__c) && Util.checkEmail(acc.Other_Email__c)) {
                        string key = String.join(new string[] { acc.Name, phone, acc.Other_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                        /** Key 5.2: remove ' b ', ' bin ', ' bt ', ' binti ', ' a/l ', ' a/p ', ' al ', ' ap ' from name */
                        key = String.join(new string[] { Util.purifyName(acc.Name), phone, acc.Other_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                    }
                }
            }
            else {
                System.debug('acc.Phone: ' + acc.Phone);
                if (String.isNotBlank(acc.Phone)) {
                    /** Key 5.1: name + phone#raw + email == Name + '_' + Phone + '_' + Office_Email__c */
                    string phone = UtilPhone.toE164(acc.Phone);
        
                    if (String.isNotBlank(acc.Name) && String.isNotBlank(acc.Office_Email__c) && Util.checkEmail(acc.Office_Email__c)) {
                        string key = String.join(new string[] { acc.Name, phone, acc.Office_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                        /** Key 5.2: remove ' b ', ' bin ', ' bt ', ' binti ', ' a/l ', ' a/p ', ' al ', ' ap ' from name */
                        key = String.join(new string[] { Util.purifyName(acc.Name), phone, acc.Office_Email__c }, '_').toUpperCase();
                        mapAccByNpe.put(key, acc);
                    }
                }
            }
        }

        System.debug('Init done . . .');
        System.debug('queryAcc: ' + queryAcc
            .replace(':setCustomer', JSON.serialize(setCustomer).replace('[', '(').replace(']', ')').replace('"', '\''))
            .replace(':setDocument', JSON.serialize(setDocument).replace('[', '(').replace(']', ')').replace('"', '\''))
            .replace(':setDms', JSON.serialize(setDms).replace('[', '(').replace(']', ')').replace('"', '\''))
            .replace(':setMobileNoWc', JSON.serialize(setMobileNoWc).replace('[', '(').replace(']', ')').replace('"', '\''))
            .replace(':setMobileNo', JSON.serialize(setMobileNo).replace('[', '(').replace(']', ')').replace('"', '\''))
            .replace(':setEmail', JSON.serialize(setEmail).replace('[', '(').replace(']', ')').replace('"', '\''))
        );
        System.debug('accs (' + accs.size() + '): ' + JSON.serialize(accs));
        System.debug('mapAccByCareNo (' + mapAccByCareNo.size() + '): ' + JSON.serialize(mapAccByCareNo));
        System.debug('mapAccByDocKey (' + mapAccByDocKey.size() + '): ' + JSON.serialize(mapAccByDocKey));
        System.debug('mapAccByDocNo (' + mapAccByDocNo.size() + '): ' + JSON.serialize(mapAccByDocNo));
        System.debug('mapAccByDmsNo (' + mapAccByDmsNo.size() + '): ' + JSON.serialize(mapAccByDmsNo));
        System.debug('mapAccByNpe (' + mapAccByNpe.size() + '): ' + JSON.serialize(mapAccByNpe));
    }

    // private static string[] phoneMatch(string mobileno) {
    //  string[] rv = new List<string>();
    //  if (String.isBlank(mobileno)) { return rv; }
    //  rv.add(mobileno);
    //  rv.add('0' + mobileno);
    //  return rv;
    // }

    private static string[] dmsMatch(string dmsNo) {
        string[] rv = new List<string>();
        if (String.isBlank(dmsNo)) { return rv; }
        for (string s : dmsNo.split('\\|')) {
            rv.add('%|' + s + '|%');
            rv.add(s + '|%');
            rv.add('%|' + s);
        }
        return rv;
    }

    // private static string dmsMapKey(string dmsKey, boolean isPerson) {
    //  return ((isPerson) ? 'P' : 'B') + dmsKey;
    // }

    private string dmsTrim(string dmsNo) {
        if (String.isBlank(dmsNo)) { return dmsNo; }
        string[] dmsNoList = dmsNo.split('\\|');
        dmsNoList.sort();
        string mergeDms = String.join(dmsNoList, '|');
        if (mergeDms.length() <= 255) { return mergeDms; }
        mergeDms = mergeDms.left(255);
        return mergeDms.left(mergeDms.lastIndexOf('|'));
    }
    
    public void setValues(CareContactRes objFr, Account objCur) {
        Util.Identification id = Util.getIdent(objFr.docNum);
        string rtDevName = objFr.isBusiness ? 'Business_Account' : 'PersonAccount';
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(rtDevName).getRecordTypeId();
        RecordType rt = Envir.recordTypeById.get(recordTypeId);
        /** Mobile phone management */
        UtilPhone up = new UtilPhone();
        if (String.isNotBlank(objFr.phone1raw))         { up.input = objFr.phone1raw; }
        else if (String.isNotBlank(objFr.phone2raw))    { up.input = objFr.phone2raw; }
        else if (String.isNotBlank(objFr.phone3raw))    { up.input = objFr.phone3raw; }
        string mobileNoFr = up.toE164();
        Integer mobilePrefixFr = up.getCountryCode();
        string nationalNoFr = up.toNoPrefixNumber();
        string email = objFr.email?.trim();
        if (objCur.Id == null) {
            /** New Account */
            System.debug('Name: ' + objFr.fullName + ' / cust no: ' + objFr.custNo);
            Account objTo = new Account();
            objTo.RecordTypeId = recordTypeId;
            objTo.Created_From__c = CREATEDFROM;
            objTo.Doc_Type__c = id.DocType;
            objTo.NRIC_Number__c = id.Original;
            objTo.DocumentNumberAlphaN__c = id.DocNumber;
            if (id.DocType == 'Malaysian NRIC') { objTo.Verified_with_NRIC__c = true; }
            objTo.Customer_Number__c = objFr.custNo;
            objTo.DMS_Number__c = dmsTrim(objFr.dmsNo);
            /** Capture erroneous email */
            if (String.isNotBlank(email) && !Util.checkEmail(email)) {
                /** Invalid email */
                string key = String.valueOf(objFr.custNo);
                if (errSobject.containsKey(key)) {
                    SQL_API_Base.ErrorTracking et = errSobject.get(key);
                    et.message += ';Invalid email: ' + email;
                }
                else {
                    errSobject.put(key, new SQL_API_Base.ErrorTracking(objFr, objTo, 'Invalid email: ' + email));
                }
            }
            /** Capture erroneous birthday */
            if (objFr.dateOfBirth != null && Util.validDate(objFr.dateOfBirth.date()) == null) {
                /** Invalid date range */
                string key = String.valueOf(objFr.custNo);
                string message = 'Invalid birthday: ' + objFr.dateOfBirth;
                if (errSobject.containsKey(key)) {
                    SQL_API_Base.ErrorTracking et = errSobject.get(key);
                    et.message += ';' + message;
                }
                else {
                    errSobject.put(key, new SQL_API_Base.ErrorTracking(objFr, objTo, message));
                }
            }
            /** Sync flags */
            objTo.SFDC_Transfer_Datetime__c = System.now();
            objTo.SFDC_Transfer_Flag__c = true;
            objTo.SFDC_Transfer_Remarks__c = 'from Care';

            if (rt.IsPersonType) {
                /** New Person Account */
                System.debug('New Person Account: ' + JSON.serialize(objFr));
                objTo.Salutation = objFr.salutation;
                objTo.LastName = objFr.fullName;
                objTo.Account_Name__c = objFr.fullName;
                objTo.OfficialName__c = objFr.fullName; // Always accept AL fullName as Official Name
                objTo.DisplayName__c = objFr.preferredName;
                objTo.Prefer_Name__pc = objFr.preferredName;
                if (String.isNotBlank(mobileNoFr))  {
                    objTo.PersonMobilePhone = mobileNoFr;
                    objTo.Mobile_Country_Code_1__pc = mobilePrefixFr;
                    objTo.Mobile_Preferred__pc = nationalNoFr;
                }
                if (Util.checkEmail(email)) {
                    objTo.PersonEmail = email;
                    objTo.Home_Email__c = email;
                    objTo.Active_Home__c = true;
                }
                if (objTo.Doc_Type__c == 'Malaysian NRIC' && (objFr.dateOfBirth == null || Date.valueOf(objFr.dateOfBirth) == Date.newInstance(1900, 1, 1))) {
                    /** Calculate Birthdate from IC if API date is not set (Unset: 1900-01-01) */
                    objTo.PersonBirthdate = u.getBirthdate(objTo.NRIC_Number__c);
                }
                else {
                    objTo.PersonBirthdate = Util.validDate(objFr.dateOfBirth?.date());
                }
                objTo.PersonMailingStreet = (String.isBlank(objFr.address1) ? '' : objFr.address1) + '\n' + (String.isBlank(objFr.address2) ? '' : objFr.address2);
                objTo.PersonMailingCity = objFr.city;
                objTo.PersonMailingPostalCode = objFr.postalCode;
                objTo.PersonMailingState = objFr.state;
            }
            else {
                /** New Business Account */
                System.debug('New Business Account: ' + JSON.serialize(objFr));
                objTo.Name = objFr.fullName;
                objTo.OfficialName__c = objFr.fullName; // Always accept AL fullName as Official Name
                if (String.isNotBlank(mobileNoFr))  { objTo.Phone = mobileNoFr; }
                if (Util.checkEmail(email)) {
                    objTo.Office_Email__c = email;
                    objTo.Active_Work__c = true;
                }
                objTo.ShippingStreet = (String.isBlank(objFr.address1) ? '' : objFr.address1) + '\n' + (String.isBlank(objFr.address2) ? '' : objFr.address2);
                objTo.ShippingCity = objFr.city;
                objTo.ShippingPostalCode = objFr.postalCode;
                objTo.ShippingState = objFr.state;
            }

            insertAccs.add(objTo);
        }
        else {
            /** Existing Account */
            Account objTo = new Account();
            objTo = objCur;
            /** Update RecordType */
            if (objCur.RecordTypeId != recordTypeId) {
                System.debug('Change RecordType:');
                System.debug('IsPerson: ' + objCur?.RecordTypeId + ' (' + Envir.recordTypeById.get(objCur.RecordTypeId)?.IsPersonType + ') -> ' + recordTypeId + ' (' + Envir.recordTypeById.get(recordTypeId)?.IsPersonType + ')');
                /** Insert Contact if RecordType Business -> Person */
                if (rt.IsPersonType) {
                    if (objCur.Contacts == null || objCur.Contacts.size() == 0) {
                        insertCons.add(new Contact(
                            Salutation = objFr.salutation
                            , LastName = objFr.fullName
                            , AccountId = objCur.Id
                            , CreatedFrom__c = CREATEDFROM
                        ));
                    }
                }
                /** Account.RecordTypeId changed */
                updateAcRt.add(new Account(Id = objCur.Id, RecordTypeId = recordTypeId));
                rt = Envir.recordTypeById.get(recordTypeId);
            }
            else {
                /** Make sure RecordTypeId is excluded in Update DML */
                objTo.RecordTypeId = null;
            }
            /** Always update these */
            objTo.Customer_Number__c = objFr.custNo;
            objTo.DMS_Number__c = dmsTrim(objFr.dmsNo);

            /** Capture erroneous email */
            if (String.isNotBlank(email) && !Util.checkEmail(email)) {
                /** Invalid email */
                string key = String.valueOf(objFr.custNo);
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
            if (objFr.dateOfBirth != null && Util.validDate(objFr.dateOfBirth.date()) == null) {
                /** Invalid date range */
                string key = String.valueOf(objFr.custNo);
                string message = 'Invalid birthday: ' + objFr.dateOfBirth;
                if (errSobject.containsKey(key)) {
                    SQL_API_Base.ErrorTracking et = errSobject.get(key);
                    et.message += ';' + message;
                }
                else {
                    errSobject.put(key, new SQL_API_Base.ErrorTracking(objFr, objTo, message));
                }
            }
            if (id.DocType?.equalsIgnoreCase('Invalid')) {
                if (String.isBlank(objTo.Doc_Type__c))      { objTo.Doc_Type__c = id.DocType; }
                if (String.isBlank(objTo.NRIC_Number__c))   { objTo.NRIC_Number__c = id.Original; }
                if (String.isBlank(objTo.DocumentNumberAlphaN__c))
                                                            { objTo.DocumentNumberAlphaN__c = id.DocNumber; }
            }
            else {
                objTo.Doc_Type__c = id.DocType;
                objTo.NRIC_Number__c = id.Original;
                objTo.DocumentNumberAlphaN__c = id.DocNumber;
            }
            System.debug('current rt.IsPerson: ' + rt.IsPersonType);
            if (rt.IsPersonType) {
                /** Existing Person Account */
                System.debug('Existing Person Account: ' + JSON.serialize(objFr));
                objTo.Salutation = objFr.salutation;
                objTo.LastName = objFr.fullName;
                objTo.Account_Name__c = objFr.fullName;
                objTo.OfficialName__c = objFr.fullName; // Always accept AL fullName as Official Name
                objTo.DisplayName__c = objFr.preferredName;
                objTo.Prefer_Name__pc = objFr.preferredName;
                if (String.isNotBlank(mobileNoFr))  {
                    objTo.PersonMobilePhone = mobileNoFr;
                    objTo.Mobile_Country_Code_1__pc = mobilePrefixFr;
                    objTo.Mobile_Preferred__pc = nationalNoFr;
                }
                if (Util.checkEmail(email)) {
                    objTo.PersonEmail = email;
                    CommonMethodsLibrary.setEmail(objTo, email);
                }
                objTo.PersonBirthdate = Util.validDate(objFr.dateOfBirth?.date());
                objTo.PersonMailingStreet = (String.isBlank(objFr.address1) ? '' : objFr.address1) + '\n' + (String.isBlank(objFr.address2) ? '' : objFr.address2);
                objTo.PersonMailingCity = objFr.city;
                objTo.PersonMailingPostalCode = objFr.postalCode;
                objTo.PersonMailingState = objFr.state;
            }
            else {
                /** Existing Business Account */
                System.debug('Existing Business Account: ' + JSON.serialize(objFr));
                objTo.Name = objFr.fullName;
                if (String.isNotBlank(mobileNoFr))  { objTo.Phone = mobileNoFr; }
                if (Util.checkEmail(email)) {
                    objTo.Office_Email__c = email;
                    objTo.Active_Work__c = true;
                    if (objTo.Home_Email__c == email)   { objTo.Home_Email__c = ''; }
                    if (objTo.Other_Email__c == email)  { objTo.Other_Email__c = ''; }
                    objTo.Active_Home__c = objTo.Active_Other__c = false;
                }
                objTo.ShippingStreet = (String.isBlank(objFr.address1) ? '' : objFr.address1) + '\n' + (String.isBlank(objFr.address2) ? '' : objFr.address2);
                objTo.ShippingCity = objFr.city;
                objTo.ShippingPostalCode = objFr.postalCode;
                objTo.ShippingState = objFr.state;
                if (objCur.Contacts == null || objCur.Contacts.size() == 0) {
                    insertCons.add(new Contact(
                        Salutation = objFr.salutation
                        , LastName = objFr.fullName
                        , AccountId = objTo.Id
                        , CreatedFrom__c = CREATEDFROM
                    ));
                }
            }

            updateAccs.add(objTo);
        }
    }

    /** Button: Pull from Care API (Account) */
    Webservice static string refreshAcc(Id accId) {
        try {
            Account acc = [SELECT Id, Customer_Number__c FROM Account WHERE Id = :accId];
            if (acc?.Customer_Number__c == null) { return 'Error: Unable to refresh Account (w/o Customer Number).'; }
            SQL_Acc_Queue q = new SQL_Acc_Queue();
            q.dateFrom = q.dateTo = null;
            q.custNo = new long[] { acc.Customer_Number__c?.longValue() };
            SQL_Acc_Queue.CareContactRes[] res = q.callCareApi();
            if (res == null || res.size() <= 0) { return 'Error: Unable to find account for refresh.'; }
            q.upsertAccount(res);
            return 'Refreshed successfully!';
        }
        catch (QueryException e) { return 'Error: No record found with id: \'' + accId + '\''; }
        catch (Exception e) { return 'Error: ' + e.getMessage() + (SQL_API_Base.ISSANDBOX ? '\n\n' + e.getStackTraceString() : ''); }
    }
    
    public class CareContactReq extends SQL_API_Base.CareReq {
        public long[] CustomerNo;
        public string[] DocumentNo;
        public long LastId;
    }

    public virtual class CareContactRes {
        public long[] contactIds;
        public string companyCode;
        public string source;
        public long custNo;
        public string dmsNo;
        public boolean isBusiness;
        public string salutation;
        public string fullName;
        public string preferredName;
        public Datetime dateOfBirth;
        public string docNum;
        public string docNumRaw;
        public string gender;
        public string prefix;
        public string mobile;
        public string phone1raw;
        public string prefix2;
        public string mobile2;
        public string phone2raw;
        public string prefix3;
        public string mobile3;
        public string phone3raw;
        public string email;
        public string address1;
        public string address2;
        public string address3;
        public string postalCode;
        public string city;
        public string state;
        public boolean emailOptOut;
        public boolean letterOptOut;
        public boolean smsOptOut;
    }
}