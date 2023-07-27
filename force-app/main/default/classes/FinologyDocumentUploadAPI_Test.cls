@IsTest
public with sharing class FinologyDocumentUploadAPI_Test {
    @isTest 
    public static void doUploadDocumentTest01() {
        Vehicle_Ownership__c ownership = TestFactory.genVO(1, false)[0];
        insert ownership;

        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();

        Test.startTest();
        String msg = FinologyDocumentUploadAPI.uploadDocument('This is dummy pdf template', 'Test File', ownership.Id);
        Test.stopTest();
        
        System.assertEquals(msg, 'Document uploaded successfully', 'Test Run Successful');
        Assert.isNotNull(msg);
        Assert.areEqual(msg, 'Document uploaded successfully');
    }
    
    @isTest 
    public static void doUploadDocumentTest02() {
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();

        Test.startTest();
        String msg = FinologyDocumentUploadAPI.uploadDocument('This is dummy pdf template', '', '');
        Test.stopTest();
        
        System.assertEquals(msg, 'Document Not uploaded successfully', 'Test Run Successful');
        Assert.isNotNull(msg);
        Assert.areEqual(msg, 'Document Not uploaded successfully');
    }
}