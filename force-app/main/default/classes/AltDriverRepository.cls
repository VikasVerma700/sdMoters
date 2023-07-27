public with sharing class AltDriverRepository {
    public AltDriverRepository() {
        this.vehOwnershipIdSet = new Set<Id>();
        //this.driverAccountCustNumSet = new Set<String>();
        this.vehOwnershipList = new List<Vehicle_Ownership__c>();
        this.accountMap = new AccountLookup();
    }

    public static void reviseAltDrivers(Set<Id> vehicleIdSet){
        AltDriverRepository altDriverRepo = new AltDriverRepository();
        String query = 'SELECT ';
        query += String.join(new List<String>(schema.SObjectType.Vehicle_Ownership__c.fields.getMap().keySet()),',');
        query += ',Vehicle__r.DmsDriverNumber__c';
        query += ' FROM Vehicle_Ownership__c';
        query += ' WHERE Vehicle__c IN :vehicleIdSet';
        altDriverRepo.vehOwnershipList = Database.query(query);
        for(Vehicle_Ownership__c vehOwnership: altDriverRepo.vehOwnershipList){
            altDriverRepo.vehOwnershipIdSet.add(vehOwnership.Id);
        }
        altDriverRepo.initMaps();
        altDriverRepo.upsertAltDrivers();
    }
    
    public List<Vehicle_Ownership__c> vehOwnershipList;
    public Set<Id> vehOwnershipIdSet;
    private Map<Id,Map<String,List<Alternative_Driver__c>>> vehOwnerId2key2AltDriverList;
    // Set<String> driverAccountCustNumSet;
    private AccountLookup accountMap;

    public static String joinKeys(List<String> keyList){
		String key = String.join(keyList,'_').toUpperCase();
		return key;
	}

    public void initMaps(){

        /*
        //query all vehicle ownership records mentioned by Id
        String query = 'SELECT ';
        Set<Id> vehOwnershipIdSetLocal = new Set<Id>(this.vehOwnershipIdSet);
        query += String.join(new List<String>(schema.SObjectType.Case.fields.getMap().keySet()),',');
        query += ',Vehicle__r.DmsDriverNumber__c';
        query += ' FROM Vehicle_Ownership__c';
        query += ' WHERE Id IN :vehOwnershipIdSetLocal';
        this.vehOwnershipList = Database.query(query);
        */
        String query;
        Set<String> driverAccountCustNumSet = new Set<String>();
        //prepare AccountLookup instance based on customer number from vo
        for(Vehicle_Ownership__c vehOwnership: this.vehOwnershipList){
            if(vehOwnership.Vehicle__r.DmsDriverNumber__c != null){
                driverAccountCustNumSet.add(String.valueOf(vehOwnership.Vehicle__r.DmsDriverNumber__c));
            }
        }

        List<ExternalSystemAccount__c> customerEsaList = [
            SELECT Id, CustomerNumber__c, Account__c
            FROM ExternalSystemAccount__c
            WHERE CustomerNumber__c IN :driverAccountCustNumSet
        ];

        Set<Id> custAccountIdSet = new Set<Id>();
        for(ExternalSystemAccount__c esa: [SELECT Account__c FROM ExternalSystemAccount__c WHERE CustomerNumber__c IN :driverAccountCustNumSet]){
            custAccountIdSet.add(esa.Account__c);
        }

        query = 'SELECT ';
        query += String.join(new List<String>(schema.SObjectType.Account.fields.getMap().keySet()),',');
        query += ' FROM Account ';
        //query += 'WHERE Customer_Number__c IN :driverAccountCustNumSet ';
        query += 'WHERE Id IN :custAccountIdSet';

		// [SELECT Account__r.* FROM ExternalSystemAccount__c WHERE Company__r.DmsCompanyCode__c = '' AND CustomerNumber__c IN :driverAccountCustNumSet];
        List<Account> accountList = Database.query(query);
        this.accountMap.updateMaps(accountList, true);

        //prepare a subMap with key(vo's Id  + accountId ) to altDrivers
        //prepare map from vo's Id to above submap
        this.vehOwnerId2key2AltDriverList = new Map<Id,Map<String,List<Alternative_Driver__c>>>();
        List<Alternative_Driver__c> altDriverList = [
            SELECT Id, Name, Vehicle_Ownership__c, Vehicle_Ownership__r.Name,
                Vehicle_Ownership__r.VehicleOwnershipNumber__c, Account__c,
                Account__r.Name, Account__r.Customer_Number__c, Created_From__c,
                Relationship_to_Owner__c, Status__c, UniqueKey__c
            FROM Alternative_Driver__c
            WHERE Vehicle_Ownership__c IN :this.vehOwnershipIdSet
        ];

        for(Alternative_Driver__c altDriver:  altDriverList){
            Map<String,List<Alternative_Driver__c>> key2AltDriverList = this.vehOwnerId2key2AltDriverList.get(altDriver.Vehicle_Ownership__c);
            if(key2AltDriverList == null){
                key2AltDriverList = new Map<String,List<Alternative_Driver__c>>();
            }
            
            List<String> keyList = new List<String>{
                String.valueOf(altDriver.Vehicle_Ownership__c), String.valueOf(altDriver.Account__c)
            };
            String altDriverKey = joinKeys(keyList);


            List<Alternative_Driver__c> altDriverSubList = key2AltDriverList.get(altDriverKey);

            if(altDriverSubList == null){
                altDriverSubList = new List<Alternative_Driver__c>();
            }
            altDriverSubList.add(altDriver);
            key2AltDriverList.put(altDriverKey,altDriverSubList);
            this.vehOwnerId2key2AltDriverList.put(altDriver.Vehicle_Ownership__c,key2AltDriverList);
        }
    }

    public void upsertAltDrivers(){
        List<Alternative_Driver__c> altDriverUpsertList = new List<Alternative_Driver__c>();
        Set<Id> deleteAltDriverIdSet = new Set<Id>();
        
        for(Vehicle_Ownership__c vehOwnership: this.vehOwnershipList){
            Map<String,List<Alternative_Driver__c>> key2AltDriverList = this.vehOwnerId2key2AltDriverList.get(vehOwnership.Id);
            System.debug(key2AltDriverList);
            System.debug(this.vehOwnerId2key2AltDriverList);
            //flag all alt driver from same source
            if(key2AltDriverList != null){
                for(List<Alternative_Driver__c> altDriverList : key2AltDriverList.values()){
                    for(Alternative_Driver__c altDriver: altDriverList){
                        if(altDriver.Created_From__c == vehOwnership.CreatedFrom__c){
                            altDriver.Status__c = 'Removed';
                            altDriverUpsertList.add(altDriver);
                        }
                    }
                }
            }

            Id driverId = this.accountMap.getIdbyCustNum(vehOwnership.Vehicle__r.DmsDriverNumber__c);
            if(driverId != null){
                List<String> keyList = new List<String>();
                keyList.add(String.valueOf(vehOwnership.Id));
                keyList.add(String.valueOf(driverId));
                String altDriverKey = joinKeys(keyList);

                //if alt drivers for same account already exist, delete all of them except one
                if(key2AltDriverList != null && key2AltDriverList.containsKey(altDriverKey)){
                    for(Alternative_Driver__c altDriver: key2AltDriverList.get(altDriverKey)){
                        altDriver.Created_From__c = vehOwnership.CreatedFrom__c;
                        altDriver.Status__c = 'Removed';
                        deleteAltDriverIdSet.add(altDriver.Id);
                    }
                    //add first one so as to only remove duplicates
                    key2AltDriverList.get(altDriverKey)[0].Status__c = vehOwnership.End_Date__c == null? 'Active':'Inactive';
                    deleteAltDriverIdSet.remove(key2AltDriverList.get(altDriverKey)[0].Id);
                }
                //if drivers do not exist currently for this account and it is diff from customer, then create one
                else {
                    if(driverId != vehOwnership.Customer__c){
                        Alternative_Driver__c altDriver = new Alternative_Driver__c();
                        altDriver.Vehicle_Ownership__c = vehOwnership.Id;
                        altDriver.Account__c = driverId;
                        Account driverAccount = this.accountMap.getAccountById(driverId);
                        altDriver.Alternative_Driver_Name__c = driverAccount.Name;
                        altDriver.Alternative_Driver_Contact_Number__c = driverAccount.PersonMobilePhone;
                        if(altDriver.Alternative_Driver_Contact_Number__c == null){
                            //to be discussed
                        }
                        altDriver.Email_Address__c = driverAccount.Default_Email__c;
                        altDriver.Created_From__c = vehOwnership.CreatedFrom__c;
                        altDriver.Status__c = vehOwnership.End_Date__c == null? 'Active':'Inactive';
                        altDriverUpsertList.add(altDriver);
                    }
                }
            }
        }

        List<Alternative_Driver__c> altDriverDelList = [
            SELECT Id
            FROM Alternative_Driver__c
            WHERE Id IN :deleteAltDriverIdSet
        ];
        List<Database.DeleteResult> altDriverDeleteResult = Database.delete(altDriverDelList, false);
        List<Database.UpsertResult> altDriverUpsertResult = Database.upsert(altDriverUpsertList, false);
        ApplicationLogUtility.logUpsertFailure(Util.getClassname(this),altDriverUpsertResult,ApplicationLogUtility.PRIORITY_HIGH, false);


    }
}