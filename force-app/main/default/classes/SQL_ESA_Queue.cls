public with sharing class SQL_ESA_Queue implements Database.AllowsCallouts,Queueable{
    private static final string USERNAME = SQL_API_Base.USERNAME;
    private static final string PASSWORD = SQL_API_Base.PASSWORD;
    private static final string ENDPOINT = SQL_API_Base.ENDPOINT + 'v3/customer/list';
    //private static final string JOB_NAME = 'SQLESAQueue';
    @Testvisible
    private static final string SOURCE_AUTOLINE = 'Autoline';
    @Testvisible
    private static final string SOURCE_CARE = 'CareDb';
    @Testvisible
    private static final string SOURCE_GDMS = 'GDMS';
    @Testvisible
    private static final string SOURCE_UNITS = 'Units';

    public CareContactRes[] careResponseList;
    //map to compare external system account
    private Map<String, ExternalSystemAccount__c> uniqueKey2ExSysAccount;
    private Map<String,CareContactRes> uniqueKey2CareResponse;

    //gdms
    public List<CustomerVehicleService.QueryCustomerAccount_CustomerRow> CustomerAccountList;
    private Map<String,CustomerVehicleService.QueryCustomerAccount_CustomerRow> uniqueKey2CustomerAccount;

    /** Email Diagnostic */
    private static SQL_API_Base.API_DEBUG api;
    private static string[] errEmail = new List<string>();
    private static Map<string, SQL_API_Base.ErrorTracking> errSobject = new Map<string, SQL_API_Base.ErrorTracking>();
    
    public string[] company = SQL_API_Base.COMPANY_CODE;
    public DateTime dateFrom;
    public DateTime dateTo;
    public long[] custNoList;
    public long lastId;
    public String lastRowId;
    public long rowCount = 50;
    public final Integer minRowCount = 10;
    public boolean followOnToVeh = false;
    public SQL_API_Base.RowTracking esaRt = new SQL_API_Base.RowTracking();
    public ExternalSystem extSystem;
    public String jobName{
        get;
        private set;
    }


    public SQL_ESA_Queue(ExternalSystem extSystem){
        this.extSystem = extSystem;
        this.jobName = Util.getClassname(this) + '_' + this.extSystem.systemType.name();
        this.dateFrom = SQL_API_Base.getRunTime(this.jobName);
    }

    public void addCareDb(CareContactRes careResponse){
        this.careResponseList.add(careResponse);
        CareContactRes careDbResponse= careResponse.copy();
        careDbResponse.source = SOURCE_CARE;
        this.careResponseList.add(careDbResponse);
    }

    public void callCareApi() {
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
        req.CustomerNo = this.custNoList;
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
                System.debug(res.size());
            }
            else { throw new ExternalObjectException(api?.Response); }
        }
        catch (Exception e) { throw e; }
        finally { System.debug(api?.toString()); }

        this.careResponseList = new List<CareContactRes>();
        for(CareContactRes careResponse: res){
            if(careResponse.source == SOURCE_AUTOLINE){
                String dmsNo = careResponse.dmsNo;
                if(String.isNotBlank(dmsNo)){
                    for(String dmsSplit : dmsNo.split('\\|')){
                        CareContactRes autoLineResponse = careResponse.copy();
                        autoLineResponse.dmsNo = dmsSplit;
                        this.addCareDb(autoLineResponse);
                    }
                }
            }
            else{
                this.addCareDb(careResponse);
            }
        }
    }

    public void fetchGdmsCustomerAccounts(){
        String endpoint = 'callout:';
        endpoint += Envir.isSandbox ? 'GdmsTrain' : 'GdmsProduction';
        CustomerVehicleService vehService = new CustomerVehicleService(endpoint);
        String searchField = 'mod_datetime';
        String searchValue = this.dateFrom?.format('dd/MM/yyyy HH:mm:ss.SSS');
        if(String.isNotBlank(searchValue)){
            searchValue += '-'+this.dateTo?.format('dd/MM/yyyy HH:mm:ss.SSS');
        }
        Integer batchSize = (Integer) this.rowCount;
        CustomerVehicleService.QueryCustomerAccountResponse custAccountResp = vehService.QueryCustomerAccount(CompanyRepository.C099, searchField, searchValue, this.lastRowId, batchSize);
        this.lastRowId = custAccountResp.LastRowID;
        this.CustomerAccountList = custAccountResp.Customer.CustomerRow;
    }

    public void initMaps(){
        if(this.extSystem.systemType == ExternalSystem.Type.CareDb){
            this.uniqueKey2CareResponse = new Map<String,CareContactRes>();
            this.uniqueKey2ExSysAccount = new Map<String,ExternalSystemAccount__c>();
    
            for(CareContactRes careResponse: this.careResponseList){
                String uniqueKey = careResponse.companyCode;
                uniqueKey += '_'+careResponse.getSource();
    
                if(careResponse.source == SOURCE_AUTOLINE){
                    uniqueKey += careResponse.isBusiness? '_C' : '_P';
                    uniqueKey += '_'+careResponse.dmsNo;
                }
                else{
                    uniqueKey += '_'+String.valueOf(careResponse.custNo);
                }
                uniqueKey2CareResponse.put(uniqueKey,careResponse);
            }
    
            List<ExternalSystemAccount__c> externalSysAccountList = [
                SELECT Account__c, Address1__c, Address3__c, Address2__c,
                    Birthdate__c, City__c, CompanyCode__c, CompanyMagicNumber__c, CustomerNumber__c,
                    DocumentNumber__c, EmailHome__c, Gender__c, FullName__c, Id,
                    Postcode__c, State__c, UniqueKey__c, Source__c
                FROM ExternalSystemAccount__c
                WHERE UniqueKey__c IN: this.uniqueKey2CareResponse.keySet()
                    AND SourceBy__c = :SOURCE_CARE
            ];
    
            for(ExternalSystemAccount__c exSysAccount: externalSysAccountList){
                this.uniqueKey2ExSysAccount.put(exSysAccount.UniqueKey__c,exSysAccount);
            }
        }
        else if(this.extSystem.systemType == ExternalSystem.Type.GDMS){
            this.uniqueKey2CustomerAccount = new Map<String,CustomerVehicleService.QueryCustomerAccount_CustomerRow>();
            this.uniqueKey2ExSysAccount = new Map<String,ExternalSystemAccount__c>();
            for(CustomerVehicleService.QueryCustomerAccount_CustomerRow custAccount: this.CustomerAccountList){
                String uniqueKey = CompanyRepository.C099 + '_'+ ExternalSystem.Type.GDMS.name();
                uniqueKey += '_'+String.valueOf(custAccount.CustomerNo);
                this.uniqueKey2CustomerAccount.put(uniqueKey,custAccount);
            }

            List<ExternalSystemAccount__c> externalSysAccountList = [
                SELECT Account__c, Address1__c, Address3__c, Address2__c,
                    Birthdate__c, City__c, CompanyCode__c, CompanyMagicNumber__c, CustomerNumber__c,
                    DocumentNumber__c, EmailHome__c, Gender__c, FullName__c, Id,
                    Postcode__c, State__c, UniqueKey__c, Source__c
                FROM ExternalSystemAccount__c
                WHERE UniqueKey__c IN: this.uniqueKey2CustomerAccount.keySet()
                    AND SourceBy__c = :ExternalSystem.Type.GDMS.name()
            ];
    
            for(ExternalSystemAccount__c exSysAccount: externalSysAccountList){
                this.uniqueKey2ExSysAccount.put(exSysAccount.UniqueKey__c,exSysAccount);
            }
        }
    }

    public void upsertEsa(){
        List<ExternalSystemAccount__c> exSysAccountList = new List<ExternalSystemAccount__c>();
        if(this.extSystem.systemType == ExternalSystem.Type.CareDb){
            for(String uniqueKey :uniqueKey2CareResponse.keySet()){

                CareContactRes careResponse= uniqueKey2CareResponse.get(uniqueKey);
    
                ExternalSystemAccount__c exSysAccount = this.uniqueKey2ExSysAccount.get(uniqueKey);
                if(exSysAccount == null){
                    exSysAccount = new ExternalSystemAccount__c(UniqueKey__c = uniqueKey);
                    exSysAccount.SourceBy__c = SOURCE_CARE;
                    exSysAccount.Source__c = careResponse.getSource();
                }
                
                exSysAccount.Address1__c = careResponse.address1;
                exSysAccount.Address2__c = careResponse.address2;
                exSysAccount.Address3__c = careResponse.address3;
                exSysAccount.City__c = careResponse.city;
                exSysAccount.state__c = careResponse.state;
                exSysAccount.Postcode__c = careResponse.postalCode;
    
                exSysAccount.Birthdate__c = String.valueOf(careResponse.dateOfBirth);
    
                exSysAccount.CompanyCode__c = careResponse.companyCode;
                exSysAccount.CustomerNumber__c = String.valueOf(careResponse.custNo);
                exSysAccount.DocumentNumber__c = careResponse.docNum;
                if(careResponse.source == SOURCE_AUTOLINE){
                    if(careResponse.isBusiness == true){
                        exSysAccount.CompanyMagicNumber__c = careResponse.dmsNo;
                        exSysAccount.CustomerType__c = 'C';
                        //exSysAccount.CustomerNumber__c = null;
                    }
                    else{
                        //exSysAccount.CustomerNumber__c = careResponse.dmsNo;
                        exSysAccount.CompanyMagicNumber__c = null;
                        exSysAccount.CustomerType__c = 'P';
                    }
                    exSysAccount.CustomerNumber__c = null;
                }
                
    
                exSysAccount.EmailHome__c = careResponse.email?.trim();
                
                exSysAccount.Gender__c = careResponse.gender;
                exSysAccount.PreferredName__c = careResponse.preferredName;
                exSysAccount.Salutation__c = careResponse.salutation;
                exSysAccount.FullName__c = careResponse.fullName;
    
                exSysAccount.PhoneMobile__c = careResponse.phone1raw;
                exSysAccount.PhoneHome__c = careResponse.phone2raw;
                exSysAccount.PhoneOffice__c = careResponse.phone3raw;
    
                exSysAccount.SourceBy__c = SOURCE_CARE;
    
                exSysAccountList.add(exSysAccount);
            }
    
            ESATriggerHandler.careApiInvocation = true;
            for(ExternalSystemAccount__c exSysAccount:exSysAccountList){
                System.debug(exSysAccount);
            }
            Database.UpsertResult[] exSysAccountUpsertResultList = Database.upsert(exSysAccountList,false);
        }

        else if(this.extSystem.systemType == ExternalSystem.Type.GDMS){
            for(String uniqueKey: this.uniqueKey2CustomerAccount.keySet()){
                CustomerVehicleService.QueryCustomerAccount_CustomerRow custAccount =
                    this.uniqueKey2CustomerAccount.get(uniqueKey);
                ExternalSystemAccount__c exSysAccount = this.uniqueKey2ExSysAccount.get(uniqueKey);
                if(exSysAccount == null){
                    exSysAccount = new ExternalSystemAccount__c(UniqueKey__c = uniqueKey);
                    exSysAccount.Source__c = ExternalSystem.Type.GDMS.name();
                    exSysAccount.SourceBy__c = ExternalSystem.Type.GDMS.name();
                }
                exSysAccount.Address1__c = custAccount.Address;
                exSysAccount.Address2__c = custAccount.Address2;
                exSysAccount.City__c = custAccount.City;
                exSysAccount.Postcode__c = custAccount.PostCode;
                exSysAccount.Birthdate__c = String.valueOf(custAccount.DOB);
                exSysAccount.CompanyCode__c = custAccount.CompanyCode;
                exSysAccount.CustomerNumber__c = String.valueOf(custAccount.CustomerNo);
                exSysAccount.DocumentNumber__c = custAccount.DocNum;
                exSysAccount.CustomerType__c = custAccount.CustomerType;
                exSysAccount.EmailHome__c = custAccount.OtherEmail;
                exSysAccount.PreferredName__c = custAccount.PrefferedName;
                exSysAccount.Salutation__c = custAccount.Salutation;
                exSysAccount.FullName__c = custAccount.FirstName + ' ' + custAccount.LastName;
                exSysAccount.PhoneMobile__c = custAccount.MobilePhone;
                exSysAccount.PhoneHome__c = custAccount.HomePhone;
                exSysAccount.PhoneOffice__c = custAccount.OfficePhone;
                exSysAccountList.add(exSysAccount);
            }
            for(ExternalSystemAccount__c exSysAccount: exSysAccountList){
                System.debug(exSysAccount);
            }
            Database.UpsertResult[] exSysAccountUpsertResultList = Database.upsert(exSysAccountList,false);
        }

    }

    public void execute(QueueableContext context){
        if(this.extSystem.systemType == ExternalSystem.Type.CareDb){
            try{
                this.callCareApi();
                this.initMaps();
                this.upsertEsa();
                if(this.careResponseList.size() ==0){
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
                    string header = this.jobName;
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
                    ApplicationLogUtility.insertCalloutErrorLog('SQL_ESA_Queue', e.getMessage(), e.getStackTraceString());
                }
            }
            catch (Exception e) {
                string header = this.jobName;
                string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
                string error = JSON.serialize(this) + '\n\nAPI:\n' + api?.toString();
                string emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
                errEmail.add(emailBody);
                ApplicationLogUtility.insertApexErrorLog('SQL_ESA_Queue', e.getMessage(), e.getStackTraceString());
            }
            finally {
                if (errEmail != null && errEmail.size() > 0) {
                    CommonMethodsLibrary.sendErrorEmail(new User[] { SQL_API_Base.USER_CUR }, String.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
                }
            }
        }
        else if(this.extSystem.systemType == ExternalSystem.Type.GDMS){
            try{
                this.fetchGdmsCustomerAccounts();
                this.initMaps();
                this.upsertEsa();
                //requeue the same class
                if(this.CustomerAccountList.size()>0){
                    if (!Test.isRunningTest()) {
                        System.enqueueJob(this);
                    }
                }
                else{
                //enqueue vehicle resource
                VehicleResource vehResource = new VehicleResource(this.extSystem);
                System.enqueueJob(vehResource);
                }
            }
            catch(CalloutException e){
                ApplicationLogUtility.getCalloutErrorLog(Util.getClassname(this), e.getMessage(), e.getStackTraceString(),null,null,true,ApplicationLogUtility.PRIORITY_HIGH);
            }
            catch(Exception e){
                ApplicationLogUtility.insertApexErrorLog(Util.getClassname(this), e.getMessage(), e.getStackTraceString());
            }


        }

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

        public CareContactRes copy(){
            return (CareContactRes)JSON.deserialize(JSON.serialize(this),CareContactRes.class);
        }

        public String getSource(){
            if(this.source == SOURCE_GDMS){
                for(String gdmsSource:SQL_API_Base.gdmsSource2CompanyCodeList.keySet()){
                    List<String> companyCodeList = SQL_API_Base.gdmsSource2CompanyCodeList.get(gdmsSource);
                    if(companyCodeList.contains(this.companyCode)){
                        return gdmsSource;
                    }
                }
                return null;
            }

            else{
                return this.source;
            }
        }
    }
}