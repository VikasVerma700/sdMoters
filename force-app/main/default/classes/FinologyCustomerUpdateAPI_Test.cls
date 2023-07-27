@isTest
public without sharing class FinologyCustomerUpdateAPI_Test {
    @isTest 
    public static void customerUpdateTest1() {
        Vehicle_Ownership__c ownership = TestFactory.genVO(1, false)[0];
        insert ownership;

        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
      
        Test.startTest();
        String msg = FinologyCustomerUpdateAPI.customerUpdate(ownership.Id);
        Test.stopTest();
        
        System.assertEquals(msg, 'Customer Updated Successfully', 'Test Run Successful');
        Assert.isNotNull(msg);
        Assert.areEqual(msg, 'Customer Updated Successfully');
    }
    
     @isTest 
    public static void customerUpdateTest2() {
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();

        Test.startTest();
        String msg = FinologyCustomerUpdateAPI.customerUpdate('8485451');
        Test.stopTest();
        
        System.assertEquals(msg, 'Customer Not Updated Successfully', 'Test Run Successful');
        Assert.isNotNull(msg);
        Assert.areEqual(msg, 'Customer Not Updated Successfully');
    }
}