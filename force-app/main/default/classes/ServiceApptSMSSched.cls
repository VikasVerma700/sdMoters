global class ServiceApptSMSSched implements Schedulable, Database.Batchable<sObject>, Database.AllowsCallouts {

/** Schedule Job methods */
	global static String scheduleJob() {
		string name = 'Service Appointment SMS Reminder/Missed (ServiceApptSMSSched)';
		string jobName = (Test.isRunningTest() ? '[Test] ' + name: name);
		return System.schedule(jobName, '0 0 12 * * ? *', new ServiceApptSMSSched());
	}

	global void execute(SchedulableContext sc) { Database.executeBatch(this, 1); }

/** Batchable methods */
	global String query;
	public ServiceApptSMSSched() {
		this.query =
			'SELECT Id, Appointment_Date__c, Apppointment_Status__c, Company__r.Name, RemindSmsSendAt__c ' +
			'FROM Service_Appointment__c ' +
			'WHERE Company__r.Name = \'028\' ' +
			'AND Apppointment_Status__c IN (\'ACTIVE\', \'NO SHOW\') ' +
			'AND Appt_Type__c = \'Service Appointment\' ' +
			// 'AND (DAY_ONLY(Appointment_Date__c) = NEXT_N_DAYS:1 ' +
			'AND (DAY_ONLY(RemindSmsSendAt__c) = TODAY ' +
			'	OR DAY_ONLY(Appointment_Date__c) = YESTERDAY)';
	}

	global Database.QueryLocator start(Database.BatchableContext BC) { return Database.getQueryLocator(query); }

	global void execute(Database.BatchableContext BC, List<sObject> scope) {
		try {
			// Date next2Days = Date.today().addDays(1);
			List<Id> reminderList = new List<Id>();
			List<Id> missedList = new List<Id>();
			for (sObject s : scope) {
				Service_Appointment__c sa = (Service_Appointment__c) s;
				if (sa.Apppointment_Status__c == 'ACTIVE' && sa.RemindSmsSendAt__c.date() == Date.today() /* next2Days */) {
					reminderList.add(sa.Id);
				}
				else if (sa.Apppointment_Status__c == 'NO SHOW' && sa.Appointment_Date__c.date() == Date.today().addDays(-1)) {
					missedList.add(sa.Id);
				}
			}
			if (!Test.isRunningTest() && reminderList.size() > 0) { ServiceApptSMSReminder.sendReminder(reminderList); }

			if (!Test.isRunningTest() && missedList.size() > 0) { ServiceApptSMSMissed.sendMissedAppt(missedList); }
		} catch (Exception e) {
			String emailBody = CommonMethodsLibrary.constructErrEmail('ServiceApptSMSSched', e.getStackTraceString(), e.getMessage());
			CommonMethodsLibrary.sendErrorEmail(ServiceApptBooking.ERR_USER, emailBody);
		}
	}

	global void finish(Database.BatchableContext BC) {}
}