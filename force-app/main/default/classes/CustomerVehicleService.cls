public class CustomerVehicleService {
    public String endpoint;
    public String serviceName;
    public String lastServiceName;
    public List<String> ns_map_type_info;
    private static Map<String,String> COMPANY_NAME_TO_SERVICE_NAME = new Map<String,String>{
        CompanyRepository.C199 => 'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
        CompanyRepository.C099 => 'urn:MY-BY-CustomerVehicleService:MY_BY_CustomerVehicleService'
    };

    public static Map<String,String> COMPANY_NAME_TO_LAST_SERVICE_NAME = new Map<String,String>{
        CompanyRepository.C199 => 'urn:MY-BD-CustomerVehicleService',
        CompanyRepository.C099 => 'urn:MY-BY-CustomerVehicleService'
    };

    public CustomerVehicleService(String companyCode){
        this.endpoint = 'callout:';
        this.endpoint += Envir.isSandbox? 'GdmsTrain' : 'GdmsProduction';
        this.serviceName = COMPANY_NAME_TO_SERVICE_NAME.get(companyCode);
        this.lastServiceName = COMPANY_NAME_TO_LAST_SERVICE_NAME.get(companyCode);
        if(companyCode == CompanyRepository.C199){
            this.ns_map_type_info = new List<String>{
                this.serviceName, 'CustomerVehicleService','','',this.lastServiceName,''
            };
        }
        else if(companyCode == CompanyRepository.C099){
            this.ns_map_type_info = new List<String>{
                this.lastServiceName, '',this.serviceName,'CustomerVehicleService','',''
            };
        }
    }


    //query esa
    public CustomerVehicleService.QueryCustomerAccountResponse QueryCustomerAccount(String CompanyCode,String SearchField,String SearchValue,String LastRowID,Integer BatchSize) {
        CustomerVehicleService.QueryCustomerAccount request_x = new CustomerVehicleService.QueryCustomerAccount();
        request_x.CompanyCode = CompanyCode;
        request_x.SearchField = SearchField;
        request_x.SearchValue = SearchValue;
        request_x.LastRowID = LastRowID;
        request_x.BatchSize = BatchSize;
        CustomerVehicleService.QueryCustomerAccountResponse response_x;
        Map<String, CustomerVehicleService.QueryCustomerAccountResponse> response_map_x = new Map<String, CustomerVehicleService.QueryCustomerAccountResponse>();
        response_map_x.put('response_x', response_x);
        WebServiceCallout.invoke(
        this,
        request_x,
        response_map_x,
        new String[]{this.endpoint,
        '',
        this.serviceName,
        'QueryCustomerAccount',
        this.serviceName,
        'QueryCustomerAccountResponse',
        'CustomerVehicleService.QueryCustomerAccountResponse'}
        );
        response_x = response_map_x.get('response_x');
        return response_x;
    }

    //upsert service appointment
    public CustomerVehicleService.AppointmentUpsertResponse AppointmentUpsert(String CompanyCode, String SA_Username,Integer AppointmentNumber,DateTime AppointmentDateTime,String AppointmentStatus,String AppointmentDesc,String ChassisNumber,String CustomerNumber,String ContactNumber,String ContactName,String ContactEmail,String DocumentNumber) {
        CustomerVehicleService.AppointmentUpsert request_x = new CustomerVehicleService.AppointmentUpsert();
        request_x.CompanyCode = CompanyCode;
        request_x.SA_Username = SA_Username;
        request_x.AppointmentNumber = AppointmentNumber == null ? 0 : AppointmentNumber;
        request_x.AppointmentDateTime = AppointmentDateTime;	//	GMT+8:00
        request_x.AppointmentStatus = AppointmentStatus;	//	Leave blank for NEW appointment creation; ARRIVED, COMPLETED, CONVERTED TO RO, NO SHOW, CANCELLED
        request_x.AppointmentDesc = AppointmentDesc;
        request_x.ChassisNumber = ChassisNumber;
        request_x.CustomerNumber = CustomerNumber;
        request_x.ContactNumber = ContactNumber;
        request_x.ContactName = ContactName;
        request_x.ContactEmail = ContactEmail;
        request_x.DocumentNumber = DocumentNumber;
        CustomerVehicleService.AppointmentUpsertResponse response_x;
        Map<String, CustomerVehicleService.AppointmentUpsertResponse> response_map_x = new Map<String, CustomerVehicleService.AppointmentUpsertResponse>();
        response_map_x.put('response_x', response_x);
        WebServiceCallout.invoke(
        this,
        request_x,
        response_map_x,
        new String[]{this.endpoint,
        '',
        this.serviceName,
        'AppointmentUpsert',
        this.serviceName,
        'AppointmentUpsertResponse',
        'CustomerVehicleService.AppointmentUpsertResponse'}
        );
        response_x = response_map_x.get('response_x');
        return response_x;
    }

    public CustomerVehicleService.AppointmentUpsertResponse AppointmentUpsert(CustomerVehicleService.AppointmentUpsert apptParam) {
        CustomerVehicleService.AppointmentUpsertResponse response_x;
        Map<String, CustomerVehicleService.AppointmentUpsertResponse> response_map_x = new Map<String, CustomerVehicleService.AppointmentUpsertResponse>();
        response_map_x.put('response_x', response_x);
        WebServiceCallout.invoke(
            this,
            apptParam,
            response_map_x,
            new String[]{this.endpoint,
            '',
            this.serviceName,
            'AppointmentUpsert',
            this.serviceName,
            'AppointmentUpsertResponse',
            'CustomerVehicleService.AppointmentUpsertResponse'}
        );
        response_x = response_map_x.get('response_x');
        return response_x;
    }

    //query vehicle
    public CustomerVehicleService.QueryVehicleResponse QueryVehicle(String CompanyCode,String SearchField,String SearchValue,String LastRowID,Integer BatchSize) {
        CustomerVehicleService.QueryVehicle request_x = new CustomerVehicleService.QueryVehicle();
        request_x.CompanyCode = CompanyCode;
        request_x.SearchField = SearchField;
        request_x.SearchValue = SearchValue;
        request_x.LastRowID = LastRowID;
        request_x.BatchSize = BatchSize;
        CustomerVehicleService.QueryVehicleResponse response_x;
        Map<String, CustomerVehicleService.QueryVehicleResponse> response_map_x = new Map<String, CustomerVehicleService.QueryVehicleResponse>();
        response_map_x.put('response_x', response_x);
        WebServiceCallout.invoke(
        this,
        request_x,
        response_map_x,
        new String[]{this.endpoint,
        '',
        this.serviceName,
        'QueryVehicle',
        this.serviceName,
        'QueryVehicleResponse',
        'CustomerVehicleService.QueryVehicleResponse'}
        );
        response_x = response_map_x.get('response_x');
        return response_x;
    }

    //query service appointment
    public CustomerVehicleService.AppointmentGetResponse AppointmentGet(String CompanyCode,String Workshop,String SearchField,String SearchValue) {
        CustomerVehicleService.AppointmentGet request_x = new CustomerVehicleService.AppointmentGet();
        request_x.CompanyCode = CompanyCode;
        request_x.Workshop = Workshop;
        request_x.SearchField = SearchField;
        request_x.SearchValue = SearchValue;
        CustomerVehicleService.AppointmentGetResponse response_x;
        Map<String, CustomerVehicleService.AppointmentGetResponse> response_map_x = new Map<String, CustomerVehicleService.AppointmentGetResponse>();
        response_map_x.put('response_x', response_x);
        WebServiceCallout.invoke(
        this,
        request_x,
        response_map_x,
        new String[]{this.endpoint,
        '',
        this.serviceName,
        'AppointmentGet',
        this.serviceName,
        'AppointmentGetResponse',
        'CustomerVehicleService.AppointmentGetResponse'}
        );
        response_x = response_map_x.get('response_x');
        return response_x;
    }

    //query employee resource
    public CustomerVehicleService.QueryUsersResponse QueryUsers() {
        CustomerVehicleService.QueryUsers request_x = new CustomerVehicleService.QueryUsers();
        CustomerVehicleService.QueryUsersResponse response_x;
        Map<String, CustomerVehicleService.QueryUsersResponse> response_map_x = new Map<String, CustomerVehicleService.QueryUsersResponse>();
        response_map_x.put('response_x', response_x);
        WebServiceCallout.invoke(
        this,
        request_x,
        response_map_x,
        new String[]{this.endpoint,
        '',
        this.serviceName,
        'QueryUsers',
        this.serviceName,
        'QueryUsersResponse',
        'CustomerVehicleService.QueryUsersResponse'}
        );
        response_x = response_map_x.get('response_x');
        return response_x;
    }

    //update data
    public CustomerVehicleService.UpdateDataResponse UpdateData(String ip_json) {
        CustomerVehicleService.UpdateData request_x = new CustomerVehicleService.UpdateData();
        request_x.ip_json = ip_json;
        CustomerVehicleService.UpdateDataResponse response_x;
        Map<String, CustomerVehicleService.UpdateDataResponse> response_map_x = new Map<String, CustomerVehicleService.UpdateDataResponse>();
        response_map_x.put('response_x', response_x);
        WebServiceCallout.invoke(
        this,
        request_x,
        response_map_x,
        new String[]{this.endpoint,
        '',
        this.serviceName,
        'UpdateData',
        this.serviceName,
        'UpdateDataResponse',
        'CustomerVehicleService.UpdateDataResponse'}
        );
        response_x = response_map_x.get('response_x');
        return response_x;
    }
    public class FaultDetail {
        public String errorMessage;
        public String requestID;
        private transient String[] errorMessage_type_info = new String[]{'errorMessage','urn:soap-fault:details',null,'1','1','false'};
        private transient String[] requestID_type_info = new String[]{'requestID','urn:soap-fault:details',null,'1','1','false'};
        private transient String[] apex_schema_type_info = new String[]{'urn:soap-fault:details','false','false'};
        private transient String[] field_order_type_info = new String[]{'errorMessage','requestID'};
    }
    public class AppointmentUpsertResponse {
        public String result;
        public String ResultStatus;
        public Integer AppointmentNumber;
        private transient String[] result_type_info = new String[]{'result','this.namespace',null,'1','1','true'};
        private transient String[] ResultStatus_type_info = new String[]{'ResultStatus','this.namespace',null,'1','1','true'};
        private transient String[] AppointmentNumber_type_info = new String[]{'AppointmentNumber','this.namespace',null,'1','1','true'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'result','ResultStatus','AppointmentNumber'};
    }
    public class Vehicle {
        public String CompanyCode;
        public String Workshop;
        public String VehicleType;
        public Integer StockNo;
        public Long Units;
        public String ChassisNumber;
        public String EngineNumber;
        public String Make;
        public String ModelRange;
        public String ModelDesc;
        public String Model;
        public String Variant;
        public String VariantDesc;
        public String Trims;
        public String ColourCode;
        public String ColourName;
        public String EngineCapacity;
        public Integer EngineSize;
        public String Fuel;
        public Integer Cylinders;
        public String BodyType;
        public String Transmission;
        public String SellingDealerCode;
        public String SellingDealerName;
        public Integer ProductionDate;
        public Date WarrantyValidity;
        public Date ExtendedWarrantyValidity;
        public Long CustomerNo;
        public String CustomerPIN;
        public String CustomerType;
        public String CustomerName;
        public String Salutation;
        public String SSN;
        public Integer DriverID;
        public String DriverPIN;
        public String RegistrationNumber;
        public Date RegistrationDate;
        public String Validity;
        public String Stat_x;
        public Integer Mileage;
        public Date NextServiceDate;
        public DateTime LastUpdate;
        //newly added
        public String TrimsDesc;
        public Integer ProductionMonth;
        public Integer ProductionYear;
        public String ModelRangeDesc;
        private transient String[] CompanyCode_type_info = new String[]{'CompanyCode','this.namespace',null,'1','1','true'};
        private transient String[] Workshop_type_info = new String[]{'Workshop','this.namespace',null,'1','1','true'};
        private transient String[] VehicleType_type_info = new String[]{'VehicleType','this.namespace',null,'1','1','true'};
        private transient String[] StockNo_type_info = new String[]{'StockNo','this.namespace',null,'1','1','true'};
        private transient String[] Units_type_info = new String[]{'Units','this.namespace',null,'1','1','true'};
        private transient String[] VIN_type_info = new String[]{'VIN','this.namespace',null,'1','1','true'};
        private transient String[] EngineNumber_type_info = new String[]{'EngineNumber','this.namespace',null,'1','1','true'};
        private transient String[] Make_type_info = new String[]{'Make','this.namespace',null,'1','1','true'};
        private transient String[] ModelRange_type_info = new String[]{'ModelRange','this.namespace',null,'1','1','true'};
        private transient String[] ModelDesc_type_info = new String[]{'ModelDesc','this.namespace',null,'1','1','true'};
        private transient String[] Model_type_info = new String[]{'Model','this.namespace',null,'1','1','true'};
        private transient String[] Variant_type_info = new String[]{'Variant','this.namespace',null,'1','1','true'};
        private transient String[] VariantDesc_type_info = new String[]{'VariantDesc','this.namespace',null,'1','1','true'};
        private transient String[] Trims_type_info = new String[]{'Trims','this.namespace',null,'1','1','true'};
        private transient String[] ColourCode_type_info = new String[]{'ColourCode','this.namespace',null,'1','1','true'};
        private transient String[] ColourName_type_info = new String[]{'ColourName','this.namespace',null,'1','1','true'};
        private transient String[] EngineCapacity_type_info = new String[]{'EngineCapacity','this.namespace',null,'1','1','true'};
        private transient String[] EngineSize_type_info = new String[]{'EngineSize','this.namespace',null,'1','1','true'};
        private transient String[] Fuel_type_info = new String[]{'Fuel','this.namespace',null,'1','1','true'};
        private transient String[] Cylinders_type_info = new String[]{'Cylinders','this.namespace',null,'1','1','true'};
        private transient String[] BodyType_type_info = new String[]{'BodyType','this.namespace',null,'1','1','true'};
        private transient String[] Transmission_type_info = new String[]{'Transmission','this.namespace',null,'1','1','true'};
        private transient String[] SellingDealerCode_type_info = new String[]{'SellingDealerCode','this.namespace',null,'1','1','true'};
        private transient String[] SellingDealerName_type_info = new String[]{'SellingDealerName','this.namespace',null,'1','1','true'};
        private transient String[] ProductionDate_type_info = new String[]{'ProductionDate','this.namespace',null,'1','1','true'};
        private transient String[] WarrantyValidity_type_info = new String[]{'WarrantyValidity','this.namespace',null,'1','1','true'};
        private transient String[] ExtendedWarrantyValidity_type_info = new String[]{'ExtendedWarrantyValidity','this.namespace',null,'1','1','true'};
        private transient String[] CustomerNo_type_info = new String[]{'CustomerNo','this.namespace',null,'1','1','true'};
        private transient String[] CustomerPIN_type_info = new String[]{'CustomerPIN','this.namespace',null,'1','1','true'};
        private transient String[] CustomerType_type_info = new String[]{'CustomerType','this.namespace',null,'1','1','true'};
        private transient String[] CustomerName_type_info = new String[]{'CustomerName','this.namespace',null,'1','1','true'};
        private transient String[] Salutation_type_info = new String[]{'Salutation','this.namespace',null,'1','1','true'};
        private transient String[] SSN_type_info = new String[]{'SSN','this.namespace',null,'1','1','true'};
        private transient String[] DriverID_type_info = new String[]{'DriverID','this.namespace',null,'1','1','true'};
        private transient String[] DriverPIN_type_info = new String[]{'DriverPIN','this.namespace',null,'1','1','true'};
        private transient String[] RegistrationNumber_type_info = new String[]{'RegistrationNumber','this.namespace',null,'1','1','true'};
        private transient String[] RegistrationDate_type_info = new String[]{'RegistrationDate','this.namespace',null,'1','1','true'};
        private transient String[] Validity_type_info = new String[]{'Validity','this.namespace',null,'1','1','true'};
        private transient String[] Stat_x_type_info = new String[]{'Stat','this.namespace',null,'1','1','true'};
        private transient String[] Mileage_type_info = new String[]{'Mileage','this.namespace',null,'1','1','true'};
        private transient String[] NextServiceDate_type_info = new String[]{'NextServiceDate','this.namespace',null,'1','1','true'};
        private transient String[] LastUpdate_type_info = new String[]{'LastUpdate','this.namespace',null,'1','1','true'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'CompanyCode','Workshop','VehicleType','StockNo','Units','VIN','EngineNumber','Make','ModelRange','ModelDesc','Model','Variant','VariantDesc','Trims','ColourCode','ColourName','EngineCapacity','EngineSize','Fuel','Cylinders','BodyType','Transmission','SellingDealerCode','SellingDealerName','ProductionDate','WarrantyValidity','ExtendedWarrantyValidity','CustomerNo','CustomerPIN','CustomerType','CustomerName','Salutation','SSN','DriverID','DriverPIN','RegistrationNumber','RegistrationDate','Validity','Stat_x','Mileage','NextServiceDate','LastUpdate'};
    }
    public class QueryVehicle {
        public String CompanyCode;
        public String SearchField;
        public String SearchValue;
        public String LastRowID;
        public Integer BatchSize;
        private transient String[] CompanyCode_type_info = new String[]{'CompanyCode','this.namespace',null,'1','1','true'};
        private transient String[] SearchField_type_info = new String[]{'SearchField','this.namespace',null,'1','1','true'};
        private transient String[] SearchValue_type_info = new String[]{'SearchValue','this.namespace',null,'1','1','true'};
        private transient String[] LastRowID_type_info = new String[]{'LastRowID','this.namespace',null,'1','1','true'};
        private transient String[] BatchSize_type_info = new String[]{'BatchSize','this.namespace',null,'1','1','true'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'CompanyCode','SearchField','SearchValue','LastRowID','BatchSize'};
    }
    public class Vehicles {
        public CustomerVehicleService.Vehicle[] Vehicle;
        private transient String[] Vehicle_type_info = new String[]{'Vehicle','this.namespace',null,'0','-1','false'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'Vehicle'};
    }
    public class Appointments {
        public CustomerVehicleService.Appointment[] Appointment;
        private transient String[] Appointment_type_info = new String[]{'Appointment','this.namespace',null,'0','-1','false'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'Appointment'};
    }
    public class QueryVehicleResponse {
        public String result;
        public String LastRowID;
        public Integer ElapsedTime;
        public CustomerVehicleService.Vehicles Vehicles;
        private transient String[] result_type_info = new String[]{'result','this.namespace',null,'1','1','true'};
        private transient String[] LastRowID_type_info = new String[]{'LastRowID','this.namespace',null,'1','1','true'};
        private transient String[] ElapsedTime_type_info = new String[]{'ElapsedTime','this.namespace',null,'1','1','true'};
        private transient String[] Vehicles_type_info = new String[]{'Vehicles','this.namespace',null,'1','1','false'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'result','LastRowID','ElapsedTime','Vehicles'};
    }
    public class QueryCustomerAccount_CustomerParam {
        public CustomerVehicleService.QueryCustomerAccount_CustomerRow[] CustomerRow;
        private transient String[] CustomerRow_type_info = new String[]{'CustomerRow','this.namespace',null,'0','-1','false'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'CustomerRow'};
    }
    public class QueryUsersResponse {
        public String result;
        public CustomerVehicleService.UserAccounts UserAccounts;
        private transient String[] result_type_info = new String[]{'result','this.namespace',null,'1','1','true'};
        private transient String[] UserAccounts_type_info = new String[]{'UserAccounts','this.namespace',null,'1','1','false'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'result','UserAccounts'};
    }
    public class Appointment {
        public String Workshop;
        public Integer AppointmentNumber;
        public DateTime AppointmentDateTime;
        public String AppointmentStatus;
        public DateTime DeliveryDateTime;
        public DateTime OpenDateTime;
        public DateTime ModifiedDateTime;
        public String ModifiedBy;
        public Date CloseDate;
        public Date CancelledDate;
        public String CustomerNumber;
        public String ChassisNumber;
        public String RegistrationNumber;
        public String WorkType;
        public String ServiceType;
        public String PaymentMethod;
        public String InMileage;
        public String SA_UserName;
        public String SA_Code;
        public String SA_EmployeeName;
        public String CustomerComment;
        public String AppointmentChannel;
        public String ContactName;
        public String ContactNumber;
        public String ContactEmail;
        public String DocumentNumber;
        private transient String[] Workshop_type_info = new String[]{'Workshop','this.namespace',null,'1','1','true'};
        private transient String[] AppointmentNumber_type_info = new String[]{'AppointmentNumber','this.namespace',null,'1','1','true'};
        private transient String[] AppointmentDateTime_type_info = new String[]{'AppointmentDateTime','this.namespace',null,'1','1','true'};
        private transient String[] AppointmentStatus_type_info = new String[]{'AppointmentStatus','this.namespace',null,'1','1','true'};
        private transient String[] DeliveryDateTime_type_info = new String[]{'DeliveryDateTime','this.namespace',null,'1','1','true'};
        private transient String[] OpenDateTime_type_info = new String[]{'OpenDateTime','this.namespace',null,'1','1','true'};
        private transient String[] ModifiedDateTime_type_info = new String[]{'ModifiedDateTime','this.namespace',null,'1','1','true'};
        private transient String[] ModifiedBy_type_info = new String[]{'ModifiedBy','this.namespace',null,'1','1','true'};
        private transient String[] CloseDate_type_info = new String[]{'CloseDate','this.namespace',null,'1','1','true'};
        private transient String[] CancelledDate_type_info = new String[]{'CancelledDate','this.namespace',null,'1','1','true'};
        private transient String[] CustomerNumber_type_info = new String[]{'CustomerNumber','this.namespace',null,'1','1','true'};
        private transient String[] ChassisNumber_type_info = new String[]{'ChassisNumber','this.namespace',null,'1','1','true'};
        private transient String[] RegistrationNumber_type_info = new String[]{'RegistrationNumber','this.namespace',null,'1','1','true'};
        private transient String[] WorkType_type_info = new String[]{'WorkType','this.namespace',null,'1','1','true'};
        private transient String[] ServiceType_type_info = new String[]{'ServiceType','this.namespace',null,'1','1','true'};
        private transient String[] PaymentMethod_type_info = new String[]{'PaymentMethod','this.namespace',null,'1','1','true'};
        private transient String[] InMileage_type_info = new String[]{'InMileage','this.namespace',null,'1','1','true'};
        private transient String[] SA_UserName_type_info = new String[]{'SA_UserName','this.namespace',null,'1','1','true'};
        private transient String[] SA_Code_type_info = new String[]{'SA_Code','this.namespace',null,'1','1','true'};
        private transient String[] SA_EmployeeName_type_info = new String[]{'SA_EmployeeName','this.namespace',null,'1','1','true'};
        private transient String[] CustomerComment_type_info = new String[]{'CustomerComment','this.namespace',null,'1','1','true'};
        private transient String[] AppointmentChannel_type_info = new String[]{'AppointmentChannel','this.namespace',null,'1','1','true'};
        private transient String[] ContactName_type_info = new String[]{'ContactName','this.namespace',null,'1','1','true'};
        private transient String[] ContactNumber_type_info = new String[]{'ContactNumber','this.namespace',null,'1','1','true'};
        private transient String[] ContactEmail_type_info = new String[]{'ContactEmail','this.namespace',null,'1','1','true'};
        private transient String[] DocumentNumber_type_info = new String[]{'DocumentNumber','this.namespace',null,'1','1','true'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'Workshop','AppointmentNumber','AppointmentDateTime','AppointmentStatus','DeliveryDateTime','OpenDateTime','ModifiedDateTime','ModifiedBy','CloseDate','CancelledDate','CustomerNumber','ChassisNumber','RegistrationNumber','WorkType','ServiceType','PaymentMethod','InMileage','SA_UserName','SA_Code','SA_EmployeeName','CustomerComment','AppointmentChannel','ContactName','ContactNumber','ContactEmail','DocumentNumber'};
    }
    public class UserAccounts {
        public CustomerVehicleService.UserAccount[] UserAccount;
        private transient String[] UserAccount_type_info = new String[]{'UserAccount','this.namespace',null,'0','-1','false'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'UserAccount'};
    }
    public class QueryUsers {
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{};
    }
    public class AppointmentUpsert {
        public String CompanyCode;
		public String Workshop;
        //public String Username;
        //public String Password;
        public String SA_Username;
        public Integer AppointmentNumber;
        public DateTime AppointmentDateTime;
        public String AppointmentStatus;
        public String AppointmentDesc;
        public String ChassisNumber;
		public String RegistrationNumber;
		public String CustomerNumber;
        public String ContactNumber;
        public String ContactName;
        public String ContactEmail;
        public String DocumentNumber;
        private transient String[] CompanyCode_type_info = new String[]{'CompanyCode','this.namespace',null,'1','1','true'};
        //private transient String[] Username_type_info = new String[]{'Username','this.namespace',null,'1','1','true'};
        //private transient String[] Password_type_info = new String[]{'Password','this.namespace',null,'1','1','true'};
        private transient String[] SA_Username_type_info = new String[]{'SA_Username','this.namespace',null,'1','1','true'};
        private transient String[] AppointmentNumber_type_info = new String[]{'AppointmentNumber','this.namespace',null,'1','1','true'};
        private transient String[] AppointmentDateTime_type_info = new String[]{'AppointmentDateTime','this.namespace',null,'1','1','true'};
        private transient String[] AppointmentStatus_type_info = new String[]{'AppointmentStatus','this.namespace',null,'1','1','true'};
        private transient String[] AppointmentDesc_type_info = new String[]{'AppointmentDesc','this.namespace',null,'1','1','true'};
        private transient String[] ChassisNumber_type_info = new String[]{'ChassisNumber','this.namespace',null,'1','1','true'};
        private transient String[] CustomerNumber_type_info = new String[]{'CustomerNumber','this.namespace',null,'1','1','true'};
        private transient String[] ContactNumber_type_info = new String[]{'ContactNumber','this.namespace',null,'1','1','true'};
        private transient String[] ContactName_type_info = new String[]{'ContactName','this.namespace',null,'1','1','true'};
        private transient String[] ContactEmail_type_info = new String[]{'ContactEmail','this.namespace',null,'1','1','true'};
        private transient String[] DocumentNumber_type_info = new String[]{'DocumentNumber','this.namespace',null,'1','1','true'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        //private transient String[] field_order_type_info = new String[]{'CompanyCode','Username','Password','SA_Username','AppointmentNumber','AppointmentDateTime','AppointmentStatus','AppointmentDesc','ChassisNumber','CustomerNumber','ContactNumber','ContactName','ContactEmail','DocumentNumber'};
        private transient String[] field_order_type_info = new String[]{'CompanyCode','SA_Username','AppointmentNumber','AppointmentDateTime','AppointmentStatus','AppointmentDesc','ChassisNumber','CustomerNumber','ContactNumber','ContactName','ContactEmail','DocumentNumber'};
    }

    public class UserAccount{
        public String CompanyCode;
        public String UserName;
        public String FullName;
        public String Email;
        public String SAPID;
        public String WindowsID;
        public String DefWorkshop;
        public String DefBranch;
        public Boolean IsActive;
        public String QueueRoleCode;
        public String TeamCode;
        public String MobileNumber;
        public Integer EmployeeNum;
        public String EmployeeStatusCode;
        public String EmployeeStatusDescription;
        public CustomerVehicleService.AccountsWorkshopAccess[] AccountsWorkshopAccess;
        public CustomerVehicleService.AccountsBranchAccess[] AccountsBranchAccess;
        private transient String[] CompanyCode_type_info = new String[]{'CompanyCode','this.namespace',null,'1','1','true'};
        private transient String[] UserName_type_info = new String[]{'UserName','this.namespace',null,'1','1','true'};
        private transient String[] FullName_type_info = new String[]{'FullName','this.namespace',null,'1','1','true'};
        private transient String[] Email_type_info = new String[]{'Email','this.namespace',null,'1','1','true'};
        private transient String[] SAPID_type_info = new String[]{'SAPID','this.namespace',null,'1','1','true'};
        private transient String[] WindowsID_type_info = new String[]{'WindowsID','this.namespace',null,'1','1','true'};
        private transient String[] DefWorkshop_type_info = new String[]{'DefWorkshop','this.namespace',null,'1','1','true'};
        private transient String[] DefBranch_type_info = new String[]{'DefBranch','this.namespace',null,'1','1','true'};
        private transient String[] IsActive_type_info = new String[]{'IsActive','this.namespace',null,'1','1','true'};
        private transient String[] QueueRoleCode_type_info = new String[]{'QueueRoleCode','this.namespace',null,'1','1','true'};
        private transient String[] AccountsWorkshopAccess_type_info = new String[]{'AccountsWorkshopAccess','this.namespace',null,'0','-1','false'};
        private transient String[] AccountsBranchAccess_type_info = new String[]{'AccountsBranchAccess','this.namespace',null,'0','-1','false'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'CompanyCode','UserName','FullName','Email','SAPID','DefWorkshop','DefBranch','IsActive','QueueRoleCode','AccountsWorkshopAccess','AccountsBranchAccess'};
    }
    public class AccountsBranchAccess {
        public String Branch;
        public String BranchDesc;
        private transient String[] Branch_type_info = new String[]{'Branch','this.namespace',null,'1','1','true'};
        private transient String[] BranchDesc_type_info = new String[]{'BranchDesc','this.namespace',null,'1','1','true'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'Branch','BranchDesc'};
    }
    public virtual class QueryCustomerAccount_CustomerRow {
        public String CompanyCode;
        public String PIN;
        public Integer CustomerNo;
        public String CustomerType;
        public Boolean Cust_Driver;
        public Integer Units;
        public String Salutation;
        public String FirstName;
        public String LastName;
        public String PrefferedName;
        public String DocType;
        public String DocNum;
        public Date DOB;
        public Date DriLicExp;
        public String MobilePhone;
        public String HomePhone;
        public String OfficePhone;
        public String MobilePhoneAlt;
        public String HomePhoneAlt;
        public String OfficePhoneAlt;
        public String HomeEmail;
        public String OfficeEmail;
        public String OtherEmail;
        public String Address;
        public String Address2;
        public String City;
		public String State;
        public String Country;
        public String PostCode;
        public String BillingAddress;
        public DateTime LastUpdate;
        public DateTime CreatedDate;
        private transient String[] CompanyCode_type_info = new String[]{'CompanyCode','this.namespace',null,'1','1','true'};
        private transient String[] PIN_type_info = new String[]{'PIN','this.namespace',null,'1','1','true'};
        private transient String[] CustomerNo_type_info = new String[]{'CustomerNo','this.namespace',null,'1','1','true'};
        private transient String[] CustomerType_type_info = new String[]{'CustomerType','this.namespace',null,'1','1','true'};
        private transient String[] Cust_Driver_type_info = new String[]{'Cust-Driver','this.namespace',null,'1','1','true'};
        private transient String[] Units_type_info = new String[]{'Units','this.namespace',null,'1','1','true'};
        private transient String[] Salutation_type_info = new String[]{'Salutation','this.namespace',null,'1','1','true'};
        private transient String[] FirstName_type_info = new String[]{'FirstName','this.namespace',null,'1','1','true'};
        private transient String[] LastName_type_info = new String[]{'LastName','this.namespace',null,'1','1','true'};
        private transient String[] PrefferedName_type_info = new String[]{'PrefferedName','this.namespace',null,'1','1','true'};
        private transient String[] DocType_type_info = new String[]{'DocType','this.namespace',null,'1','1','true'};
        private transient String[] DocNum_type_info = new String[]{'DocNum','this.namespace',null,'1','1','true'};
        private transient String[] DOB_type_info = new String[]{'DOB','this.namespace',null,'1','1','true'};
        private transient String[] DriLicExp_type_info = new String[]{'DriLicExp','this.namespace',null,'1','1','true'};
        private transient String[] MobilePhone_type_info = new String[]{'MobilePhone','this.namespace',null,'1','1','true'};
        private transient String[] HomePhone_type_info = new String[]{'HomePhone','this.namespace',null,'1','1','true'};
        private transient String[] OfficePhone_type_info = new String[]{'OfficePhone','this.namespace',null,'1','1','true'};
        private transient String[] MobilePhoneAlt_type_info = new String[]{'MobilePhoneAlt','this.namespace',null,'1','1','true'};
        private transient String[] HomePhoneAlt_type_info = new String[]{'HomePhoneAlt','this.namespace',null,'1','1','true'};
        private transient String[] OfficePhoneAlt_type_info = new String[]{'OfficePhoneAlt','this.namespace',null,'1','1','true'};
        private transient String[] HomeEmail_type_info = new String[]{'HomeEmail','this.namespace',null,'1','1','true'};
        private transient String[] OfficeEmail_type_info = new String[]{'OfficeEmail','this.namespace',null,'1','1','true'};
        private transient String[] OtherEmail_type_info = new String[]{'OtherEmail','this.namespace',null,'1','1','true'};
        private transient String[] Address_type_info = new String[]{'Address','this.namespace',null,'1','1','true'};
        private transient String[] Address2_type_info = new String[]{'Address2','this.namespace',null,'1','1','true'};
        private transient String[] City_type_info = new String[]{'City','this.namespace',null,'1','1','true'};
        private transient String[] Country_type_info = new String[]{'Country','this.namespace',null,'1','1','true'};
        private transient String[] PostCode_type_info = new String[]{'PostCode','this.namespace',null,'1','1','true'};
        private transient String[] BillingAddress_type_info = new String[]{'BillingAddress','this.namespace',null,'1','1','true'};
        private transient String[] LastUpdate_type_info = new String[]{'LastUpdate','this.namespace',null,'1','1','true'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'CompanyCode','PIN','CustomerNo','CustomerType','Cust_Driver','Units','Salutation','FirstName','LastName','PrefferedName','DocType','DocNum','DOB','DriLicExp','MobilePhone','HomePhone','OfficePhone','MobilePhoneAlt','HomePhoneAlt','OfficePhoneAlt','HomeEmail','OfficeEmail','OtherEmail','Address','Address2','City','Country','PostCode','BillingAddress','LastUpdate'};
    }
    public class AccountsWorkshopAccess {
        public String Workshop;
        public String WorkshopDesc;
        private transient String[] Workshop_type_info = new String[]{'Workshop','this.namespace',null,'1','1','true'};
        private transient String[] WorkshopDesc_type_info = new String[]{'WorkshopDesc','this.namespace',null,'1','1','true'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'Workshop','WorkshopDesc'};
    }
    public class AppointmentGet {
        public String CompanyCode;
        public String Workshop;
        public String SearchField;
        public String SearchValue;
        private transient String[] CompanyCode_type_info = new String[]{'CompanyCode','this.namespace',null,'1','1','true'};
        private transient String[] Workshop_type_info = new String[]{'Workshop','this.namespace',null,'1','1','true'};
        private transient String[] SearchField_type_info = new String[]{'SearchField','this.namespace',null,'1','1','true'};
        private transient String[] SearchValue_type_info = new String[]{'SearchValue','this.namespace',null,'1','1','true'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'CompanyCode','Workshop','SearchField','SearchValue'};
    }
    public class AppointmentGetResponse {
        public String result;
        public String ResultStatus;
        public CustomerVehicleService.Appointments Appointments;
        private transient String[] result_type_info = new String[]{'result','this.namespace',null,'1','1','true'};
        private transient String[] ResultStatus_type_info = new String[]{'ResultStatus','this.namespace',null,'1','1','true'};
        private transient String[] Appointments_type_info = new String[]{'Appointments','this.namespace',null,'1','1','false'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'result','ResultStatus','Appointments'};
    }
    public class QueryCustomerAccount {
        public String CompanyCode;
        public String SearchField;
        public String SearchValue;
        public String LastRowID;
        public Integer BatchSize;
        private transient String[] CompanyCode_type_info = new String[]{'CompanyCode','this.namespace',null,'1','1','true'};
        private transient String[] SearchField_type_info = new String[]{'SearchField','this.namespace',null,'1','1','true'};
        private transient String[] SearchValue_type_info = new String[]{'SearchValue','this.namespace',null,'1','1','true'};
        private transient String[] LastRowID_type_info = new String[]{'LastRowID','this.namespace',null,'1','1','true'};
        private transient String[] BatchSize_type_info = new String[]{'BatchSize','this.namespace',null,'1','1','true'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'CompanyCode','SearchField','SearchValue','LastRowID','BatchSize'};
    }
    public class QueryCustomerAccountResponse {
        public String result;
        public String LastRowID;
        public Integer ElapsedTime;
        public CustomerVehicleService.QueryCustomerAccount_CustomerParam Customer;
        private transient String[] result_type_info = new String[]{'result','this.namespace',null,'1','1','true'};
        private transient String[] LastRowID_type_info = new String[]{'LastRowID','this.namespace',null,'1','1','true'};
        private transient String[] ElapsedTime_type_info = new String[]{'ElapsedTime','this.namespace',null,'1','1','true'};
        private transient String[] Customer_type_info = new String[]{'Customer','this.namespace',null,'1','1','true'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'result','LastRowID','ElapsedTime','Customer'};
    }
    public class UpdateDataResponse {
        public String result;
		public String ip_json;
        private transient String[] result_type_info = new String[]{'result','this.namespace',null,'1','1','true'};
        private transient String[] ip_json_type_info = new String[]{'ip_json','this.namespace',null,'1','1','true'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'result','results'};
    }
    public class UpdateData {
        public String ip_json;
        private transient String[] ip_json_type_info = new String[]{'ip_json','this.namespace',null,'1','1','true'};
        private transient String[] apex_schema_type_info = new String[]{'this.namespace','true','false'};
        private transient String[] field_order_type_info = new String[]{'ip_json'};
    }
    public class QueryCustomerAccountResponseFuture extends System.WebServiceCalloutFuture {
        public CustomerVehicleService.QueryCustomerAccountResponse getValue() {
            CustomerVehicleService.QueryCustomerAccountResponse response = (CustomerVehicleService.QueryCustomerAccountResponse)System.WebServiceCallout.endInvoke(this);
            return response;
        }
    }
    public class AppointmentUpsertResponseFuture extends System.WebServiceCalloutFuture {
        public CustomerVehicleService.AppointmentUpsertResponse getValue() {
            CustomerVehicleService.AppointmentUpsertResponse response = (CustomerVehicleService.AppointmentUpsertResponse)System.WebServiceCallout.endInvoke(this);
            return response;
        }
    }
    public class QueryVehicleResponseFuture extends System.WebServiceCalloutFuture {
        public CustomerVehicleService.QueryVehicleResponse getValue() {
            CustomerVehicleService.QueryVehicleResponse response = (CustomerVehicleService.QueryVehicleResponse)System.WebServiceCallout.endInvoke(this);
            return response;
        }
    }
    public class AppointmentGetResponseFuture extends System.WebServiceCalloutFuture {
        public CustomerVehicleService.AppointmentGetResponse getValue() {
            CustomerVehicleService.AppointmentGetResponse response = (CustomerVehicleService.AppointmentGetResponse)System.WebServiceCallout.endInvoke(this);
            return response;
        }
    }
    public class QueryUsersResponseFuture extends System.WebServiceCalloutFuture {
        public CustomerVehicleService.QueryUsersResponse getValue() {
            CustomerVehicleService.QueryUsersResponse response = (CustomerVehicleService.QueryUsersResponse)System.WebServiceCallout.endInvoke(this);
            return response;
        }
    }
}