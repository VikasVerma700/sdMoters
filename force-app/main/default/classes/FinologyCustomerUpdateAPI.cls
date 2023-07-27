@RestResource(urlMapping='/v1/Finology/CustomerUpdate')
global without sharing class FinologyCustomerUpdateAPI {
    @HttpPost
    global static string customerUpdate(String vehOwnId) {
        String response ;
        try{
            if(!String.isBlank(vehOwnId)) { 
                
                Vehicle_Ownership__c vehOwnershipRec = [Select Id, Name, Registration_No__c, Status__c, Customer__c, Vehicle_Make__c, Vehicle__c from Vehicle_Ownership__c
                                                        where Status__c = 'Active' AND Id =: vehOwnId order by CreatedDate desc LIMIT 1 ];
                
                List<Insurance_Policy__c> existingPolicy = [Select Id, Vehicle_Ownership__c, Vehicle__c from Insurance_Policy__c where Vehicle_Ownership__c =: vehOwnId 
                                                            order by CreatedDate desc LIMIT 1 ];
                
                Insurance_Policy__c newPolicy = new Insurance_Policy__c();
                newPolicy.Policy_Holder__c = vehOwnershipRec.Customer__c;
                newPolicy.Vehicle_Ownership__c = vehOwnershipRec.Id;
                newPolicy.Vehicle__c = vehOwnershipRec.Vehicle__c;
                newPolicy.Vehicle_Make__c = vehOwnershipRec.Vehicle_Make__c;
                if(!existingPolicy.isEmpty()){
                    newPolicy.Previous_Insurance_Policy__c = existingPolicy[0].Id;
                }
                
                if(Insurance_Policy__c.SObjectType.getDescribe().isCreateable() == false && Insurance_Policy__c.SObjectType.getDescribe().isAccessible() == false ) {
                    throw new DmlException('No permissions to insert.');
                }else{
                    insert newPolicy;
                }
                
                Insurance_Transaction__c insTransaction = new Insurance_Transaction__c();
                insTransaction.Insurance_Name_ID__c = newPolicy.Id;
                if(Insurance_Transaction__c.SObjectType.getDescribe().isCreateable() == false && Insurance_Transaction__c.SObjectType.getDescribe().isAccessible() == false ) {
                    throw new DmlException('No permissions to insert.');
                }else{
                    insert insTransaction;
                }
            }
            response = 'Customer Updated Successfully';
            
        }catch(Exception e) {
            System.debug('Exception Error '+e.getCause()+' lineno. '+e.getLineNumber()+' msg '+e.getMessage());
            response = 'Customer Not Updated Successfully';
            FinologyCustomerUpdateAPI updateCust = new FinologyCustomerUpdateAPI();
            ApplicationLogUtility.insertApexErrorLog(updateCust, e, 'Low', False);
            ApplicationLogUtility.insertLogs();
        }     
        
        return  response;
    }   
}