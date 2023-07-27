@isTest
public with sharing class ServiceAppointmentResource_Test {
    public static final String PERSON_ACCOUNT = 'personTest';
    public static final String BUSINESS_ACCOUNT = 'businessTest';
    private static CustomerVehicleService.Appointment serviceAppt;
    static{
        serviceAppt = new CustomerVehicleService.Appointment();
        serviceAppt.AppointmentDateTime = Date.today();
        serviceAppt.AppointmentStatus = 'Open';
        serviceAppt.CloseDate = Date.today().addDays(7);
        serviceAppt.CancelledDate = null;
        serviceAppt.CustomerComment = 'test Comment';
        serviceAppt.ServiceType = 'Repair';
        serviceAppt.ContactName = 'test Name';
        serviceAppt.ContactNumber = '6565665656';
        serviceAppt.ContactEmail = 'testusername@testdomain.test';
        serviceAppt.Workshop = 'XY';
        serviceAppt.ChassisNumber = 'TEST1234';
        serviceAppt.CustomerNumber = '12345678';
    }

    @TestSetup
    static void makeData(){
        SQL_API_Base_Test.makeData();
        Company__c C099 = new Company__c(Name = '099', DmsCompanyCode__c = '099');
        insert C099;
        Account accnt = TestFactory.genBusinessAccount(1, false)[0];
        accnt.Name = BUSINESS_ACCOUNT;
        accnt.NRIC_Number__c = null;
        accnt.DocumentNumberAlphaN__c = null;
        insert accnt;

        ExternalSystemAccount__c esa = new ExternalSystemAccount__c(CustomerNumber__c = '12345678', Account__c = accnt.Id);
        insert esa;
    }
    @isTest
    private static void testGdms(){
        ExternalSystem gdmsInternalSystem = new ExternalSystem(CompanyRepository.C099);
        ServiceAppointmentResource serviceApptResource = new ServiceAppointmentResource();
        serviceApptResource.setExternalSystem(gdmsInternalSystem);
        serviceApptResource.appointmentResponseList = new List<CustomerVehicleService.Appointment>{serviceAppt};
        Test.startTest();
        QueueableContext qContext = null;
        serviceApptResource.execute(qContext);
        List<Service_Appointment__c> serviceApptList = [
            SELECT Id, Workshop__c,Appointment_Date_End_Time__c,Appointment_Date__c,Account__c
            FROM Service_Appointment__c
        ];
        Test.stopTest();
        System.debug(serviceApptList);
        System.assertEquals(1,serviceApptList.size());
        System.assert(serviceApptList[0].Account__c != null);
        
    }
    
}