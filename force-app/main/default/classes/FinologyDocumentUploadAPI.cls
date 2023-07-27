@RestResource(urlMapping='/v1/Finology/DocumentUpload')
global without sharing class FinologyDocumentUploadAPI {
    @HttpPost
    global static string uploadDocument(String document, String docName, String vehOwnId) {
        String response ;
        try{
            Map<String, String> parentRecLinkEntityIdMap = new Map<String, String>();
            
            ContentVersion fileToUpload = new ContentVersion();
            fileToUpload.ContentLocation = 'S'; 
            fileToUpload.pathOnClient = docName+'.pdf';
            fileToUpload.title = docName;
            fileToUpload.versionData = Blob.toPDF(document);
            Database.SaveResult saveResult;
            try {
                if(ContentVersion.SObjectType.getDescribe().isCreateable() == false && ContentVersion.SObjectType.getDescribe().isAccessible() == false ) {
                    throw new DmlException('No permissions to insert.');
                }else{
                    saveResult = Database.insert(fileToUpload);
                }
            } catch (DmlException dmle) {
                system.debug('Failed to insert fileToUpload, error is: ' + dmle.getMessage() );
            }
            
            Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:fileToUpload.Id].ContentDocumentId;
            
            if(!String.isBlank(vehOwnId)){
                parentRecLinkEntityIdMap.put(vehOwnId, contentDocumentId );
                Vehicle_Ownership__c vehOwnershipRec = [Select Id, Name, Registration_No__c, Status__c, Customer__c, Vehicle_Make__c, Vehicle__c from Vehicle_Ownership__c
                                                        where Status__c = 'Active' AND Id =: vehOwnId order by CreatedDate desc LIMIT 1 ];
                if(!String.isBlank(vehOwnershipRec.Customer__c)){
                    parentRecLinkEntityIdMap.put(vehOwnershipRec.Customer__c, contentDocumentId );
                } 
            }
            
            list<ContentDocumentLink> cdlList = new list<ContentDocumentLink>();
            for(String objRecId : parentRecLinkEntityIdMap.keySet()){
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = parentRecLinkEntityIdMap.get(objRecId); 
                cdl.LinkedEntityId = objRecId;
                cdl.ShareType = 'I'; 
                cdl.Visibility = 'AllUsers';
                cdlList.add(cdl);
            }
            
            if(ContentDocumentLink.SObjectType.getDescribe().isCreateable() == false && ContentDocumentLink.SObjectType.getDescribe().isAccessible() == false ) {
                throw new DmlException('No permissions to insert.');
            }else{
                insert cdlList;
            }  
            response = 'Document uploaded successfully';
            
        }catch(Exception e){
            System.debug('Exception Error '+e.getCause()+' lineno. '+e.getLineNumber()+' msg '+e.getMessage());
            response = 'Document Not uploaded successfully';
            FinologyDocumentUploadAPI finologyDoc = new FinologyDocumentUploadAPI();
            ApplicationLogUtility.insertApexErrorLog(finologyDoc, e, 'Low', False);
            ApplicationLogUtility.insertLogs();
        }
        
        return response;
    }
}