public with sharing class ProcessAppLogs implements Database.Batchable<SObject>{

    public static final String STATUS_PROCESSED = 'Processed';
    private static final Map<BatchType,DmsCallbackQueue.EventType> batchType2DmsEventType = new Map<BatchType,DmsCallbackQueue.EventType>{
        BatchType.TYPE_ESA => DmsCallbackQueue.EventType.ACCOUNT ,
        BatchType.TYPE_SA => DmsCallbackQueue.EventType.APPOINTMENT, 
        BatchType.TYPE_V => DmsCallbackQueue.EventType.VEHICLE,
        BatchType.TYPE_VO => DmsCallbackQueue.EventType.VEHICLE_OWNERSHIP
    };

    private static final Map<BatchType,BatchType> nextType = new Map<BatchType,BatchType>{
        BatchType.TYPE_ESA => BatchType.TYPE_V,
        BatchType.TYPE_V => BatchType.TYPE_VO,
        BatchType.TYPE_VO => BatchType.TYPE_SA
    };
    private static final Integer QUEUE_FREQ = 5;
    private static final String BLANK_LOG_MESSAGE = 'NA';
    public static void startJobs(BatchType startBatchType, Integer minutesFromNow){
        ProcessAppLogs appLogProcess = new ProcessAppLogs(startBatchType);
        appLogProcess.scheduleNext = true;
        String nextJobId = System.scheduleBatch(appLogProcess, appLogProcess.jobName, minutesFromNow);
        String message = 'JobId : '+ nextJobId+ ' scheduled ';
        message += '\n JobName : '+appLogProcess.jobName;
        ApplicationLogUtility.insertApexCompletionLog('ProcessAppLogs',message,'startJobs', ApplicationLogUtility.PRIORITY_LOW, false);
        ApplicationLogUtility.insertLogs();
    }

    public BatchType type;
    public String jobName;
    public boolean scheduleNext;
    public Integer logsParsed;

    public ProcessAppLogs(BatchType type) {
        this.type = type;
		this.jobName = Util.getClassname(this)+' | '+this.type.name();
        System.debug(this.jobName);
        this.scheduleNext = true;
        this.logsParsed = 0;
    }

    public Database.QueryLocator start(Database.BatchableContext bc){
        String query;
        Database.QueryLocator appLogLocator;
        if(batchType2DmsEventType.keySet().contains(this.type)){

            List<String> classNameList;
            String objectPrefix;

            if(this.type == BatchType.TYPE_SA){
                classNameList = new List<String>{'ServiceAppointmentHandler','DmsServiceAppointment'};
                objectPrefix = Service_Appointment__c.sObjectType.getDescribe().getKeyPrefix();
            }

            if(this.type == BatchType.TYPE_V){
                classNameList = new List<String>{'DmsVehicle'};
                objectPrefix = Vehicle__c.sObjectType.getDescribe().getKeyPrefix();
            }

            if(this.type == BatchType.TYPE_ESA){
                objectPrefix = ExternalSystemAccount__c.sObjectType.getDescribe().getKeyPrefix();
                classNameList = new List<String>{
                    'DmsEsaAccount'
                };
            }

            if(this.type == BatchType.TYPE_VO){
                objectPrefix = Vehicle_Ownership__c.sObjectType.getDescribe().getKeyPrefix();
                classNameList = new List<String>{
                    'DmsVehicleOwnership'
                };
            }

            String calloutFilter = 'Error sending '+objectPrefix+'%';
            String apexErrorFilter = 'Exception : '+objectPrefix+'%';
			query = 'SELECT '+ String.join(new List<String>(schema.SObjectType.ApplicationLog__c.fields.getMap().keySet()),',');
			query += ' FROM ApplicationLog__c';
			query += ' WHERE ( ApexClassName__c IN :classNameList AND';
			query += ' ( ErrorMessage__c LIKE :calloutFilter';
            query += ' OR ErrorMessage__c LIKE :apexErrorFilter) AND';
            query += ' Status__c != :STATUS_PROCESSED )';
            query += ' OR (ApexClassName__c = null AND ErrorMessage__c = :BLANK_LOG_MESSAGE)';
            System.debug(Database.query(query).size());
            System.debug(Database.query(query));
            appLogLocator = Database.getQueryLocator(query);
		}
        System.debug('start: '+this.type.name());
        return appLogLocator;
    }

    public void execute(Database.BatchableContext bc, List<ApplicationLog__c> appLogList){
        System.debug('execute: '+this.type.name());
        String processLogMessage = 'Process Log Report: '+ this.type.name();
        String processDetail = '';
        Map<String,Set<Id>> companyCode2recordIdSet;
        List<Database.UpsertResult> logUpsertResultList;
        Set<String> invalidLogs = new Set<String>();
        if(batchType2DmsEventType.keySet().contains(this.type)){
            Set<String> recordIdSet = new Set<String>();
            companyCode2recordIdSet = new Map<String,Set<Id>>();
            for(ApplicationLog__c appLog:appLogList){
                try{
                    List<String> messagePartList = appLog.ErrorMessage__c.split(' ');
                    Id recordId = Id.valueOf(messagePartList[2]);
                    String companyCode = messagePartList[3];
                    appLog.Status__c = STATUS_PROCESSED;
                    this.logsParsed += 1;
                }
                catch(Exception invalidLogError){
                    invalidLogs.add(appLog.Id);
                }
            }

            DmsCallbackQueue.EventType evtType = batchType2DmsEventType.get(this.type);
            if(evtType != null){
                try{
                    for(String companyCode: companyCode2recordIdSet.keySet()){
                        DmsCallbackQueue.generateEvents(new List<Id>(companyCode2recordIdSet.get(companyCode)),evtType, companyCode);
                    }
                }
                catch(Exception publishError){
                    processDetail += JSON.serialize(publishError);
                }
            }
            logUpsertResultList = Database.upsert(appLogList);
            Map<String,Set<String>> invalidLogMap = new Map<String,Set<String>>{
                'Invalid logs: ' => invalidLogs
            };
            processDetail += '\n'+JSON.serialize(invalidLogMap);
            processDetail += '\n'+JSON.serialize(logUpsertResultList);
            ApplicationLogUtility.insertApexCompletionLog('ProcessAppLogs', processLogMessage, processDetail,ApplicationLogUtility.PRIORITY_LOW,false);
            ApplicationLogUtility.insertLogs();
        }
    }

    public void finish(Database.BatchableContext bc){
        Datetime nextScheduleTime = Datetime.now().addMinutes(QUEUE_FREQ);
        System.debug('finish: '+this.type.name());
        if(this.scheduleNext == true){
            if(batchType2DmsEventType.keySet().contains(this.type)){
                BatchType nextBatchType = nextType.get(this.type);
                if(nextBatchType != null){
                    ProcessAppLogs appLogProcess = new ProcessAppLogs(nextBatchType);
                    appLogProcess.logsParsed = this.logsParsed;
                    Database.executeBatch(appLogProcess);
                }
                else if(this.logsParsed >0 && nextScheduleTime.day() == Datetime.now().day()) {
                    startJobs(BatchType.TYPE_ESA,QUEUE_FREQ);
                }
            }
        }
    }

    public enum BatchType{
		TYPE_SA,//send failed service appointment records again
        TYPE_ESA,//send failed esa
        TYPE_V,//send failed vehicle
        TYPE_VO//send failed vehicle ownership
	}
}