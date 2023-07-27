public class ServiceApptSMSConfirm {
	@InvocableMethod(label='Send confirmation SMS' description='Sends confirmation SMS for service appointment.')
	public static void smsConfirmation(List<Id> saList) {
		if (System.isFuture() || System.isBatch() || (Limits.getAsyncCalls() + saList.size()) > Limits.getLimitAsyncCalls()) {
			return;
		}
		sendFutureConfirmation(saList);
	}

	@Future(callout=true)
	public static void sendFutureConfirmation(List<Id> saList) {
		sendConfirmation(saList);
	}

	public static void sendConfirmation(List<Id> saList) {
		try {
			List<Service_Appointment__c> appts = [
				SELECT
					Id, Name, OwnerId, Company__r.Name, Workshop__r.Name
					, Contact_No__c, Service_Request__c
					, ConfirmSms__c, ConfirmSmsText__c
				FROM Service_Appointment__c
				WHERE Id = :saList
				AND Company__r.Name = '028'
				AND Apppointment_Status__c = 'ACTIVE'
				AND Appt_Type__c = 'Service Appointment'
				AND ConfirmSms__c = true
			];
			List<Task> taskRec = new List<Task>();
			//string sendRes;
			M3TechApiServiceWrapper.DeliverMsgReturnWrapper sendRes= new M3TechApiServiceWrapper.DeliverMsgReturnWrapper();
			string smsText;
			Task curT;
			for (Service_Appointment__c sa : appts) {
				try {
					smsText = sa.ConfirmSmsText__c;
          			sendRes = ServiceApptBooking.sendApptSMS2(sa, smsText);
				}
				catch (Exception e) { sendRes.returnDesc = e.getMessage(); }
				curT = CommonMethodsLibrary.createTask(null, sa.Id, sa.OwnerId, 'Automated Tasks', 'System Generated Tasks', '', 'Low', 'Confirmation SMS', false, null);
				curT.Status = 'Completed';
				curT.ActivityDate = Date.today();
				curT.Description = 'Text:' + smsText;
				curT.MsgID__c = sendRes.msgId;
				curT.PhoneNumber__c = sendRes.mobileNumber;
				curT.ResponseCode__c = sendRes.returnCode + ' '+ sendRes.returnDesc;
				curT.SMSCount__c = sendRes.smsCount;
				taskRec.add(curT);
      		}
			List<Database.SaveResult> srList = Database.insert(taskRec, false);
			CommonMethodsLibrary.emailResultFailure(srList, taskRec, 'sendConfirmation', 'ServiceApptBooking', ServiceApptBooking.ERR_USER);
		}
		catch (Exception e) {
			String emailBody = CommonMethodsLibrary.constructErrEmail('ServiceApptBooking', e.getStackTraceString(), e.getMessage());
			CommonMethodsLibrary.sendErrorEmail(ServiceApptBooking.ERR_USER, emailBody);
		}
	}
}