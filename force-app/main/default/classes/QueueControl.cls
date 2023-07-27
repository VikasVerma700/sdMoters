public with sharing class QueueControl implements Queueable{
    Integer delay;// a delay in minutes
    Object job;

    public QueueControl(Object job, Integer delay){
        this.delay = delay;
        this.job = job;
    }

    //static method to queue other Queueable jobs who wish to be executed after more than  10 minutes 
    public static void enqueue(Object queueJob,Integer delay){
        QueueControl qControl = new QueueControl(queueJob, delay);
        System.enqueueJob(qControl);

    }

    public void execute(QueueableContext qContext){
        if(this.delay > 10){
            this.delay -= 10;
            this.enqueueTest(this, 10);// queue QueueControl class' instance to execute and check after 10 minutes
        }
        else{
            this.enqueueTest(this.job,delay);
        }
    }

    private void enqueueTest(Object queueJob, Integer delay){
        if(!Test.isRunningTest()){
            System.enqueueJob(queueJob, delay);
        }
        ApplicationLogUtility.insertApexCompletionLog(Util.getClassname(this),'Queued: '+Util.getClassname(queueJob),'EnqueueTest',ApplicationLogUtility.PRIORITY_HIGH,false);
    }
}