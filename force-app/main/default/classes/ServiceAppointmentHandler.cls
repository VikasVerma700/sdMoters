public without sharing class ServiceAppointmentHandler extends TriggerBase {
    public class ServiceAppointmentException extends Exception {}
    public static Boolean SQL_UPDATE = false;
    private static final Map<Id, Workshop__c> ALLOW_DUP_WS = new Map<Id, Workshop__c>([SELECT Id, Name FROM Workshop__c WHERE Name IN ('7PD - SDPC', '7PD - ECC', 'W0', 'W4')]);
    public static List<Id> upsertedAppointmentIdList = new List<Id>();
    public static final String TRIG_SETTING = 'Service Appointment'; 
    public static final String EVENT_NAME = 'APPOINTMENT';
    public static set<Id> dmsAppointmentIds = new Set<Id>();
    public ServiceAppointmentHandler() {
        super(TRIG_SETTING, 1);
    }

    public override void beforeInsert(List<SObject> triggerNew) {
        System.debug('Trigger.beforeInsert');
        ServiceAppointmentHandler.checkUniqueServiceAppointment((List<Service_Appointment__c>) triggerNew);
    }

    public override void beforeUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
        System.debug('Trigger.beforeUpdate');
        ServiceAppointmentHandler.checkUniqueServiceAppointment((List<Service_Appointment__c>) triggerNew.values());
        ServiceAppointmentHandler.updateSQL(triggerNew, triggerOld);
        ServiceAppointmentHandler.deleteUtilOnCancel((List<Service_Appointment__c>) triggerNew.values());
    }

    public override void afterInsert(Map<Id, SObject> triggerNew) {
        Set<Id> gdmsCompanyIdSet = new Set<Id>();
        for(String companyCode: CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(ExternalSystem.Type.GDMS)){
            if (CompanyRepository.name2Company.get(companyCode) == null) { continue; }
            gdmsCompanyIdSet.add(CompanyRepository.name2Company.get(companyCode).Id);
        }

        System.debug('Trigger.afterInsert: isQueueable(): ' + System.isQueueable());
        if (!System.isQueueable()) {
            Set<Id> sasId = new Set<Id>();
            ServiceAppointmentHandler.qrAttach(triggerNew.keySet());
        }
        if(!System.isFuture()){
            for(Id serviceApptId: triggerNew.keySet()){
                SObject serviceAppt = triggerNew.get(serviceApptId);
                if(gdmsCompanyIdSet.contains(Id.valueOf(String.valueOf(serviceAppt.get('Company__c'))))){
                    if(!upsertedAppointmentIdList.contains(serviceApptId)){
                        System.debug('called from insert');
                        // upsertToGdms(serviceApptId,false);
                        upsertedAppointmentIdList.add(serviceApptId);
                    }
                }
            }
        }
    }

    public override void afterUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
        Set<Id> gdmsCompanyIdSet = new Set<Id>();
        for(String companyCode: CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(ExternalSystem.Type.GDMS)){
            if (CompanyRepository.name2Company.get(companyCode) == null) { continue; }
            gdmsCompanyIdSet.add(CompanyRepository.name2Company.get(companyCode).Id);
        }
        
        System.debug('Trigger.afterUpdate: isQueueable(): ' + System.isQueueable());
        if (!System.isQueueable()) {
            ServiceAppointmentHandler.qrRemove(triggerNew.keySet());
            /** Notify Mobility CSO */
            System.debug('afterUpdate: calling notifyWorkshop next');
            ServiceAppointmentHandler.notifyWorkshop(triggerNew, triggerOld);
        }

        if(!System.isFuture()){
            for(Id serviceApptId: triggerNew.keySet()){
                SObject serviceAppt = triggerNew.get(serviceApptId);
                if(gdmsCompanyIdSet.contains(Id.valueOf(String.valueOf(serviceAppt.get('Company__c'))))){
                    if(!upsertedAppointmentIdList.contains(serviceApptId)){
                        System.debug('called form update');
                        // upsertToGdms(serviceApptId,true);
                        upsertedAppointmentIdList.add(serviceApptId);
                    }
                }
            }
        }

        // Publish DMS platform  Events
        Set<Id> appointmentIdSet = new Set<Id> ();
        for(Service_Appointment__c appointment : (List<Service_Appointment__c>) triggerNew.values()){
            appointmentIdSet.add(appointment.Id);
        }

        Set<Id> appointmentIds = new Set<Id> ();
        for(Id ids :appointmentIdSet ){
            system.debug('dmsAppointmentIds :'+dmsAppointmentIds);
            if(!dmsAppointmentIds.contains(ids)){
                appointmentIds.add(ids);
            }
        }
      
        if(!appointmentIds.isEmpty()){
            publishPlatformEvent(appointmentIds);
            dmsAppointmentIds = new Set<Id>();
        }
       
    }

    public static void publishPlatformEvent(Set<Id> appointmentIds){
        Map<String, Map<String, List<String>>> entityWithRecordIdMap = new Map<String, Map<String, List<String>>>();
        Map<String, List<String>> companyCodeWithVehicleMap = new Map<String, List<String>>();
	    for(Service_Appointment__c appoint : [Select Id, Company__r.DmsCompanyCode__c from Service_Appointment__c where Company__r.DmsCompanyCode__c != null AND Id IN : appointmentIds]){
            if(companyCodeWithVehicleMap.containsKey(appoint.Company__r.DmsCompanyCode__c)){
                companyCodeWithVehicleMap.get(appoint.Company__r.DmsCompanyCode__c).add(appoint.Id);
            } else {
                companyCodeWithVehicleMap.put(appoint.Company__r.DmsCompanyCode__c, new List<String>{appoint.Id});
            }      
	    } 
        entityWithRecordIdMap.put(EVENT_NAME, companyCodeWithVehicleMap);
        DmsCallbackTriggerHandler handler = new DmsCallbackTriggerHandler(EVENT_NAME, entityWithRecordIdMap);
        handler.publishEvent();
    }

    //Invoked on Before Insert/Update
    public static void checkUniqueServiceAppointment(List<Service_Appointment__c> triggerNew) {
        //Map<Id, Company__c> cmpMap = new Map<Id, Company__c>([SELECT Id, Name FROM Company__c WHERE Name IN ('028')]);
        Map<Id,Company__c> cmpMap = new Map<Id,Company__c>(CompanyRepository.id2Company);
        Map<Id, Workshop__c> cmpWks = new Map<Id, Workshop__c>([SELECT Id, Name FROM Workshop__c]);
        Set<Id> setSAIds = new Set<Id>();
        Set<String> setUniqueCSADate = new Set<String>();
        Set<String> setUniqueVehicleDate = new Set<String>();
        Map<String, Service_Appointment__c> mapDuplicateSAs = new Map<String, Service_Appointment__c>();
        Company__c curCmp;
        for (Service_Appointment__c objSA : triggerNew) {
            curCmp = cmpMap.get(objSA.Company__c);
            if (objSA.Cancel_Appointment__c || objSA.Apppointment_Status__c == 'CANCELLED' || objSA.Apppointment_Status__c == 'NO SHOW') {
                objSA.UniqueServiceAppointment__c = null;
                objSA.UniqueCSADateTime__c = null;
            }
            else {
                if (curCmp == null) { continue; }
                if (objSA.Employee_Master__c != null) {
                    objSA.UniqueCSADateTime__c = objSA.Employee_Master__c + String.valueOf(objSA.Appointment_Date__c);
                    setUniqueCSADate.add(objSA.UniqueCSADateTime__c);
                } else {
                    objSA.UniqueCSADateTime__c = null;
                }
                if (objSA.Chassis__c != null) {
                    objSA.UniqueServiceAppointment__c = objSA.Chassis__c + String.valueOf(objSA.Appointment_Date__c.date()) + objSA.Company__c;
                    if (!ALLOW_DUP_WS.containsKey(objSA.Workshop__c)) { setUniqueVehicleDate.add(objSA.UniqueServiceAppointment__c); }
                }
                setSAIds.add(objSA.Id);
            }
        }

        List<Service_Appointment__c> appList = [SELECT Id, Name, Chassis__c, Chassis__r.Name, Employee_Master__c, Employee_Master__r.Name, Appointment_Date__c,
                                                UniqueServiceAppointment__c, UniqueCSADateTime__c
                                                FROM Service_Appointment__c WHERE Id NOT IN :setSAIds AND Workshop__c NOT IN :ALLOW_DUP_WS.keySet()
                                                AND (UniqueServiceAppointment__c IN :setUniqueVehicleDate OR UniqueCSADateTime__c IN :setUniqueCSADate)];
        for (Service_Appointment__c objSA : appList) {
            if (objSA.UniqueServiceAppointment__c != null) { mapDuplicateSAs.put(objSA.UniqueServiceAppointment__c, objSA); }
            if (objSA.UniqueCSADateTime__c != null) { mapDuplicateSAs.put(objSA.UniqueCSADateTime__c, objSA); }
        }

        /** 20200508: SmsTemplate__c */
        Map<String, SmsTemplate__c> stMap = new Map<String, SmsTemplate__c>();
        for (SmsTemplate__c st :[SELECT Id, Key__c FROM SmsTemplate__c]) {
            if (!stMap.containsKey(st.Key__c)) { stMap.put(st.Key__c, st); }
        }

        String errStr;
        Workshop__c curWks;
        Service_Appointment__c csaMatch, vehMatch, roomMatch;
        for (Service_Appointment__c objSA : triggerNew) {
            String cmpName = CompanyRepository.id2Company.get(objSA.Company__c).DmsCompanyCode__c;
            curCmp = CompanyRepository.name2Company.get(cmpName);
            curWks = cmpWks.get(objSA.Workshop__c);

            csaMatch = (objSA.UniqueCSADateTime__c != null) ? mapDuplicateSAs.get(objSA.UniqueCSADateTime__c) : null;
            vehMatch = (objSA.UniqueServiceAppointment__c != null) ? mapDuplicateSAs.get(objSA.UniqueServiceAppointment__c) : null;
            roomMatch = (objSA.UniqueCSADateTime__c != null) ? mapDuplicateSAs.get(objSA.UniqueCSADateTime__c) : null;

            if (objSA.Employee_Master__c != null && csaMatch != null) {
                errStr = '<a target="_blank" href="' + csaMatch.Id + '">' + csaMatch.Name + '</a>';
                objSA.addError('CSA ' + csaMatch.Employee_Master__r.Name + ' is booked on the same date.<br/>Please check this record: ' + errStr, false);
            }

            if (objSA.Chassis__c != null && vehMatch != null) {
                errStr ='<a target="_blank" href="' + vehMatch.Id + '">' + vehMatch.Name + '</a>';
                objSA.addError('Vehicle ' + vehMatch.Chassis__r.Name + ' is booked on the same date.<br/>Please check this record: ' + errStr, false);
            }

            /** 20200508: SmsTemplate__c */
            //string keySt = String.format('{0}_{1}_{2}', new string[] { curCmp.Name, curWks.Name, objSA.Service_Request__c });
            System.debug(curCmp);
            System.debug(curWks);
            System.debug(objSA);
            string keySt = Util.joinKeys(new string[] { curCmp.Name, curWks.Name, objSA.Service_Request__c }, '_');
            try{
                if (stMap.containsKey(keySt)) { objSA.SmsTemplate__c = stMap.get(keySt).Id; }
            }
            catch(Exception e){
                System.debug(e);
            }
            

        }
    }

    public static void deleteUtilOnCancel(List<Service_Appointment__c> apptList) {
        System.debug('deleteUtilOnCancel(): ' + JSON.serialize(apptList));
        Set<Id> apptIds = new Set<Id>();
        for (Service_Appointment__c a : apptList) {
            if (a.Cancel_Appointment__c || a.Apppointment_Status__c == 'CANCELLED') { apptIds.add(a.Id); }
        }
        if (apptIds.size() < 1) { return; }

        List<Appointment_Utilization__c> utilList = [SELECT Id, Service_Appointment__c FROM Appointment_Utilization__c
                                                     WHERE Service_Appointment__c IN :apptIds AND Service_Appointment__c != null];
        System.debug('utilList to be deleted: ' + JSON.serialize(utilList));
        delete utilList;
    }

    // public static void updateSQL(List<Service_Appointment__c> triggerNew) {
    //  if (SQL_UPDATE) return;
    //  Set<Id> apptIds = new Set<Id>();
    //  for (Service_Appointment__c sa : triggerNew) {
    //      apptIds.add(sa.Id);
    //  }
    //  // System.enqueueJob(new SQL_Appt_Queue(apptIds));
    //  Database.executeBatch(new SQL_Appt_Queue(apptIds), 100);
    //  SQL_UPDATE = true;
    // }
    public static void updateSQL(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
        Set<Id> apptIds = new Set<Id>();
        if (triggerOld == null) {  apptIds.addAll(triggerNew.keySet()); }
        else {
            /** After Update - filter for records where status changed */
            for (SObject s :triggerNew.values()) {
                Service_Appointment__c sa = (Service_Appointment__c) s;
                Service_Appointment__c saOld = (Service_Appointment__c) triggerOld.get(s.Id);

                if (sa.Vehicle_Ownership__c != saOld.Vehicle_Ownership__c
                    || sa.Account__c != saOld.Account__c
                    || sa.Chassis__c != saOld.Chassis__c
                    || sa.Employee_Master__c != saOld.Employee_Master__c
                    || sa.Registration_No__c != saOld.Registration_No__c
                    || sa.Workshop__c != saOld.Workshop__c
                    || sa.Apppointment_Status__c != saOld.Apppointment_Status__c
                    || sa.Appointment_Date__c != saOld.Appointment_Date__c
                    || sa.Service_Request__c != saOld.Service_Request__c
                    || sa.Customer_Comment__c != saOld.Customer_Comment__c
                    || sa.Contact_Name__c != saOld.Contact_Name__c
                    || sa.Contact_No__c != saOld.Contact_No__c
                    || sa.Email_Address_Notification__c != saOld.Email_Address_Notification__c) {
                    // apptIds.add(sa.Id);
                    /** Reset transfer flag to queue record for Care API update. */
                    sa.SFDC_Transfer_Flag__c = false;
                }
            }
        }
        // if (apptIds.size() > 0) {
        //  // Database.executeBatch(new SQL_Appt_Queue(apptIds), 100);
        //  Service_Appointment__c[] sas = [
        //      SELECT
        //          Id, Appointment_Date__c, Service_Request__c, Account__r.Customer_Number__c, Company__r.Name
        //          , Workshop__r.Name, Vehicle_Make__c, Vehicle_Ownership__r.VehicleOwnershipNumber__c
        //          , Chassis__r.Vehicle_Number__c, Employee_Master__r.Employee_Reference__c, Contact_Name__c
        //          , Contact_No__c, Email_Address_Notification__c, Apppointment_Status__c, Customer_Comment__c
        //          , Remarks__c, CreatedDate, CreatedBy.Name, Employee_Master__c, Employee_Master__r.Name
        //          , Employee_Master__r.Employee_Number__c, Vehicle_Ownership__r.Customer__c
        //          , Vehicle_Ownership__r.Registration_No__c, Vehicle_Ownership__r.Vehicle__r.Name
        //          , Created_From__c
        //      FROM Service_Appointment__c
        //      WHERE CreatedDate != null
        //      AND Id IN :apptIds
        //  ];
        //  SQL_Appt_Queue.ApptSetRes res = SQL_Appt_Queue.pushAppt_Api_v1(sas);
        //  SQL_Appt_Queue.upsertAppt(res, sas);
        // }
    }

    /** 20200824: Insert QR code image as Attachment */
    @future (callout=true)
    public static void qrAttach(Set<Id> sasId) {
        string[] errEmail = new List<string>();
        string contentType = 'image/png';
        string attachmentName = 'SelfCheckInQr.png';
        Map<Id, Blob> saQrBlobs = new Map<Id, Blob>();

        Service_Appointment__c[] sas = [
            SELECT Id, Name, Apppointment_Status__c
            FROM Service_Appointment__c 
            WHERE Id IN :sasId
        ];

        for (Service_Appointment__c sa :sas) {
            if (sa.Apppointment_Status__c != 'ACTIVE') { continue; }
            /** Download QR */
            List<string> qrs = ServiceApptBooking.getApptQR(new List<Id> { sa.Id });
            string qr;
            if (qrs != null && qrs.size() > 0) { qr = qrs[0]; }
            
            try {
                Http http = new Http();
                HttpRequest req;
                HttpResponse res;
                req = new HttpRequest();
                req.setEndpoint(qr);
                req.setMethod('GET');
                req.setHeader('Accept', '*/*');
                req.setHeader('Content-Type', contentType);
                req.setTimeout(120000);
                res = http.send(req);

                if (Test.isRunningTest()) { saQrBlobs.put(sa.Id, Blob.valueOf('This is only test')); }
                else {
                    if (res.getStatusCode() == 200) { 
                        saQrBlobs.put(sa.Id, res.getBodyAsBlob()); 
                    }
                }
            }
            catch (Exception e) {
                ApplicationLogUtility.insertApexErrorLog(new ServiceAppointmentHandler(), e, ApplicationLogUtility.PRIORITY_HIGH, false);
                string msg = String.format('{0} ({1}): {2}: {3}', new string[] { sa?.Name, sa.Id, e?.getMessage(), e?.getStackTraceString() });
                errEmail.add(msg);
            }
        }
        Attachment[] attaches = [SELECT Id, Body, ContentType, Description, Name, ParentId FROM Attachment WHERE Name = :attachmentName AND ParentId IN :sasId];
        Set<Id> attId = new Set<Id>();
        for (Attachment att :attaches) { attId.add(att.ParentId); }
        
        for (Service_Appointment__c sa :sas) {
            if (sa.Apppointment_Status__c == 'ACTIVE') { 
                /** Prevent duplicated attachment. */
                if (attId.contains(sa.Id)) { continue; }
                /** Insert attachment. */
                try {
                    Attachment att = new Attachment();
                    Blob bd = saQrBlobs.get(sa.Id);
                    att.Body = bd == null ? Blob.valueOf('') : bd;
                    att.ContentType = contentType;
                    att.Description = 'Customer\'s self check-in QR code.';
                    att.Name = attachmentName;
                    att.ParentId = sa.Id;
                    attaches.Add(att);
                }
                catch (Exception e) { }
            }
        }
        /** Attachment operations. */
        upsert attaches;

        /** Send error email */
        if (errEmail.size() > 0) {
            String subject = Envir.subject + ': qrAttach() error!';
            CommonMethodsLibrary.sendErrorEmail(SQL_API_Base.USER_ADMINS, String.join(errEmail, '<br/>'), true, subject);
        }
        ApplicationLogUtility.insertLogs();
    }

    public static void qrRemove(Set<Id> sasId) {
        System.debug('qrRemove');

        Service_Appointment__c[] sas = [
            SELECT Id, Apppointment_Status__c
            FROM Service_Appointment__c 
            WHERE Id IN :sasId
        ];
        Set<Id> delAtt = new Set<Id>();
        for (Service_Appointment__c sa :sas) {
            if (sa.Apppointment_Status__c != 'ACTIVE') { delAtt.add(sa.Id); }
        }
        delete [SELECT Id FROM Attachment WHERE ParentId IN :delAtt];
    }

    public static void notifyWorkshop(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
        System.debug('notifyWorkshop triggered (triggerOld = ' + (triggerOld != null) + ')');
        string CTRY_PREFIX = '60';
        string DEF_NUM = '+60192651650';
        Set<Id> coi = new Set<Id>();
        Set<Id> wsi = new Set<Id>();
        Set<Id> voi = new Set<Id>();
        for (SObject so :triggerNew.values()) {
            Service_Appointment__c sa = (Service_Appointment__c)so;
            coi.add(sa.Company__c);
            wsi.add(sa.Workshop__c);
            voi.add(sa.Vehicle_Ownership__c);
        }
        Map<Id, Company__c> mapCo = new Map<Id, Company__c>([SELECT Id, Name FROM Company__c WHERE Id IN :coi]);
        Map<Id, Workshop__c> mapWs = new Map<Id, Workshop__c>([SELECT Id, Name, Contact_Number__c, Service_Centre_Name__c FROM Workshop__c WHERE Id IN :wsi]);
        Map<Id, Vehicle_Ownership__c> mapVo = new Map<Id, Vehicle_Ownership__c>([SELECT Id,  Registration_No__c FROM Vehicle_Ownership__c WHERE Id IN :voi]);

        Set<Id> apptId = new Set<Id>();
        for (SObject so :triggerNew.values()) {
            Service_Appointment__c sa = (Service_Appointment__c)so;
            Service_Appointment__c pSa = (Service_Appointment__c)triggerOld.get(sa.Id);
            
            // System.debug(String.format('AU: F: [{0}] T: [{1}]', new string[] { pSa.Appointment_Date__c.format('dd MMM yyyy hh:mm a'), sa.Appointment_Date__c.format('dd MMM yyyy hh:mm a') }));
            
            if (sa.Service_Request__c != 'Mobility') { continue; }
            if (sa.Appointment_Date__c != pSa.Appointment_Date__c
                && (Date.today().daysBetween(sa.Appointment_Date_Only__c) == 1
                    || Date.today().daysBetween(pSa.Appointment_Date_Only__c) == 1
                )) {
                /** Appointment amended:
                 * From future date to TOMORROW
                 * From TOMORROW to future date
                 */
                Company__c co = (Company__c) mapCo.get(sa.Company__c);
                Workshop__c ws = (Workshop__c) mapWs.get(sa.Workshop__c);
                Vehicle_Ownership__c vo = (Vehicle_Ownership__c) mapVo.get(sa.Vehicle_Ownership__c);
                System.debug('Notify Workshop: ' + ws.Contact_Number__c);
                string smsText = String.format(
                    'Please take note that a mobile service appointment has been rescheduled.\n\n ' +
                    'Centre: {5} \n' +
                    'Name: {1} \n' +
                    'Phone: {2} \n' +
                    'Reg. No.: {0} \n' +
                    'From: {3} \n' +
                    'To: {4}.',
                    new string[] {
                        vo.Registration_No__c
                        , sa.Contact_Name__c
                        , sa.Contact_No__c
                        , pSa.Appointment_Date__c.format('dd MMM yyyy hh:mm a') + (Date.today().daysBetween(pSa.Appointment_Date__c.date()) == 1 ? ' (tmrw)' : '')
                        , sa.Appointment_Date__c.format('dd MMM yyyy hh:mm a') + (Date.today().daysBetween(sa.Appointment_Date__c.date()) == 1 ? ' (tmrw)' : '')
                        , ws.Service_Centre_Name__c
                    }
                );
                string msgId = string.format('AU{0}', new string[] { Datetime.now().format('yyyyMMddHHmmssssss') });
                string serviceId = string.format('{0}_{1}_{2}_Care', new string[] { (Envir.isSandbox ? 'Sbox' : 'Prod'), co.Name, ws.Name });
                /** Recipient number. */    
                string recipientNumber = u.sandboxPhone(CTRY_PREFIX, ws.Contact_Number__c, Envir.isSandbox, new List<String>{ DEF_NUM });
    System.debug('notifyBySms(): ' + sa.Id + ', ' + sa.OwnerId + ', ' + msgId + ', ' + serviceId + ', ' + recipientNumber);
                notifyBySms(sa.Id, sa.OwnerId, msgId, serviceId, smsText, recipientNumber);
            }
        }
    }

    @future (callout=true)
    private static void notifyBySms(Id appointmentId, Id ownerId, string msgId, string serviceId, string smsText, string phone) {
        string ret;
        try {
            string smsRet = M3TechApiWrapper.deliverMessage2(msgId, serviceId, smsText, phone);
            ret = string.format('{0} ({1})', new string[] { smsRet, phone });
        }
        catch (Exception e) { ret = e.getMessage(); }
        Task curT = CommonMethodsLibrary.createTask(null, appointmentId, ownerId, 'Automated Tasks', 'System Generated Tasks', '', 'Low', 'Reschedule SMS', false, null);
        curT.Status = 'Completed';
        curT.ActivityDate = Date.today();
        curT.Description = 'Result:' + ret + '\nText:' + smsText;
        Task[] taskRec = new List<Task>{ curT };

        System.debug('Before insert task: ' + taskRec.size() + ': ' + JSON.serialize(taskRec));
        Database.SaveResult[] sr = Database.insert(taskRec , false);
        CommonMethodsLibrary.emailResultFailure(sr, taskRec, 'Trigger.notifyWorkshop', 'ServiceAppointmentHandler', ServiceApptBooking.ERR_USER);
    }

    @future(callout = true)
    public static void upsertToGdms(Id serviceApptId, Boolean isUpdate){
        if(!upsertedAppointmentIdList.contains(serviceApptId)){
            upsertedAppointmentIdList.add(serviceApptId);
            Map<String,String> sfStatus2Gdms = new Map<String,String>{
                'active' => 'Open',
                'cancelled' => 'Cancelled',
                'converted to ro' => 'Close',
                'arrived' => 'Arrived'
            };
            try{
                String query = 'SELECT '+ String.join(new List<String>(schema.SObjectType.Service_Appointment__c.fields.getMap().keySet()),',');
                query += ' ,Employee_Master__r.Employee_Number__c,Chassis__r.Name,Account__r.Customer_Number__c,Account__r.NRIC_Number__c';
                query += ' FROM Service_Appointment__c';
                query += ' WHERE Id = :serviceApptId';
                Service_Appointment__c serviceAppt = (Service_Appointment__c) Database.query(query);
        
                String endpoint = 'callout:';
                endpoint += Envir.isSandbox ? 'GdmsTrain' : 'GdmsProduction';
                CustomerVehicleService apptService = new CustomerVehicleService(CompanyRepository.id2Company.get(serviceAppt.Company__c).DmsCompanyCode__c);
        
                CustomerVehicleService.AppointmentUpsert apptParam = new CustomerVehicleService.AppointmentUpsert();
                CustomerVehicleService.AppointmentUpsertResponse apptUpsertResponse;
                apptParam.CompanyCode = CompanyRepository.id2Company.get(serviceAppt.Company__c).DmsCompanyCode__c;
                apptParam.SA_Username = serviceAppt.Employee_Master__r.Employee_Number__c;
                apptParam.AppointmentDateTime = serviceAppt.Appointment_Date__c.addHours(8);
                apptParam.AppointmentDesc = serviceAppt.Customer_Comment__c;
                apptParam.ChassisNumber = serviceAppt.Chassis__r.Name;
                apptParam.CustomerNumber = String.valueOf(serviceAppt.Account__r.Customer_Number__c);
                apptParam.ContactNumber = serviceAppt.Contact_No__c;
                apptParam.ContactName = serviceAppt.Contact_Name__c;
                apptParam.ContactEmail = serviceAppt.Email_Address_Notification__c;
                apptParam.DocumentNumber = serviceAppt.Account__r.NRIC_Number__c;
                if(isUpdate){
                    apptParam.AppointmentStatus = sfStatus2Gdms.get(serviceAppt.Apppointment_Status__c.toLowerCase());
                    if(apptParam.AppointmentStatus == null){
                        apptParam.AppointmentStatus = serviceAppt.Apppointment_Status__c;
                    }
                }
                /** Added by Tham - 2023-08-28 11:37 */
                if (String.isBlank(serviceAppt.DmsAppointmentNumber__c)) {
                    apptParam.AppointmentNumber = 0;
                }
                else {
                    apptParam.AppointmentNumber = Integer.valueOf(serviceAppt.DmsAppointmentNumber__c);
                }
                try{
                    System.debug('appt: ' + JSON.serialize(apptParam));
                    apptUpsertResponse = apptService.AppointmentUpsert(apptParam);
                    if(apptUpsertResponse.result == 'SUCCESS' && apptUpsertResponse.ResultStatus == 'Created'){
                        if(!isUpdate){// update apointment number as per response
                            serviceAppt.DmsAppointmentNumber__c = String.valueOf(apptUpsertResponse.AppointmentNumber);
                            System.debug(String.valueOf(apptUpsertResponse.AppointmentNumber));
                            update serviceAppt;
                        }
                        String message = 'Appointment created in GDMS';
                        String stackTrace = 'serviceApptId : '+ String.valueOf(serviceApptId);
                        stackTrace += '\n Appointment Number : '+ serviceAppt.DmsAppointmentNumber__c;
                        stackTrace += '\n'+Json.serialize(apptUpsertResponse);
                        ApplicationLogUtility.insertApexCompletionLog('ServiceAppointmentHandler', message, stackTrace,ApplicationLogUtility.PRIORITY_LOW,false);
                    }
                    else if(apptUpsertResponse.result == 'SUCCESS' && apptUpsertResponse.ResultStatus == 'Updated'){
                        String message = 'Appointment updated in GDMS';
                        String stackTrace = 'serviceApptId : '+ String.valueOf(serviceApptId);
                        stackTrace += '\n Appointment Number : '+ serviceAppt.DmsAppointmentNumber__c;
                        stackTrace += '\n'+Json.serialize(apptUpsertResponse);
                        ApplicationLogUtility.insertApexCompletionLog('ServiceAppointmentHandler', message, stackTrace,ApplicationLogUtility.PRIORITY_LOW,false);
                    }
                    else{
                        String message = isUpdate ? 'Error updating ' : 'Error creating ';
                        message += String.valueOf(serviceApptId)+ ' in GDMS';
                        String stackTrace = Json.serialize(apptUpsertResponse);
                        String transactionId = null;
                        String priority = ApplicationLogUtility.PRIORITY_HIGH;
                        ApplicationLogUtility.insertApexErrorLog('ServiceAppointmentHandler', message, stackTrace,transactionId,priority,false);
                    }
                }
                catch(CalloutException calloutError){
                    calloutError.setMessage('Error sending '+ String.valueOf(serviceApptId)+' '+calloutError.getMessage());
                    ApplicationLogUtility.insertCalloutErrorLog(new ServiceAppointmentHandler(), calloutError, ApplicationLogUtility.PRIORITY_HIGH,false);
                }
            }
            catch(Exception apexError){
                apexError.setMessage('Apex Error '+ String.valueOf(serviceApptId)+' '+apexError.getMessage());
                ApplicationLogUtility.insertApexErrorLog(new ServiceAppointmentHandler(), apexError, ApplicationLogUtility.PRIORITY_HIGH,false);
            }
            ApplicationLogUtility.insertLogs();
        }
        else{
            System.debug('already '+ String.valueOf(serviceApptId)+ ' to gdms!');
        }
    }
       
}