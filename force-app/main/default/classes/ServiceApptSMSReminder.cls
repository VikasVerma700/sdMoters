public class ServiceApptSMSReminder {
	@InvocableMethod(label='Send reminder SMS' description='Sends reminder SMS for service appointment.')
	public static void smsReminder(List<Id> saList) {
		if (System.isFuture() || System.isBatch() || (Limits.getAsyncCalls() + saList.size()) > Limits.getLimitAsyncCalls()) { 
			return; 
		}
		sendFutureReminder(saList);
 	}

	@Future(callout=true)
	public static void sendFutureReminder(List<Id> saList) { sendReminder(saList); }

	public static void sendReminder(List<Id> saList) {
		try {
			List<Service_Appointment__c> appts = [
				SELECT
					Id, Name, OwnerId, Company__r.Name, Workshop__r.Name
					, Contact_No__c, Service_Request__c
					, RemindSms__c, RemindSmsText__c
				FROM Service_Appointment__c
				WHERE Id = :saList
					AND Company__r.Name = '028'
					AND Apppointment_Status__c = 'ACTIVE'
					AND Appointment_Date__c > TODAY
					AND Appt_Type__c = 'Service Appointment'
					AND RemindSms__c = true
			];
			List<Task> taskRec = new List<Task>();
			//string sendRes;
			M3TechApiServiceWrapper.DeliverMsgReturnWrapper sendRes= new M3TechApiServiceWrapper.DeliverMsgReturnWrapper();
			string smsText;
			Task curT;
			for (Service_Appointment__c sa : appts) {
				try {
					smsText = sa.RemindSmsText__c;
					sendRes = ServiceApptBooking.sendApptSMS2(sa, smsText);
				}
				catch (Exception e) { sendRes.returnDesc = e.getMessage(); }
				curT = CommonMethodsLibrary.createTask(null, sa.Id, sa.OwnerId, 'Automated Tasks', 'System Generated Tasks', '', 'Low', 'Reminder SMS', false, null);
				curT.Status = 'Completed';
				curT.ActivityDate = Date.today();
				curT.Description = 'Text:' + smsText;
				curT.MsgID__C = sendRes.msgId;
				curT.PhoneNumber__c = sendRes.mobileNumber;
				curT.responseCode__c = sendRes.returnCode + ' '+ sendRes.returnDesc;
				curT.smsCount__c = sendRes.smsCount;
				taskRec.add(curT);
			}
			List<Database.SaveResult> srList = Database.insert(taskRec, false);
			CommonMethodsLibrary.emailResultFailure(srList, taskRec, 'sendReminder', 'ServiceApptBooking', ServiceApptBooking.ERR_USER);
		}
		catch (Exception e) {
			String emailBody = CommonMethodsLibrary.constructErrEmail('ServiceApptBooking', e.getStackTraceString(), e.getMessage());
			CommonMethodsLibrary.sendErrorEmail(ServiceApptBooking.ERR_USER, emailBody);
		}
	}

}