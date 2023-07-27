global class SQL_API_Sched implements Database.AllowsCallouts, Schedulable {
    private static final string JOB_NAME = 'SQL_API_Sched';
    public static final Integer INTERVAL = SQL_API_Base.INTERVAL;

    global static void scheduleJob() {
        /** Start from 3rd minute, so we could have cross day retrieval for non-timestamp records */
        for (Integer i = 10; i < 60; i += INTERVAL) {
            string jobName = 'SQL API (' + JOB_NAME + ') ' + String.valueOf(i).leftPad(2, '0');
            string cronExp = '0 ' + i + ' * * * ?';
            SQL_API_Sched schedulable = new SQL_API_Sched();
            if (Test.isRunningTest()) { jobName += '_Test'; }

            System.schedule(jobName, cronExp, schedulable);
        }
    }

    global void execute(SchedulableContext sc) {
        /*
        SQL_Acc_Queue queueable = new SQL_Acc_Queue();
        queueable.dateTo = Datetime.now();
        queueable.followOnToVeh = true;
        if (!Test.isRunningTest()) { System.enqueueJob(queueable); }
        */
        /*
        SQL_ESA_Queue esaQueue = new SQL_ESA_Queue();
        esaQueue.dateTo = Datetime.now();
        esaQueue.followOnToVeh = true;
        if(!Test.isRunningTest()){
            System.enqueueJob(esaQueue);
        }
        */
        //queue care db classes
        ExternalSystem careDbSystem = new ExternalSystem(ExternalSystem.Type.CareDb);
        ExtSysAccountResource esaResourceCare = new ExtSysAccountResource(careDbSystem);
        esaResourceCare.followOn = false;
        System.enqueueJob(esaResourceCare);

        //queue gdms resources
        ExternalSystem gdmsSystem = new ExternalSystem(ExternalSystem.Type.GDMS);
        ExtSysAccountResource esaResourceGdms = new ExtSysAccountResource(gdmsSystem);
        esaResourceGdms.followOn = false;
        System.enqueueJob(esaResourceGdms);
        
    }
}