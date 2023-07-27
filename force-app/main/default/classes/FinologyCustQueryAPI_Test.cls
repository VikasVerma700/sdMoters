@IsTest
public without sharing class FinologyCustQueryAPI_Test {
    @isTest 
    public static void testGetCustomerQuery() {
        Vehicle_Ownership__c ownership = TestFactory.genVO(1, false)[0];
        insert ownership;
        
        Insurance_Policy__c policy = TestFactory.genInsurancePolicy(1, false)[0];
        policy.Vehicle_Ownership__c = ownership.Id;
        insert policy;
        
        Account acc =[Select id, NRIC_Number__c from Account where Id =:ownership.Customer__c];
        Vehicle__c vehicle =[Select id, Name from Vehicle__c where Id =:ownership.Vehicle__c];

        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.addParameter('regisNo', ownership.Registration_No__c);
        RestContext.request.addParameter('docuNo', acc.NRIC_Number__c);
        RestContext.request.addParameter('chassisNo', vehicle.Name);
        
        Test.startTest();
        FinologyCustQueryAPI.ResponseResult result = FinologyCustQueryAPI.getCustomerQuery();
        Test.stopTest();
        
        System.assertEquals(result.msg, 'Success', 'Vehicle Registration Not NULL');
        Assert.isNotNull(result);
        Assert.areEqual(result.msg, 'Success');
    }
}