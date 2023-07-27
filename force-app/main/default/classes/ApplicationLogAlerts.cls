public class ApplicationLogAlerts implements Schedulable,Database.Batchable<SObject>{
    public String batchJobName;
    public Datetime instantiatedTime;
    public Datetime expectedFireTime;
    public Boolean scheduleNext;
    private static final Integer SCHEDULE_INTERVAL = 30;
    public List<String> jobIdList{
        get{
            return this.jobIdList;
        }
        private set;
    }

    public static String SCHEDULED_JOB_NAME{
        get{
            return 'APP_LOG_SCHEDULE';
        }
        private set;
    }

    public static String BATCH_JOB_NAME{
        get{
            return 'APP_LOG_BATCH';
        }
        private set;
    }

    public ApplicationLogAlerts(Datetime instantiatedTime, Boolean scheduleNext){
        this.instantiatedTime = instantiatedTime;
        this.expectedFireTime = this.instantiatedTime.addMinutes(SCHEDULE_INTERVAL);
        this.batchJobName = BATCH_JOB_NAME+' | '+String.valueOf(instantiatedTime);
        this.scheduleNext = scheduleNext;
    }

    public ApplicationLogAlerts(){
        this.batchJobName = SCHEDULED_JOB_NAME+' | '+ String.valueOf(Date.today());
        this.jobIdList = new List<String>();
    }

    public void execute(SchedulableContext sc) {
        ApplicationLogAlerts batchInstance = new ApplicationLogAlerts(calculateStartDate(0),true);
        this.jobIdList.add(System.scheduleBatch(batchInstance, batchInstance.batchJobName, 0));
        System.debug(this.jobIdList);
    }

    public Database.QueryLocator start(Database.BatchableContext bc){
        List<String> priorityList = ApplicationLogUtility.REGULAR_PRIORITY_LIST;
        //Datetime instantiatedTime = this.instantiatedTime;
        Datetime pastDay = Datetime.now().addHours(-24);
        String query = 'SELECT Id';
        query += ' FROM ApplicationLog__c';
        query += ' WHERE Priority__c IN :priorityList';
        query += ' AND CreatedDate >= :pastDay';
        query += ' ORDER BY CreatedDate';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<ApplicationLog__c> appLogList){
        List<Id> appLogIdList = new List<Id>();
        for(ApplicationLog__c appLog: appLogList){
            appLogIdList.add(appLog.Id);
        }

        ApplicationLogUtility.sendLogAlert(appLogIdList);
    }

    public void finish(Database.BatchableContext bc){
        if(this.scheduleNext){
            if(this.expectedFireTime.day() == this.instantiatedTime.day()){
                ApplicationLogAlerts nextJob = new ApplicationLogAlerts(this.expectedFireTime, true);
                String nextJobId = System.scheduleBatch(nextJob, nextJob.batchJobName, SCHEDULE_INTERVAL);
                String message = 'Job Scheduled\n';
                message = 'JobId : '+nextJobId;
                message += '\n JobName : '+nextJob.batchJobName;
                ApplicationLogUtility.insertApexErrorLog('ApplicationLogAlerts',message,'ApplicationLogAlerts => finish',null, ApplicationLogUtility.PRIORITY_LOW, true);
            }
        }
    }

    public static Datetime calculateStartDate(Integer minutes){
        Date todayDate = Datetime.now().dateGmt();//today's date in GMT
        //Datetime instance of today with empty time
        Datetime todayDatetime = Datetime.newInstanceGMT(todayDate.year(),todayDate.month(),todayDate.day());
        //minutes since January 1, 1970, 00:00:00 GMT till today 12 AM
        Long todayMinutes = todayDatetime.getTime()/60000;
        Long startMinutes = todayMinutes + minutes;
        //datetime instance representing 'interval' minutes since today 12AM
        Datetime startDate = Datetime.newInstance(startMinutes*60000);
        return startDate;
    }
}