public with sharing class ExtSysAccountLookup {
  //type + customer number -> Id
  private Map<String, Id> custNumType2Id;
  //type + customer pin -> Id
  private Map<String, Id> custPinType2Id;
  //type + document number -> Id
  private Map<String, Id> docNumType2Id;
  //customer number -> Id
  private Map<String, Id> custNum2Id;
  //docNum -> Id
  private Map<String, Id> docNum2Id;
  //custPin -> Id
  private Map<String, Id> custPin2Id;

  public void refresh() {
    this.custNumType2Id = new Map<String, Id>();
    this.custPinType2Id = new Map<String, Id>();
    this.docNumType2Id = new Map<String, Id>();
    this.custNum2Id = new Map<String, Id>();
    this.docNum2Id = new Map<String, Id>();
    this.custPin2Id = new Map<String, Id>();
  }

  public static String joinKeys(List<String> keyList) {
    String key = String.join(keyList, '_').toUpperCase();
    return key;
  }

  public static boolean isPersonVehicle(Vehicle__c vehicle) {
    return Util.isPersonEntity(
      vehicle.id,
      vehicle.DmsCustomerType__c,
      vehicle.DmsDocumentNumber__c,
      vehicle.DmsCustomerName__c
    );
    // return true;
  }

  public ExtSysAccountLookup(List<ExternalSystemAccount__c> esaList) {
    this.updateMaps(esaList, true);
  }

  public void updateMaps(
    List<ExternalSystemAccount__c> esaList,
    Boolean refresh
  ) {
    if (refresh) {
      this.refresh();
    }

    List<String> keyList;
    for (ExternalSystemAccount__c extSysAccount : esaList) {
      //String custType = String.valueOf(ESATriggerHandler.isPersonEsa(extSysAccount));
      if (
        String.isNotBlank(extSysAccount.DocumentNumberAlphaN__c) &&
        extSysAccount.DocumentNumberAlphaN__c.length() > 5
      ) {
        /*
                keyList = new List<String>{
                    custType,extSysAccount.DocumentNumber__c
                };
                this.docNumType2Id.put(joinKeys(keyList),extSysAccount.Account__c);
                */
        keyList = new List<String>{ extSysAccount.DocumentNumberAlphaN__c };
        this.docNum2Id.put(joinKeys(keyList), extSysAccount.Account__c);
      }
      if (String.isNotBlank(extSysAccount.CustomerNumber__c)) {
        /*
                keyList = new List<String>{
                    custType,extSysAccount.CustomerNumber__c
                };
                this.custNumType2Id.put(joinKeys(keyList),extSysAccount.Account__c);
                */
        keyList = new List<String>{ extSysAccount.CustomerNumber__c };
        this.custNum2Id.put(joinKeys(keyList), extSysAccount.Account__c);
      }
      if (String.isNotBlank(extSysAccount.GdmsPin__c)) {
        /*
                keyList = new List<String>{
                    custType,extSysAccount.GdmsPin__c
                };
                this.custPinType2Id.put(joinKeys(keyList),extSysAccount.Account__c);
                */
        keyList = new List<String>{ extSysAccount.GdmsPin__c };
        this.custPin2Id.put(joinKeys(keyList), extSysAccount.Account__c);
      }
    }
  }

  public Id lookup(Vehicle__c vehicle) {
    //String custType = String.valueOf(isPersonVehicle(vehicle));
    Id esaId;
    List<String> keyList;
    if (String.isNotBlank(vehicle.DmsCustomerNumber__c)) {
      keyList = new List<String>{ vehicle.DmsCustomerNumber__c };
      esaId = this.custNum2Id.get(joinKeys(keyList));
    }

    if (esaId == null && String.isNotBlank(vehicle.DmsCustomerPin__c)) {
      keyList = new List<String>{ vehicle.DmsCustomerPin__c };
      esaId = this.custPin2Id.get(joinKeys(keyList));
    }

    if (esaId == null && String.isNotBlank(vehicle.DmsDocumentNumber__c)) {
      esaId = this.docNumType2Id.get(joinKeys(keyList));
      if (esaId == null) {
        keyList = new List<String>{ vehicle.DmsDocumentNumber__c };
        esaId = this.docNum2Id.get(joinKeys(keyList));
      }
    }
    return esaId;
  }

  public static ExternalSystemAccount__c prepareEsa(
    CustomerVehicleService.QueryCustomerAccount_CustomerRow custAccount
  ) {
    String extSysName = CompanyRepository.NAME_TO_EXTERNAL_SYSTEM.get(
        custAccount.CompanyCode
      )
      .name();
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
    System.debug('docnoraw set: ' + extSysAccount.DocumentNumber__c);
    if (custAccount.DocNum != null) {
      Pattern nonAlphanumeric = Pattern.compile('[^a-zA-Z0-9]');
      Matcher nonAlphaMatcher = nonAlphanumeric.matcher(custAccount.DocNum);
      extSysAccount.DocumentNumberAlphaN__c = nonAlphaMatcher.replaceAll('')
        .toUpperCase();
      System.debug('docno set: ' + extSysAccount.DocumentNumberAlphaN__c);
    }
    extSysAccount.GdmsPin__c = custAccount.PIN;
    extSysAccount.CustomerType__c = custAccount.CustomerType;
    extSysAccount.EmailHome__c = custAccount.HomeEmail;
    extSysAccount.EmailOther__c = custAccount.OtherEmail;
    extSysAccount.EmailOffice__c = custAccount.OfficeEmail;
    extSysAccount.PreferredName__c = custAccount.PrefferedName;
    extSysAccount.LastName__c = custAccount.LastName;
    extSysAccount.FirstName__c = custAccount.FirstName;
    extSysAccount.Salutation__c = custAccount.Salutation;
    extSysAccount.FullName__c =
      custAccount.FirstName +
      ' ' +
      custAccount.LastName;
    extSysAccount.PhoneMobileE164__c = UtilPhone.toE164(
      custAccount.MobilePhone
    );
    extSysAccount.PhoneMobile__c = custAccount.MobilePhone;
    extSysAccount.PhoneHomeE164__c = UtilPhone.toE164(custAccount.HomePhone);
    extSysAccount.PhoneHome__c = custAccount.HomePhone;
    extSysAccount.PhoneOfficeE164__c = UtilPhone.toE164(
      custAccount.OfficePhone
    );
    extSysAccount.PhoneOffice__c = custAccount.OfficePhone;
    extSysAccount.CreatedDate__c = custAccount.CreatedDate;
    if (custAccount.Cust_Driver == null) {
      extSysAccount.IsDriver__c = false;
    } else {
      extSysAccount.IsDriver__c = !custAccount.Cust_Driver;
    }
    if (custAccount.DriLicExp != null) {
      extSysAccount.DrivingLicenseExpiry__c = custAccount.DriLicExp.format();
    }
    if (String.isNotBlank(custAccount.State)) {
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

  public static ExternalSystemAccount__c prepareAccountToEsa(
    ExternalSystemAccount__c extAcc,
    Account account,
    String source,
    String cmp
  ) {
    String recordTypeDevName = Schema.SObjectType.Account.getRecordTypeInfosById()
      .get(account.RecordTypeId)
      .getDeveloperName();
    ExternalSystemAccount__c extSysAccount = extAcc;
    if (recordTypeDevName == 'PersonAccount') {
      extSysAccount.Salutation__c = account.Salutation;
      extSysAccount.FirstName__c = account.FirstName;
      extSysAccount.LastName__c = account.LastName;
      extSysAccount.PreferredName__c = account.Prefer_Name__pc;
      extSysAccount.CompanyName__c = account.CompanyName__pc;
      if (extSysAccount == null) {
        extSysAccount.DocumentType__c = 'Malaysian NRIC';
      }
      extSysAccount.DrivingLicenseExpiry__c = String.valueOf(
        account.LicenseExpiryDate__pc
      );
      extSysAccount.isPerson__c = true;
      extSysAccount.CustomerType__c = 'I';
      extSysAccount.PhoneMobile__c = account.PersonMobilePhone;
      extSysAccount.PhoneHome__c = account.PersonHomePhone;
      extSysAccount.EmailHome__c = account.Home_Email__c;
      extSysAccount.Postcode__c = account.PersonMailingPostalCode;
      extSysAccount.City__c = account.PersonMailingCity;
      extSysAccount.State__c = account.PersonMailingState;
      extSysAccount.Country__c = account.PersonMailingCountry;
      if (account.PersonMailingStreet != null) {
        List<String> res = account.PersonMailingStreet.split(',', 2);
        if (res.size() == 2) {
          extSysAccount.Address1__c = res[0] != null
            ? res[0]
            : account.PersonMailingStreet;
          extSysAccount.Address2__c = res[1] != null
            ? res[1]
            : res[0] != null ? res[0] : account.PersonMailingStreet;
        }
        if (res.size() == 1) {
          extSysAccount.Address1__c = account.PersonMailingStreet;
        }
      }
    } else {
      extSysAccount.FullName__c = account.Name;
      if (extSysAccount == null) {
        extSysAccount.DocumentType__c = 'Company Reg No.';
      }
      extSysAccount.isPerson__c = false;
      extSysAccount.CustomerType__c = 'C';
      extSysAccount.PhoneOffice__c = account.Phone;
      extSysAccount.PhoneMobile__c = account.Phone;
      extSysAccount.City__c = account.BillingCity;
      extSysAccount.State__c = account.BillingState;
      extSysAccount.Postcode__c = account.BillingPostalCode;
      extSysAccount.Country__c = account.BillingCountry;
      if (account.BillingStreet != null) {
        List<String> res = account.BillingStreet.split(',', 2);
        if (res.size() == 2) {
          extSysAccount.Address1__c = res[0] != null
            ? res[0]
            : account.BillingStreet;
          extSysAccount.Address2__c = res[1] != null
            ? res[1]
            : res[0] != null ? res[0] : account.BillingStreet;
        }
        if (res.size() == 1) {
          extSysAccount.Address1__c = account.BillingStreet;
        }
      }
    }
    extSysAccount.Birthdate__c = String.valueOf(account.PersonBirthdate);
    extSysAccount.DocumentNumber__c = account.NRIC_Number__c;
    extSysAccount.DocumentNumberAlphaN__c = account.DocumentNumberAlphaN__c;
    extSysAccount.EmailOffice__c = account.Office_Email__c;
    extSysAccount.EmailOther__c = account.Other_Email__c;
    extSysAccount.Account__c = extSysAccount.Account__c == null
      ? account.Id
      : extSysAccount.Account__c;
    if (String.isNotBlank(source)) {
      extSysAccount.SourceBy__c = source;
      extSysAccount.Source__c = source;
    }

    if (String.isNotBlank(cmp)) {
      extSysAccount.CompanyCode__c = cmp;
    }

    if (
      cmp != null &&
      account.Customer_Number__c != null &&
      account.Customer_Number__c != 0
    ) {
      String uniqueKey = cmp + '_';
      uniqueKey += String.valueOf(account.Customer_Number__c);
      extSysAccount.UniqueKey__c = uniqueKey;
    }
    return extSysAccount;
  }
}
