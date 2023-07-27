global class CustAppCallbackQueue implements Queueable, Database.AllowsCallouts {
	List<Customer_App_Callback__e> events;
	public CustAppCallbackQueue(List<Customer_App_Callback__e> callbacks) { this.events = new List<Customer_App_Callback__e>(callbacks); }

	public void execute(QueueableContext context) {
		try {
			if (this.events == null || this.events.isEmpty()) { return; }
			Customer_App_Callback__e evt = this.events.remove(0);
			CustAppCallbackQueue.processCallback(evt);
			if (this.events.size() > 0 && Limits.getLimitQueueableJobs() > Limits.getQueueableJobs() && !Test.isRunningTest()) {
				System.enqueueJob(new CustAppCallbackQueue(this.events));
			}
		} catch (Exception e) {
			String emailBody = CommonMethodsLibrary.constructErrEmail('Error from CustAppCallbackQueue', e.getStackTraceString(), e.getMessage());
			System.debug('CustAppCallbackQueue Error: ' + emailBody);
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
		}
	}
	
	public static void enqueue(List<Customer_App_Callback__e> callbackList) {
		try {
			System.enqueueJob(new CustAppCallbackQueue(trigger.new));
		} catch (Exception e) {
			String emailBody = CommonMethodsLibrary.constructErrEmail('Error from CustAppTrigger', e.getStackTraceString(), e.getMessage());
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
		}
	}

	public static void processCallback(Customer_App_Callback__e callback) {
		System.debug(callback.Event__c + ': CustAppCallbackQueue.processCallback(): ' + JSON.serialize(callback));
		try {
			switch on callback.Event__c {  // switch to final static variable of class when possible
				when 'UPDATE_ACCOUNT' {
					CustAppAccount.sendWebhook(callback);
				} when 'RESYNC_ACCOUNT' {
					CustAppAccountAPI.sendResyncWebhook(callback);
				} when 'UPSERT_VEHICLE' {
					CustAppVehicle.sendWebhook(callback);
				} when 'REMOVE_VEHICLE' {
					CustAppVehicle.sendWebhookRemoveVo(callback);
				} when 'REMOVE_VEHICLE_ALTERNATE_DRIVER', 'UPSERT_VEHICLE_ALTERNATE_DRIVER' {
					CustAppAltDriver.sendWebhook(callback);
				} when 'UPSERT_VEHICLE_APPOINTMENT' {
					Id roOrApptId = callback.Id__c;
					if (roOrApptId.getSObjectType() == Schema.ServiceOrder__c.getSObjectType()) {
						CustAppRO.sendWebhook(callback);
					} else {
						CustAppAppt.sendWebhook(callback);
					}
				// } when 'NOTIFY_REPAIR_ORDER_STATUS' {
				// 	CustAppRO.sendWebhook(callback, true);
				} when 'REMOVE_VEHICLE_APPOINTMENT' {
					CustAppAppt.sendWebhook(callback);
				} when 'REMOVE_VEHICLE_REPAIR_ORDER' {
					CustAppRO.sendWebhook(callback);
				} when 'UPSERT_TEST_DRIVE' {
					// CustAppTD.sendWebhook(callback);
				} when 'UPSERT_VEHICLE_WARRANTY' {
					CustAppVehicle.sendWarrantyWebhook(callback);
				} when 'UPDATE_ENQUIRY' {
					CustAppEnquiry.sendWebhook(callback);
				} when else {
					throw new CustAppAPI.CustAppException('Unexpected callback Event: ' + callback.Event__c);
				}
			}
		} catch (Exception e) {
			String subject = Envir.subject + ': Callback to WHIP error!';
			string header = 'CustAppCallbackQueue.cls';
			string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
			string error = callback.getSObjectType().getDescribe().getName() + ':\n' + JSON.serialize(callback);
			string emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
			System.debug(emailBody);
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody, true, subject);
		}
	}
}