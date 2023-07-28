public without sharing class AccountHandler extends TriggerBase {
  public class AccountException extends Exception {
  }
  //public static User ADMIN = [SELECT Id FROM User WHERE Alias = 'godlike' AND isActive = true LIMIT 1];
  public static User admin;
  public static string updatedFrom;
  static {
    admin = TriggerBase.admin;
    updatedFrom = 'UI';
  }
  public static boolean preventDefaultSubs;

  public static final String TRIG_SETTING = 'Account';
  public AccountHandler() {
    super(TRIG_SETTING);
  }

  public override void beforeInsert(List<SObject> triggerNew) {
    // updateModelInterest((List<Account>) triggerNew, null);
    // accOwnerAssignment((List<Account>) triggerNew, CUR_USER);
    //checkMobilePreferredDup((List<Account>) triggerNew);
    excludeSharkTankLeadsFromMC((List<Account>) triggerNew);
    //checkPhone((List<Account>) triggerNew);
    for (Account ac : (List<Account>) triggerNew) {
      ac.UpdatedFrom__c = updatedFrom;
    }
  }

  public override void beforeUpdate(
    Map<Id, SObject> triggerNew,
    Map<Id, SObject> triggerOld
  ) {
    // updateModelInterest((List<Account>) triggerNew.values(), (Map<Id, Account>) triggerOld);
    // accOwnerAssignment((List<Account>) triggerNew.values(), CUR_USER);
    //checkMobilePreferredDup((List<Account>) triggerNew.values());
    //checkPhone((List<Account>) triggerNew.values());
    // excludeSharkTankLeadsFromMC((Map<Id, Account>) triggerNew, (Map<Id, Account>) triggerOld);
    for (Account ac : (List<Account>) triggerNew.values()) {
      ac.UpdatedFrom__c = updatedFrom;
    }
  }

  public override void beforeDelete(
    Map<Id, SObject> triggerNew,
    Map<Id, SObject> triggerOld
  ) {
    // checkExistOppOrTD((List<Account>)triggerOld.values(), CUR_USER);
  }

  public override void afterInsert(Map<Id, SObject> triggerNew) {
    if (!System.isFuture() && !System.isQueueable() && !System.isBatch()) {
      // createSalesContact((List<Account>) triggerNew.values());
      // createGDMSAccountNo_and_Opp((List<Account>) triggerNew.values(), CUR_USER);
    }

    /*
		if(preventDefaultSubs != true){
			createSubscriptions(triggerNew.values());
		}
		*/
  }

  public override void afterUpdate(
    Map<Id, SObject> triggerNew,
    Map<Id, SObject> triggerOld
  ) {
    if (!System.isFuture() && !System.isBatch() && !System.isQueueable()) {
      // createGDMSAccountNo_and_Opp((List<Account>) triggerNew.values(), CUR_USER);
    }

    Set<Id> accountIdSet = new Set<Id>();
    for (Account account : (List<Account>) triggerNew.values()) {
      accountIdSet.add(account.Id);
    }

    String query = 'SELECT ';
    query += String.join(
      new List<String>(schema.SObjectType.Account.fields.getMap().keySet()),
      ','
    );
    query +=
      ', ( SELECT ' +
      String.join(
        new List<String>(
          schema.SObjectType.ExternalSystemAccount__c.fields.getMap().keySet()
        ),
        ','
      );
    query += ' FROM ExternalSystemAccounts__r )';
    query += ' FROM Account ';
    query += 'WHERE Id IN :accountIdSet';
    List<Account> accountList = Database.query(
      String.escapeSingleQuotes(query)
    );
    List<ExternalSystemAccount__c> esaAccListToUpdate = new List<ExternalSystemAccount__c>();

    if (!accountList.isEmpty()) {
      for (Account account : accountList) {
        if (account.ExternalSystemAccounts__r.size() > 0) {
          for (
            ExternalSystemAccount__c extAcc : account.ExternalSystemAccounts__r
          ) {
            if (!ESATriggerHandler.dmsEsaAccountIds.contains(extAcc.Id)) {
              esaAccListToUpdate.add(prepareEsaAccount(extAcc, account));
            }
          }
        }
      }
    }

    ESATriggerHandler.careApiInvocation = false;
    Database.SaveResult[] esaAccountUpdateList = Database.Update(
      esaAccListToUpdate,
      false
    );
    ESATriggerHandler.careApiInvocation = true;

    for (Database.SaveResult sr : esaAccountUpdateList) {
      if (!sr.isSuccess()) {
        for (Database.Error dbError : sr.getErrors()) {
          ApplicationLogUtility.insertApexErrorLog(
            new AccountHandler(),
            dbError,
            ApplicationLogUtility.PRIORITY_HIGH,
            false
          );
        }
      }
    }
    ApplicationLogUtility.insertLogs();
  }

  public static ExternalSystemAccount__c prepareEsaAccount(
    ExternalSystemAccount__c extAcc,
    Account account
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
      extSysAccount.isPerson__c = false;
      extSysAccount.CustomerType__c = 'C';
      extSysAccount.PhoneOffice__c = account.Phone;
      extSysAccount.City__c = account.BillingCity;
      extSysAccount.State__c = account.BillingState;
      extSysAccount.Postcode__c = account.BillingPostalCode;
      extSysAccount.Country__c = account.BillingCountry;
      extSysAccount.PhoneMobile__c = account.Phone;
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
    extSysAccount.DocumentNumber__c = account.NRIC_Number__c != null
      ? account.NRIC_Number__c
      : account.DocumentNumberAlphaN__c;
    extSysAccount.EmailOffice__c = account.Office_Email__c;
    extSysAccount.EmailOther__c = account.Other_Email__c;
    return extSysAccount;
  }

  public override void afterDelete(Map<Id, SObject> triggerOld) {
    resyncCustAfterMerge((List<Account>) triggerOld.values());
  }

  // public static void updateModelInterest(List<Account> triggerNew, Map<Id, Account> triggerOldMap) {
  // 	for (Account acc : triggerNew) {
  // 		Account oldAcc = triggerOldMap != null ? triggerOldMap.get(acc.Id) : null;
  // 		ModelInterest_Helper.modelCheck(oldAcc, acc);
  // 		Set<String> sgModelInt = ModelInterest_Helper.getPicklistValues(acc, 'Model_Interest__c');
  // 		Set<String> newModelInt = new Set<String>();
  // 		Set<String> discontModelInt = !String.isBlank(acc.Model_Interest_Discontinued__c) ? new Set<String>(acc.Model_Interest_Discontinued__c.split(';'))
  // 																						  : new Set<String>();
  // 		for (String modelInt : ModelInterest_Helper.getFieldValue(acc, new Set<String>{'Model_Interest__c'})) {
  // 			if (!sgModelInt.contains(modelInt)) {
  // 				discontModelInt.add(modelInt);
  // 			} else {
  // 				newModelInt.add(modelInt);
  // 			}
  // 		}
  // 		acc.Model_Interest__c = String.join(new List<String>(newModelInt), ';');
  // 		acc.Model_Interest_Discontinued__c = String.join(new List<String>(discontModelInt), ';');
  // 	}
  // }

  /*
	public static void checkMobilePreferredDup (List<Account> triggerNew) {
		Map<String, Account> mapDuplicateAccounts = new Map<String, Account>();
		Set<Id> setAccountIds = new Set<Id>();
		Set<String> mobileNum = new Set<String>();
		String strMobileNo;
		for (Account objAccount : triggerNew) {
			setAccountIds.add(objAccount.Id);
			// if (objAccount.Mobile_Preferred__pc != null) {
			// 	strMobileNo = String.valueOf(objAccount.Mobile_Preferred__pc);
			// 	if (strMobileNo.toUpperCase() != 'CRM' && !mobileNum.add(strMobileNo)) {
			// 		objAccount.addError('Account with Duplicate Mobile (Preferred).', false);
			// 	}
			// }
			strMobileNo = UtilPhone.toE164(objAccount.PersonMobilePhone);
			if (strMobileNo != null) {
				if (!mobileNum.add(strMobileNo)) {
					objAccount.addError('Account with Duplicate Mobile (Preferred).', false);
				}
			}
		}

		// List<Account> accList = [SELECT Id, Account_Name__c, Mobile_Preferred__pc, LastName FROM Account
		// 						 WHERE IsPersonAccount = TRUE AND Mobile_Preferred__pc IN :mobileNum];
		List<Account> accList = [SELECT Id, Account_Name__c, PersonMobilePhone, LastName FROM Account
								 WHERE IsPersonAccount = TRUE AND PersonMobilePhone IN :mobileNum];

		for (Account objAccount : accList) {
			if (!setAccountIds.contains(objAccount.Id)) {
				mapDuplicateAccounts.put(objAccount.Mobile_Preferred__pc, objAccount);
			}
		}

		String strError;
		for (Account objAccount : triggerNew) {
			if (mapDuplicateAccounts.containsKey(objAccount.Mobile_Preferred__pc) &&
				mapDuplicateAccounts.get(objAccount.Mobile_Preferred__pc).Id != objAccount.Id) {
				strError = strError + '</br><a href=\'/' + mapDuplicateAccounts.get(objAccount.Mobile_Preferred__pc).Id + '\'>'
									+ mapDuplicateAccounts.get(String.valueOf(objAccount.Mobile_Preferred__pc)).LastName + '</a>';
				objAccount.addError('Account with Duplicate Mobile (Preferred): ' + strError, false);
			}
		}
	}
	*/

  public static void excludeSharkTankLeadsFromMC(List<Account> triggerNew) {
    /** Only process integration data */
    // if (System.isQueueable() && System.isBatch()) {
    /** Exclude Sharktank lead from SF MC by default */
    for (Account acc : triggerNew) {
      if (
        acc.AccountSource != null &&
        acc.AccountSource.equalsIgnoreCase('SharkTank')
      ) {
        acc.MobySyncToMc__c = false;
      }
    }
    // }
  }

  // public static void excludeSharkTankLeadsFromMC(Map<Id, Account> triggerNew, Map<Id, Account> triggerOld) {
  // 	System.debug('BeforeUpdate Trigger.excludeSharkTankLeadsFromMC()');
  // 	/** Only process integration data */
  // 	// if (System.isQueueable() && System.isBatch()) {
  // 		/** Exclude Sharktank lead from SF MC when not linked with Autoline */
  // 		for (Id id :triggerNew.keySet()) {
  // 			Account newAcc = triggerNew.get(id);
  // 			Account oldAcc = triggerOld.get(id);
  // 			if (newAcc.AccountSource != null && newAcc.AccountSource.equalsIgnoreCase('SharkTank')
  // 				&& oldAcc.Customer_Number__c == null) {
  // 				newAcc.MobySyncToMc__c = false;
  // 			}
  // 		}
  // 	// }
  // }

  // public static void createGDMSAccountNo_and_Opp(List<Account> triggerNew, String cmp) {
  // 	createGDMSAccountNo_and_Opp(triggerNew, new User(Id = UserInfo.getUserId(), Company__c = cmp));
  // }

  // public static void createGDMSAccountNo_and_Opp(List<Account> triggerNew, User usr) {
  // 	List<Id> accIds = new List<Id>();
  // 	for (Account acc : triggerNew) {
  // 		accIds.add(acc.Id);
  // 	}

  // 	if (usr.Company__c == '02' || usr.Company__c == '03' || usr.Company__c == '888') {
  // 		if (Limits.getLimitQueueableJobs() > Limits.getQueueableJobs() && !Test.isRunningTest()) {
  // 			// System.enqueueJob(new CreateGDMSAcc_Queue(accIds, usr.Company__c));
  // 		}
  // 	} else if(usr.Company__c == '13') {
  // 		// SDSInsertAccountWS.insertTriggerSDSAccount(accIds, usr.Company__c);
  // 	} else if(usr.Company__c == '05') {
  // 		// PPSLInsertAccountWS.insertTriggerPPSLAccount(accIds, usr.Company__c, 'Trigger');
  // 	}
  // }

  // public static void createSalesContact(List<Account> triggerNew) {
  // 	if (Limits.getLimitQueueableJobs() > Limits.getQueueableJobs() && !Test.isRunningTest()) {
  // 		System.enqueueJob(new SalesContactCheck_Queue(triggerNew));
  // 	}
  // }

  // assign ownership to Admin
  // public static void accOwnerAssignment(List<Account> triggerNew, User usr) {
  // 	//User admin = [SELECT Id FROM User WHERE Name = 'Salesforce Admin' AND isActive = true LIMIT 1];
  // 	//User currUser = [SELECT Id, Company__c FROM User WHERE Id =: Userinfo.getUserId()];
  // 	Set<Id> ownerList = new Set<Id>();

  // 	for (Account acc : triggerNew) {
  // 		ownerList.add(acc.OwnerId);
  // 	}
  // 	Map<Id,User> ownerMap = new Map<Id,User> ([SELECT Id, IsPortalEnabled FROM User WHERE Id IN :ownerList]);

  // 	for (Account acc : triggerNew) {
  // 		//check company flag depending on Logged in user Company
  // 		acc.PMA__c = (usr.Company__c == '888' || acc.PMA__c);
  // 		acc.PML__c = (usr.Company__c == '02' || acc.PML__c);
  // 		acc.VAL__c = (usr.Company__c == '03' || acc.VAL__c);
  // 		acc.PPSL__c = (usr.Company__c == '05' || acc.PPSL__c);
  // 		acc.SDSL__c = (usr.Company__c == '05' || acc.SDSL__c); // should be 07
  // 		acc.SDS__c = (usr.Company__c == '13' || acc.SDS__c);

  // 		//change ownership to Salesforce Admin IF Owner is not Partner User
  // 		if (!ownerMap.get(acc.OwnerId).IsPortalEnabled) {
  // 			acc.OwnerId = ADMIN.Id;
  // 		}
  // 	}
  // }

  // Called by Sales Order
  // public static void verifyAccDocType(List<sObject> triggerNew) {
  // 	List<Id> listId = new List<Id>();
  // 	Map<Id,String> errMap = new Map<Id,String>();
  // 	List<Opportunity> oppList = new List<Opportunity>();
  // 	String objName = '';
  // 	if (triggerNew[0].get('Id') != null) {
  // 		objName = ((Id)triggerNew[0].get('Id')).getSObjectType().getDescribe().getName();
  // 	}
  // 	String errMssg = 'Please change the Customer Account Document Type to NRIC/FIN';

  // 	for (sObject so : triggerNew){
  // 		// CANNOT USE ACCOUNT FIELD DUE TO PPSL NOT FOLLOWING STANDARD
  // 		listId.add((Id)so.get('Opportunity__c'));
  // 		errMssg += ' before creating Sales Order';
  // 	}

  // 	// only query for Sales Order use cases
  // 	try {
  // 		oppList = [SELECT Id, Account.IsPersonAccount, Account.Doc_Type__c FROM Opportunity WHERE Id IN: listId AND Account.IsPersonAccount = true];
  // 	}
  // 	catch (exception e) {
  // 		System.debug('@@@ Error : ' + e);
  // 	}

  // 	try {
  // 		for (Opportunity opp : oppList) {
  // 			System.debug('@@@ Check opp : ' + opp);
  // 			if (opp.AccountId != null && !opp.Account.Doc_Type__c.contains('Singapore NRIC') && !opp.Account.IsPersonAccount) {
  // 				errMap.put(opp.Id,errMssg);
  // 			}
  // 		}
  // 	}
  // 	catch (exception e) {
  // 		System.debug('@@@ Error : ' + e);
  // 	}

  // 	// add the error to the corresponding record
  // 	for (sObject so : triggerNew) {
  // 		if (errMap.containsKey((Id)so.get('Opportunity__c'))) {
  // 			so.addError(errMap.get((Id)so.get('Opportunity__c')));
  // 		}
  // 	}
  // }

  // public static void checkExistOppOrTD(List<Account> triggerNew, User usr) {
  // 	if (usr.Profile.Name != 'System Administrator'){
  // 		Map<Id, Account> accMap = new Map<Id, Account>([SELECT Id, (SELECT Id FROM Opportunities), (SELECT Id FROM Test_Drive__r) FROM Account WHERE Id In :triggerNew]);
  // 		for (Account acc : triggerNew) {
  // 			if (accMap.get(acc.Id).Opportunities.size() > 0 || accMap.get(acc.Id).Test_Drive__r.size() > 0) {
  // 				System.debug('Please delete any existing Opportunity and Test Drive');
  // 				acc.addError('</br><font size="+0" color="red"><Strong>Please delete any existing Opportunity and Test Drive</Strong></font></br>', false);
  // 			}
  // 		}
  // 	}
  // }

  public static void resyncCustAfterMerge(List<Account> triggerOld) {
    Set<Id> idList = new Set<Id>();
    for (Account acc : triggerOld) {
      if (acc.MasterRecordId != null) {
        idList.add(acc.MasterRecordId);
      } // this is set to the master record after a merge
    }
    List<Customer_App_Callback__e> callbacks = new List<Customer_App_Callback__e>();
    for (Id i : idList) {
      Customer_App_Callback__e newE = new Customer_App_Callback__e();
      newE.Id__c = i;
      newE.Event__c = 'RESYNC_ACCOUNT';
      callbacks.add(newE);
    }
    if (callbacks.size() > 0) {
      EventBus.publish(callbacks);
    }
  }

  public static void checkPhone(List<Account> accountList) {
    UtilPhone phoneUtil = new UtilPhone();
    for (Account accnt : accountList) {
      if (accnt.isPersonAccount) {
        phoneUtil.input = accnt.PersonMobilePhone;
        if (phoneUtil.output == null) {
          accnt.PersonMobilePhone = null;
        }
      } else {
        phoneUtil.input = accnt.phone;
        if (phoneUtil.output == null) {
          accnt.Phone = null;
        }
      }
    }
  }

  /*
	public static void createSubscriptions(List<Account> accountList){
		List<Subscription__c> subList = new List<Subscription__c>();
		Map<String,Company__c> name2CompanyMap = new Map<String,Company__c>();
		for(Company__c company:[SELECT Id,Name FROM Company__c ]){
			name2CompanyMap.put(company.Name,company);
		}
		for(Account newAccount: accountList){
			List<String> companyNameList = newAccount.OperatingUnit__c.split(';');
			System.debug(companynameList);
			for(String companyName: companyNameList){
				Id companyId = name2CompanyMap.get(companyName).Id;
				if(companyId != null){
					subList.addAll(SubsRepository.create(newAccount.Id, companyId,null,false));
				}
			}
		}
		insert subList;
	}*/
}
