@isTest
public without sharing class DmsAPI_Test {
    public static final String PERSON_ACCOUNT = 'personTest';
    public static final String BUSINESS_ACCOUNT = 'businessTest';
    
    @TestSetup
    static void makeData(){
        SQL_API_Base_Test.makeData();
        Company__c C099 = new Company__c(MobyCompanyCode__c = 'SDBA', Name = CompanyRepository.C099);
        C099.DmsCompanyCode__c = CompanyRepository.C099;
        insert C099;
        
        TestFactory.genTriggerSettings(VehicleTriggerHandler.TRIG_SETTING,true);
        Vehicle_Type__c vehType = new Vehicle_Type__c();
        vehType.Name = 'N';
        vehType.Company__c = C099.Id;
        insert vehType;
        
        Account accnt = TestFactory.genAccount(1, false)[0];
        accnt.LastName = PERSON_ACCOUNT;
        accnt.NRIC_Number__c = '123456';
        accnt.DocumentNumberAlphaN__c = '123456';
        accnt.Mobile_Country_Code_1__pc = null;
        accnt.Mobile_Preferred__pc = null;
        accnt.PersonMobilePhone = null;
        accnt.Customer_Number__c = 101821;
        insert accnt;
        
        TestFactory.genTriggerSettings(ESATriggerHandler.TRIG_SETTING,true);
        ExternalSystemAccount__c customerEsa = new ExternalSystemAccount__c(isPerson__c = true, DocumentNumber__c = '123456');
        customerEsa.CompanyCode__c ='099'; 
        customerEsa.CustomerNumber__c = '101821';
        customerEsa.Account__c = accnt.Id; 
        customerEsa.CustomerType__c = 'I';
        insert customerEsa;
        
    }
    @isTest
    public static void testUpdateAccount(){
        
        RestRequest request = new RestRequest(); 
        RestResponse res = new RestResponse();
        request.requestUri = '/services/apexrest/dms/v1/webhook';
        request.httpMethod = 'POST'; 
        request.requestBody = Blob.valueOf('{"event": "UPDATE_ACCOUNT", "payload": [{"PostCode": "42100", "PIN": "2532", "OfficeEmail": "andrea0999chua@hotmail.com", "MobilePhone": "0126840999", "LastName": "CHUA CHYE HWEE", "DocType": "Instrastat", "DocNum": "840912105999", "CustomerType": "I", "CustomerNo": 102158999, "Cust_Driver": true, "Country": "MALAYSIA", "CompanyCode": "099", "City": "KLANG SELANGOR", "Address2": "TAMAN KLANG UTAMA", "Address": "11 JALAN SUNGAI KERAMAT 12"}]}');
        RestContext.request = request;
        RestContext.response= res;
        
        User user = createUser(
            'batmandarkknightrises@gmail.com',
            'Salesforce API Only System Integrations',
            new List<String> {'GdmsIntegration'},
            new List<String> {'SalesforceAPIIntegrationPsl'}
        );
        Test.startTest();
        System.runAs(user){ 
            DmsAPI.callback();
            res = RestContext.response; 
            DmsAPI.CallbackReqEvent reqBody = (DmsAPI.CallbackReqEvent) JSON.deserialize(res.responseBody.toString(), DmsAPI.CallbackReqEvent.class);
            String actual = JSON.serialize(reqBody);
            String expected = '{"event":"UPDATE_ACCOUNT"}';
            System.assertEquals(actual, expected,'Call In Success');
        }  
        Test.stopTest();
    }
    
    @isTest
    public static void testUpdateVehicle(){
        RestRequest request = new RestRequest(); 
        RestResponse res = new RestResponse();
        request.requestUri = '/services/apexrest/dms/v1/webhook';
        request.httpMethod = 'POST'; 
        request.requestBody = Blob.valueOf('{"event": "UPDATE_VEHICLE","payload": [{"CompanyCode": "099","Workshop": "SA","VehicleType": "N","VehicleID": 0,"ChassisNumber": "LGXCE4CB3P2050198","EngineNumber": "TZ200XSQ2H3001026","Make": "BYD","ModelRange": "BYDA3","ModelRangeDesc": "BYD ATTO 3","Model": "SC2E-2","ModelDesc": "BYD ATTO 3 Extended","Variant": "SC2E-2","VariantDesc": "BYD ATTO 3 Extended","Trims": "1","TrimsDesc": "Black","ColourCode": "WAC","ColourName": "Ski White","EngineCapacity": null,"EngineSize": null,"Fuel": "Electric","Cylinders": null,"BodyType": "P","Transmission": " ","SellingDealerCode": "DQ","SellingDealerName": "Dealer Sales","ProductionYear": 2023,"ProductionMonth": 1,"WarrantyValidity": null,"ExtendedWarrantyValidity": null,"CustomerNo": 101821,"DriverNo": 101821,"RegistrationNumber": "NBW9339","RegistrationDate": "2023-05-05","Validity": "","Mileage": 0,"NextServiceDate": "2023-04-11"}]}');
        RestContext.request = request;
        RestContext.response= res;
        
        User user = createUser(
            'batmandarkknightrises@gmail.com',
            'Salesforce API Only System Integrations',
            new List<String> {'GdmsIntegration'},
            new List<String> {'SalesforceAPIIntegrationPsl'}
        );
        Test.startTest();
        System.runAs(user){ 
            DmsAPI.callback();
            res = RestContext.response; 
            DmsAPI.CallbackReqEvent reqBody = (DmsAPI.CallbackReqEvent) JSON.deserialize(res.responseBody.toString(), DmsAPI.CallbackReqEvent.class);
            String actual = JSON.serialize(reqBody);
            String expected = '{"event":"UPDATE_VEHICLE"}';
            System.assertEquals(actual, expected,'Call In Success');
        }
        test.stopTest();
    }
    @isTest
    public static void testUpdateAppointment(){
        RestRequest request = new RestRequest(); 
        RestResponse res = new RestResponse();
        request.requestUri = '/services/apexrest/dms/v1/webhook';
        request.httpMethod = 'POST'; 
        request.requestBody = Blob.valueOf('{"event": "UPDATE_APPOINTMENT","payload": [{"WorkType": "MEC","Workshop": "SA","ServiceType": "","SA_UserName": "ya302188","SA_EmployeeName": "Chan Zhi Fai","SA_Code": "CZF","RegistrationNumber": "VKM9008","PaymentMethod": "810000 Service Cash Sales Account","OpenDateTime": "2023-06-26T10:15:00.000Z","ModifiedDateTime": "2023-06-26T05:08:00.000Z","ModifiedBy": "YA300938","InMileage": "0","DocumentNumber": "","DeliveryDateTime": null,"CustomerNumber": "101667","CustomerComment": "To carry out 3 months service","ContactNumber": "0122862180","ContactName": "Yinson Mobility Sdn. bhd.","ContactEmail": "jason.devendran@byd.simedarby.com","CloseDate": "2023-06-26","ChassisNumber": "LGXCE4CBXP2010930","CancelledDate": null,"AppointmentStatus": "Close","AppointmentNumber": 200001,"AppointmentDateTime": "2023-06-30T10:15:00.000Z","AppointmentChannel": "5"}]}');
        RestContext.request = request;
        RestContext.response= res;
        User user = createUser(
            'batmandarkknightrises@gmail.com',
            'Salesforce API Only System Integrations',
            new List<String> {'GdmsIntegration'},
            new List<String> {'SalesforceAPIIntegrationPsl'}
        );
        Test.startTest();
        System.runAs(user){ 
            DmsAPI.callback();
            res = RestContext.response; 
            DmsAPI.CallbackReqEvent reqBody = (DmsAPI.CallbackReqEvent) JSON.deserialize(res.responseBody.toString(), DmsAPI.CallbackReqEvent.class);
            String actual = JSON.serialize(reqBody);
            String expected = '{"event":"UPDATE_APPOINTMENT"}';
            System.assertEquals(actual, expected,'Call In Success');
        }
        test.stopTest();
    }
    
    @isTest
    public static void testUpdateEmployeeMaster(){
        RestRequest request = new RestRequest(); 
        RestResponse res = new RestResponse();
        request.requestUri = '/services/apexrest/dms/v1/webhook';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"event": "UPDATE_EMPLOYEE_MASTER","payload": [{"CompanyCode": "099","UserName": "ya302188","FullName": "Chan Zhi Fai","Email": "chan.zhi.fai@byd.simedarby.com","SAPID": "302188","WindowsID": "chan.zhi.fai","DefWorkshop": "SA","DefBranch": "SA","IsActive": true,"QueueRoleCode": "csoSA","AccountsWorkshopAccess": [{"Workshop": "SA","WorkshopDesc": "Ara Workshop"}],"AccountsBranchAccess": [{"Branch": "SA","BranchDesc": "Ara Workshop"}]}]}');
        RestContext.request = request;
        RestContext.response= res;
        
        User user = createUser(
            'batmandarkknightrises@gmail.com',
            'Salesforce API Only System Integrations',
            new List<String> {'GdmsIntegration'},
            new List<String> {'SalesforceAPIIntegrationPsl'}
        );
        Test.startTest();
        System.runAs(user){ 
            DmsAPI.callback();
            res = RestContext.response; 
            DmsAPI.CallbackReqEvent reqBody = (DmsAPI.CallbackReqEvent) JSON.deserialize(res.responseBody.toString(), DmsAPI.CallbackReqEvent.class);
            String actual = JSON.serialize(reqBody);
            String expected = '{"event":"UPDATE_EMPLOYEE_MASTER"}';
            System.assertEquals(actual, expected,'Call In Success');
        }
        test.stopTest();
    }
    
    @isTest
    public static void testException(){
        RestRequest request = new RestRequest(); 
        RestResponse res = new RestResponse();
        request.requestUri = '/services/apexrest/dms/v1/webhook';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"event": "UPDATE_EMPLOYEE_MASTER","payload":[]}');
        RestContext.request = request;
        RestContext.response= res;
        
        User user = createUser(
            'batmandarkknightrises@gmail.com',
            'Salesforce API Only System Integrations',
            new List<String> {'GdmsIntegration'},
            new List<String> {'SalesforceAPIIntegrationPsl'}
        ); 
        Test.startTest();
        System.runAs(user){ 
            DmsAPI.callback();
        }
        test.stopTest();
    }
    
    public static User createUser( String email, String profileName, List<String> permissionSets,List<String> permissionSetLicenses) {
        List<User> usrs = [SELECT Id FROM User WHERE Email = :email];
        User usr;
        if (usrs.isEmpty()) {
            Profile p = [SELECT Id FROM Profile WHERE Name = :profileName];
            usr = new User(
                Alias = 'usr123',
                Email = email,
                EmailEncodingKey = 'UTF-8',
                FirstName = 'Test1',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                Username = email + '.test.qa123'
            );
            
            insert usr;
            
            if (!permissionSetLicenses.isEmpty()) {
                List<PermissionSetLicense> psls = [SELECT Id, DeveloperName FROM PermissionSetLicense WHERE DeveloperName IN :permissionSetLicenses ];
                List<PermissionSetLicenseAssign> pslas = new List<PermissionSetLicenseAssign>(); 
                for (PermissionSetLicense psl : psls) {
                    pslas.add(new PermissionSetLicenseAssign(PermissionSetLicenseId = psl.Id, AssigneeId = usr.Id));
                }
                insert pslas;
            }
            
            if (!permissionSets.isEmpty()) {
                List<PermissionSet> permSets = [SELECT Id FROM PermissionSet WHERE Name IN :permissionSets];
                List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
                for (PermissionSet ps : permSets) {
                    psas.add(new PermissionSetAssignment(PermissionSetId = ps.Id, AssigneeId = usr.Id));
                }
                insert psas;
            } 
        } else {
            usr = usrs[0];
        }
        System.assert(usr != null);
        return usr;
    }
}