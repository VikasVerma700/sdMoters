//Generated by wsdl2apex

public class Byd {
    public class MY_BD_CustomerVehicleServiceObj {
        //public String endpoint_x = 'https://dms.simedarbymotors.com:8443/wsav11_train/wsa1';
        //https://dms.simedarbymotors.com:8443/wsav11_train/wsa1
        public String endpoint_x = 'callout:'+'GdmsTrain';
        public Map<String,String> inputHttpHeaders_x;
        public Map<String,String> outputHttpHeaders_x;
        public String clientCertName_x;
        public String clientCert_x;
        public String clientCertPasswd_x;
        public Integer timeout_x;
        private String[] ns_map_type_info = new String[]{'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService', 'BydByd', 'urn:soap-fault:details', 'soapFaultDetails', 'urn:MY-BD-CustomerVehicleService', 'Byd'};
        public BydByd.QueryCustomerAccountResponse_element QueryCustomerAccount(String CompanyCode,String SearchField,String SearchValue,String LastRowID,Integer BatchSize) {
            BydByd.QueryCustomerAccount_element request_x = new BydByd.QueryCustomerAccount_element();
            request_x.CompanyCode = CompanyCode;
            request_x.SearchField = SearchField;
            request_x.SearchValue = SearchValue;
            request_x.LastRowID = LastRowID;
            request_x.BatchSize = BatchSize;
            BydByd.QueryCustomerAccountResponse_element response_x;
            Map<String, BydByd.QueryCustomerAccountResponse_element> response_map_x = new Map<String, BydByd.QueryCustomerAccountResponse_element>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              '',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'QueryCustomerAccount',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'QueryCustomerAccountResponse',
              'BydByd.QueryCustomerAccountResponse_element'}
            );
            response_x = response_map_x.get('response_x');
            return response_x;
        }
        public BydByd.AppointmentUpsertResponse_element AppointmentUpsert(String CompanyCode,String SA_Username,Integer AppointmentNumber,DateTime AppointmentDateTime,String AppointmentStatus,String AppointmentDesc,String ChassisNumber,String CustomerNumber,String ContactNumber,String ContactName,String ContactEmail,String DocumentNumber) {
            BydByd.AppointmentUpsert_element request_x = new BydByd.AppointmentUpsert_element();
            request_x.CompanyCode = CompanyCode;
            request_x.SA_Username = SA_Username;
            request_x.AppointmentNumber = AppointmentNumber;
            request_x.AppointmentDateTime = AppointmentDateTime;
            request_x.AppointmentStatus = AppointmentStatus;
            request_x.AppointmentDesc = AppointmentDesc;
            request_x.ChassisNumber = ChassisNumber;
            request_x.CustomerNumber = CustomerNumber;
            request_x.ContactNumber = ContactNumber;
            request_x.ContactName = ContactName;
            request_x.ContactEmail = ContactEmail;
            request_x.DocumentNumber = DocumentNumber;
            BydByd.AppointmentUpsertResponse_element response_x;
            Map<String, BydByd.AppointmentUpsertResponse_element> response_map_x = new Map<String, BydByd.AppointmentUpsertResponse_element>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              '',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'AppointmentUpsert',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'AppointmentUpsertResponse',
              'BydByd.AppointmentUpsertResponse_element'}
            );
            response_x = response_map_x.get('response_x');
            return response_x;
        }
        public BydByd.QueryVehicleResponse_element QueryVehicle(String CompanyCode,String SearchField,String SearchValue,String LastRowID,Integer BatchSize) {
            BydByd.QueryVehicle_element request_x = new BydByd.QueryVehicle_element();
            request_x.CompanyCode = CompanyCode;
            request_x.SearchField = SearchField;
            request_x.SearchValue = SearchValue;
            request_x.LastRowID = LastRowID;
            request_x.BatchSize = BatchSize;
            BydByd.QueryVehicleResponse_element response_x;
            Map<String, BydByd.QueryVehicleResponse_element> response_map_x = new Map<String, BydByd.QueryVehicleResponse_element>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              '',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'QueryVehicle',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'QueryVehicleResponse',
              'BydByd.QueryVehicleResponse_element'}
            );
            response_x = response_map_x.get('response_x');
            return response_x;
        }
        public BydByd.AppointmentGetResponse_element AppointmentGet(String CompanyCode,String Workshop,String SearchField,String SearchValue) {
            BydByd.AppointmentGet_element request_x = new BydByd.AppointmentGet_element();
            request_x.CompanyCode = CompanyCode;
            request_x.Workshop = Workshop;
            request_x.SearchField = SearchField;
            request_x.SearchValue = SearchValue;
            BydByd.AppointmentGetResponse_element response_x;
            Map<String, BydByd.AppointmentGetResponse_element> response_map_x = new Map<String, BydByd.AppointmentGetResponse_element>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              '',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'AppointmentGet',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'AppointmentGetResponse',
              'BydByd.AppointmentGetResponse_element'}
            );
            response_x = response_map_x.get('response_x');
            return response_x;
        }
        public BydByd.QueryUsersResponse_element QueryUsers() {
            BydByd.QueryUsers_element request_x = new BydByd.QueryUsers_element();
            BydByd.QueryUsersResponse_element response_x;
            Map<String, BydByd.QueryUsersResponse_element> response_map_x = new Map<String, BydByd.QueryUsersResponse_element>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              '',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'QueryUsers',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'QueryUsersResponse',
              'BydByd.QueryUsersResponse_element'}
            );
            response_x = response_map_x.get('response_x');
            return response_x;
        }
        public BydByd.updateDataResponse_element updateData(String ip_json) {
            BydByd.updateData_element request_x = new BydByd.updateData_element();
            request_x.ip_json = ip_json;
            BydByd.updateDataResponse_element response_x;
            Map<String, BydByd.updateDataResponse_element> response_map_x = new Map<String, BydByd.updateDataResponse_element>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              '',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'updateData',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'updateDataResponse',
              'BydByd.updateDataResponse_element'}
            );
            response_x = response_map_x.get('response_x');
            return response_x;
        }
    }
}