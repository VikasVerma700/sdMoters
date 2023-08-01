public with sharing class ESATriggerHandler extends TriggerBase {
  public static final String TRIG_SETTING = 'External System Account';
  public static final String EVENT_NAME = 'ACCOUNT';
  public static boolean careApiInvocation;
  public static set<Id> dmsEsaAccountIds = new Set<Id>();
  public ESATriggerHandler() {
    super(TRIG_SETTING);
  }

  public override void beforeInsert(List<SObject> triggerNew) {
    rectifyEsaRecords((List<ExternalSystemAccount__c>) triggerNew);
    if (careApiInvocation == true) {
      updateAccountLookup((List<ExternalSystemAccount__c>) triggerNew);
      //rectifyLookupAccounts((List<ExternalSystemAccount__c>) triggerNew);
    }
    /** Flag Account's Updated From */
    // if (triggerNew.size() == 1) {
    // 	ExternalSystemAccount__c esa = ((List<ExternalSystemAccount__c>) triggerNew)[0];
    // 	AccountHandler.updatedFrom = String.join(new string[] { esa.CompanyCode__c, esa.CustomerNumber__c }, '_');
    // }
  }

  public override void beforeUpdate(
    Map<Id, SObject> triggerNew,
    Map<Id, SObject> triggerOld
  ) {
    rectifyEsaRecords((List<ExternalSystemAccount__c>) triggerNew.values());
    if (careApiInvocation == true) {
      updateAccountLookup((List<ExternalSystemAccount__c>) triggerNew.values());
      //rectifyLookupAccounts((List<ExternalSystemAccount__c>) triggerNew.values());
    }
    /** Flag Account's Updated From */
    // if (triggerNew.size() == 1) {
    // 	ExternalSystemAccount__c esa = ((List<ExternalSystemAccount__c>) triggerNew.values())[0];
    // 	AccountHandler.updatedFrom = String.join(new string[] { esa.CompanyCode__c, esa.CustomerNumber__c }, '_');
    // }
  }

  public override void afterUpdate(
    Map<Id, SObject> triggerNew,
    Map<Id, SObject> triggerOld
  ) {
    // Publish DMS platform  Events
    system.debug('dmsEsaAccountIds :' + dmsEsaAccountIds);
    Set<Id> esaAccountIds = new Set<Id>();
    for (
      ExternalSystemAccount__c esaAccount : (List<ExternalSystemAccount__c>) triggerNew.values()
    ) {
      if (!dmsEsaAccountIds.contains(esaAccount.Id)) {
        esaAccountIds.add(esaAccount.Id);
      }
    }

    if (!esaAccountIds.isEmpty()) {
      publishPlatformEvent(esaAccountIds);
      dmsEsaAccountIds = new Set<Id>();
    }
  }

  public static void publishPlatformEvent(Set<Id> esaIds) {
    Map<String, Map<String, List<String>>> entityWithRecordIdMap = new Map<String, Map<String, List<String>>>();
    Map<String, List<String>> companyCodeWithVehicleMap = new Map<String, List<String>>();
    for (ExternalSystemAccount__c esa : [
      SELECT Id, CompanyCode__c
      FROM ExternalSystemAccount__c
      WHERE CompanyCode__c != NULL AND Id IN :esaIds
    ]) {
      if (companyCodeWithVehicleMap.containsKey(esa.CompanyCode__c)) {
        companyCodeWithVehicleMap.get(esa.CompanyCode__c).add(esa.Id);
      } else {
        companyCodeWithVehicleMap.put(
          esa.CompanyCode__c,
          new List<String>{ esa.Id }
        );
      }
    }
    entityWithRecordIdMap.put(EVENT_NAME, companyCodeWithVehicleMap);
    DmsCallbackTriggerHandler handler = new DmsCallbackTriggerHandler(
      EVENT_NAME,
      entityWithRecordIdMap
    );
    handler.publishEvent();
  }

  public static String joinKeys(List<String> keyList) {
    String key = String.join(keyList, '_').toUpperCase();
    return key;
  }

  public static void add(Set<String> stringSet, String str) {
    if (String.isNotBlank(str)) {
      stringSet.add(str);
    }
  }

  /**
   * @param  extSysAccountList records whose account lookup has to be updated
   */
  public static void updateAccountLookup(
    List<ExternalSystemAccount__c> extSysAccountList
  ) {
    Set<String> companyCodeSet = new Set<String>();
    Set<String> customerNumSet = new Set<String>();
    Set<String> magicNumSet = new Set<String>();
    Set<String> docNumSet = new Set<String>();
    Set<String> emailSet = new Set<String>();

    for (ExternalSystemAccount__c exSysAccount : extSysAccountList) {
      if (String.isNotBlank(exSysAccount.CompanyCode__c)) {
        companyCodeSet.add(exSysAccount.CompanyCode__c);
      }

      if (String.isNotBlank(exSysAccount.CompanyMagicNumber__c)) {
        magicNumSet.add(exSysAccount.CompanyMagicNumber__c);
      }

      if (
        String.isNotBlank(exSysAccount.DocumentNumber__c) &&
        exSysAccount.DocumentNumber__c.length() > 5
      ) {
        docNumSet.add(exSysAccount.DocumentNumber__c);
      }

      if (String.isNotBlank(exSysAccount.CustomerNumber__c)) {
        customerNumSet.add(exSysAccount.CustomerNumber__c);
      } else {
        exSysAccount.uniqueKey__c = null;
      }

      if (String.isNotBlank(exSysAccount.EmailHome__c)) {
        emailSet.add(exSysAccount.EmailHome__c);
      }
    }

    String query = 'SELECT ';
    Set<String> accountFieldSet = schema.SObjectType.Account.fields.getMap()
      .keySet();
    accountFieldSet.remove(
      'SMS_Routine_Service_Info_Opt_Out__pc'.toLowerCase()
    );
    accountFieldSet.remove('SMS_Opt_Out__pc'.toLowerCase());
    accountFieldSet.remove(
      'SMS_Email_Mail_Promotions_Opt_Out__pc'.toLowerCase()
    );
    accountFieldSet.remove('Benefits_Events_Opt_Out__pc'.toLowerCase());
    accountFieldSet.remove('Deactivate__pc'.toLowerCase());
    accountFieldSet.remove('Product_Information_Opt_Out__pc'.toLowerCase());
    accountFieldSet.remove('Magazine_Brochure_Opt_Out__pc'.toLowerCase());
    accountFieldSet.remove('Hot_lead__pc'.toLowerCase());
    accountFieldSet.remove('Marketing_Opt_Out__pc'.toLowerCase());
    accountFieldSet.remove('et4ae5__HasOptedOutOfMobile__pc'.toLowerCase());
    accountFieldSet.remove(
      'Club_Magazine_Newsletter_Opt_Out__pc'.toLowerCase()
    );
    accountFieldSet.remove('PDPA__pc'.toLowerCase());
    accountFieldSet.remove('Service_CS_Survey_Opt_Out__pc'.toLowerCase());
    accountFieldSet.remove('Survey_Opt_Out__pc'.toLowerCase());
    accountFieldSet.remove('Letter_Opt_Out__pc'.toLowerCase());
    query += String.join(new List<String>(accountFieldSet), ',');
    query += ',(SELECT Id,CompanyCode__c FROM ExternalSystemAccounts__r) ';
    query += ' FROM Account ';
    query += 'WHERE NRIC_Number__c IN :docNumSet OR ';
    query += 'DocumentNumberAlphaN__c IN :docNumSet OR ';
    query += 'Home_Email__c IN :emailSet OR ';
    query += 'Office_Email__c IN :emailSet OR ';
    query += 'Other_Email__c IN :emailSet';
    List<Account> accountList = Database.query(query);
    AccountLookup accountMaps = new AccountLookup();
    accountMaps.updateMaps(accountList, true);
    Map<String, Set<Id>> companyName2AccountIdSet = new Map<String, Set<Id>>();

    List<ExternalSystemAccount__c> nullAccountEsaList = new List<ExternalSystemAccount__c>();
    List<ExternalSystemAccount__c> updateAccountEsaList = new List<ExternalSystemAccount__c>();

    for (ExternalSystemAccount__c exSysAccount : extSysAccountList) {
      Id accountId = accountMaps.look(exSysAccount);
      if (accountId == null) {
        //account creation/updation
        nullAccountEsaList.add(exSysAccount);
      } else {
        if (accountId != exSysAccount.Account__c) {
          exSysAccount.Account__c = accountId;
        }
        updateAccountEsaList.add(exSysAccount);
      }
    }
    accountMaps.insertMissingAccounts();
    for (ExternalSystemAccount__c extSysAccount : nullAccountEsaList) {
      Id accountId = accountMaps.look(extSysAccount);
      extSysAccount.Account__c = accountId;
      String stackTrace = 'ESATriggerHandler: nullAccountEsaList';
      String message = 'Account not found/created for following ExternalSystemAccounts:';
      if (accountId == null) {
        message += '\n';
        if (extSysAccount.Id != null) {
          message += 'Id: ' + String.valueOf(extSysAccount.Id);
        }
        if (extSysAccount.CustomerNumber__c != null) {
          message += ' CustomerNumber__c: ' + extSysAccount.CustomerNumber__c;
        }
      } else {
        if (extSysAccount.CompanyCode__c != null) {
          Set<Id> accountIdSet = companyName2AccountIdSet.get(
            extSysAccount.CompanyCode__c
          );
          if (accountIdSet == null) {
            accountIdSet = new Set<Id>();
          }
          accountIdSet.add(accountId);
          companyName2AccountIdSet.put(
            extSysAccount.CompanyCode__c,
            accountIdSet
          );
        }
      }
    }

    if (updateAccountEsaList.size() > 0) {
      List<Account> updatedAccountlist = new List<Account>();
      Set<Id> accountIdSet = new Set<Id>();
      for (ExternalSystemAccount__c extSysAccount : updateAccountEsaList) {
        Account lookupAccount = accountMaps.getAccountById(
          extSysAccount.Account__c
        );
        if (!accountIdSet.contains(lookupAccount.Id)) {
          lookupAccount = AccountLookup.assignDetails(
            extSysAccount,
            lookupAccount
          );
          updatedAccountlist.add(lookupAccount);
          accountIdSet.add(lookupAccount.Id);
        }
      }

      List<Database.UpsertResult> accountUpdateResultList = Database.upsert(
        updatedAccountlist,
        false
      );
      System.debug('Control was here');
      System.debug(accountUpdateResultList);
      ApplicationLogUtility.logUpsertFailure(
        'ESATriggerHandler',
        accountUpdateResultList,
        ApplicationLogUtility.PRIORITY_HIGH,
        true
      );
      /*
            try{
                Database.upsert(updatedAccountlist,true);
            }
            catch(Exception upsertException){
                ApplicationLogUtility.insertApexErrorLog('ESATriggerHandler', upsertException, ApplicationLogUtility.PRIORITY_HIGH,true);
            }*/
    }

    if (companyName2AccountIdSet.keySet().size() > 0) {
      SubsRepository.create(companyName2AccountIdSet, true);
    }
  }

  /*
    public static void rectifyLookupAccounts(List<ExternalSystemAccount__c> extSysAccountList){
        List<ApplicationLog__c> appLogList = new List<ApplicationLog__c>();
        for(ExternalSystemAccount__c exSysAccount: extSysAccountList){
            if (String.isNotBlank(exSysAccount.EmailHome__c) && !Util.checkEmail(exSysAccount.EmailHome__c)) {
                //** Invalid email 
                ApplicationLog__c appLog = new ApplicationLog__c();
                appLog.ApexClassName__c = 'ESATriggerHandler';

                String error= 'Invalid email : ';
                error += exSysAccount.EmailHome__c;
                error += ' -> null';
                appLog.ErrorMessage__c = error;

                String stackTrace = 'rectifyLookupAccounts()';
                stackTrace += 'ESA UniqueId : '+exSysAccount.UniqueKey__c;
                stackTrace += 'Lookup Account : '+exSysAccount.Account__c;
                appLog.StackTrace__c = stackTrace;

                appLog.Type__c = ApplicationLogUtility.TYPE_APEX;
                appLog.Priority__c = ApplicationLogUtility.PRIORITY_LOW;
                appLog.TransactionId__c = Request.getCurrent().getRequestId();
                appLog.Status__c = 'Record Updated';
                appLogList.add(appLog);
                exSysAccount.EmailHome__c = null;
            }

            //** Capture erroneous birthday 
            if (exSysAccount.Birthdate__c != null && Util.validDate(exSysAccount.Birthdate__c) == null) {
                //** Invalid date range 
                ApplicationLog__c appLog = new ApplicationLog__c();
                appLog.ApexClassName__c = 'ESATriggerHandler';

                String error= 'Invalid Date of Birth : ';
                error += exSysAccount.Birthdate__c;
                error += ' -> null';
                appLog.ErrorMessage__c = error;

                String stackTrace = 'rectifyLookupAccounts()';
                stackTrace += 'ESA UniqueId : '+exSysAccount.UniqueKey__c;
                stackTrace += 'Lookup Account : '+exSysAccount.Account__c;
                appLog.StackTrace__c = stackTrace;

                appLog.Type__c = ApplicationLogUtility.TYPE_APEX;
                appLog.Priority__c = ApplicationLogUtility.PRIORITY_LOW;
                appLog.TransactionId__c = Request.getCurrent().getRequestId();
                appLog.Status__c = 'Record Updated';
                appLogList.add(appLog);
            }
        }
        if(appLogList.size()>0){
            Database.insert(appLogList,false);
        }
    }
    */

  public static boolean isPersonEsa(ExternalSystemAccount__c extSysAccount) {
    String custName = extSysAccount.PreferredName__c;
    if (String.isBlank(custName)) {
      custName = extSysAccount.FullName__c;
    }
    return Util.isPersonEntity(
      extSysAccount.Id,
      extSysAccount.CustomerType__c,
      extSysAccount.DocumentNumberAlphaN__c,
      custName
    );
    // return true;
  }

  public static void rectifyEsaRecords(
    List<ExternalSystemAccount__c> extSysAccountList
  ) {
    for (ExternalSystemAccount__c extSysAccount : extSysAccountList) {
      if (String.isBlank(extSysAccount.CustomerNumber__c)) {
        extSysAccount.UniqueKey__c = null;
      }
    }
  }
}
