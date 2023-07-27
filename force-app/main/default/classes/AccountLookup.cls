public with sharing class AccountLookup {

    //isPerson? + NRIC_Number__c => Id
    //isPerson? + DocumentNumberAlphaN__c => Id
    Map<String,Id> docKey2Id;

    //NRIC_Number__c => Id
    //DocumentNumberAlphaN__c => Id
    Map<String,Id> docNum2Id;

    //name+phone+email => Id
    //purified name +phone + email => Id
    Map<String,Id> npe2Id;

    //customer_number -> Id
    Map<String,Id> custNum2Id;

    //Id => Account
    Map<Id,Account> id2Account;

    Set<String> missingAccountKeySet;
    List<Account> missingAccountList;
    List<Account> accountList;

    public static String joinKeys(List<String> keyList){
        String key = String.join(keyList,'_').toUpperCase();
        return key;
    }

    private static Set<String> getDocKeys(Account accnt){
        List<String>  keyList;
        Set<String> keySet = new Set<String>();
        if(String.isNotBlank(accnt.NRIC_Number__c)){
            keyList = new List<String>();
            keyList.add(String.valueOf(accnt.isPersonAccount));
            keyList.add(accnt.NRIC_Number__c);
            keySet.add(joinKeys(keyList));
        }

        if(String.isNotBlank(accnt.DocumentNumberAlphaN__c)){
            keyList = new List<String>();
            keyList.add(String.valueOf(accnt.isPersonAccount));
            keyList.add(accnt.DocumentNumberAlphaN__c);
            keySet.add(joinKeys(keyList));
        }
        return keySet;
    }

    private static Set<String> getDocNumKeys(Account accnt){
        List<String>  keyList;
        Set<String> keySet = new Set<String>();
        if(String.isNotBlank(accnt.NRIC_Number__c)){
            keyList = new List<String>();
            keyList.add(accnt.NRIC_Number__c);
            keySet.add(joinKeys(keyList));
        }

        if(String.isNotBlank(accnt.DocumentNumberAlphaN__c)){
            keyList = new List<String>();
            keyList.add(accnt.DocumentNumberAlphaN__c);
            keySet.add(joinKeys(keyList));
        }
        return keySet;
    }

    private static Set<String> getNpeKeys(Account accnt){
        List<String>  keyList;
        Set<String> keySet = new Set<String>();
        if(String.isNotBlank(accnt.Name)){
    
            List<String> accountPhoneList = new List<String>();
            if(String.isNotBlank(accnt.Mobile_Preferred__pc) && accnt.IsPersonAccount){
                accountPhoneList.add(UtilPhone.toE164(String.valueOf(accnt.Mobile_Country_Code_1__pc) + accnt.Mobile_Preferred__pc));
            }
            if(String.isNotBlank(accnt.PersonMobilePhone) && accnt.IsPersonAccount){
                accountPhoneList.add(UtilPhone.toE164(accnt.PersonMobilePhone));
            }
            if(String.isNotBlank(accnt.Phone) && !accnt.IsPersonAccount ){
                accountPhoneList.add(UtilPhone.toE164(accnt.Phone));
            }

            List<String> accountEmailList = new List<String>{accnt.Office_Email__c,accnt.Home_Email__c,accnt.Other_Email__c};

            for(String phone: accountPhoneList){
                for(String email: accountEmailList){
                    if(Util.checkEmail(email)){

                        keyList = new List<String>();
                        keyList.add(accnt.Name);
                        keyList.add(phone);
                        keyList.add(email);
                        keySet.add(joinKeys(keyList));

                        keyList = new List<String>();
                        keyList.add(Util.purifyName(accnt.Name));
                        keyList.add(phone);
                        keyList.add(email);
                        keySet.add(joinKeys(keyList));
                    }
                }
            }
        }
        return keySet;
    }

    public static Account prepareAccount(ExternalSystemAccount__c extSysAccount){
        if(String.isNotBlank(extSysAccount.DocumentNumber__c) && extSysAccount.DocumentNumber__c.length()>4){
            Account lookupAccount = new Account();
            String accountRecordTypeDevName;
            if(extSysAccount.SourceBy__c == ExternalSystem.Type.CareDb.name()){
                accountRecordTypeDevName = extSysAccount.CompanyMagicNumber__c == null? 'PersonAccount' : 'Business_Account';
            }
            else if(extSysAccount.SourceBy__c == ExternalSystem.Type.GdmsInternal.name()){
                accountRecordTypeDevName = ESATriggerHandler.isPersonEsa(extSysAccount) ? 'PersonAccount' : 'Business_Account';
            }
            Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(accountRecordTypeDevName).getRecordTypeId();
            lookupAccount.recordTypeId = recordTypeId;
            Util.Identification id = Util.getIdent(extSysAccount.DocumentNumber__c);
            lookupAccount.Doc_Type__c = id.DocType;
            lookupAccount.NRIC_Number__c = id.Original;
            lookupAccount.DocumentNumberAlphaN__c = id.DocNumber;
    
            if(id.DocType == 'Malaysian NRIC'){
                lookupAccount.Verified_with_NRIC__c = true; 
            }
            
            if(String.isNotBlank(extSysAccount.CustomerNumber__c)){
                //lookupAccount.Customer_Number__c = Decimal.valueOf(exSysAccount.CustomerNumber__c);
            }
            /*
            lookupAccount.SFDC_Transfer_Datetime__c = System.now();
            lookupAccount.SFDC_Transfer_Flag__c = true;
            lookupAccount.SFDC_Transfer_Remarks__c = 'from Care';
            */
            lookupAccount.Created_From__c = CompanyRepository.NAME_TO_EXTERNAL_SYSTEM.get(extSysAccount.CompanyCode__c).name();
            lookupAccount = assignDetails(extSysAccount, lookupAccount);
    
            if(accountRecordTypeDevName == 'PersonAccount'){
                lookupAccount.Salutation = extSysAccount.Salutation__c;
                lookupAccount.LastName = extSysAccount.FullName__c;
                lookupAccount.Account_Name__c = extSysAccount.FullName__c;
                lookupAccount.OfficialName__c = extSysAccount.FullName__c; // Always accept AL fullName as Official Name
                lookupAccount.DisplayName__c = extSysAccount.PreferredName__c;
                lookupAccount.Prefer_Name__pc = extSysAccount.PreferredName__c;
                if (lookupAccount.Doc_Type__c == 'Malaysian NRIC' && (extSysAccount.Birthdate__c == null || Date.valueOf(extSysAccount.Birthdate__c) == Date.newInstance(1900, 1, 1))) {
                    /** Calculate Birthdate from IC if API date is not set (Unset: 1900-01-01) */
                    lookupAccount.PersonBirthdate = u.getBirthdate(lookupAccount.NRIC_Number__c);
                }
                else {
                    if(extSysAccount.Birthdate__c == null){
                        lookupAccount.PersonBirthDate = null;
                    }
                    else{
                        lookupAccount.PersonBirthdate = Util.validDate(Date.valueOf(extSysAccount.Birthdate__c));
                    }
                }
                /*moved to assign details
                lookupAccount.PersonMailingStreet = (String.isBlank(extSysAccount.Address1__c) ? '' : extSysAccount.Address1__c) + '\n' + (String.isBlank(extSysAccount.Address2__c) ? '' : extSysAccount.Address2__c);
                lookupAccount.PersonMailingCity = extSysAccount.City__c;
                lookupAccount.PersonMailingPostalCode = extSysAccount.Postcode__c;
                lookupAccount.PersonMailingState = extSysAccount.State__c;
                */
            }
            else{
                lookupAccount.Name = extSysAccount.FullName__c;
                lookupAccount.OfficialName__c = extSysAccount.FullName__c; // Always accept AL fullName as Official Name
            }
            lookupAccount = assignDetails(extSysAccount, lookupAccount);
            return lookupAccount;
        }
        return null;
    }

    public static Account assignDetails(ExternalSystemAccount__c extSysAccount, Account lookupAccount){
        String message = '';
        String stackTrace = 'Asign Details\nESA: '+extSysAccount.UniqueKey__c;

        //handle emails
        if(Util.checkEmail(extSysAccount.EmailHome__c)){
            if(extSysAccount.isPerson__c){
                lookupAccount.PersonEmail = extSysAccount.EmailHome__c;
            }
            lookupAccount.Home_Email__c = extSysAccount.EmailHome__c;
        }
        else{
            message += 'Invalid/null EmailHome__c';
        }

        if(Util.checkEmail(extSysAccount.EmailOffice__c)){
            lookupAccount.Office_Email__c = extSysAccount.EmailOffice__c;
            if(lookupAccount.PersonEmail == null && extSysAccount.isPerson__c){
                lookupAccount.PersonEmail = extSysAccount.EmailOffice__c;
            }
            else if(extSysAccount.isPerson__c == false){
            }
        }
        else{
            message += '\nInvalid/null EmailOffice__c';
        }

        if(Util.checkEmail(extSysAccount.EmailOther__c)){
            lookupAccount.Other_Email__c = extSysAccount.EmailOther__c;
            if(lookupAccount.PersonEmail == null && extSysAccount.isPerson__c){
                lookupAccount.PersonEmail = extSysAccount.EmailOther__c;
            }
            if(lookupAccount.Office_Email__c == null && extSysAccount.isPerson__c == false){
                lookupAccount.Office_Email__c = extSysAccount.EmailOther__c;
            }
        }
        else{
            message += '\nInvalid/null EmailOther__c';
        }

        lookupAccount.Active_Home__c = false;
        lookupAccount.Active_Work__c = false;
        lookupAccount.Active_Other__c = false;
        System.debug('checkpoint 1');
        if(extSysAccount.isPerson__c){
            if(lookupAccount.Home_Email__c != null){
                lookupAccount.Active_Home__c = true;
            }
            else if(lookupAccount.Office_Email__c != null){
                lookupAccount.Active_Work__c = true;
            }
            else if(lookupAccount.Other_Email__c != null){
                lookupAccount.Active_Other__c = true;
            }
        }

        else{
            System.debug('checkpoint 2');
            if(lookupAccount.Office_Email__c != null){
                lookupAccount.Active_Work__c = true;
            }
            else if(lookupAccount.Home_Email__c != null){
                lookupAccount.Active_Home__c = true;
            }
            else if(lookupAccount.Other_Email__c != null){
                lookupAccount.Active_Other__c = true;
            }
        }
        //handle phone fields
        List<String> phoneList = new List<String>{extSysAccount.PhoneMobileE164__c,extSysAccount.PhoneHomeE164__c,extSysAccount.PhoneOfficeE164__c};
        String phone;
        for(String exSysPhone:phoneList){
            if(String.isNotBlank(exSysPhone)){
                phone = exSysPhone;
                break;
            }
        }

        if(String.isNotBlank(phone)){
            if(extSysAccount.isPerson__c){
                lookupAccount.PersonMobilePhone = phone;
            }
            else{
                lookupAccount.Phone = phone;
            }

        }

        if(extSysAccount.isPerson__c){
            lookupAccount.PersonMailingStreet = (String.isBlank(extSysAccount.Address1__c) ? '' : extSysAccount.Address1__c) + '\n' + (String.isBlank(extSysAccount.Address2__c) ? '' : extSysAccount.Address2__c);
            lookupAccount.PersonMailingCity = extSysAccount.City__c;
            lookupAccount.PersonMailingState = extSysAccount.State__c;
            lookupAccount.PersonMailingCountry = extSysAccount.Country__c;
            if(String.isNotBlank(extSysAccount.Postcode__c)){
                lookupAccount.PersonMailingPostalCode = extSysAccount.Postcode__c.replaceAll('\\s','');
            }
        }
        else{
            lookupAccount.BillingStreet = (String.isBlank(extSysAccount.Address1__c) ? '' : extSysAccount.Address1__c) + '\n' + (String.isBlank(extSysAccount.Address2__c) ? '' : extSysAccount.Address2__c);
            lookupAccount.BillingCity = extSysAccount.City__c;
            lookupAccount.BillingState = extSysAccount.State__c;
            lookupAccount.BillingCountry = extSysAccount.Country__c;
            if(String.isNotBlank(extSysAccount.Postcode__c)){
                lookupAccount.BillingPostalCode = extSysAccount.Postcode__c.replaceAll('\\s','');
            }
        }
        return lookupAccount;

    } 
    
    public AccountLookup(){
        this.refresh();
    }

    public void refresh(){
        this.docKey2Id = new Map<String,Id>();
        this.docNum2Id = new Map<String,Id>();
        this.npe2Id = new Map<String,Id>();
        this.id2Account = new Map<Id,Account>();
        this.missingAccountList = new List<Account>();
        this.missingAccountKeySet = new Set<String>();
        this.custNum2Id = new Map<String,Id>();
    }

    public void updateMaps(List<Account> accountList, boolean refresh){
        if(refresh){
            this.refresh();
        }

        for(Account accnt: accountList){

            for(String dockey: getDocKeys(accnt)){
                this.docKey2Id.put(dockey,accnt.Id);
            }
            for(String dockey: getDocNumKeys(accnt)){
                this.docNum2Id.put(dockey,accnt.Id);
            }
            for(String npe: getNpeKeys(accnt)){
                this.npe2Id.put(npe, accnt.Id);
            }
            if(accnt.Customer_Number__c != null){
                this.custNum2Id.put(String.valueOf(accnt.Customer_Number__c),accnt.Id);
            }
            if(accnt.Id != null){
                this.id2Account.put(accnt.Id,accnt);
            }
        }
    }

    public Id look(ExternalSystemAccount__c extSysAccount){
        Set<String> accountKeySet = new Set<String>();
        List<String> keyList = new List<String>();
        Id lookupAccountId = null;

        if (String.isNotBlank(extSysAccount.DocumentNumber__c)) {
            keyList = new List<String>();
            keyList.add(String.valueOf(extSysAccount.isPerson__c));
            keyList.add(extSysAccount.DocumentNumber__c);
            lookupAccountId = this.docKey2Id.get(joinKeys(keyList));
            if(lookupAccountId == null ){
                keyList = new List<String>();
                keyList.add(extSysAccount.DocumentNumber__c);
                lookupAccountId = this.docNum2Id.get(joinKeys(keyList));
            }
        }

        if(lookupAccountId == null && String.isNotBlank(extSysAccount.EmailHome__c)){
            Set<String> extSysAccountPhoneSet = new Set<String>();
            extSysAccountPhoneSet.add(extSysAccount.PhoneMobileE164__c);
            extSysAccountPhoneSet.add(extSysAccount.PhoneHomeE164__c);
            extSysAccountPhoneSet.add(extSysAccount.PhoneOfficeE164__c);

            for(String extSysAccountPhone : extSysAccountPhoneSet){
                if(String.isNotBlank(extSysAccountPhone) && (lookupAccountId == null)){
                    keyList = new List<String>();
                    keyList.add(Util.purifyName(extSysAccount.FullName__c));
                    keyList.add(extSysAccountPhone);
                    keyList.add(extSysAccount.EmailHome__c);
                    String key = joinKeys(keyList);
                    if(this.npe2Id.containsKey(key)){
                        lookupAccountId = this.npe2Id.get(key);
                    }
                }
            }
        }

        if(lookupAccountId == null){
            Account missingAccount = prepareAccount(extSysAccount);
            if(missingAccount != null){
                this.addMissingAccount(missingAccount);
            }
        }
        return lookupAccountId;
    }

    public void insertMissingAccounts(){
        List<Account> newAccountList = new List<Account>();
        if(this.missingAccountList.size()>0){
            List<Database.SaveResult> accountInsertResultList = new List<Database.SaveResult>();
            accountInsertResultList = Database.insert(missingAccountList,false);
            for(Database.SaveResult accountInsertResult: accountInsertResultList){
                if(!accountInsertResult.isSuccess()){
                    for(Database.Error dbError: accountInsertResult.getErrors()){
                        ApplicationLogUtility.insertApexErrorLog(this,dbError,ApplicationLogUtility.PRIORITY_HIGH,false);
                    }
                }
            }
        }
        for(Account missingAccount: this.missingAccountList){
            if(missingAccount.Id != null){
                newAccountList.add(missingAccount);
            }
        }
        this.updateMaps(newAccountList, false);
    }

    private void addMissingAccount(Account accnt){
        boolean doAdd = false;
        Set<String> keySet = new Set<String>();
        keySet.addAll(getDocKeys(accnt));
        keySet.addAll(getDocNumKeys(accnt));
        keySet.addAll(getNpeKeys(accnt));

        doAdd = missingAccountKeySet.addAll(keySet) ? true: false;

        if(doAdd = true){
            this.missingAccountList.add(accnt);
        }
    }

    public Account getAccountById(Id accountId){
        return this.id2Account.get(accountId);
    }

    public Id getIdbyCustNum(String custNum){
        return this.custNum2Id.get(custNum);
    }
}