public with sharing class DmsServiceAppointment {
   public final static Map<String, String> SFSTATUS2GDMS = new Map<String, String>{
        'active' => 'Open',
        'cancelled' => 'Cancelled',
        'converted to ro' => 'Close',
        'arrived' => 'Arrived'
    };
    public static void sendWebhook(DmsCallBack__e callback) {
        try {
            Service_Appointment__c appointment = retrieveAppointmentDetails(callback.Id__c);
            if (appointment == null) { return; }
            CustomerVehicleService.AppointmentUpsert appoint =  prepareAppointment(appointment);
            CustomerVehicleService service  = new CustomerVehicleService(appoint.CompanyCode);
			try{
                ServiceAppointmentWebhook hook = new ServiceAppointmentWebhook(callback.Event__c.toLowercase(), new List<CustomerVehicleService.AppointmentUpsert>{ appoint });
                string jsonHook = JSON.serialize(hook);
                System.debug(' jsonHook : '+jsonHook); 
                CustomerVehicleService.UpdateDataResponse resp = service.updateData(jsonHook);
                String response = JSON.serialize(resp);
                System.debug(' resp : '+ response); 
                // Parse the JSON data
                Map<String, Object> jsonData = (Map<String, Object>) JSON.deserializeUntyped(response);
                String ipJsonString = (String) jsonData.get('ip_json');
                Map<String, Object> ipJsonData = (Map<String, Object>) JSON.deserializeUntyped(ipJsonString);
                String statusCode = (String) ipJsonData.get('statusCode');
                List<Object> payload = (List<Object>) ipJsonData.get('payload');
                Map<String, Object> payloadData = (Map<String, Object>) payload[0];
                System.debug('statusCode : '+statusCode);
                
                if(statusCode == '200'){
                    Integer appointmentNumber = (Integer) payloadData.get('AppointmentNumber');
                    System.debug('appointmentNumber : '+appointmentNumber);
                    if(appointmentNumber != null && appointment.DmsAppointmentNumber__c != String.valueOf(appointmentNumber)){
                        appointment.DmsAppointmentNumber__c = String.valueOf(appointmentNumber);
                        if( !ServiceAppointmentHandler.dmsAppointmentIds.contains(appointment.Id)){
                            ServiceAppointmentHandler.dmsAppointmentIds.add(appointment.Id);
                        }
                        update appointment;  
                    }
                                       
                    ApplicationLogUtility.insertCalloutSuccessLog('DmsServiceAppointment', jsonHook, response.unescapeJava(), Request.getCurrent().getRequestId(), false); 
                }else{
                    String errorMsg  = (String) payloadData.get('Message');
                    System.debug('errorMsg : '+errorMsg);
                    ApplicationLogUtility.insertCalloutSuccessLog('DmsServiceAppointment', jsonHook, response.unescapeJava(), Request.getCurrent().getRequestId(), errorMsg, false);
                }               
                
			}
			catch(CallOutException callOutError){
                System.debug( 'callOutError.getMessage() : '+callOutError.getMessage());
				callOutError.setMessage('Error sending '+ String.valueOf(callback.Id__c)+' '+callback.CompanyCode__c + ' '+callOutError.getMessage());
				ApplicationLogUtility.insertCalloutErrorLog(new DmsServiceAppointment(), callOutError, ApplicationLogUtility.PRIORITY_HIGH,false);
			} 
            
        } catch(Exception e){
            System.debug('Exception Error '+e.getCause()+' Error msg '+e.getMessage() +' line no. '+e.getLineNumber());
            DmsServiceAppointment appointment = new DmsServiceAppointment();
            e.setMessage('Exception : '+ String.valueOf(callback.Id__c)+' '+callback.CompanyCode__c +' '+e.getMessage());
            ApplicationLogUtility.insertApexErrorLog(appointment, e, ApplicationLogUtility.PRIORITY_HIGH, false);
        } 
        ApplicationLogUtility.insertLogs();
    }

    public static CustomerVehicleService.AppointmentUpsert prepareAppointment( Service_Appointment__c appointment){
        String cmpCode = CompanyRepository.id2Company.get(appointment.Company__c).DmsCompanyCode__c;
        ExternalSystemAccount__c esaAccount =[Select Id, CustomerNumber__c from ExternalSystemAccount__c WHERE CompanyCode__c =:cmpCode AND Account__c =:appointment.Account__c Order By CreatedDate Desc LIMIT 1 ];

        CustomerVehicleService.AppointmentUpsert apptParam = new CustomerVehicleService.AppointmentUpsert();
        apptParam.CompanyCode = cmpCode;
        apptParam.SA_Username = appointment.Employee_Master__r.Employee_Number__c;
        apptParam.AppointmentDateTime = appointment.Appointment_Date__c;
        apptParam.AppointmentDesc = appointment.Customer_Comment__c;
        apptParam.ChassisNumber = appointment.Chassis__r.Name;
        apptParam.CustomerNumber = String.valueOf(esaAccount.CustomerNumber__c);
        apptParam.ContactNumber = appointment.Contact_No__c;
        apptParam.ContactName = appointment.Contact_Name__c;
        apptParam.ContactEmail = appointment.Email_Address_Notification__c;
        apptParam.DocumentNumber = appointment.Account__r.NRIC_Number__c;
        apptParam.AppointmentStatus = SFSTATUS2GDMS.get(appointment.Apppointment_Status__c.toLowerCase()) != null ? SFSTATUS2GDMS.get(appointment.Apppointment_Status__c.toLowerCase()) : appointment.Apppointment_Status__c;
        apptParam.AppointmentNumber = String.isBlank(appointment.DmsAppointmentNumber__c) == true ? 0 : Integer.valueOf(appointment.DmsAppointmentNumber__c);
		apptParam.Workshop = appointment.Workshop__r.Name;
        apptParam.RegistrationNumber = appointment.Registration_No__c;
        return apptParam;
    }

    public static Service_Appointment__c retrieveAppointmentDetails(String recId){
        String query = 'SELECT '+ String.join(new List<String>(schema.SObjectType.Service_Appointment__c.fields.getMap().keySet()),',');
			query += ' ,Employee_Master__r.Employee_Number__c,Chassis__r.Name,Account__r.Customer_Number__c,Account__r.NRIC_Number__c, Company__r.name ';
			query += ', Workshop__r.Name';
			query += ' FROM Service_Appointment__c';
			query += ' WHERE Id = :recId LIMIT 1';
			return Database.query(String.escapeSingleQuotes(query));
    }

    public class ServiceAppointmentWebhook {
		public String event;
		public List<CustomerVehicleService.AppointmentUpsert> payload;
		public ServiceAppointmentWebhook(String event, List<CustomerVehicleService.AppointmentUpsert> loadList) {
			this.event = event;
			this.payload = loadList;
		}
	}

    public static CallbackAppointmentResp checkExistingAppointment(List<CustomerVehicleService.Appointment> payloadList) {

        List<Database.UpsertResult> resultList = ServiceAppointmentResource.upsertServiceAppointments(payloadList, CompanyRepository.C099);
        if(resultList.isEmpty()){ return null; }

        Map<Id, String>appointmentIdMap = new Map<Id, String>();
        for(Database.UpsertResult sr : resultList) {
            if(!sr.isSuccess()) {
                String error;
                for(Database.Error dbError: sr.getErrors()) {
                    error += dbError; 
                }
                appointmentIdMap.put(sr.getId(), error);
            }else{
                appointmentIdMap.put(sr.getId(), 'Success');
            }
        }
        List<Details> detailsList = new list<Details>();
        for(Service_Appointment__c appt : [Select Id, CreatedDate, LastModifiedDate from Service_Appointment__c Where Id IN :appointmentIdMap.keySet() WITH SECURITY_ENFORCED]){
            if(appointmentIdMap.containsKey(appt.Id)){
                if(appointmentIdMap.get(appt.Id) == 'Success'){
                    String message;
                    if(date.newInstance(appt.LastModifiedDate.year(), appt.LastModifiedDate.month(), appt.LastModifiedDate.day()) == date.newInstance(appt.CreatedDate.year(), appt.CreatedDate.month(), appt.CreatedDate.day()) && appt.CreatedDate.format('HH:mm') == appt.LastModifiedDate.format('HH:mm')){
                        message = 'Inserted';
                    }else{
                        message = 'Updated';
                    }
                    detailsList.add( new Details(appt.Id, 'Service Appointment Successfully '+message));
                }else{
                    detailsList.add( new Details(appt.Id, appointmentIdMap.get(appt.Id)));
                }
            }
        }

        return new CallbackAppointmentResp('UPDATE_APPOINTMENT', detailsList);
    }

    public class CallbackAppointmentResp {
		public String event;
        public List<Details> details;
        public CallbackAppointmentResp(String evt, List<Details> detList) {
            this.event = evt;
            this.details = detList;
        }
    }

    public class Details {
        public String appointmentId;
        public String message;
        public Details(String appointId,String msg) {
            this.appointmentId = appointId;
            this.message = msg;
        }
    }

}