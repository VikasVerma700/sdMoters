public with sharing class ServiceAppointmentResource extends Resource implements Queueable,Database.AllowsCallouts{

    private Set<String> companyNameSet;

    private Set<String> workshopNameSet;

    private Set<String> custNumSet;
    private Map<String,Id> custNum2AccountId;

    private Set<String> vehNumSet;
    private Map<String,Id> name2VehicleId;

    private Set<String> dmsNumSet;
    private Map<String,Service_Appointment__c> dmsNumber2ServiceAppt;

    private Set<String> empNumberSet;
    private Map<String,Id> empNumber2Id;

    public List<CustomerVehicleService.Appointment> appointmentResponseList;
    public Integer batchSize;

    public static final Map<String,String> gdms2SfStatus = new Map<String,String>{
        'open' => 'ACTIVE',
        'cancelled' => 'CANCELLED',
        'close' => 'CONVERTED TO RO',
        'arrived' => 'ARRIVED'
    };

    public ServiceAppointmentResource(ExternalSystem extSystem){
        super(extSystem);
        this.batchSize = 50;
        this.appointmentResponseList = new List<CustomerVehicleService.Appointment>();
        this.empNumberSet = new Set<String>();
        this.empNumber2Id = new Map<String,Id>();
        this.dmsNumSet = new Set<String>();
        this.dmsNumber2ServiceAppt = new Map<String,Service_Appointment__c>();

        this.vehNumSet = new Set<String>();
        this.name2VehicleId = new Map<String,Id>();

        this.custNumSet = new Set<String>();
        this.custNum2AccountId = new Map<String,Id>();

        this.workshopNameSet = new Set<String>();
        System.debug(this.workshopNameSet);

        this.companyNameSet = new Set<String>();
    }

    public ServiceAppointmentResource(){
        this.appointmentResponseList = new List<CustomerVehicleService.Appointment>();
        this.empNumberSet= new Set<String>();
        this.empNumber2Id = new Map<String,Id>();

        this.dmsNumSet = new Set<String>();
        this.dmsNumber2ServiceAppt = new Map<String,Service_Appointment__c>();

        this.vehNumSet = new Set<String>();
        this.name2VehicleId = new Map<String,Id>();

        this.custNumSet = new Set<String>();
        this.custNum2AccountId = new Map<String,Id>();

        this.workshopNameSet = new Set<String>();
        System.debug(this.workshopNameSet);

        this.companyNameSet = new Set<String>();
    }

    private Service_Appointment__c put(Service_Appointment__c serviceAppt, String fieldname, Object newValue){
        sObject sObjRecord = serviceAppt;
        return (Service_Appointment__c)this.put(sObjRecord, fieldname, newValue);
    }

    private static Datetime dateToDatetime(Date d){
        Datetime dt = Datetime.newInstance(d.year(),d.month(),d.day());
        return dt;
    }

    public static List<Database.UpsertResult> upsertServiceAppointments(List<CustomerVehicleService.Appointment> appointmentList, String companyCode){
        ExternalSystem extSystem = new ExternalSystem(companyCode);
        ServiceAppointmentResource apptResource = new ServiceAppointmentResource(extSystem);
        apptResource.appointmentResponseList = appointmentList;
        apptResource.initMaps();
        List<Database.UpsertResult> appointmentUpsertResult = apptResource.upsertAppointments();
        ApplicationLogUtility.insertLogs();
        return appointmentUpsertResult;
    }

    public void execute(QueueableContext qContext){
        if(CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(ExternalSystem.Type.GDMS).contains(this.extSystem.companyName)){
            try{
                CustomerVehicleService appointmentService = new CustomerVehicleService(this.extSystem.companyName);
                String searchField = 'LastModifiedDateTime';
                String searchValue = this.dateFrom?.format('dd/MM/yyyy HH:mm:ss.SSS');
                if(String.isNotBlank(searchValue)){
                    searchValue += '-'+this.dateTo?.format('dd/MM/yyyy HH:mm:ss.SSS');
                }
    
                String request = this.extSystem.companyName+ ' | '+searchField+ ':\n';
                request += searchValue;
    
                if(!Test.isRunningTest()){
                    CustomerVehicleService.AppointmentGetResponse appointmentResponse = appointmentService.AppointmentGet(this.extSystem.companyName, null, searchField, searchValue);
                    System.debug(this.appointmentResponseList);
                    if(appointmentResponse.Appointments.Appointment != null){
                        this.appointmentResponseList = appointmentResponse.Appointments.Appointment;
                    }
                    
                    System.debug(this.appointmentResponseList);
                }
                this.initMaps();
                this.upsertAppointments();
                String response = 'Size:\n';
                response += this.appointmentResponseList.size();
                ApplicationLogUtility.insertCalloutSuccessLog(Util.getClassname(this), request, response, null,false);

                //requeue the same class
                Boolean requeueItself = this.isSelfQueueable;
                if(this.appointmentResponseList.size() < this.batchSize  || Test.isRunningTest()){
                    requeueItself = false;
                }

                if(requeueItself){
                    this.appointmentResponseList.clear();
                    System.enqueueJob(this);
                }
                else{
                    this.updateLastRun();
                    if(this.followOn){
                        this.queueNext(true);
                    }
                }
            }
            catch(CalloutException e){
                ApplicationLogUtility.insertCalloutErrorLog(this, e,ApplicationLogUtility.PRIORITY_HIGH,false);
                Resource.queueStart(this.extSystem.companyName);
            }
            catch(Exception e){
                ApplicationLogUtility.insertApexErrorLog(this, e, ApplicationLogUtility.PRIORITY_HIGH,false);
                Resource.queueStart(this.extSystem.companyName);
            }
        }
        ApplicationLogUtility.insertLogs();
    }

    public void initMaps(){
        List<String> keyList;

        if(CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(ExternalSystem.Type.GDMS).contains(this.extSystem.companyName)){
            for(CustomerVehicleService.Appointment serviceAppt: this.appointmentResponseList){
                System.debug(this.workshopNameSet);
                u.add(this.workshopNameSet, serviceAppt.Workshop);
                if(serviceAppt.CustomerNumber != null){
                    this.custNumSet.add(serviceAppt.CustomerNumber);
                }
                u.add(this.vehNumSet, serviceAppt.ChassisNumber);
                if(serviceAppt.AppointmentNumber != null){
                    //u.add(this.dmsNumSet, String.valueOf(serviceAppt.AppointmentNumber).leftPad(6, '0'));
                    u.add(this.dmsNumSet,String.valueOf(serviceAppt.AppointmentNumber));
                }

                u.add(this.empNumberSet,serviceAppt.SA_UserName);
            }

            Set<String> localdmsNumSet = new Set<String>(this.dmsNumSet);
            String query = 'SELECT '+ String.join(new List<String>(schema.sObjectType.Service_Appointment__c.fields.getMap().keySet()),',');
            query += ' FROM Service_Appointment__c';
            query += ' WHERE DmsAppointmentNumber__c IN :localdmsNumSet';
            List<Service_Appointment__c> serviceApptList = (List<Service_Appointment__c>) Database.query(query);
            this.dmsNumber2ServiceAppt = new Map<String,Service_Appointment__c>();
            for(Service_Appointment__c serviceAppt: serviceApptList){
                this.dmsNumber2ServiceAppt.put(serviceAppt.DmsAppointmentNumber__c, serviceAppt);
                ServiceAppointmentHandler.dmsAppointmentIds.add(serviceAppt.Id);
            }

            this.custNum2AccountId = new Map<String,Id>();
            /*
            for(Account custAccount: [SELECT Id,Customer_Number__c FROM Account WHERE Customer_Number__c IN :this.custNumSet]){
                this.custNum2AccountId.put(custAccount.Customer_Number__c,custAccount.Id);
            }
            */
            for(ExternalSystemAccount__c esa: [SELECT Id,Account__c,CustomerNumber__c FROM ExternalSystemAccount__c WHERE CustomerNumber__c IN :this.custNumSet]){
                this.custNum2AccountId.put(esa.CustomerNumber__c, esa.Account__c);
            }
            

            this.name2VehicleId = new Map<String, Id>();
            for (Vehicle__c vehicle :[SELECT Id, Name, Vehicle_Number__c FROM Vehicle__c WHERE Name IN :this.vehNumSet]) {
                this.name2VehicleId.put(vehicle.Name, vehicle.Id);
            }

            for(Employee_Master__c empMaster: [SELECT Id, Employee_Number__c FROM Employee_Master__c WHERE Employee_Number__c IN :this.empNumberSet]){
                this.empNumber2Id.put(empMaster.Employee_Number__c, empMaster.Id);
            }
        }
    }

    public List<Database.UpsertResult> upsertAppointments(){
        Id companyId = CompanyRepository.name2Company.get(this.extSystem.companyName).Id;
        List<Service_Appointment__c> serviceApptList = new List<Service_Appointment__c>();
        if(CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(ExternalSystem.Type.GDMS).contains(this.extSystem.companyName)){            List<Workshop__c> workhopList = [
                SELECT Id,Name,Company__c
                FROM Workshop__c
                WHERE Name IN :this.workshopNameSet
                    AND Company__c = :CompanyRepository.name2Company.get(this.extSystem.companyName).Id
            ];
            WorkshopLookup workshopLkp = new WorkshopLookup(workhopList);
            workshopLkp.lookAll(this.workshopNameSet, this.extSystem.companyName);
            workshopLkp.insertMissingWorkshops();
    
    
            for(CustomerVehicleService.Appointment serviceApptResponse: this.appointmentResponseList){
                Service_Appointment__c serviceAppt;
                if(serviceApptResponse.AppointmentNumber == null){
                    serviceAppt = new Service_Appointment__c();
                }
                else{
                    //serviceAppt = dmsNumber2ServiceAppt.get(String.valueOf(serviceApptResponse.AppointmentNumber).leftPad(6, '0'));
                    serviceAppt = dmsNumber2ServiceAppt.get(String.valueOf(serviceApptResponse.AppointmentNumber));
                    if(serviceAppt == null){
                        serviceAppt = new Service_Appointment__c(DmsAppointmentNumber__c = String.valueOf(serviceApptResponse.AppointmentNumber));
                        ApplicationLogUtility.insertApexErrorLog(Util.getClassname(this), 'Service Appointment Not found for number: '+ serviceApptResponse.AppointmentNumber, 'initmaps');
                    }
                }
                serviceAppt = this.put(serviceAppt,'Appointment_Date__c',serviceApptResponse.AppointmentDateTime);
                serviceAppt = this.put(serviceAppt,'Apppointment_Status__c',gdms2SfStatus.get(serviceApptResponse.AppointmentStatus.toLowerCase()));
                if(serviceApptResponse.CloseDate == null){
                    serviceAppt = this.put(serviceAppt,'Appointment_Date_End_Time__c',null);
                }
                else{
                    serviceAppt = this.put(serviceAppt,'Appointment_Date_End_Time__c',dateToDatetime(serviceApptResponse.CloseDate));
                }

                if(serviceApptResponse.CancelledDate == null){
                    serviceAppt = this.put(serviceAppt,'Cancel_Appointment_Date_Time__c',null);
                }
                else{
                    serviceAppt = this.put(serviceAppt,'Cancel_Appointment_Date_Time__c',dateToDatetime(serviceApptResponse.CancelledDate));
                }
                
                serviceAppt = this.put(serviceAppt,'Customer_Comment__c',serviceApptResponse.CustomerComment);
                serviceAppt = this.put(serviceAppt,'Service_Request__c',serviceApptResponse.ServiceType);
                serviceAppt = this.put(serviceAppt,'Contact_Name__c',serviceApptResponse.ContactName);
                serviceAppt = this.put(serviceAppt,'Contact_No__c',serviceApptResponse.ContactNumber);
                serviceAppt = this.put(serviceAppt,'Email_Address_Notification__c',serviceApptResponse.ContactEmail);
                serviceAppt = this.put(serviceAppt,'Workshop__c',workshopLkp.lookWorkshop(this.extSystem.companyName,serviceApptResponse.Workshop).Id);
                serviceAppt = this.put(serviceAppt,'Company__c',companyId);
                serviceAppt = this.put(serviceAppt,'Created_From__c','gdms');
                serviceAppt = this.put(serviceAppt,'Chassis__c',this.name2VehicleId.get(serviceApptResponse.ChassisNumber));
                serviceAppt = this.put(serviceAppt,'Employee_Master__c',this.empNumber2Id.get(serviceApptResponse.SA_UserName));
                if(serviceApptResponse.CustomerNumber != null){
                    //Id accountId = this.custNum2AccountId.get(Integer.valueOf(serviceApptResponse.CustomerNumber) + 0.0);
                    Id accountId = this.custNum2AccountId.get(serviceApptResponse.CustomerNumber);
                    if(accountId == null){
                        ApplicationLogUtility.insertApexErrorLog(Util.getClassname(this),'No account found for '+ serviceApptResponse.CustomerNumber,'upsertAppointments()',null,ApplicationLogUtility.PRIORITY_HIGH,false);
                    }
                    else{
                        serviceAppt = this.put(serviceAppt,'Account__c',accountId);
                    }
                }
                
                if(serviceAppt.Id == null || this.hasChanged.contains(serviceAppt.Id)){
                    serviceApptList.add(serviceAppt);
                }
            }
        }
        if(serviceApptList.size()>0){
            List<Database.UpsertResult> serviceApptUpsertResultList = new List<Database.UpsertResult>();
            serviceApptUpsertResultList = Database.upsert(serviceApptList,false);
            for(Database.UpsertResult serviceApptUpsertResult: serviceApptUpsertResultList){
                if(!serviceApptUpsertResult.isSuccess()){
                    for(Database.Error dbError: serviceApptUpsertResult.getErrors()){
                        ApplicationLogUtility.insertApexErrorLog(this,dbError,ApplicationLogUtility.PRIORITY_LOW,false);
                    }
                }
            }
            return serviceApptUpsertResultList;
        }
        return null;
    }

}