@IsTest
public without sharing class DmsCallbackTrigger_Test {
    @TestSetup
    public static void setup() {
        TestFactory.genTriggerSettings('External System Account', true);
        TestFactory.genTriggerSettings('Vehicle', true);
        TestFactory.genTriggerSettings('Service Appointment', true);
        TestFactory.genTriggerSettings('Vehicle Ownership', true);
        
        Company__c company = TestFactory.genCompany(1, false)[0];
        company.Name = '099';
        company.DmsCompanyCode__c = '099';
        insert company;
        
        Vehicle_Make__c make = TestFactory.genVehMake('BYD', false);
        make.Company__c = company.Id;
        insert make;
        
        Vehicle__c vehicle = TestFactory.genVehicle(1, false)[0];
        vehicle.Company__c = company.Id;
        vehicle.Vehicle_Make__c = make.Id;
        vehicle.DmsDriverNumber__c = '7852152';
        insert vehicle;
    }
    @IsTest
    public static void testDmsEsaAccount() {
        Account account = TestFactory.genAccount(1, true)[0];
        ExternalSystemAccount__c esa = new ExternalSystemAccount__c(CompanyCode__c = '099', CustomerNumber__c = '12345');
        esa.Account__c = account.Id;
        insert esa;
        test.startTest();
        esa.EmailHome__c = 'testgdms10@gmail.com';
        update esa;
        Test.setMock(WebServiceMock.class, new AccountWebServiceMockImpl());
        test.stopTest();
    } 
    @IsTest
    public static void testDmsVehicle() {
        Vehicle__c vehicle =[Select Id from Vehicle__c limit 1];
        test.startTest();
        vehicle.Road_Tax_Expiry_Date__c =  Date.today().addDays(-1);
        update vehicle;
        Test.setMock(WebServiceMock.class, new VehicleWebServiceMockImpl());
        test.stopTest();
        
    }
    @IsTest
    public static void testDmsVehicleOwnership() {
        Vehicle__c vehicle =[Select Id from Vehicle__c limit 1];
        Vehicle_Ownership__c owner = TestFactory.genVO(1, false)[0];
        owner.Vehicle__c = vehicle.Id;
        insert owner;
        test.startTest();
        owner.Start_Date__c = Date.today().addDays(-1);
        update owner;
        Test.setMock(WebServiceMock.class, new WebServiceMockImpl());
        test.stopTest();
    } 
    @IsTest
    public static void testDmsServiceAppointment(){
        Vehicle__c vehicle =[Select Id, Company__c from Vehicle__c limit 1];
        Account account = TestFactory.genAccount(1, true)[0];
        ExternalSystemAccount__c esa = new ExternalSystemAccount__c(CompanyCode__c = '099', CustomerNumber__c = '12345');
        esa.Account__c = account.Id;
        insert esa;
        
        Service_Appointment__c appoint = TestFactory.genSvcAppt(1, false)[0]; 
        appoint.Company__c = vehicle.Company__c;
        appoint.Account__c = account.Id;
        insert appoint; 
        
        test.startTest();
        appoint.Customer_Comment__c = appoint.Customer_Comment__c +' testing';
        appoint.Apppointment_Status__c = 'CANCELLED';
        update appoint;
        
        Test.setMock(WebServiceMock.class, new WebServiceMockImpl());
        test.stopTest(); 
        
    }
    
    @IsTest
    public static void generateEventsTest(){
        Vehicle__c vehicle =[Select Id, Company__r.DmsCompanyCode__c from Vehicle__c limit 1];
        DmsCallbackQueue.EventType evtType = DmsCallbackQueue.EventType.VEHICLE;
        test.startTest();
        DmsCallbackQueue.generateEvents(new List<Id>{vehicle.Id}, evtType, vehicle.Company__r.DmsCompanyCode__c);
        test.stopTest();
    }
    
    public class AccountWebServiceMockImpl implements WebServiceMock {
        public void doInvoke(
            Object stub,
            Object request,
            Map<String, Object> response,
            String endpoint,
            String soapAction,
            String requestName,
            String responseNS,
            String responseName,
            String responseType) {
                CustomerVehicleService.UpdateDataResponse respElement = new CustomerVehicleService.UpdateDataResponse();
                respElement.result = '';
                respElement.ip_json = '{"payload":[{"State":"Malaysia","PostCode":"49180","OfficeEmail":"ytlmm@yahoo.com","MobilePhone":"0136367373","LastName":"Datawise Consultant Sdn. Bhd.","DocType":"Instrastat","DocNum":"1139459T","CustomerType":"C","CustomerNo":101026,"Cust_Driver":false,"Country":"MY","CompanyCode":"199","City":"Puchong, Selangor","Address2":"Bandar Kinrara,","Address":"17 Jalan BK6 B/5,","esaId":"a1J0p000001cpMdEAI","accountId":"0010p00001IkaSDAAZ"}],"event":"account"}';
                response.put('response_x', respElement);  
            }
    }
    
    public class VehicleWebServiceMockImpl implements WebServiceMock {
        public void doInvoke(
            Object stub,
            Object request,
            Map<String, Object> response,
            String endpoint,
            String soapAction,
            String requestName,
            String responseNS,
            String responseName,
            String responseType) {
                CustomerVehicleService.UpdateDataResponse respElement = new CustomerVehicleService.UpdateDataResponse();
                respElement.result = '';
                respElement.ip_json = '{"payload":[{"VehicleType":"N","VariantDesc":"BYD ATTO 3 Extended","Variant":"SC2E-2","Trims":"1","Transmission":"Automatic","SellingDealerName":"TREC Sales","SellingDealerCode":"VT","RegistrationNumber":"BHX222","RegistrationDate":"2023-02-28","ModelRange":"BYD ATTO 3","ModelDesc":"BYD ATTO 3","Model":"BYDA3","Mileage":0,"Make":"byd","Fuel":"Electric","EngineNumber":"TZ200XSQ 2G2050712","CustomerNo":101026,"CompanyCode":"199","ColourName":"WAC","ChassisNumber":"LGXCE4CB7P2010061"}],"event":"vehicle"}';
                response.put('response_x', respElement);  
            }
    }
    
    public class AppointmentWebServiceMockImpl implements WebServiceMock {
        public void doInvoke(
            Object stub,
            Object request,
            Map<String, Object> response,
            String endpoint,
            String soapAction,
            String requestName,
            String responseNS,
            String responseName,
            String responseType) {
                CustomerVehicleService.UpdateDataResponse respElement = new CustomerVehicleService.UpdateDataResponse();
                respElement.result = '';
                respElement.ip_json = 'Mock response';
                response.put('response_x', respElement);  
            }
    }
    
    public class WebServiceMockImpl implements WebServiceMock {
        public void doInvoke(
            Object stub,
            Object request,
            Map<String, Object> response,
            String endpoint,
            String soapAction,
            String requestName,
            String responseNS,
            String responseName,
            String responseType) {
                CustomerVehicleService.UpdateDataResponse respElement = new CustomerVehicleService.UpdateDataResponse();
                respElement.result = '';
                respElement.ip_json = '{"payload":[{"State":"Malaysia","PostCode":"49180","OfficeEmail":"ytlmm@yahoo.com","MobilePhone":"0136367373","LastName":"Datawise Consultant Sdn. Bhd.","DocType":"Instrastat","DocNum":"1139459T","CustomerType":"C","CustomerNo":101026,"Cust_Driver":false,"Country":"MY","CompanyCode":"199","City":"Puchong, Selangor","Address2":"Bandar Kinrara,","Address":"17 Jalan BK6 B/5,","esaId":"a1J0p000001cpMdEAI","accountId":"0010p00001IkaSDAAZ"}],"event":"account"}';
                response.put('response_x', respElement);  
            }
    }
}