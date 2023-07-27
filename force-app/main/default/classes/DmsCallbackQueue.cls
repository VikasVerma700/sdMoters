public without sharing class DmsCallbackQueue implements Queueable, Database.AllowsCallouts {
    public enum EventType{
        ACCOUNT, 
        VEHICLE,
		APPOINTMENT,
		VEHICLE_OWNERSHIP
    }

    List<DmsCallBack__e> events;
    public DmsCallbackQueue(List<DmsCallBack__e> callbacks) {
        this.events = new List<DmsCallBack__e>(callbacks);
    }

    public void execute(QueueableContext context) {
		try {
			if (this.events == null || this.events.isEmpty()){
                return;
            }
            else{
                DmsCallBack__e evt = this.events.remove(0);
                DmsCallbackQueue.processCallback(evt);
                if (this.events.size() > 0 && Limits.getLimitQueueableJobs() > Limits.getQueueableJobs() && !Test.isRunningTest()) {
                    System.enqueueJob(new DmsCallbackQueue(this.events));
                }
                else{
                    try{
                        System.debug('control tried to queue batch');
                        ProcessAppLogs.startJobs(ProcessAppLogs.BatchType.TYPE_ESA, 2);
                    }
                    catch(Exception schedulerError){
                        ApplicationLogUtility.insertApexErrorLog('DmsCallbackQueue', schedulerError, ApplicationLogUtility.PRIORITY_HIGH, false);
                    }
                }
            }
		} catch (Exception e) {
			generateExceptionLog(e);
		}
	}

    public static void enqueue(List<DmsCallBack__e> callbackList) {
		try {
			System.enqueueJob(new DmsCallbackQueue(callbackList));
		} catch (Exception e) {
			generateExceptionLog(e);
		}
    }
    
    public static void processCallback(DmsCallBack__e callback) {
        EventType currentEventType = EventType.valueOf(callback.Event__c);
		try {
			switch on currentEventType {  
				when ACCOUNT {
					DmsEsaAccount.sendWebhook(callback);
				} when VEHICLE {
                    DmsVehicle.sendWebhook(callback); 
				} when VEHICLE_OWNERSHIP {
					DmsVehicleOwnership.sendWebhook(callback);
				} when APPOINTMENT {
					DmsServiceAppointment.sendWebhook(callback);
				} 
				 
			}
		} catch (Exception e) {
			generateExceptionLog(e);
		}
	}

	public static void generateExceptionLog(Exception e){
		DmsCallbackQueue dmsQue = new DmsCallbackQueue(new List<DmsCallBack__e>());
        ApplicationLogUtility.insertApexErrorLog(dmsQue, e, ApplicationLogUtility.PRIORITY_HIGH, False);
        ApplicationLogUtility.insertLogs();
	}

    public static void generateEvents(List<Id> recordIdList, EventType evtType, String companyCode){
    try { 
        System.debug('control was here to reprocess records');
        for(String str : recordIdList){
            DmsCallBack__e dmsCallback = new DmsCallBack__e( Event__c = String.valueOf(evtType), Id__c = str, CompanyCode__c = companyCode);
            processCallback(dmsCallback);	
        }
        ApplicationLogUtility.insertLogs();
        } catch(Exception e) {
            generateExceptionLog(e);
        }
    }
	
}