//Generated by wsdl2apex

public class AsyncC199Service {
    public class AsyncMY_BD_CustomerVehicleServiceObj {
        public String endpoint_x = 'https://dms.simedarbymotors.com:8443/wsav11_train/wsa1';
        public Map<String,String> inputHttpHeaders_x;
        public String clientCertName_x;
        public Integer timeout_x;
        private String[] ns_map_type_info = new String[]{'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService', 'C199Stubs', 'urn:soap-fault:details', 'C199ErrorDetails', 'urn:MY-BD-CustomerVehicleService', 'C199Service'};
        public AsyncC199Stubs.QueryCustomerAccountResponse_elementFuture beginQueryCustomerAccount(System.Continuation continuation,String CompanyCode,String SearchField,String SearchValue,String LastRowID,Integer BatchSize) {
            C199Stubs.QueryCustomerAccount_element request_x = new C199Stubs.QueryCustomerAccount_element();
            request_x.CompanyCode = CompanyCode;
            request_x.SearchField = SearchField;
            request_x.SearchValue = SearchValue;
            request_x.LastRowID = LastRowID;
            request_x.BatchSize = BatchSize;
            return (AsyncC199Stubs.QueryCustomerAccountResponse_elementFuture) System.WebServiceCallout.beginInvoke(
              this,
              request_x,
              AsyncC199Stubs.QueryCustomerAccountResponse_elementFuture.class,
              continuation,
              new String[]{endpoint_x,
              '',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'QueryCustomerAccount',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'QueryCustomerAccountResponse',
              'C199Stubs.QueryCustomerAccountResponse_element'}
            );
        }
        public AsyncC199Stubs.AppointmentUpsertResponse_elementFuture beginAppointmentUpsert(System.Continuation continuation,String CompanyCode,String SA_Username,Integer AppointmentNumber,DateTime AppointmentDateTime,String AppointmentStatus,String AppointmentDesc,String ChassisNumber,String CustomerNumber,String ContactNumber,String ContactName,String ContactEmail,String DocumentNumber) {
            C199Stubs.AppointmentUpsert_element request_x = new C199Stubs.AppointmentUpsert_element();
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
            return (AsyncC199Stubs.AppointmentUpsertResponse_elementFuture) System.WebServiceCallout.beginInvoke(
              this,
              request_x,
              AsyncC199Stubs.AppointmentUpsertResponse_elementFuture.class,
              continuation,
              new String[]{endpoint_x,
              '',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'AppointmentUpsert',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'AppointmentUpsertResponse',
              'C199Stubs.AppointmentUpsertResponse_element'}
            );
        }
        public AsyncC199Stubs.QueryVehicleResponse_elementFuture beginQueryVehicle(System.Continuation continuation,String CompanyCode,String SearchField,String SearchValue,String LastRowID,Integer BatchSize) {
            C199Stubs.QueryVehicle_element request_x = new C199Stubs.QueryVehicle_element();
            request_x.CompanyCode = CompanyCode;
            request_x.SearchField = SearchField;
            request_x.SearchValue = SearchValue;
            request_x.LastRowID = LastRowID;
            request_x.BatchSize = BatchSize;
            return (AsyncC199Stubs.QueryVehicleResponse_elementFuture) System.WebServiceCallout.beginInvoke(
              this,
              request_x,
              AsyncC199Stubs.QueryVehicleResponse_elementFuture.class,
              continuation,
              new String[]{endpoint_x,
              '',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'QueryVehicle',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'QueryVehicleResponse',
              'C199Stubs.QueryVehicleResponse_element'}
            );
        }
        public AsyncC199Stubs.AppointmentGetResponse_elementFuture beginAppointmentGet(System.Continuation continuation,String CompanyCode,String Workshop,String SearchField,String SearchValue) {
            C199Stubs.AppointmentGet_element request_x = new C199Stubs.AppointmentGet_element();
            request_x.CompanyCode = CompanyCode;
            request_x.Workshop = Workshop;
            request_x.SearchField = SearchField;
            request_x.SearchValue = SearchValue;
            return (AsyncC199Stubs.AppointmentGetResponse_elementFuture) System.WebServiceCallout.beginInvoke(
              this,
              request_x,
              AsyncC199Stubs.AppointmentGetResponse_elementFuture.class,
              continuation,
              new String[]{endpoint_x,
              '',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'AppointmentGet',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'AppointmentGetResponse',
              'C199Stubs.AppointmentGetResponse_element'}
            );
        }
        public AsyncC199Stubs.QueryUsersResponse_elementFuture beginQueryUsers(System.Continuation continuation) {
            C199Stubs.QueryUsers_element request_x = new C199Stubs.QueryUsers_element();
            return (AsyncC199Stubs.QueryUsersResponse_elementFuture) System.WebServiceCallout.beginInvoke(
              this,
              request_x,
              AsyncC199Stubs.QueryUsersResponse_elementFuture.class,
              continuation,
              new String[]{endpoint_x,
              '',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'QueryUsers',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'QueryUsersResponse',
              'C199Stubs.QueryUsersResponse_element'}
            );
        }
        public AsyncC199Stubs.updateDataResponse_elementFuture beginUpdateData(System.Continuation continuation,String ip_json) {
            C199Stubs.updateData_element request_x = new C199Stubs.updateData_element();
            request_x.ip_json = ip_json;
            return (AsyncC199Stubs.updateDataResponse_elementFuture) System.WebServiceCallout.beginInvoke(
              this,
              request_x,
              AsyncC199Stubs.updateDataResponse_elementFuture.class,
              continuation,
              new String[]{endpoint_x,
              '',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'updateData',
              'urn:MY-BD-CustomerVehicleService:MY_BD_CustomerVehicleService',
              'updateDataResponse',
              'C199Stubs.updateDataResponse_element'}
            );
        }
    }
}