public without sharing class FinologyRenewalReminderBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
    public String idfType;
    public String postalCode;
    public Set<Id> successRecordsId = new Set<Id>();
    public Set<Id> errorRecordsId = new Set<Id>();
    public Set<Id> voIdSet = new Set<Id>();
    
    public FinologyRenewalReminderBatch(String idType, String postCode){
        voIdSet = getVehiOwner();
        postalCode = postCode;
        idfType = idType ;
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT ID, Registration_No__c FROM Vehicle_Ownership__c Where Id IN : voIdSet' 
        );
    }
    public void execute(Database.BatchableContext bc, List<Vehicle_Ownership__c> scope){
        System.debug('scope : '+scope);
        try{
            for(Vehicle_Ownership__c vo : scope){
                String retMessage = FinologyVehicleInfo.getVehicleInfo(vo.Registration_No__c, idfType, postalCode, true);
                if(retMessage !=  'error in call API'){
                    successRecordsId.add(vo.id);
                }else{
                    errorRecordsId.add(vo.id);
                }
            } 
            
            if(!FinologyVehicleInfo.vehicleList.IsEmpty()){
                if(Vehicle__c.SObjectType.getDescribe().isCreateable() == false && Vehicle__c.SObjectType.getDescribe().isUpdateable() == false && Insurance_Policy__c.SObjectType.getDescribe().isAccessible() == false ) {
                    throw new DmlException('No permissions to upsert.');
                }else{
                    Database.upsert(FinologyVehicleInfo.vehicleList);
                }
            }
            
            if(!FinologyVehicleInfo.policyList.IsEmpty()){
                if(Insurance_Policy__c.SObjectType.getDescribe().isCreateable() == false && Insurance_Policy__c.SObjectType.getDescribe().isUpdateable() == false && Insurance_Policy__c.SObjectType.getDescribe().isAccessible() == false ) {
                    throw new DmlException('No permissions to upsert.');
                }else{
                    Database.upsert(FinologyVehicleInfo.policyList);
                } 
            }
            
            if(!FinologyVehicleInfo.logList.IsEmpty()){
                if(ApplicationLog__c.SObjectType.getDescribe().isCreateable() == false && ApplicationLog__c.SObjectType.getDescribe().isAccessible() == false ) {
                    throw new DmlException('No permissions to insert.');
                }else{
                    Database.insert(FinologyVehicleInfo.logList);
                }  
            }    
            
            if(!FinologyVehicleInfo.vehOwnerList.IsEmpty()){
                List<Vehicle_Ownership__c> updateVehOwners = new List<Vehicle_Ownership__c>();
                for(Vehicle_Ownership__c owner : FinologyVehicleInfo.vehOwnerList ){
                    owner.End_Date__c = date.today();
                    updateVehOwners.add(owner);
                }
                if(Vehicle_Ownership__c.SObjectType.getDescribe().isUpdateable() == false && Vehicle_Ownership__c.SObjectType.getDescribe().isAccessible() == false ) {
                    throw new DmlException('No permissions to insert.');
                }else{
                    Database.update(updateVehOwners); 
                } 
            }
            
        }catch(Exception e){
            System.debug('Batch Exception Error '+e.getCause()+' line no : '+e.getLineNumber()+' msg '+e.getMessage());
            FinologyRenewalReminderBatch batch = new FinologyRenewalReminderBatch(idfType, postalCode);
            ApplicationLogUtility.insertApexErrorLog(batch, e, 'Low', False);
            ApplicationLogUtility.insertLogs();
        }
        
    }
    
    public void finish(Database.BatchableContext bc){
        System.debug('successRecordsId : '+successRecordsId);
        System.debug('errorRecordsId : '+errorRecordsId);
    }
    
    public static Set<Id> getVehiOwner(){
        Set<Id> voIdSet = new Set<Id>();
        for(Insurance_Policy__c plc : [Select Id, Vehicle_Ownership__c, Policy_Expiry_Date__c from Insurance_Policy__c Where Active__c = true AND Vehicle_Ownership__c != null 
                                       AND Vehicle_Ownership__r.Status__c = 'Active' AND Vehicle_Ownership__r.Customer__r.NRIC_Number__c != null AND Policy_Expiry_Date__c != null ]){ 
                     System.debug('plc : '+plc);                      
            if( ( (date.today().year() - plc.Policy_Expiry_Date__c.year() ) * 12) + ( date.today().month() - plc.Policy_Expiry_Date__c.month() ) <= 2 && plc.Policy_Expiry_Date__c <= date.today() ){
              voIdSet.add(plc.Vehicle_Ownership__c);
            }                                 
        }
        return voIdSet;
    }
    
}