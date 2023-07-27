public with sharing virtual class Resource implements IHasExternalSystem{
    public Datetime dateFrom;
    public Datetime dateTo;
    public ExternalSystem extSystem;
    public boolean followOn;
    public String lastRowId;
    public boolean testResponseSet;
    public Integer batchSize;
    protected Set<Id> hasChanged;

    private static final Integer CYCLE_INTERVAL = 15;//minutes 

    public String className{
        get;
        private set;
    }

    public String jobName{
        get{
            return this.className +'_'+this.extSystem.companyName;
        }
    }

    public boolean isSelfQueueable{
        get{
            try{
                return Queueable__mdt.getInstance(this.className).SelfQueueable__c;
            }
            catch(Exception selfQueueException){
                return false;
            }
        }
    }

    //start date based on current user's timezone
    public String getStartDate(){
        return this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
    }

    public String getEndDate(){
        return this.dateTo.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
    }

    public void updateLastRun(){
        Service_Run__c jobRun = [SELECT Name,Last_Run__c FROM Service_Run__c WHERE Name = :this.jobName][0];
        jobRun.Last_Run__c = this.DateTo;
        update jobRun;
    }

    public Resource(ExternalSystem extSystem){
        this();
        this.extSystem = extSystem;
        this.dateFrom = SQL_API_Base.getRunTime(this.jobName);
    }

    public Resource(){
        this.dateTo = Datetime.now();
        this.className = Util.getClassname(this);
        this.hasChanged = new Set<Id>();
        this.batchSize = 50;
        this.followOn = true;
    }

    public Resource queueNext(boolean queue){
        Type resourceInstance;
        try{
            String nextResourceName = ResourceControl__mdt.getInstance(this.jobName).target__c;
            resourceInstance = Type.forName(nextResourceName);
        }
        catch(Exception e){
            String companyCode = this.extSystem.companyName;
            return Resource.queueStart(companyCode);
        }
        if(resourceInstance != null){
            Resource nextResource = (Resource) resourceInstance.newInstance();
            nextResource.setExternalSystem(this.extSystem);
            nextResource.dateTo = this.dateTo;
            if(queue){
                System.enqueueJob(nextResource);
            }
            return nextResource;
        }
        else{
            String companyCode = this.extSystem.companyName;
            return Resource.queueStart(companyCode);
        }
    }

    public static Resource queueStart(String companyCode){
        String message = 'resource for Company: '+companyCode+ 'not queued/halted';
        String priority = ApplicationLogUtility.PRIORITY_HIGH;
        String className = 'Resource';
        
        ExternalSystem extSystem = new ExternalSystem(companyCode);
        String startClassName = ResourceControl__mdt.getInstance('C'+companyCode).target__c;
        Type resourceInstance = Type.forName(startClassName);
        Resource startResource = (Resource) resourceInstance.newInstance();
        startResource.setExternalSystem(extSystem);
        startResource.dateTo = Datetime.now().addMinutes(CYCLE_INTERVAL);
        String stackTrace = 'queueStart('+companyCode+')';
        stackTrace += 'Target Day: '+ String.valueOf(startResource.dateTo.day());
        stackTrace += '\nCurrent Day:'+String.valueOf(Datetime.now().day());

        if(startResource.dateTo.day() == Datetime.now().day()){
            QueueControl.enqueue(startResource,CYCLE_INTERVAL);
            priority = ApplicationLogUtility.PRIORITY_LOW;
            message = 'Resource for Company: '+ companyCode + ' queued';
        }
        ApplicationLogUtility.insertApexCompletionLog(className,message,stackTrace,priority,false);
        return startResource;
    }

    public void setExternalSystem(ExternalSystem extSystem){
        this.extSystem = extSystem;
        this.dateFrom = this.dateFrom = SQL_API_Base.getRunTime(this.jobName);
    }

    protected sObject put(sObject sObjRecord, String fieldname, Object newValue){
        Object oldValue = sObjRecord.put(fieldname, newValue);
        if(sObjRecord.get('Id')!= null && oldValue != newValue){
            this.hasChanged.add(Id.valueOf(String.valueOf(sObjRecord.get('Id'))));
        }
        return sObjRecord;
    }
}