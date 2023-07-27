@IsTest
public without sharing class FinologySalesAgentAPI_Test {
   @isTest 
    public static void testgetSalesAgent() {
        Employee_Master__c empMaster = TestFactory.genEmpMaster(1, true)[0];
        empMaster.Employee_Status_Code__c = 'SC';
        update empMaster;
        
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.addParameter('empNumber', empMaster.Employee_Reference__c);
        RestContext.request.addParameter('empMasterId', empMaster.Id);
        
        Test.startTest();
        FinologySalesAgentAPI.ResponseResult result = FinologySalesAgentAPI.getSalesAgent();
        Test.stopTest();
        
        System.assertEquals(result.msg, 'Success', 'SalesAgent Not NULL');
        Assert.isNotNull(result);
        Assert.areEqual(result.msg, 'Success');
    }
}