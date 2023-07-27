public with sharing class ServiceApptSMSMissed {
	@InvocableMethod(label='Send missed SMS' description='Sends missed SMS for service appointment.')
	public static void smsMissedAppt(List<Id> saList) {
		if (System.isFuture() || System.isBatch() || (Limits.getAsyncCalls() + saList.size()) > Limits.getLimitAsyncCalls()) { return; }
		sendFutureMissedSMS(saList);
 	}

	@Future(callout=true)
	public static void sendFutureMissedSMS(List<Id> saList) { sendMissedAppt(saList); }

	public static void sendMissedAppt(List<Id> saList) {
		try {
			List<Service_Appointment__c> appts = [
				SELECT
					Id, Name, OwnerId, Company__r.Name, Workshop__r.Name
					, Contact_No__c, Service_Request__c
					, MissSms__c, MissSmsText__c
				FROM Service_Appointment__c
				WHERE Id = :saList
				AND Company__r.Name = '028'
				AND Appt_Type__c = 'Service Appointment'
				AND Apppointment_Status__c = 'NO SHOW'
				AND Appointment_Date__c < TODAY
				AND MissSms__c = true
			];
			List<Task> taskRec = new List<Task>();
			//string sendRes;
			M3TechApiServiceWrapper.DeliverMsgReturnWrapper sendRes= new M3TechApiServiceWrapper.DeliverMsgReturnWrapper();
			string smsText;
			Task curT;
			for (Service_Appointment__c sa : appts) {
				try {
					smsText = sa.MissSmsText__c;
					sendRes = ServiceApptBooking.sendApptSMS2(sa, smsText);
				}
				catch (Exception e) { sendRes.returnDesc = e.getMessage(); }
				curT = CommonMethodsLibrary.createTask(null, sa.Id, sa.OwnerId, 'Automated Tasks', 'System Generated Tasks', '', 'Low', 'Missed Appt SMS', false, null);
				curT.Status = 'Completed';
				curT.ActivityDate = Date.today();
				curT.Description = 'Text:' + smsText;
				curT.MsgID__C = sendRes.msgId;
				curT.PhoneNumber__c = sendRes.mobileNumber;
				curT.responseCode__c = sendRes.returnCode +' '+ sendRes.returnDesc;
				curT.smsCount__c = sendRes.smsCount;
				taskRec.add(curT);
			}
			List<Database.SaveResult> srList = Database.insert(taskRec, false);
			CommonMethodsLibrary.emailResultFailure(srList, taskRec, 'sendMissedAppt', 'ServiceApptBooking', ServiceApptBooking.ERR_USER);
		} catch (Exception e) {
			String emailBody = CommonMethodsLibrary.constructErrEmail('ServiceApptBooking', e.getStackTraceString(), e.getMessage());
			CommonMethodsLibrary.sendErrorEmail(ServiceApptBooking.ERR_USER, emailBody);
		}
	}
}