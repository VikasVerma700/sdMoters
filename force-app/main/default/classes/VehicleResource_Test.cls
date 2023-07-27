@isTest
public with sharing class VehicleResource_Test {
    public static final String PERSON_ACCOUNT = 'personTest';
    public static final String BUSINESS_ACCOUNT = 'businessTest';

    static CustomerVehicleService.Vehicle vehicleResponse = new CustomerVehicleService.Vehicle();
    static{
        vehicleResponse.CompanyCode = CompanyRepository.C099;
        vehicleResponse.Workshop = 'SA';
        vehicleResponse.VehicleType = 'nc';
        vehicleResponse.StockNo = 146;
        vehicleResponse.Units = 511;
        vehicleResponse.VIN = 'LGXCE4CB2N2130492';
        vehicleResponse.EngineNumber = 'TZ200XSQ 2G2023415';
        vehicleResponse.Make = 'byd';
        vehicleResponse.ModelRange = 'BYDA3';
        vehicleResponse.Model = 'SC2E-2';
        vehicleResponse.Variant = 'SC2E-2';
        vehicleResponse.VariantDesc = 'BYD ATTO 3 Extended';
        vehicleResponse.Trims = '1';
        vehicleResponse.ColourCode = 'RA5';
        vehicleResponse.ColourName = 'Parkour Red';
        vehicleResponse.EngineCapacity = null;
        vehicleResponse.EngineSize = null;
        vehicleResponse.Fuel = 'Electric';
        vehicleResponse.Cylinders = null;
        vehicleResponse.BodyType = 'P';
        vehicleResponse.Transmission = null;
        vehicleResponse.SellingDealerCode = 'VA';
        vehicleResponse.ProductionDate = 202210;
        vehicleResponse.WarrantyValidity = null;
        vehicleResponse.ExtendedWarrantyValidity = null;
        vehicleResponse.CustomerNo = 100077;
        vehicleResponse.CustomerPIN = '86';
        vehicleResponse.CustomerType = null;
        vehicleResponse.CustomerName = 'Ngan Hong Yean';
        vehicleResponse.Salutation = null;
        vehicleResponse.SSN = '840825-14-6111';
        vehicleResponse.DriverID = 100078;
        vehicleResponse.DriverPIN = '86';
        vehicleResponse.RegistrationNumber = 'PQP8873';
        vehicleResponse.RegistrationDate = Date.newInstance(2022, 12, 30);
        vehicleResponse.Validity = null;
        vehicleResponse.Stat_x = 'Invoiced';
        vehicleResponse.Mileage = 0;
        vehicleResponse.NextServiceDate = Date.newInstance(2022, 12, 30);
        vehicleResponse.LastUpdate = Datetime.newInstance(2023, 02, 09, 13, 10, 10);
    }

    @TestSetup
    public static void makeData(){
        SQL_API_Base_Test.makeData();
        Account accnt = TestFactory.genAccount(1, false)[0];
        accnt.LastName = PERSON_ACCOUNT;
        accnt.NRIC_Number__c = 'x';
        accnt.DocumentNumberAlphaN__c = 'x';
        accnt.Mobile_Country_Code_1__pc = null;
        accnt.Mobile_Preferred__pc = null;
        accnt.PersonMobilePhone = null;
        accnt.Customer_Number__c = 100077;
        insert accnt;

        Account driverAccount = TestFactory.genAccount(1, false)[0];
        driverAccount.LastName = PERSON_ACCOUNT;
        driverAccount.NRIC_Number__c = null;
        driverAccount.DocumentNumberAlphaN__c = null;
        driverAccount.Mobile_Country_Code_1__pc = null;
        driverAccount.Mobile_Preferred__pc = null;
        driverAccount.PersonMobilePhone = null;
        driverAccount.Customer_Number__c = 100078;
        insert driverAccount;

        TestFactory.genTriggerSettings(ESATriggerHandler.TRIG_SETTING,true);
        ExternalSystemAccount__c customerEsa = new ExternalSystemAccount__c(isPerson__c = true, DocumentNumber__c = 'x');
        insert customerEsa;
        System.debug(customerEsa.Account__c);
        System.debug(accnt.Id);
        

        accnt = TestFactory.genBusinessAccount(1, false)[0];
        accnt.Name = BUSINESS_ACCOUNT;
        accnt.NRIC_Number__c = null;
        accnt.DocumentNumberAlphaN__c = null;
        insert accnt;

        Company__c C099 = new Company__c(MobyCompanyCode__c = 'SDBA', Name = CompanyRepository.C099);
        C099.DmsCompanyCode__c = CompanyRepository.C099;
        insert C099;
        Company__c C028 = new Company__c(MobyCompanyCode__c = 'SDBA', Name = CompanyRepository.C028);
        C028.DmsCompanyCode__c = CompanyRepository.C028;
        insert C028;
        TestFactory.genTriggerSettings(VehicleTriggerHandler.TRIG_SETTING,true);
        TestFactory.genTriggerSettings(ApplicationLogTriggerHandler.TRIG_SETTING,true);
        Vehicle_Type__c vehType = new Vehicle_Type__c();
        vehType.Name = 'N';
        vehType.Company__c = C099.Id;
        insert vehType;
    }

    @isTest
    static void testVehicleGeneration(){
        ExternalSystem gdmsInternal = new ExternalSystem(CompanyRepository.C099);
        VehicleResource vehResource = new VehicleResource();
        vehResource.setExternalSystem(gdmsInternal);
        vehResource.dateFrom = Date.newInstance(1900, 01, 01);
        vehResource.dateTo = Date.today();
        vehResource.followOn = false;
        vehResource.gdmsVehicleList = new List<CustomerVehicleService.Vehicle>{
            vehicleResponse
        };
        QueueableContext qContext = null;
        vehResource.execute(qContext);
        List<Vehicle__c> vehicleList = [
            SELECT Id
            FROM Vehicle__c
            WHERE CreatedFrom__c = 'GDMS'
                AND Company__c = :CompanyRepository.name2Company.get(CompanyRepository.C099).Id
        ];
        System.assert(1 == vehicleList.size());

    }
    @isTest
    static void testAltDriverGeneration(){
        System.debug([SELECT Id,Account__c FROM ExternalSystemAccount__c]);
        ExternalSystem gdmsInternal = new ExternalSystem(CompanyRepository.C099);
        VehicleResource vehResource = new VehicleResource();
        vehResource.setExternalSystem(gdmsInternal);
        vehResource.dateFrom = Date.newInstance(1900, 01, 01);
        vehResource.dateTo = Date.today();
        vehResource.followOn = false;
        vehResource.gdmsVehicleList = new List<CustomerVehicleService.Vehicle>{
            vehicleResponse
        };
        QueueableContext qContext = null;
        vehResource.execute(qContext);
    }

    @isTest
    static void testvehicleResource028(){
        CareService.VehicleResponse vehicle = new CareService.VehicleResponse();
		List<CareService.VehicleResponse> vehicleList = new List<CareService.VehicleResponse>();
		vehicle.companyCode = CompanyRepository.C028;
		vehicle.company = 'Sime Darby Auto Bavaria Sdn Bhd';
		vehicle.source = 'Autoline';
		vehicle.vehNo = 23167;
		vehicle.dmsNo = '21161';
		vehicle.vehMakeCode = 'B';
		vehicle.vehMake = 'BMW';
		vehicle.vehModelRange = '87';
		vehicle.vehModelCode = 'Generic';
		vehicle.vehModelDesc = 'BMW Generic Model';
		vehicle.vehModelYear = 2012;
		vehicle.vehColorCode = ' ';
		vehicle.vehColor = '300 alpinweiss 3';
		vehicle.vehTrimCode = '';
		vehicle.vehTrim = 'LCB8 Leather \'Dakota\'/terra';
		vehicle.vehVariantCode = 'Generic';
		vehicle.vehVariantDesc = 'BMW Generic Model';
		vehicle.chassis = 'PM1XG14060DV69340';
		vehicle.engineNum = 'A7980139';
		vehicle.engineCap = 0.0;
		vehicle.description = 'XG24A7 - F10/520i';
		vehicle.productionDate = Datetime.valueOf('1899-12-30 00:00:00');
		vehicle.productionMonth = '0';
		vehicle.productionYear = '2012';
		vehicle.bodyStyle = '';
		vehicle.vehType = 'N';
		vehicle.regDate = Datetime.valueOf('2012-12-10 00:00:00');
		vehicle.regNum = 'BMW1002';
		vehicle.mileage = 0;
		vehicle.nextServiceDate = null;
		vehicle.vsbRef = '0';
		vehicle.vsbRefCmp = 'A0';
		vehicle.sellingDealer = 'Auto Bavaria';
		vehicle.warrantyExDate = Datetime.valueOf('2014-12-10 00:00:00');
		vehicle.extendedWarrantyDate = Datetime.valueOf('1900-01-01 00:00:00');
		vehicleList.add(vehicle);

        ExternalSystem careExternalSystem = new ExternalSystem(CompanyRepository.C028);
        VehicleResource vehResource = new VehicleResource();
        vehResource.setExternalSystem(careExternalSystem);
        vehResource.dateFrom = Date.newInstance(1900, 01, 01);
        vehResource.dateTo = Date.today();
        vehResource.followOn = false;
        vehResource.testResponseSet = true;
        vehResource.careVehicleList = new List<CareService.VehicleResponse>{
            vehicle
        };
        QueueableContext qContext = null;
        vehResource.execute(qContext);
        List<Vehicle__c> autolineVehicleList = [
            SELECT Id
            FROM Vehicle__c
            WHERE CreatedFrom__c = 'Autoline'
                AND Company__c = :CompanyRepository.name2Company.get(CompanyRepository.C028).Id
        ];
        System.debug(autolineVehicleList);
        System.assert(1 == autolineVehicleList.size());
    }
}