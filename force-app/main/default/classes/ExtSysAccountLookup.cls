public with sharing class ExtSysAccountLookup {
    //type + customer number -> Id
    private Map<String,Id> custNumType2Id;
    //type + customer pin -> Id
    private Map<String,Id> custPinType2Id;
    //type + document number -> Id
    private Map<String, Id> docNumType2Id;
    //customer number -> Id
    private Map<String,Id> custNum2Id;
    //docNum -> Id
    private Map<String,Id> docNum2Id;

    public void refresh(){
        this.custNumType2Id = new Map<String,Id>();
        this.custPinType2Id = new Map<String,Id>();
        this.docNumType2Id = new Map<String,Id>();
        this.custNum2Id = new Map<String,Id>();
        this.docNum2Id = new Map<String,Id>();
    }

    public static String joinKeys(List<String> keyList){
		String key = String.join(keyList,'_').toUpperCase();
		return key;
	}

    public static boolean isPersonVehicle(Vehicle__c vehicle){
        return Util.isPersonEntity(vehicle.DmsCustomerType__c, vehicle.DmsDocumentNumber__c, vehicle.DmsCustomerName__c);
    }

    public ExtSysAccountLookup(List<ExternalSystemAccount__c> esaList){
        this.updateMaps(esaList,true);
    }

    public void updateMaps(List<ExternalSystemAccount__c> esaList, Boolean refresh){
        if(refresh){
            this.refresh();
        }

        List<String> keyList;
        for(ExternalSystemAccount__c extSysAccount: esaList){
            String custType = String.valueOf(ESATriggerHandler.isPersonEsa(extSysAccount));
            if(String.isNotBlank(extSysAccount.DocumentNumber__c) && extSysAccount.DocumentNumber__c.length()>5){
                keyList = new List<String>{
                    custType,extSysAccount.DocumentNumber__c
                };
                this.docNumType2Id.put(joinKeys(keyList),extSysAccount.Account__c);
                keyList = new List<String>{
                    extSysAccount.DocumentNumber__c
                };
                this.docNum2Id.put(joinKeys(keyList),extSysAccount.Account__c);
            }
            if(String.isNotBlank(extSysAccount.CustomerNumber__c)){
                keyList = new List<String>{
                    custType,extSysAccount.CustomerNumber__c
                };
                this.custNumType2Id.put(joinKeys(keyList),extSysAccount.Account__c);
                keyList = new List<String>{
                    extSysAccount.CustomerNumber__c
                };
                this.custNum2Id.put(joinKeys(keyList),extSysAccount.Account__c);
            }
            if(String.isNotBlank(extSysAccount.GdmsPin__c)){
                keyList = new List<String>{
                    custType,extSysAccount.GdmsPin__c
                };
                this.custPinType2Id.put(joinKeys(keyList),extSysAccount.Account__c);
            }
        }
    }

    public Id lookup(Vehicle__c vehicle){
        System.debug(this.custNumType2Id);
        System.debug(this.custPinType2Id);
        System.debug(this.docNumType2Id);
        System.debug(this.custNum2Id);

        String custType = String.valueOf(isPersonVehicle(vehicle));
        System.debug(custType);
        System.debug(vehicle.DmsCustomerNumber__c);
        System.debug(vehicle.DmsCustomerPin__c);
        System.debug(vehicle.DmsDocumentNumber__c);
        Id esaId;
        List<String> keyList;
        if(String.isNotBlank(vehicle.DmsCustomerNumber__c)){
            keyList = new List<String>{
                custType,vehicle.DmsCustomerNumber__c
            };

            esaId = this.custNumType2Id.get(joinKeys(keyList));
            if(esaId == null){
                keyList = new List<String>{
                    vehicle.DmsCustomerNumber__c
                };
                esaId = this.custNum2Id.get(joinKeys(keyList));
            }
        }

        if(esaId == null && String.isNotBlank(vehicle.DmsCustomerPin__c)){
            keyList = new List<String>{
                custType,vehicle.DmsCustomerPin__c
            };
            esaId = this.custPinType2Id.get(joinKeys(keyList));
        }

        if(esaId == null && String.isNotBlank(vehicle.DmsDocumentNumber__c)){
            keyList = new List<String>{
                custType,vehicle.DmsDocumentNumber__c
            };
            esaId = this.docNumType2Id.get(joinKeys(keyList));
            if(esaId == null){
                keyList = new List<String>{
                    vehicle.DmsDocumentNumber__c
                };
                esaId = this.docNum2Id.get(joinKeys(keyList));
            }
        }
        if(esaId == null && String.isNotBlank(vehicle.DmsCustomerNumber__c)){
            keyList = new List<String>{
                vehicle.DmsCustomerNumber__c
            };
            esaId = this.custNumType2Id.get(joinKeys(keyList));
        }
        return esaId;
    }

    public static ExternalSystemAccount__c prepareEsa(CustomerVehicleService.QueryCustomerAccount_CustomerRow custAccount){
        String extSysName = CompanyRepository.NAME_TO_EXTERNAL_SYSTEM.get(custAccount.CompanyCode).name();
        ExternalSystemAccount__c extSysAccount = new ExternalSystemAccount__c();
        extSysAccount.Source__c = extSysName;
        extSysAccount.SourceBy__c = extSysName;
        extSysAccount.Address1__c = custAccount.Address;
        extSysAccount.Address2__c = custAccount.Address2;
        extSysAccount.City__c = custAccount.City;
        extSysAccount.Postcode__c = custAccount.PostCode;
        extSysAccount.Birthdate__c = String.valueOf(custAccount.DOB);
        extSysAccount.CompanyCode__c = custAccount.CompanyCode;
        extSysAccount.CustomerNumber__c = String.valueOf(custAccount.CustomerNo);
        extSysAccount.DocumentNumber__c = custAccount.DocNum;
        extSysAccount.GdmsPin__c = custAccount.PIN;
        extSysAccount.CustomerType__c = custAccount.CustomerType;
        extSysAccount.EmailHome__c = custAccount.HomeEmail;
        extSysAccount.EmailOther__c = custAccount.OtherEmail;
        extSysAccount.EmailOffice__c = custAccount.OfficeEmail;
        extSysAccount.PreferredName__c = custAccount.PrefferedName;
        extSysAccount.LastName__c = custAccount.LastName;
        extSysAccount.FirstName__c = custAccount.FirstName;
        extSysAccount.Salutation__c = custAccount.Salutation;
        extSysAccount.FullName__c = custAccount.FirstName + ' ' + custAccount.LastName;
        extSysAccount.PhoneMobileE164__c = UtilPhone.toE164(custAccount.MobilePhone);
        extSysAccount.PhoneMobile__c = custAccount.MobilePhone;
        extSysAccount.PhoneHomeE164__c = UtilPhone.toE164(custAccount.HomePhone);
        extSysAccount.PhoneHome__c = custAccount.HomePhone;
        extSysAccount.PhoneOfficeE164__c = UtilPhone.toE164(custAccount.OfficePhone);
        extSysAccount.PhoneOffice__c = custAccount.OfficePhone;
        extSysAccount.CreatedDate__c = custAccount.CreatedDate;
        if(custAccount.Cust_Driver == null){
            extSysAccount.IsDriver__c = false;
        }
        else{
            extSysAccount.IsDriver__c = !custAccount.Cust_Driver;
        }
        if(custAccount.DriLicExp != null){
            extSysAccount.DrivingLicenseExpiry__c = custAccount.DriLicExp.format();
        }
        if(String.isNotBlank(custAccount.State)){
            extSysAccount.State__c = custAccount.State;
        }
        extSysAccount.Country__c = custAccount.Country;
        extSysAccount.DocumentType__c = custAccount.DocType;
        extSysAccount.LastUpdate__c = custAccount.LastUpdate;
        extSysAccount.isPerson__c = ESATriggerHandler.isPersonEsa(extSysAccount);
        String uniqueKey = custAccount.CompanyCode + '_';
        uniqueKey += String.valueOf(custAccount.CustomerNo);
        extSysAccount.UniqueKey__c = uniqueKey;
        return extSysAccount;
    }
}