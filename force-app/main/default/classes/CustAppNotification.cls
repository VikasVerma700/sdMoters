global class CustAppNotification implements Queueable, Database.AllowsCallouts, Database.Batchable<SObject> {
	public final static String NOTIFICATION_PREFIX_SUCC = 'App Notification';
	public final static String NOTIFICATION_PREFIX_ERR = 'Failed App Notification';
	private List<Id> notifyList;
	public CustAppNotification(List<Id> notifyList) { this.notifyList = notifyList; }

	public void execute(QueueableContext context) {
		try {
			if (this.notifyList == null || this.notifyList.isEmpty()) { return; }
			Id nId = this.notifyList.remove(0);
			String successSubj = NOTIFICATION_PREFIX_SUCC + '%';
			List<Notification__c> notification = [SELECT Id, Name, Account__c, Company__r.Name, Message__c, Action__c, Data__c, Template__c, App_ID__c,
													(SELECT Id FROM Tasks WHERE Subject LIKE :successSubj) FROM Notification__c WHERE Id = :nId];
			if (notification.size() > 0 && notification[0].Tasks.size() <= 0) { CustAppNotification.sendNotification(notification[0], true); }
			if (this.notifyList.size() > 0 && Limits.getLimitQueueableJobs() > Limits.getQueueableJobs() && !Test.isRunningTest()) {
				System.enqueueJob(new CustAppNotification(this.notifyList));
			}
		} catch (Exception e) {
			String emailBody = CommonMethodsLibrary.constructErrEmail('Error from CustAppNotification', e.getStackTraceString(), e.getMessage());
			System.debug('CustAppNotification Error: ' + emailBody);
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
		}
	}

	public Database.QueryLocator start(Database.BatchableContext BC) {
		if (this.notifyList == null || this.notifyList.isEmpty()) { return null; }
		String successSubj = NOTIFICATION_PREFIX_SUCC + '%';
		return Database.getQueryLocator([SELECT Id, Name, Account__c, Company__r.Name, Message__c, Action__c, Data__c, Template__c, App_ID__c,
										(SELECT Id FROM Tasks WHERE Subject LIKE :successSubj) FROM Notification__c WHERE Id IN :this.notifyList]
		);
	}
	public void execute(Database.BatchableContext BC, List<SObject> scope) {
		if (scope == null || scope.size() == 0) { return; }
		for (SObject sobj :scope) {
			Notification__c notification = (Notification__c)sobj;
			if (notification.Tasks.size() <= 0) {
				CustAppNotification.sendNotification(notification, true);
			}
		}
	}
	public void finish(Database.BatchableContext BC) {
		// do nothing
	}

	public static void processCallback() {
		RestRequest req = RestContext.request;
		NotificationReadPayload reqBody = (NotificationReadPayload) JSON.deserialize(req.requestBody.toString(), NotificationReadPayload.class);
		if (reqBody == null || reqBody.payload == null || reqBody.payload.inboxMessageUuid == null || reqBody.payload.accountUuid == null ||
			reqBody.payload.readAt == null) {
			throw new CustAppAPI.CustAppException('Empty payload');
		}

		String uuid = reqBody.payload.accountUuid;
		List<Customer_External_Account__c> custAccList = CustAppEnquiryBase.getCustAccList(uuid);
		if (custAccList.size() <= 0) { throw new CustAppAPI.CustAppException('Unknown customer UUID.'); }
		List<Notification__c> notificationList = [SELECT Id, First_Read_Datetime__c FROM Notification__c WHERE Ext_UUID__c = :reqBody.payload.inboxMessageUuid
													AND Account__c = :custAccList[0].Account__c];
		if (notificationList.size() <= 0) { throw new CustAppAPI.CustAppException('Invalid inbox message id.'); }
		for (Notification__c n : notificationList) {
			n.Read__c = true;
			n.First_Read_Datetime__c = (n.First_Read_Datetime__c != null) ? n.First_Read_Datetime__c : reqBody.payload.readAt;
		}
		update notificationList;
	}

	public static void sendNotification(Notification__c notification, Boolean createTask) {
		try {
			if (notification.Account__c == null) { throw new CustAppAPI.CustAppException('No account tagged.'); }
			String accType = notification.App_ID__c;
			// String accType = CustAppAccount.EXT_ACC_TYPE.get(notification.Company__r.Name);
			List<Customer_External_Account__c> extAcc = [SELECT Id, Username__c, Account__r.PersonContactId, UUID__c, Type__c FROM Customer_External_Account__c WHERE
														Account__c = :notification.Account__c AND Type__c = :accType AND IsActive__c = TRUE];
			Http http = new Http();
			HttpRequest req = new HttpRequest();
			req.setEndpoint(CustAppAPI.URL_BASE + '/v1.0/account/push-notification');
			req.setMethod('POST');
			req.setHeader('Content-Type', 'application/json');
			req.setHeader('Authorization', 'Bearer ' + CustAppAPI.login(notification.Company__r.Name));
			req.setTimeout(30000);
			List<Task> taskList = new List<Task>();
			List<Notification__c> updNotificationList = new List<Notification__c>();
			for (Customer_External_Account__c acc : extAcc) {
				SQL_API_Base.API_DEBUG api = new SQL_API_Base.API_DEBUG();
				System.debug('trying: ' + acc.Username__c);
				try {
					req.setBody(notificationReq(notification, acc));
					api.parse(req, new string[] { 'Content-Type', 'Authorization' });
					HttpResponse resp = http.send(req);
					api.parse(resp);
					if (resp == null || String.isBlank(resp.getBody())) { throw new CustAppAPI.CustAppException('Invalid response.'); }
					System.debug('push-notification: ' + resp.getBody());
					Response notificationResp = (Response) JSON.deserialize(resp.getBody(), Response.class);
					if (resp.getStatusCode() == 200 || resp.getStatusCode() == 201) {
						if (notificationResp.response == null || notificationResp.response.data == null) {
							throw new CustAppAPI.CustAppException('Invalid Notification response.');
						}
						if (!String.isBlank(notificationResp.response.data.inboxMessageUuid)) {
							updNotificationList.add(new Notification__c(Id = notification.Id, Ext_UUID__c = notificationResp.response.data.inboxMessageUuid));
						}
						taskList.add(createTask(notification, acc, notificationResp.response.data));
					} else {
						throw new CustAppAPI.CustAppException('Invalid status code from CustAppAPI:sendNotification. (' + resp.getStatusCode() + ')');
					}
				} catch (Exception e) {
					taskList.add(createErrTask(notification, acc, e));
				}
				finally { System.debug(api.toString()); }
			}
			if (updNotificationList.size() > 0) {
				List<Database.SaveResult> notifySRList = Database.update(updNotificationList, false);
				CommonMethodsLibrary.emailResultFailure(notifySRList, updNotificationList, 'sendNotification', 'CustAppNotification', CustAppAPI.EMAIL_LIST);
			}
			List<Database.SaveResult> srList = Database.insert(taskList, false);
			CommonMethodsLibrary.emailResultFailure(srList, taskList, 'sendNotification:taskList', 'CustAppNotification', CustAppAPI.EMAIL_LIST);
		} catch (Exception e) {
			String emailBody = CommonMethodsLibrary.constructErrEmail('CustAppNotification', e.getStackTraceString(), e.getMessage());
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
		}
	}

	public static Task createErrTask(Notification__c notification, Customer_External_Account__c acc, Exception e) {
		String subj = NOTIFICATION_PREFIX_ERR + '(' + acc.Type__c + '):' + notification.Name;
		subj = (subj.length() > 80) ? subj.left(77) + '...' : subj;
		Task t = CommonMethodsLibrary.createTask(acc.Account__r.PersonContactId, notification.Id, UserInfo.getUserId(), 'Automated Tasks',
												'System Generated Tasks', '', 'Low', subj, false, null);
		t.Status = 'Completed';
		t.ActivityDate = Date.today();
		t.Description = 'UUID:' + acc.UUID__c + '\n' + e.getStackTraceString();
		return t;
	}

	public static Task createTask(Notification__c notification, Customer_External_Account__c acc, NotificationData data) {
		if (data.account.uuid != acc.UUID__c) { throw new CustAppAPI.CustAppException('UUID do not match.'); }
		String subj = NOTIFICATION_PREFIX_SUCC + '(' + acc.Type__c + '):' + notification.Name;
		subj = (subj.length() > 80) ? subj.left(77) + '...' : subj;
		Task t = CommonMethodsLibrary.createTask(acc.Account__r.PersonContactId, notification.Id, UserInfo.getUserId(), 'Automated Tasks',
												'System Generated Tasks', '', 'Low', subj, false, null);
		t.Status = 'Completed';
		t.ActivityDate = Date.today();
		t.Description = 'UUID:' + data.account.uuid + '\n';
		List<String> results = new List<String>();
		if (data.account == null || String.isBlank(data.account.uuid)) { return t; }
		String template = '{0} ({1} {2}) - {3} ({4}): {5}';
		for (DeliveryStatus d : data.account.devices) {
			List<String> values = new List<String> { d.device?.device, d.device?.os, d.device?.osVersion, acc?.Type__c, d.device?.appVersion, d.deliveryStatus };
			results.add(String.format(template, values));
		}
		t.Description += String.join(results, '\n');
		return t;
	}

	public static String notificationReq(Notification__c notification, Customer_External_Account__c acc) {
		Request reqBody = new Request();
		reqBody.title = notification.Name;
		reqBody.body = notification.Message__c;
		reqBody.accountUuid = acc.UUID__c;
		reqBody.navigation = (!String.isBlank(notification.Action__c)) ? (NavCls) JSON.deserialize(notification.Action__c, NavCls.class) : null;
		reqBody.templateName = (String.isBlank(notification.Template__c)) ? null : notification.Template__c;
		reqBody.customTag = (!String.isBlank(notification.Data__c)) ? (Map<String, String>) JSON.deserialize(notification.Data__c, Map<String, String>.class) :
							null;
		return JSON.serialize(reqBody);
	}

	global class Request {
		public String title;
		public String body;
		public String accountUuid;
		public NavCls navigation;
		public String templateName;
		public Map<String, String> customTag;
	}

	global class NavCls {
		public String screen;
		public Map<String, String> payload;
	}

	global class Response extends CustAppAPI.APIResp {
		global NotificationResp response;
	}

	global class NotificationResp {
		public String message;
		public NotificationData data;
	}

	global class NotificationData {
		public String inboxMessageUuid;
		public AccountData account;
	}

	global class AccountData {
		public String uuid;
		public List<DeliveryStatus> devices;
	}

	global class DeviceInfo extends CustAppAccount.DeviceCls {
		global String appIdentifier;
	}

	global class DeliveryStatus {
		global DeviceInfo device;
		global String deliveryStatus;
	}

	global class NotificationReadPayload {
		public String event;
		public NotificationReadReq payload;
	}

	global class NotificationReadReq {
		public String accountUuid;
		public String inboxMessageUuid;
		public DateTime readAt;
	}
}