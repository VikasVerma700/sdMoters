public class NotificationHandler extends TriggerBase {
	public static final String TRIG_SETTING = 'Notification';
	public NotificationHandler() { super(TRIG_SETTING, 2); }

	public override void afterInsert(Map<Id, SObject> triggerNew) {
		createSends(triggerNew);
		sendCustAppNotifications(triggerNew);
	}

	public override void afterUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
		createSends(triggerNew);
		sendCustAppNotifications(triggerNew);
	}

	public static void sendCustAppNotifications(Map<Id, SObject> triggerNew) {
		try {
			Set<Id> toSend = new Set<Id>();
			Set<String> appIds = CustAppAccount.REV_TYPE.keySet();
			for (SObject so : triggerNew.values()) {
				Notification__c curN = (Notification__c) so;
				if (curN.Account__c != null && appIds.contains(curN.App_ID__c)) { toSend.add(curN.Id); }
			}
			if (toSend.size() <= 0) { return; }
			if (Limits.getLimitQueueableJobs() <= Limits.getQueueableJobs()) {
				throw new CustAppAPI.CustAppException('Unable to send Notifications ' + toSend);
			} else {
				/** Convert to Database.executeBatch() because conflict with existing SQL Sync using Apex Queue */
				CustAppNotification pn = new CustAppNotification(new List<Id>(toSend));
				if (!System.isQueueable()) { System.enqueueJob(pn); }
				else if (!System.isBatch()) { Database.executeBatch(pn, 1); }
				else { throw new CustAppAPI.CustAppException('Failed to execute either Queue or Batch ' + toSend); }
			}
		} catch (Exception e) {
			String errBody = CommonMethodsLibrary.constructErrEmail('NotificationHandler:sendCustAppNotifications', e.getStackTraceString(), e.getMessage());
			// CommonMethodsLibrary.sendErrorEmail(TriggerBase.ERR_USER, errBody);
			CommonMethodsLibrary.sendErrorEmail(SQL_API_Base.USER_ADMINS, errBody);
		}
	}

	public static void createSends(Map<Id, SObject> triggerNew) {
		try {
			Map<Id, Notification__c> unread = filterUserUnread(triggerNew);
			Map<Id, Map<String, List<User_Message_Token__c>>> tokenMap = getMessageTokens(unread.values());
			Map<Id, Set<Id>> seenMsgToken = getAlreadySent(unread.values());
			List<Notification_Send__c> needSend = new List<Notification_Send__c>();
			Map<String, List<User_Message_Token__c>> appTokenMap;
			List<User_Message_Token__c> curTokens;
			Set<Id> seenSet;
			Notification_Send__c newSend;
			for (Notification__c n : unread.values()) {
				appTokenMap = tokenMap.get(n.User__c);
				if (appTokenMap == null) { continue; }
				curTokens = appTokenMap.get(n.App_ID__c);
				if (curTokens == null) { continue; }
				seenSet = seenMsgToken.get(n.Id);
				for (User_Message_Token__c t : curTokens) {
					if (seenSet != null && seenSet.contains(t.Id)) { continue; }
					if (t.CreatedDate > n.CreatedDate) { continue; }
					newSend = new Notification_Send__c();
					newSend.Notification__c = n.Id;
					newSend.User_Message_Token__c = t.Id;
					newSend.Name = n.Name + '-' + t.Device_Name__c;
					newSend.Name = (newSend.name.length() > 80) ? (newSend.name.left(78) + '..') : newSend.name;
					needSend.add(newSend);
				}
			}
			if (needSend.size() > 0) {
				List<Database.SaveResult> srList = Database.insert(needSend, false);
				CommonMethodsLibrary.emailResultFailure(srList, needSend, 'NotificationHandler', 'createSends', TriggerBase.ERR_USER);
			}
		} catch (Exception e) {
			String errBody = CommonMethodsLibrary.constructErrEmail('NotificationHandler:createSends', e.getStackTraceString(), e.getMessage());
			CommonMethodsLibrary.sendErrorEmail(TriggerBase.ERR_USER, errBody);
		}
	}

	private static Map<Id, Map<String, List<User_Message_Token__c>>> getMessageTokens(List<Notification__c> notificationList) {
		Set<Id> userIds = new Set<Id>();
		Set<String> appIds = new Set<String>();
		for (Notification__c n : notificationList) {
			userIds.add(n.User__c);
			appIds.add(n.App_ID__c);
		}
		List<User_Message_Token__c> tokens = [SELECT Id, User__c, Token__c, Device_Name__c, App_ID__c, CreatedDate FROM User_Message_Token__c WHERE
												IsActive__c = TRUE AND User__c IN :userIds AND App_ID__c IN :appIds];
		Map<Id, Map<String, List<User_Message_Token__c>>> tokenMap = new Map<Id, Map<String, List<User_Message_Token__c>>>();
		Map<String, List<User_Message_Token__c>> innerMap;
		List<User_Message_Token__c> tokenList;
		for (User_Message_Token__c t : tokens) {
			innerMap = tokenMap.get(t.User__c);
			innerMap = (innerMap == null) ? new Map<String, List<User_Message_Token__c>>() : innerMap;
			tokenList = innerMap.get(t.App_ID__c);
			tokenList = (tokenList == null) ? new List<User_Message_Token__c>() : tokenList;
			tokenList.add(t);
			innerMap.put(t.App_ID__c, tokenList);
			tokenMap.put(t.User__c, innerMap);
		}
		return tokenMap;
	}

	private static Map<Id, Set<Id>> getAlreadySent(List<Notification__c> notificationList) {
		List<Notification_Send__c> sentList = [SELECT Id, Notification__c, User_Message_Token__c FROM Notification_Send__c
												WHERE Notification__c IN :notificationList];
		Map<Id, Set<Id>> seenMsgToken = new Map<Id, Set<Id>>();
		Set<Id> curSet;
		for (Notification_Send__c n : sentList) {
			curSet = seenMsgToken.get(n.Notification__c);
			curSet = (curSet == null) ? new Set<Id>() : curSet;
			curSet.add(n.User_Message_Token__c);
			seenMsgToken.put(n.Notification__c, curSet);
		}
		return seenMsgToken;
	}

	private static Map<Id, Notification__c> filterUserUnread(Map<Id, SObject> triggerNew) {
		Map<Id, Notification__c> unread = new Map<Id, Notification__c>();
		Notification__c curN;
		for (SObject so : triggerNew.values()) {
			curN = (Notification__c) so;
			if (curN.User__c != null && !curN.Read__c) {
				unread.put(curN.Id, curN);
			}
		}
		return unread;
	}
}