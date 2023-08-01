@RestResource(urlMapping='/dms/v1/webhook')
global with sharing class DmsAPI {
  public enum EventType {
    UPDATE_ACCOUNT,
    UPDATE_VEHICLE,
    UPDATE_APPOINTMENT,
    UPDATE_EMPLOYEE_MASTER,
    UPDATE_SALES_ORDER
  }

  @HttpPost
  global static void callback() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;
    Exception restError;
    try {
      CallbackReqEvent reqBody = (CallbackReqEvent) JSON.deserialize(
        req.requestBody.toString(),
        CallbackReqEvent.class
      );
      EventType currentEventType = EventType.valueOf(reqBody.event);
      switch on currentEventType {
        when UPDATE_ACCOUNT {
          CallbackAccountReq reqAccount = (CallbackAccountReq) JSON.deserialize(
            req.requestBody.toString(),
            CallbackAccountReq.class
          );
          List<CustomerVehicleService.QueryCustomerAccount_CustomerRow> loadList = reqAccount.payload;
          DmsEsaAccount.CallbackAccountResp response = DmsEsaAccount.checkExistingAccount(
            loadList
          );
          res.responseBody = Blob.valueOf(JSON.serialize(response));
        }
        when UPDATE_VEHICLE {
          CallbackVehicleReq reqVehicle = (CallbackVehicleReq) JSON.deserialize(
            req.requestBody.toString(),
            CallbackVehicleReq.class
          );
          List<CustomerVehicleService.Vehicle> loadList = reqVehicle.payload;
          DmsVehicle.CallbackVehicleResp response = DmsVehicle.checkExistingVehicle(
            loadList
          );
          res.responseBody = Blob.valueOf(JSON.serialize(response));
        }
        when UPDATE_APPOINTMENT {
          CallbackAppointmentReq reqAppointment = (CallbackAppointmentReq) JSON.deserialize(
            req.requestBody.toString(),
            CallbackAppointmentReq.class
          );
          List<CustomerVehicleService.Appointment> loadList = reqAppointment.payload;
          DmsServiceAppointment.CallbackAppointmentResp response = DmsServiceAppointment.checkExistingAppointment(
            loadList
          );
          res.responseBody = Blob.valueOf(JSON.serialize(response));
        }
        when UPDATE_EMPLOYEE_MASTER {
          CallbackEmployeeMasterReq reqEmployee = (CallbackEmployeeMasterReq) JSON.deserialize(
            req.requestBody.toString(),
            CallbackEmployeeMasterReq.class
          );
          List<CustomerVehicleService.UserAccount> loadList = reqEmployee.payload;
          DmsEmployeeMaster.CallbackEmployeeResp response = DmsEmployeeMaster.checkExistingEmployeeMaster(
            loadList
          );
          res.responseBody = Blob.valueOf(JSON.serialize(response));
        }
        when UPDATE_SALES_ORDER {
          CallbackSalesOrderReq reqSalesOrder = (CallbackSalesOrderReq) JSON.deserialize(
            req.requestBody.toString(),
            CallbackSalesOrderReq.class
          );
          List<DmsSalesOrder.SalesReq> loadList = reqSalesOrder.payload;
          DmsSalesOrder.CallbackSalesOrderResp response = DmsSalesOrder.checkExistingSalesOrders(
            loadList
          );
          res.responseBody = Blob.valueOf(JSON.serialize(response));
        }
      }
    } catch (Exception e) {
      restError = e;
      System.debug(
        'Exception Error ' +
          e.getCause() +
          ' lineno. ' +
          e.getLineNumber() +
          ' msg ' +
          e.getMessage()
      );
      DmsAPI dms = new DmsAPI();
      ApplicationLogUtility.insertApexErrorLog(dms, e, 'Low', false);
      ApplicationLogUtility.insertLogs();
      CallbackError err = new CallbackError();
      err.message = e.getMessage();
      err.errorCode = '500';
      res.responseBody = Blob.valueOf(JSON.serialize(err));
    }
    String className = 'DmsApi';
    String request;
    String response;

    if (req.requestBody != null) {
      request = req.requestBody.toString();
    }
    if (res.responseBody != null) {
      response = res.responseBody.toString();
    }
    if (restError != null) {
      response += 'Exception Encountered:\n';
      response += JSON.serialize(restError);
    }
    String message =
      'GDMS Incoming Request completed at: ' + String.valueOf(Datetime.now());
    ApplicationLogUtility.insertCalloutSuccessLog(
      className,
      request,
      response,
      null,
      message,
      true
    );
  }

  global virtual class CallbackReqEvent {
    public String event;
  }

  global class CallbackAccountReq extends CallbackReqEvent {
    public List<CustomerVehicleService.QueryCustomerAccount_CustomerRow> payload;
  }

  global class CallbackVehicleReq extends CallbackReqEvent {
    public List<CustomerVehicleService.Vehicle> payload;
  }

  global class CallbackAppointmentReq extends CallbackReqEvent {
    public List<CustomerVehicleService.Appointment> payload;
  }

  global class CallbackEmployeeMasterReq extends CallbackReqEvent {
    public List<CustomerVehicleService.UserAccount> payload;
  }

  global class CallbackSalesOrderReq extends CallbackReqEvent {
    public List<DmsSalesOrder.SalesReq> payload;
  }

  global class CallbackError {
    public String message;
    public String errorCode;
  }
  // Used to check field laval  accessbility
  public static SObjectAccessDecision stripFieldValidity(
    System.AccessType accessType,
    List<SObject> sourceRecordsList
  ) {
    SObjectAccessDecision decision = Security.stripInaccessible(
      accessType,
      sourceRecordsList
    );
    return decision;
  }
}
