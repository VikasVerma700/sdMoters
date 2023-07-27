global without sharing class CustAppCampaignMember {
	public final static String EVENT_NAME = 'UPSERT_MARKETING_RSVP';

	public static void processCallback() {
		RestRequest req = RestContext.request;
		CmpgMemberHook reqBody = (CmpgMemberHook) JSON.deserialize(req.requestBody.toString(), CmpgMemberHook.class);
		if (reqBody == null || reqBody.payload == null) { throw new CustAppAPI.CustAppException('Empty payload.'); }
		CmpgMemberInfo payload = reqBody.payload;
		if (String.isBlank(payload.campaign) || String.isBlank(payload.accountUuid)) {
			throw new CustAppAPI.CustAppException('Invalid payload.');
		}
		String type = CustAppAccount.EXT_ACC_TYPE.get(payload.companyId);
		if (String.isBlank(type)) { throw new CustAppAPI.CustAppException('Unknown company id.'); }
		List<Customer_External_Account__c> custAccList = [SELECT Id, Type__c, Account__c, Account__r.Partial_NRIC__c, Account__r.NRIC_Number_wo_Prefix__c,
															Account__r.Doc_Type__c, Account__r.PersonContactId FROM Customer_External_Account__c WHERE
															UUID__c = :payload.accountUuid AND Type__c = :type];
		if (custAccList.size() <= 0) { throw new CustAppAPI.CustAppException('Unknown customer uuid'); }
		List<CampaignMember> memberList = [SELECT Id, RSVP_Status__c, RSVP_Guests__c, Remarks__c FROM CampaignMember WHERE
											Campaign.External_Display_Name__c = :payload.campaign AND ContactId = :custAccList[0].Account__r.PersonContactId];
		CampaignMember cm = (memberList.size() <= 0) ? new CampaignMember() : memberList[0];
		if (cm.Id == null) {
			List<Campaign> cmList = [SELECT Id FROM Campaign WHERE External_Display_Name__c = :payload.campaign ORDER BY CreatedDate DESC LIMIT 1];
			if (cmList.size() <= 0) { throw new CustAppAPI.CustAppException('Invalid campaign.'); }
			cm.CampaignId = cmList[0].Id;
			cm.Account_Name__c = custAccList[0].Account__c;
			cm.ContactId = custAccList[0].Account__r.PersonContactId;
			cm.Source__c = 'BMW Customer App';
		}
		cm.RSVP_Guests__c = payload.pax;
		String remarks = 'Ref:' + payload.referenceNumber;
		remarks += (payload.selectedDate != null) ? ('\nSelected Date/Time:' + payload.selectedDate.startDate.format('dd/MM/yyyy hh:mm') + ' to ' +
					payload.selectedDate.endDate.format('dd/MM/yyyy hh:mm')) : '';
		cm.Remarks__c = (String.isBlank(cm.Remarks__c)) ? remarks : (cm.Remarks__c + '\n' + remarks);
		switch on (payload.status) {
			when 'UPDATED', 'RESERVED' {
				// TODO check what needs to be done for updated
				cm.RSVP_Status__c = 'Accepted';
			} when 'ATTENDED' {
				cm.RSVP_Status__c = 'Arrived';
			} when 'CANCELED' {
				cm.RSVP_Status__c = 'Rejected';
			} when else {
				cm.RSVP_Status__c = payload.status;
			}
		}
		upsert cm;
	}

	global class CmpgMemberHook {
		public String event;
		public CmpgMemberInfo payload;
	}

	global class CmpgMemberInfo {
		public String campaign;
		public CmpgDate selectedDate;
		public String accountUuid;
		public String companyId;
		public Integer pax;
		public String referenceNumber;
		public String status;
	}

	global class CmpgDate {
		public DateTime startDate;
		public DateTime endDate;
	}
}