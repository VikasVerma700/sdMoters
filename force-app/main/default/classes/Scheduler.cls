global class Scheduler implements Schedulable
{
	public List<String> jobIdList;
	public Scheduler(){
		this.jobIdList = new List<String>();
	}
	global void execute(SchedulableContext ctx) {
		//schedulable emails for app logs
		try{
			ApplicationLogAlerts appLogBatchable = new ApplicationLogAlerts(Datetime.now(),false);
			System.scheduleBatch(appLogBatchable, appLogBatchable.batchJobName, 540);// 9AM Maylasian time. 1AM GMT 6:30 AM IST
		}
		catch(Exception appLogError){
			ApplicationLogUtility.insertApexErrorLog(this, appLogError,ApplicationLogUtility.PRIORITY_HIGH,true);
		}

		//schedule first case batch for the day
		try{
			CaseBatch caseBatchJob = new CaseBatch(CaseBatch.BatchType.TYPE_A, Datetime.now(),true);
			this.jobIdList.add(System.scheduleBatch(caseBatchJob,caseBatchJob.batchJobName, 0,10));
		}
		catch(Exception caseBatchError){
			ApplicationLogUtility.insertApexErrorLog(this, caseBatchError,ApplicationLogUtility.PRIORITY_HIGH,true);
		}

        /*
		//execute emp resource 
		try{
			ExternalSystem gdmsInternal = new ExternalSystem(CompanyRepository.C099);
			EmployeeMasterResource empMaster099Resource = new EmployeeMasterResource(gdmsInternal);
			System.enqueueJob(empMaster099Resource);
		}
		catch(Exception empMasterError){
			ApplicationLogUtility.insertApexErrorLog(this, empMasterError,ApplicationLogUtility.PRIORITY_HIGH,true);
		}
		
		//start resource control for company 099
		try{
			Resource.queueStart(CompanyRepository.C099);
		}
		catch(Exception C099Error){
			ApplicationLogUtility.insertApexErrorLog(this, C099Error,ApplicationLogUtility.PRIORITY_HIGH,true);
		}

        //start resource control for company 199
		try{
			Resource.queueStart(CompanyRepository.C199);
		}
		catch(Exception C199Error){
			ApplicationLogUtility.insertApexErrorLog(this, C199Error,ApplicationLogUtility.PRIORITY_HIGH,true);
		}
        */

		//queue report emails
		try{
			ReportAlerts rAlerts = new ReportAlerts();
			System.enqueueJob(rAlerts);
		}
		catch(Exception reportAlertError){
			ApplicationLogUtility.insertApexErrorLog(this, reportAlertError,ApplicationLogUtility.PRIORITY_HIGH,true);
		}
	}
}