public with sharing class DmsVehicle {
    public static void sendWebhook(DmsCallBack__e callback) {
        try { 
            Vehicle__c vehicle = retrieveVehiDetails( callback.Id__c);
            if (vehicle == null ) { return; }
            CustomerVehicleService.Vehicle payload =  prepareVehicle(vehicle);
            payload.CompanyCode = callback.CompanyCode__c;
            CustomerVehicleService service  = new CustomerVehicleService(callback.CompanyCode__c);
            try{				
                VehicleWebhook hook = new VehicleWebhook(callback.Event__c.toLowercase(), new List<CustomerVehicleService.Vehicle>{ payload } );
                string jsonHook = JSON.serialize(hook, true);
                System.debug('jsonHook : '+jsonHook);
                CustomerVehicleService.UpdateDataResponse resp = service.updateData(jsonHook);
                String response = JSON.serialize(resp);
                System.debug(' resp : '+ response); 
                ApplicationLogUtility.insertCalloutSuccessLog('DmsVehicle', jsonHook, response.unescapeJava(), Request.getCurrent().getRequestId(), false);
            }
            catch(CallOutException callOutError){            
                System.debug( 'callOutError.getMessage() : '+callOutError.getMessage());
                callOutError.setMessage('Error sending '+ String.valueOf(callback.Id__c)+' '+callback.CompanyCode__c + ' '+callOutError.getMessage());
                ApplicationLogUtility.insertCalloutErrorLog(new DmsVehicle(), callOutError, ApplicationLogUtility.PRIORITY_HIGH, false);
            }            
        } catch(Exception e){          
            System.debug('Exception Error '+e.getCause()+' Error msg '+e.getMessage() +' line no. '+e.getLineNumber());
            DmsVehicle vehicle = new DmsVehicle();
            e.setMessage('Exception : '+ String.valueOf(callback.Id__c)+' '+callback.CompanyCode__c +' '+e.getMessage());
            ApplicationLogUtility.insertApexErrorLog('DmsVehicle', e, ApplicationLogUtility.PRIORITY_HIGH, false);
        } 
        ApplicationLogUtility.insertLogs();
    }
    
    public static Vehicle__c retrieveVehiDetails(String vehId){
        String query = 'SELECT '+ String.join(new List<String>(schema.SObjectType.Vehicle__c.fields.getMap().keySet()),',');
        query += ', Vehicle_Make__r.Name, Vehicle_Make__r.Company__c, Vehicle_Model__r.Name, VehicleVariant__r.Name, Vehicle_Trim__r.Name, Vehicle_Colour__r.Name, ';
        query += 'Vehicle_Model__r.Body_Type__c, Vehicle_Model__r.Transmission__c, VehicleVariant__r.Cylinder__c, Vehicle_Make__r.Company__r.DmsCompanyCode__c  ';
        query += 'FROM Vehicle__c WHERE Id =: vehId LIMIT 1';
        return Database.query(String.escapeSingleQuotes(query));
    }
    
    public static CustomerVehicleService.Vehicle prepareVehicle(Vehicle__c vehicle){
        CustomerVehicleService.Vehicle newVehicle = new CustomerVehicleService.Vehicle();
        // newVehicle.companyCode = vehicle.Vehicle_Make__r.Company__r.DmsCompanyCode__c;
        newVehicle.workshop = null ;
        //newVehicle.stockNo = Integer.ValueOf(vehicle.Stock_Number__c);
        newVehicle.units = null;
        newVehicle.EngineNumber = vehicle.Engine_Number__c;
        newVehicle.ChassisNumber = vehicle.Name;
        newVehicle.vehicleType = vehicle.Type__c;
        newVehicle.make = vehicle.Vehicle_Make__r.Name;
        newVehicle.modelRange = vehicle.VehicleModelRange__c;
        newVehicle.modelDesc = vehicle.Vehicle_Model_Description__c;
        newVehicle.model = vehicle.Vehicle_Model__r.Name;
        newVehicle.variant = vehicle.VehicleVariant__r.Name;
        newVehicle.variantDesc = vehicle.VehicleVariantDescription__c;
        newVehicle.trims = vehicle.Vehicle_Trim__r.Name;
        newVehicle.colourCode = null;
        newVehicle.colourName = vehicle.Vehicle_Colour__r.Name;
        newVehicle.engineCapacity = String.valueOf(vehicle.EngineCapacity__c);
        newVehicle.engineSize = null;
        newVehicle.fuel = vehicle.Fuel__c;
        newVehicle.cylinders = vehicle.VehicleVariant__r.Cylinder__c != null ? Integer.valueof(vehicle.VehicleVariant__r.Cylinder__c) : null;
        newVehicle.bodyType = vehicle.Vehicle_Model__r.Body_Type__c;
        newVehicle.transmission = vehicle.Vehicle_Model__r.Transmission__c;
        newVehicle.sellingDealerCode = vehicle.SellingDealerCode__c;
        newVehicle.sellingDealerName = vehicle.SellingDealer__c;
        newVehicle.productionDate = Integer.valueOf(vehicle.Production_Date__c);
        newVehicle.warrantyValidity = vehicle.Warranty_Expiry_Date__c;
        newVehicle.extendedWarrantyValidity = vehicle.Extended_Warranty_Date__c;
        newVehicle.customerNo = vehicle.DmsCustomerNumber__c != null ? Integer.valueOf(vehicle.DmsCustomerNumber__c) : null;
        newVehicle.customerPIN = vehicle.DmsCustomerPin__c;
        newVehicle.customerType = vehicle.DmsCustomerType__c;
        newVehicle.customerName = vehicle.DmsCustomerName__c;
        newVehicle.salutation = null;
        newVehicle.ssn = null;
        newVehicle.driverId = vehicle.DmsDriverNumber__c != null ? Integer.valueOf(vehicle.DmsDriverNumber__c) : null;
        newVehicle.driverPin = vehicle.DmsDriverPin__c;
        newVehicle.registrationNumber = vehicle.Registration_Number__c;
        newVehicle.registrationDate = vehicle.Registration_Date__c;
        newVehicle.validity = null;
        newVehicle.mileage = Integer.valueOf(vehicle.Running_Mileage__c);
        newVehicle.nextServiceDate = null;   
        return newVehicle;  
    }
    
    public class VehicleWebhook {
        public String event;
        public List<CustomerVehicleService.Vehicle> payload;
        public VehicleWebhook(String event, List<CustomerVehicleService.Vehicle> loadList) {
            this.event = event;
            this.payload = loadList;
        }
    }
    
    public static CallbackVehicleResp checkExistingVehicle(List<CustomerVehicleService.Vehicle> payloadList) {
        DmsVehicle vehicle = new DmsVehicle();
        List<Database.UpsertResult> resultList = VehicleResource.prepareVehicle(payloadList);
        if(resultList.isEmpty()){return null;}
        Map<Id, String> vehicleRecIdMap = new Map<Id, String>();
        for(Database.UpsertResult sr : resultList) {
            if(!sr.isSuccess()) {
                String error;
                for(Database.Error dbError: sr.getErrors()) {
                    error += dbError; 
                }
                vehicleRecIdMap.put(sr.getId(), error);
            }else{
                vehicleRecIdMap.put(sr.getId(), 'Success');
            }
        }
        
        List<Details> detailsList = new List<Details>();
        if(vehicleRecIdMap.containsKey(null)){
            Details detail = new Details('','', 'Error in Vehicle Upsert : '+vehicleRecIdMap.get(null));
            detailsList.add(detail);
            return new CallbackVehicleResp('UPDATE_VEHICLE', detailsList);
        }
        
        Set<Id> custIdSet = new Set<Id>();
        List<ExternalSystemAccount__c> esaAccListToUpdate = new List<ExternalSystemAccount__c>();
        List<ExternalSystemAccount__c> esaAccListToInsert = new List<ExternalSystemAccount__c>();
        
        if(!vehicleRecIdMap.isEmpty()) {
            for(Vehicle__c veh : [Select Id, Name, CreatedDate, LastModifiedDate, Vehicle_Make__r.Company__r.DmsCompanyCode__c, (Select Id, Name, Customer__c from Vehicle_Ownerships1__r Where Status__c = 'Active' Order By CreatedDate Desc LIMIT 1) FROM Vehicle__c WHERE Id IN : vehicleRecIdMap.keySet()]) {
                if(veh.Vehicle_Ownerships1__r.size() > 0){
                    if(String.isBlank(veh.Vehicle_Ownerships1__r[0].Customer__c)){
                        detailsList.add( new Details(veh.Id, '', 'This Vehicle is not associated with any Account '));
                        continue;
                    }else{
                        custIdSet.add(veh.Vehicle_Ownerships1__r[0].Customer__c); 
                    }
                    
                    if(vehicleRecIdMap.containsKey(veh.Id)){
                        if(vehicleRecIdMap.get(veh.Id) == 'Success'){
                            String message = date.newinstance(veh.LastModifiedDate.year(), veh.LastModifiedDate.month(), veh.LastModifiedDate.day()) == date.newinstance(veh.CreatedDate.year(), veh.CreatedDate.month(), veh.CreatedDate.day()) && veh.CreatedDate.format('HH:mm') == veh.LastModifiedDate.format('HH:mm') ? 'Inserted' : 'Updated';
                            detailsList.add( new Details(veh.Id, veh.Vehicle_Ownerships1__r[0].Id, 'Vehicle Successfully '+message));
                        }else{
                            detailsList.add( new Details(veh.Id, veh.Vehicle_Ownerships1__r[0].Id, vehicleRecIdMap.get(veh.Id)));
                        }
                    }
                } else{
                    detailsList.add( new Details(veh.Id, '', 'This Vehicle is not associated with any VO '));
                }     
            }
        }
        
        
        String payloadCmpCode = payloadList[0].CompanyCode;
        String relatedCompanyCode = CompanyRepository.getRelatedCompanyCode(payloadCmpCode);
        String source = (CompanyRepository.NAME_TO_EXTERNAL_SYSTEM.get(relatedCompanyCode)).name();
        
        String extQuery = 'SELECT ';
        extQuery += String.join(new List<String>(schema.SObjectType.ExternalSystemAccount__c.fields.getMap().keySet()),',');
        extQuery += ' FROM ExternalSystemAccount__c WHERE Account__c IN :custIdSet AND CompanyCode__c =: payloadCmpCode Order by CreatedDate Desc LIMIT 1';
        List<ExternalSystemAccount__c> extAccountList = Database.query(String.escapeSingleQuotes(extQuery));
        
        Map<Id, ExternalSystemAccount__c> accountIdWithExistEsaAccountMap = new Map<Id, ExternalSystemAccount__c>();
        if(!extAccountList.isEmpty()){
            for(ExternalSystemAccount__c esa  : extAccountList){
                if(!accountIdWithExistEsaAccountMap.containsKey(esa.Account__c)){
                    accountIdWithExistEsaAccountMap.put(esa.Account__c, esa);
                }
            }
        }
        
        String query = 'SELECT ';
        query += String.join(new List<String>(schema.SObjectType.Account.fields.getMap().keySet()),',');
        query += ', ( SELECT '+String.join(new List<String>(schema.SObjectType.ExternalSystemAccount__c.fields.getMap().keySet()),','); 
        query += ' FROM ExternalSystemAccounts__r WHERE CompanyCode__c =:relatedCompanyCode )';
        query += ' FROM Account ';
        query += 'WHERE Id IN :custIdSet';
        List<Account> accountList = Database.query(String.escapeSingleQuotes(query));
        
        Map<Id, Account> idWithAccountMap = new Map<Id, Account>();
        List<ExternalSystemAccount__c>  existEsaAccountList = new List<ExternalSystemAccount__c> ();
        
        if(!accountList.isEmpty()) {
            for(Account account : accountList) {
                if(account.ExternalSystemAccounts__r.size() > 0) {
                    existEsaAccountList.add(account.ExternalSystemAccounts__r);  
                }
                if(!idWithAccountMap.containsKey(account.Id)){
                    idWithAccountMap.put(account.Id, account);
                }    
            }
        }
        
        if(!existEsaAccountList.isEmpty()){
            for(ExternalSystemAccount__c extAcc : existEsaAccountList){
                if(accountIdWithExistEsaAccountMap.containsKey(extAcc.Account__c)){
                    esaAccListToUpdate.add( cloningExistEsaWithPayloadCmpCodeToEsa(extAcc, accountIdWithExistEsaAccountMap.get(extAcc.Account__c), source, relatedCompanyCode ) );
                }else{
                    if(idWithAccountMap.containsKey(extAcc.Account__c)){
                        esaAccListToUpdate.add( prepareAccountToEsa(extAcc, idWithAccountMap.get(extAcc.Account__c), source, relatedCompanyCode ) );
                    }
                }
            }
        }else{
            for(Account account : accountList) {
                if(accountIdWithExistEsaAccountMap.containsKey(account.Id)){
                    esaAccListToInsert.add( cloningExistEsaWithPayloadCmpCodeToEsa(new ExternalSystemAccount__c(), accountIdWithExistEsaAccountMap.get(account.Id), source, relatedCompanyCode ) );
                }else{
                    if(idWithAccountMap.containsKey(account.Id)){
                        esaAccListToInsert.add( prepareAccountToEsa(new ExternalSystemAccount__c(), idWithAccountMap.get(account.Id), source, relatedCompanyCode ) );
                    }
                }
            }
        }
        
        
        
        
        
        /* if(!accountList.isEmpty()) {
for(Account account : accountList) {
if(accountWithEsaAccount.containsKey(account.Id)){
if(account.ExternalSystemAccounts__r.size() > 0) {
for(ExternalSystemAccount__c extAcc : account.ExternalSystemAccounts__r){
esaAccListToUpdate.add(cloningExistEsaWithPayloadCmpCodeToEsa(extAcc, accountWithEsaAccount.get(account.Id), source, relatedCompanyCode ));
}      
}else{
esaAccListToInsert.add(cloningExistEsaWithPayloadCmpCodeToEsa(new ExternalSystemAccount__c(), accountWithEsaAccount.get(account.Id) , source, relatedCompanyCode ));
}

}else{
if(account.ExternalSystemAccounts__r.size() > 0) {
for(ExternalSystemAccount__c extAcc : account.ExternalSystemAccounts__r){
esaAccListToUpdate.add(prepareAccountToEsa(extAcc, account, source, relatedCompanyCode ));
}      
}else{
esaAccListToInsert.add(prepareAccountToEsa(new ExternalSystemAccount__c(), account , source, relatedCompanyCode ));
}
} 
}
} */
        
        if(!esaAccListToInsert.isEmpty()){
            Database.SaveResult[] esaAccountInsertList = Database.insert(esaAccListToInsert, false);
            for(Database.SaveResult sr : esaAccountInsertList) {
                if(!sr.isSuccess()){
                    for(Database.Error dbError: sr.getErrors()) {
                        ApplicationLogUtility.insertApexErrorLog(vehicle, dbError, ApplicationLogUtility.PRIORITY_HIGH, false);
                    }
                }
            }
        }
        
        if(!esaAccListToUpdate.isEmpty()){
            Database.SaveResult[] esaAccountUpdateList = Database.Update(esaAccListToUpdate, false);
            for(Database.SaveResult sr : esaAccountUpdateList) {
                if(!sr.isSuccess()){
                    for(Database.Error dbError: sr.getErrors()) {
                        ApplicationLogUtility.insertApexErrorLog(vehicle, dbError, ApplicationLogUtility.PRIORITY_HIGH, false);
                    }
                }
            }
        }
        ApplicationLogUtility.insertLogs();
        return new CallbackVehicleResp('UPDATE_VEHICLE', detailsList);
    }
    
    public static ExternalSystemAccount__c cloningExistEsaWithPayloadCmpCodeToEsa(ExternalSystemAccount__c newEsaAcc, ExternalSystemAccount__c existEsaAccount, String source, String cmp) {
        ExternalSystemAccount__c esaAcc = newEsaAcc;
        esaAcc.Salutation__c =  existEsaAccount.Salutation__c;
        esaAcc.FirstName__c = existEsaAccount.FirstName__c;
        esaAcc.LastName__c = existEsaAccount.LastName__c;
        esaAcc.PreferredName__c = existEsaAccount.PreferredName__c;
        esaAcc.CompanyName__c = existEsaAccount.CompanyName__c;
        esaAcc.DocumentType__c = existEsaAccount.DocumentType__c;
        esaAcc.DrivingLicenseExpiry__c = existEsaAccount.DrivingLicenseExpiry__c;
        esaAcc.isPerson__c = existEsaAccount.isPerson__c;
        esaAcc.CustomerType__c = existEsaAccount.CustomerType__c;
        esaAcc.PhoneMobile__c = existEsaAccount.PhoneMobile__c;
        esaAcc.PhoneHome__c = existEsaAccount.PhoneHome__c;
        esaAcc.EmailHome__c = existEsaAccount.EmailHome__c;
        esaAcc.Postcode__c = existEsaAccount.Postcode__c;
        esaAcc.City__c = existEsaAccount.City__c ;
        esaAcc.State__c = existEsaAccount.State__c ;
        esaAcc.Country__c = existEsaAccount.Country__c;
        esaAcc.Address1__c =  existEsaAccount.Address1__c;
        esaAcc.Address2__c = existEsaAccount.Address2__c;
        esaAcc.FullName__c = existEsaAccount.FullName__c;
        esaAcc.PhoneOffice__c = existEsaAccount.PhoneOffice__c;  
        esaAcc.Birthdate__c = existEsaAccount.Birthdate__c;
        esaAcc.DocumentNumber__c = existEsaAccount.DocumentNumber__c;
        esaAcc.EmailOffice__c = existEsaAccount.EmailOffice__c;
        esaAcc.EmailOther__c = existEsaAccount.EmailOther__c;
      //  esaAcc.CustomerNumber__c = existEsaAccount.CustomerNumber__c != null ? existEsaAccount.CustomerNumber__c : '0';
        esaAcc.Account__c = existEsaAccount.Account__c;
        esaAcc.SourceBy__c = source;
        esaAcc.Source__c = source;
        esaAcc.CompanyCode__c = cmp;
        
        if(cmp != null && existEsaAccount.CustomerNumber__c != null && existEsaAccount.CustomerNumber__c != '0'){
            String uniqueKey = cmp + '_';
            uniqueKey += String.valueOf(existEsaAccount.CustomerNumber__c);
            esaAcc.UniqueKey__c = uniqueKey; 
        }  
        return esaAcc;
        
    }
    
    public static ExternalSystemAccount__c prepareAccountToEsa(ExternalSystemAccount__c extAcc, Account account, String source, String cmp) {
        String recordTypeDevName = Schema.SObjectType.Account.getRecordTypeInfosById().get(account.RecordTypeId).getDeveloperName();
        ExternalSystemAccount__c extSysAccount = extAcc;
        if( recordTypeDevName == 'PersonAccount'){
            extSysAccount.Salutation__c = account.Salutation;
            extSysAccount.FirstName__c = account.FirstName;
            extSysAccount.LastName__c = account.LastName;
            extSysAccount.PreferredName__c = account.Prefer_Name__pc;
            extSysAccount.CompanyName__c = account.CompanyName__pc;
            if(extSysAccount == null){
                extSysAccount.DocumentType__c = 'Malaysian NRIC';
            }
            extSysAccount.DrivingLicenseExpiry__c = String.valueOf(account.LicenseExpiryDate__pc);
            extSysAccount.isPerson__c = true;
            extSysAccount.CustomerType__c ='I';
            extSysAccount.PhoneMobile__c = account.PersonMobilePhone;
            extSysAccount.PhoneHome__c = account.PersonHomePhone;
            extSysAccount.EmailHome__c = account.Home_Email__c;
            extSysAccount.Postcode__c = account.PersonMailingPostalCode;
            extSysAccount.City__c = account.PersonMailingCity ;
            extSysAccount.State__c = account.PersonMailingState ;
            extSysAccount.Country__c = account.PersonMailingCountry;
            if(account.PersonMailingStreet != null){
                List<String> res = account.PersonMailingStreet.split(',', 2);
                if(res.size() == 2){
                    extSysAccount.Address1__c = res[0] != null ? res[0] : account.PersonMailingStreet;
                    extSysAccount.Address2__c = res[1] != null ? res[1] : res[0] != null ? res[0] : account.PersonMailingStreet;
                }
                if(res.size() == 1){
                    extSysAccount.Address1__c = account.PersonMailingStreet;
                }  
            }
        }else{
            extSysAccount.FullName__c = account.Name;
            if(extSysAccount == null){
                extSysAccount.DocumentType__c = 'Company Reg No.';
            }
            extSysAccount.isPerson__c = false;
            extSysAccount.CustomerType__c ='C';
            extSysAccount.PhoneOffice__c = account.Phone;  
            extSysAccount.City__c = account.BillingCity ;
            extSysAccount.State__c = account.BillingState ;
            extSysAccount.Postcode__c = account.BillingPostalCode;
            extSysAccount.Country__c = account.BillingCountry;
            if(account.BillingStreet != null){
                List<String> res = account.BillingStreet.split(',', 2);
                if(res.size() == 2){
                    extSysAccount.Address1__c = res[0] != null ? res[0] : account.BillingStreet;
                    extSysAccount.Address2__c = res[1] != null ? res[1] : res[0] != null ? res[0] : account.BillingStreet;
                }
                if(res.size() == 1){
                    extSysAccount.Address1__c = account.BillingStreet;
                } 
            }
        }
        extSysAccount.Birthdate__c = String.valueOf(account.PersonBirthdate);
        extSysAccount.DocumentNumber__c = account.NRIC_Number__c != null ? account.NRIC_Number__c : account.DocumentNumberAlphaN__c;
        extSysAccount.EmailOffice__c = account.Office_Email__c;
        extSysAccount.EmailOther__c = account.Other_Email__c;
        extSysAccount.CustomerNumber__c = account.Customer_Number__c != null ? String.valueOf(account.Customer_Number__c) : '0';
        extSysAccount.Account__c = extSysAccount.Account__c == null ? account.Id : extSysAccount.Account__c;
        extSysAccount.SourceBy__c = source;
        extSysAccount.Source__c = source;
        extSysAccount.CompanyCode__c = cmp;
        if(cmp != null && account.Customer_Number__c != null && account.Customer_Number__c != 0){
            String uniqueKey = cmp + '_';
            uniqueKey += String.valueOf(account.Customer_Number__c);
            extSysAccount.UniqueKey__c = uniqueKey; 
        }  
        return extSysAccount;
    } 
    
    public class CallbackVehicleResp {
        public String event;
        public List<Details> details;
        public CallbackVehicleResp(String evt, List<Details> detList) {
            this.event = evt;
            this.details = detList;
        }
    }
    
    public class Details {
        public String vehicleId;
        public String vehicleOwnershipId;
        public String message;
        public Details(String vehId, String vehoId, String msg) {
            this.vehicleId = vehId;
            this.vehicleOwnershipId = vehoId;
            this.message = msg;
        }
    }
    
}