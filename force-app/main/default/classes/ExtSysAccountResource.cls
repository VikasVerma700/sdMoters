public with sharing class ExtSysAccountResource extends Resource implements Database.AllowsCallouts,Queueable{
    public List<CareService.ContactResponse> careResponseList;
    //map to compare external system account
    private Map<String, ExternalSystemAccount__c> uniqueKey2ExSysAccount;
    private Map<String,CareService.ContactResponse> uniqueKey2CareResponse;
    public Long lastId;

    //gdms
    public List<CustomerVehicleService.QueryCustomerAccount_CustomerRow> CustomerAccountList;
    private Map<String,CustomerVehicleService.QueryCustomerAccount_CustomerRow> uniqueKey2CustomerAccount;

    public ExtSysAccountResource(ExternalSystem extSystem){
        this.extSystem = extSystem;
        this.dateFrom = SQL_API_Base.getRunTime(this.jobName);
        this.dateTo = Datetime.now();
        this.followOn = false;
        this.CustomerAccountList = new List<CustomerVehicleService.QueryCustomerAccount_CustomerRow>();
    }

    public ExtSysAccountResource(){
        this.CustomerAccountList = new List<CustomerVehicleService.QueryCustomerAccount_CustomerRow>();
        this.careResponseList = new List<CareService.ContactResponse>();
    }

    public static List<Database.UpsertResult> prepareExtSysAccount(List<CustomerVehicleService.QueryCustomerAccount_CustomerRow> custAccountList){
        ExtSysAccountResource esaResource = new ExtSysAccountResource();
        if(custAccountList.size()>0){
            String companyCode = custAccountList[0].CompanyCode;
            ExternalSystem extSystem = new ExternalSystem(companyCode);
            esaResource.setExternalSystem(extSystem);
            esaResource.CustomerAccountList = custAccountList;
            esaResource.initMaps();
            return esaResource.upsertEsa();
        }
        return null;
    }

    public void addCareDb(CareService.ContactResponse careResponse){
        this.careResponseList.add(careResponse);
        CareService.ContactResponse careDbResponse= careResponse.copy();
        careDbResponse.source = ExternalSystem.Type.CareDb.name();
        this.careResponseList.add(careDbResponse);
    }

    public void callCareApi() {
        Http http = new Http();
        HttpRequest hreq = new HttpRequest();
        hreq.setEndpoint(CareService.ENDPOINT);
        hreq.setMethod('POST');
        hreq.setHeader('Content-Type', 'application/json');
        CareService.ContactRequest req = new CareService.ContactRequest();
        req.Company =  new List<String>{this.extSystem.companyName};
        req.UserName = CareService.USERNAME;
        req.Password = CareService.PASSWORD;
        req.DateFrom = this.getStartDate();
        req.DateTo = this.getEndDate();
        req.CustomerNo = null;//this.custNoList;
        req.LastId = this.lastId;
        req.RowCount = this.batchSize;
        hreq.setBody(JSON.serialize(req, false));
        hreq.setTimeout(120000);

        CareService.ContactResponse[] res = new CareService.ContactResponse[]{};
        HttpResponse hres;
        if(!Test.isRunningTest()){
            hres = http.send(hreq);
            if (hres.getStatusCode() == 200) {
                res = (CareService.ContactResponse[]) JSON.deserialize(hres.getBody(), CareService.ContactResponse[].class);
            }
            else {
                ApplicationLogUtility.insertCalloutSuccessLog(this.className, JSON.serialize(hreq), JSON.serialize(hres),null, false);
            }
        }
        else{
            for(CareService.ContactResponse careResponse: this.careResponseList){
                res.add(careResponse);
            }
        }
        for(CareService.ContactResponse careResponse: res){
            System.debug(careResponse.source);
            System.debug(careResponse.dmsNo.split('\\|'));
            if(careResponse.source == ExternalSystem.Type.Autoline.name()){
                String dmsNo = careResponse.dmsNo;
                if(String.isNotBlank(dmsNo)){
                    for(String dmsSplit : dmsNo.split('\\|')){
                        CareService.ContactResponse autoLineResponse = careResponse.copy();
                        autoLineResponse.dmsNo = dmsSplit;
                        this.addCareDb(autoLineResponse);
                    }
                }
            }
            else{
                this.addCareDb(careResponse);
            }
        }
        for(CareService.ContactResponse careResponse: this.careResponseList){
            System.debug(this.careResponseList);
        }
    }

    public void initMaps(){
        Pattern nonAlphanumeric = Pattern.compile('[^a-zA-Z0-9]');

        if(this.extSystem.companyName == CompanyRepository.C028){
            this.uniqueKey2CareResponse = new Map<String,CareService.ContactResponse>();
            this.uniqueKey2ExSysAccount = new Map<String,ExternalSystemAccount__c>();
    
            for(CareService.ContactResponse careResponse: this.careResponseList){
                String uniqueKey = careResponse.companyCode;
                uniqueKey += '_'+CompanyRepository.NAME_TO_EXTERNAL_SYSTEM.get(careResponse.companyCode).name();
    
                if(careResponse.source == ExternalSystem.Type.Autoline.name()){
                    uniqueKey += careResponse.isBusiness? '_C' : '_P';
                    uniqueKey += '_'+careResponse.dmsNo;
                }
                else{
                    uniqueKey += '_'+String.valueOf(careResponse.custNo);
                }
                uniqueKey2CareResponse.put(uniqueKey,careResponse);
            }
    
            List<String> extSysNameList = new List<String>();
            extSysNameList.add(ExternalSystem.Type.CareDb.name());
            extSysNameList.add(ExternalSystem.Type.Autoline.name());
            List<ExternalSystemAccount__c> externalSysAccountList = [
                SELECT Account__c, Address1__c, Address3__c, Address2__c,
                    Birthdate__c, City__c, CompanyCode__c, CompanyMagicNumber__c, CustomerNumber__c,
                    DocumentNumber__c, EmailHome__c, Gender__c, FullName__c, Id,
                    Postcode__c, State__c, UniqueKey__c, Source__c
                FROM ExternalSystemAccount__c
                WHERE UniqueKey__c IN: this.uniqueKey2CareResponse.keySet()
                    AND SourceBy__c IN :extSysNameList
            ];
    
            for(ExternalSystemAccount__c exSysAccount: externalSysAccountList){
                this.uniqueKey2ExSysAccount.put(exSysAccount.UniqueKey__c,exSysAccount);
            }
        }
        else if(CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(ExternalSystem.Type.GDMS).contains(this.extSystem.companyName)){
            this.uniqueKey2CustomerAccount = new Map<String,CustomerVehicleService.QueryCustomerAccount_CustomerRow>();
            this.uniqueKey2ExSysAccount = new Map<String,ExternalSystemAccount__c>();
            for(CustomerVehicleService.QueryCustomerAccount_CustomerRow custAccount: this.CustomerAccountList){
                Matcher nonAlphaMatcher = nonAlphanumeric.matcher(custAccount.DocNum);
                custAccount.DocNum = nonAlphaMatcher.replaceAll('');
                String uniqueKey = this.extSystem.companyName + '_';
                uniqueKey += String.valueOf(custAccount.CustomerNo);
                this.uniqueKey2CustomerAccount.put(uniqueKey,custAccount);
            }

            List<ExternalSystemAccount__c> externalSysAccountList = [
                SELECT Account__c, Address1__c, Address3__c, Address2__c,
                    Birthdate__c, City__c, CompanyCode__c, CompanyMagicNumber__c, CustomerNumber__c,
                    DocumentNumber__c, EmailHome__c, Gender__c, FullName__c, Id,
                    Postcode__c, State__c, UniqueKey__c, Source__c
                FROM ExternalSystemAccount__c
                WHERE UniqueKey__c IN: this.uniqueKey2CustomerAccount.keySet()
            ];
    
            for(ExternalSystemAccount__c exSysAccount: externalSysAccountList){
                ESATriggerHandler.dmsEsaAccountIds.add(exSysAccount.Id);
                this.uniqueKey2ExSysAccount.put(exSysAccount.UniqueKey__c,exSysAccount);
            }
        }
    }

    public List<Database.UpsertResult> upsertEsa(){
        List<ExternalSystemAccount__c> exSysAccountList = new List<ExternalSystemAccount__c>();
        List<ExternalSystemAccount__c> exSysAccountUpdateList = new List<ExternalSystemAccount__c>();

        if(this.extSystem.companyName == CompanyRepository.C028){
            for(String uniqueKey :uniqueKey2CareResponse.keySet()){

                CareService.ContactResponse careResponse= uniqueKey2CareResponse.get(uniqueKey);
    
                ExternalSystemAccount__c exSysAccount = this.uniqueKey2ExSysAccount.get(uniqueKey);
                if(exSysAccount == null){
                    exSysAccount = new ExternalSystemAccount__c(UniqueKey__c = uniqueKey);
                    exSysAccount.SourceBy__c = ExternalSystem.Type.CareDb.name();
                    exSysAccount.Source__c = CompanyRepository.NAME_TO_EXTERNAL_SYSTEM.get(careResponse.companyCode).name();
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
                if(careResponse.source == ExternalSystem.Type.Autoline.name()){
                    if(careResponse.isBusiness == true){
                        exSysAccount.CompanyMagicNumber__c = careResponse.dmsNo;
                        exSysAccount.CustomerType__c = 'C';
                    }
                    else{
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
    
                exSysAccount.PhoneMobileE164__c = UtilPhone.toE164(careResponse.phone1raw);
                exSysAccount.PhoneMobile__c = careResponse.phone1raw;

                exSysAccount.PhoneHomeE164__c = UtilPhone.toE164(careResponse.phone2raw);
                exSysAccount.PhoneHome__c = careResponse.phone2raw;

                exSysAccount.PhoneOfficeE164__c = UtilPhone.toE164(careResponse.phone3raw);
                exSysAccount.PhoneOffice__c = careResponse.phone3raw;
    
                exSysAccount.SourceBy__c = careResponse.source;
                try{
                    exSysAccount.isPerson__c = !careResponse.isBusiness;
                }
                catch(Exception e){
                    exSysAccount.isPerson__c = true;
                }
                exSysAccountList.add(exSysAccount);

            }
        }

        else if(CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(ExternalSystem.Type.GDMS).contains(this.extSystem.companyName)){
            for(String uniqueKey: this.uniqueKey2CustomerAccount.keySet()){
                CustomerVehicleService.QueryCustomerAccount_CustomerRow custAccount =
                    this.uniqueKey2CustomerAccount.get(uniqueKey);
                ExternalSystemAccount__c extSysAccount = this.uniqueKey2ExSysAccount.get(uniqueKey);
                /*
                if(exSysAccount == null){
                    exSysAccount = new ExternalSystemAccount__c(UniqueKey__c = uniqueKey);
                    String extSysName = CompanyRepository.NAME_TO_EXTERNAL_SYSTEM.get(this.extSystem.companyName).name();
                    exSysAccount.Source__c = extSysName;
                    exSysAccount.SourceBy__c = extSysName;
                }
                exSysAccount.Address1__c = custAccount.Address;
                exSysAccount.Address2__c = custAccount.Address2;
                exSysAccount.City__c = custAccount.City;
                exSysAccount.Postcode__c = custAccount.PostCode;
                exSysAccount.Birthdate__c = String.valueOf(custAccount.DOB);
                exSysAccount.CompanyCode__c = custAccount.CompanyCode;
                exSysAccount.CustomerNumber__c = String.valueOf(custAccount.CustomerNo);
                exSysAccount.DocumentNumber__c = custAccount.DocNum;
                exSysAccount.GdmsPin__c = custAccount.PIN;
                exSysAccount.CustomerType__c = custAccount.CustomerType;
                exSysAccount.EmailHome__c = custAccount.HomeEmail;
                exSysAccount.EmailOther__c = custAccount.OtherEmail;
                exSysAccount.EmailOffice__c = custAccount.OfficeEmail;
                exSysAccount.PreferredName__c = custAccount.PrefferedName;
                exSysAccount.Salutation__c = custAccount.Salutation;
                exSysAccount.FullName__c = custAccount.FirstName + ' ' + custAccount.LastName;
                exSysAccount.PhoneMobileE164__c = UtilPhone.toE164(custAccount.MobilePhone);
                exSysAccount.PhoneMobile__c = custAccount.MobilePhone;
                exSysAccount.PhoneHomeE164__c = UtilPhone.toE164(custAccount.HomePhone);
                exSysAccount.PhoneHome__c = custAccount.HomePhone;
                exSysAccount.PhoneOfficeE164__c = UtilPhone.toE164(custAccount.OfficePhone);
                exSysAccount.PhoneOffice__c = custAccount.OfficePhone;
                exSysAccount.GdmsPin__c = custAccount.PIN;
                if(custAccount.Cust_Driver == null){
                    exSysAccount.IsDriver__c = false;
                }
                else{
                    exSysAccount.IsDriver__c = custAccount.Cust_Driver;
                }
                exSysAccount.DocumentType__c = custAccount.DocType;
                exSysAccount.LastUpdate__c = custAccount.LastUpdate;
                exSysAccount.isPerson__c = ESATriggerHandler.isPersonEsa(exSysAccount);
                */
                if(extSysAccount == null){
                    extSysAccount = ExtSysAccountLookup.prepareEsa(custAccount);
                    System.debug(extSysAccount.UniqueKey__c);
                }
                else{
                    Id esaId = extSysAccount.Id;
                    extSysAccount = ExtSysAccountLookup.prepareEsa(custAccount);
                    extSysAccount.Id = esaId;
                    System.debug(extSysAccount.UniqueKey__c);
                    System.debug(extSysAccount.Id);
                }
                exSysAccountList.add(extSysAccount);
            }
        }
        if(exSysAccountList.size()>0){
            List<Database.UpsertResult> exSysAccountUpsertResultList = new List<Database.UpsertResult>();
            ESATriggerHandler.careApiInvocation = true;
            exSysAccountUpsertResultList = Database.upsert(exSysAccountList,false);
            ESATriggerHandler.careApiInvocation = false;
            for(Database.UpsertResult exSysAccountUpsertResult: exSysAccountUpsertResultList){
                if(!exSysAccountUpsertResult.isSuccess()){
                    for(Database.Error dbError: exSysAccountUpsertResult.getErrors()){
                        ApplicationLogUtility.insertApexErrorLog(this,dbError,ApplicationLogUtility.PRIORITY_LOW,false);
                    }
                }
            }
            return exSysAccountUpsertResultList;
        }
        return null;
    }

    public void execute(QueueableContext context){
        if(this.extSystem.companyName == CompanyRepository.C028){
            try{
                this.callCareApi();
                this.initMaps();
                this.upsertEsa();
                Boolean requeueItself = this.isSelfQueueable;
                if(this.careResponseList.size() < this.batchSize || Test.isRunningTest()){
                    requeueItself = false;
                }
                if(Test.isRunningTest()){
                    requeueItself = false;
                }
                if(requeueItself){
                    this.careResponseList.clear();
                    System.enqueueJob(this);
                }
                else{
                    this.updateLastRun();
                    if(this.followOn){
                        this.queueNext(true);
                    }
                }
            }
            catch (CalloutException e) {
                ApplicationLogUtility.insertCalloutErrorLog(this.jobName, e,ApplicationLogUtility.PRIORITY_HIGH,false);
            }
            catch (Exception e) {
                ApplicationLogUtility.insertApexErrorLog(this.jobName, e, ApplicationLogUtility.PRIORITY_HIGH,false);
            }
        }
        else if(CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(ExternalSystem.Type.GDMS).contains(this.extSystem.companyName)){
            try{
                CustomerVehicleService esaService = new CustomerVehicleService(this.extSystem.companyName);
                String searchField = 'mod_datetime';
                String searchValue = this.dateFrom?.format('dd/MM/yyyy HH:mm:ss.SSS');
                if(String.isNotBlank(searchValue)){
                    searchValue += '-'+this.dateTo?.format('dd/MM/yyyy HH:mm:ss.SSS');
                }
                Integer batchSize = (Integer) this.batchSize;
                String request = this.extSystem.companyName+' | mod_datetime:\n';
                request += searchValue;
                request += 'lastRowId:\n';
                request += this.lastRowId;
                if(!Test.isRunningTest()){
                    CustomerVehicleService.QueryCustomerAccountResponse custAccountResp = esaService.QueryCustomerAccount(this.extSystem.companyName, searchField, searchValue, this.lastRowId, batchSize);
                    this.lastRowId = custAccountResp.LastRowID;
                    if(custAccountResp.Customer.CustomerRow != null){
                        this.CustomerAccountList = custAccountResp.Customer.CustomerRow;
                    }
                }
                this.initMaps();
                this.upsertEsa();

                String response = '';
                response += 'Size: '+ this.CustomerAccountList.size();
                response += 'lastRowId:\n';
                response += this.lastRowId;

                //create a succcess log
                ApplicationLogUtility.insertCalloutSuccessLog(Util.getClassname(this), request, response, null,false);

                //requeue the same class
                Boolean requeueItself = this.isSelfQueueable;
                if(this.CustomerAccountList.size() < batchSize || Test.isRunningTest()){
                    requeueItself = false;
                }
                if(requeueItself){
                    this.CustomerAccountList.clear() ;
                    System.enqueueJob(this);
                }
                else{
                    this.updateLastRun();
                    if(this.followOn){
                        this.queueNext(true);
                    }
                }
            }
            catch(CalloutException e){
                System.debug(this.jobName);
                ApplicationLogUtility.insertCalloutErrorLog(this.jobName, e,ApplicationLogUtility.PRIORITY_HIGH,false);
                Resource.queueStart(this.extSystem.companyName);
            }
            catch(Exception e){
                ApplicationLogUtility.insertApexErrorLog(this.jobName, e, ApplicationLogUtility.PRIORITY_HIGH,false);
                Resource.queueStart(this.extSystem.companyName);
            }
        }
        ApplicationLogUtility.insertLogs();

    }
}