public with sharing class DmsEsaAccount {
  public static void sendWebhook(DmsCallBack__e callback) {
    try {
      ExternalSystemAccount__c esaAcc = retrieveEsaAccDetails(callback.Id__c);
      if (esaAcc == null) {
        return;
      }
      EsaAccount account = new EsaAccount(esaAcc);
      CustomerVehicleService service = new CustomerVehicleService(
        account.CompanyCode
      );
      try {
        EsaAccountWebhook hook = new EsaAccountWebhook(
          callback.Event__c.toLowercase(),
          new List<EsaAccount>{ account }
        );
        string jsonHook = JSON.serialize(hook, true);
        System.debug('jsonHook : ' + jsonHook);
        CustomerVehicleService.UpdateDataResponse resp = service.updateData(
          jsonHook
        );
        String response = JSON.serialize(resp);
        System.debug(' resp : ' + response);
        // Parse the JSON data
        Map<String, Object> jsonData = (Map<String, Object>) JSON.deserializeUntyped(
          response
        );
        String ipJsonString = (String) jsonData.get('ip_json');
        Map<String, Object> ipJsonData = (Map<String, Object>) JSON.deserializeUntyped(
          ipJsonString
        );
        List<Object> payload = (List<Object>) ipJsonData.get('payload');
        if (!payload.isEmpty()) {
          Map<String, Object> payloadData = (Map<String, Object>) payload[0];
          Integer CustomerNo = (Integer) payloadData.get('CustomerNo');
          System.debug('CustomerNo : ' + CustomerNo);
          if (
            CustomerNo != null &&
            esaAcc.CustomerNumber__c != String.valueOf(CustomerNo)
          ) {
            esaAcc.CustomerNumber__c = String.valueOf(CustomerNo);
            if (!ESATriggerHandler.dmsEsaAccountIds.contains(esaAcc.Id)) {
              ESATriggerHandler.dmsEsaAccountIds.add(esaAcc.Id);
            }
            update esaAcc;
          }
        }
        ApplicationLogUtility.insertCalloutSuccessLog(
          'DmsEsaAccount',
          jsonHook,
          response.unescapeJava(),
          Request.getCurrent().getRequestId(),
          false
        );
      } catch (CallOutException callOutError) {
        System.debug(
          'callOutError.getMessage() : ' + callOutError.getMessage()
        );
        callOutError.setMessage(
          'Error sending ' +
            String.valueOf(callback.Id__c) +
            ' ' +
            callback.CompanyCode__c +
            ' ' +
            callOutError.getMessage()
        );
        ApplicationLogUtility.insertCalloutErrorLog(
          new DmsEsaAccount(),
          callOutError,
          ApplicationLogUtility.PRIORITY_HIGH,
          false
        );
      }
    } catch (Exception e) {
      System.debug(
        'Exception Error ' +
          e.getCause() +
          ' Error msg ' +
          e.getMessage() +
          ' line no. ' +
          e.getLineNumber()
      );
      DmsEsaAccount dmsAcc = new DmsEsaAccount();
      e.setMessage(
        'Exception : ' +
          String.valueOf(callback.Id__c) +
          ' ' +
          callback.CompanyCode__c +
          ' ' +
          e.getMessage()
      );
      ApplicationLogUtility.insertApexErrorLog(
        dmsAcc,
        e,
        ApplicationLogUtility.PRIORITY_HIGH,
        false
      );
    }
    ApplicationLogUtility.insertLogs();
  }

  public static ExternalSystemAccount__c retrieveEsaAccDetails(String esaId) {
    String query =
      'SELECT ' +
      String.join(
        new List<String>(
          schema.SObjectType.ExternalSystemAccount__c.fields.getMap().keySet()
        ),
        ','
      );
    query += ' FROM ExternalSystemAccount__c  WHERE Id =: esaId LIMIT 1';
    return Database.query(String.escapeSingleQuotes(query));
  }

  public static CallbackAccountResp checkExistingAccount(
    List<CustomerVehicleService.QueryCustomerAccount_CustomerRow> payloadList
  ) {
    List<Database.UpsertResult> resultList = ExtSysAccountResource.prepareExtSysAccount(
      payloadList
    );
    if (resultList.isEmpty()) {
      return null;
    }
    Map<Id, String> extSysnAccMap = new Map<Id, String>();
    for (Database.UpsertResult sr : resultList) {
      if (!sr.isSuccess()) {
        String error;
        for (Database.Error dbError : sr.getErrors()) {
          error += dbError;
        }
        extSysnAccMap.put(sr.getId(), error);
      } else {
        extSysnAccMap.put(sr.getId(), 'Success');
      }
    }

    List<Details> detailsList = new List<Details>();
    for (ExternalSystemAccount__c ext : [
      SELECT Id, Account__c, CreatedDate, LastModifiedDate, CustomerNumber__c
      FROM ExternalSystemAccount__c
      WHERE Id IN :extSysnAccMap.keySet()
    ]) {
      if (extSysnAccMap.containsKey(ext.Id)) {
        if (extSysnAccMap.get(ext.Id) == 'Success') {
          String message;
          if (
            date.newinstance(
              ext.LastModifiedDate.year(),
              ext.LastModifiedDate.month(),
              ext.LastModifiedDate.day()
            ) ==
            date.newinstance(
              ext.CreatedDate.year(),
              ext.CreatedDate.month(),
              ext.CreatedDate.day()
            ) &&
            ext.CreatedDate.format('HH:mm') ==
            ext.LastModifiedDate.format('HH:mm')
          ) {
            message = 'Inserted';
          } else {
            message = 'Updated';
          }
          detailsList.add(
            new Details(
              ext.Account__c,
              ext.Id,
              ext.CustomerNumber__c,
              'Account Successfully ' + message
            )
          );
        } else {
          detailsList.add(
            new Details(
              ext.Account__c,
              ext.Id,
              ext.CustomerNumber__c,
              extSysnAccMap.get(ext.Id)
            )
          );
        }
      }
    }

    if (extSysnAccMap.containsKey(null)) {
      Details detail = new Details(
        '',
        '',
        '',
        'Error in account Upsert : ' + extSysnAccMap.get(null)
      );
      detailsList.add(detail);
    }

    ApplicationLogUtility.insertLogs();
    return new CallbackAccountResp('UPDATE_ACCOUNT', detailsList);
  }

  public class CallbackAccountResp {
    public String event;
    public List<Details> details;
    public CallbackAccountResp(String evt, List<Details> dtList) {
      this.event = evt;
      this.details = dtList;
    }
  }

  public class Details {
    public String message;
    public String CustomerNo;
    public String EsaId;
    public String AccountId;
    public Details(String accId, String esaId, String CustNo, String msg) {
      this.message = msg;
      this.CustomerNo = CustNo;
      this.EsaId = esaId;
      this.AccountId = accId;
    }
  }

  public class EsaAccountWebhook {
    public String event;
    public List<CustomerVehicleService.QueryCustomerAccount_CustomerRow> payload;
    public EsaAccountWebhook(String event, List<EsaAccount> loadList) {
      this.event = event;
      this.payload = loadList;
    }
  }

  public class EsaAccount extends CustomerVehicleService.QueryCustomerAccount_CustomerRow {
    public string accountId;
    public string esaId;
    public EsaAccount(ExternalSystemAccount__c extAcc) {
      this.CompanyCode = extAcc.CompanyCode__c;
      this.PIN = extAcc.GdmsPin__c;
      this.CustomerType = extAcc.CustomerType__c;
      this.CustomerNo = String.isBlank(extAcc.CustomerNumber__c)
        ? 0
        : Integer.ValueOf(extAcc.CustomerNumber__c);
      this.Cust_Driver = extAcc.IsDriver__c;
      this.Salutation = extAcc.Salutation__c;
      this.PrefferedName = extAcc.PreferredName__c;
      this.DocType = extAcc.DocumentType__c;
      this.DocNum = extAcc.DocumentNumber__c;
      this.DOB = String.isNotBlank(extAcc.Birthdate__c)
        ? Date.valueOf(extAcc.Birthdate__c)
        : null;
      this.DriLicExp = String.isNotBlank(extAcc.DrivingLicenseExpiry__c)
        ? Date.valueOf(extAcc.DrivingLicenseExpiry__c)
        : null;
      this.MobilePhone = extAcc.PhoneMobile__c;
      this.HomePhone = extAcc.PhoneHome__c;
      this.OfficePhone = extAcc.PhoneOffice__c;
      this.HomeEmail = extAcc.EmailHome__c;
      this.OfficeEmail = extAcc.EmailOffice__c;
      this.OtherEmail = extAcc.EmailOther__c;
      this.Address = extAcc.Address1__c;
      this.Address2 = extAcc.Address2__c;
      this.City = extAcc.City__c;
      this.State = extAcc.State__c;
      this.Country = extAcc.Country__c;
      this.PostCode = extAcc.Postcode__c;
      this.FirstName = extAcc.FirstName__c;
      this.LastName = extAcc.LastName__c;
      this.accountId = extAcc.Account__c;
      this.esaId = extAcc.Id;
    }
  }
}
