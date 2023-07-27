global without sharing class CustAppCampaign {
	public final static String EVENT_NAME = 'UPSERT_MARKETING_CAMPAIGN';
	public final static String REM_EVENT = 'REMOVE_MARKETING_CAMPAIGN';
	public final static Map<String, String> CMPG_CMP_MAP = new Map<String, String> { '028' => 'BMW Customer App' };
	public static List<String> CMPG_FIELDS;
	public static List<String> CMPG_MEM_FIELDS;

	static {
		CMPG_FIELDS = new List<String> { 'Id', 'Name', 'External_Display_Name__c', 'Company__r.Name' };
		CMPG_MEM_FIELDS = new List<String> { 'Id, ContactId' };
		String cmpgMem = '(SELECT ' + String.join(CMPG_MEM_FIELDS, ',') + ' FROM CampaignMembers WHERE ContactId != null)';
		CMPG_FIELDS.add(cmpgMem);
	}

	public static void sendWebhook(Customer_App_Callback__e callback) {
		String cmpgId = callback.Id__c;
		String query = 'SELECT ' + String.join(CMPG_FIELDS, ',') + ' FROM Campaign WHERE Id = :cmpgId';
		List<Campaign> cmpgList = Database.query(query);
		if (cmpgList.size() <= 0) { return; }
		List<Id> contactIdList = new List<Id>();
		for (CampaignMember cm : cmpgList[0].CampaignMembers) { contactIdList.add(cm.ContactId); }
		Set<String> types = new Set<String>();
		for (Campaign cmpg : cmpgList) {
			String custType = CMPG_CMP_MAP.get(cmpg.Company__r.Name);
			if (String.isBlank(custType)) { continue; }
			types.add(custType);
		}
		List<Account> accList = [SELECT Id, PersonContactId FROM Account WHERE PersonContactId = :contactIdList];
		List<Id> accIdList = new List<Id>();
		Map<Id, Id> contactToAcc = new Map<Id, Id>();
		for (Account acc : accList) {
			accIdList.add(acc.Id);
			contactToAcc.put(acc.PersonContactId, acc.Id);
		}
		Map<Id, List<Customer_External_Account__c>> accounts = CustAppAccount.getExtAccounts(accIdList, types);
		if (accounts.size() <= 0) { return; }
		Map<Id, List<String>> uuidMap = new Map<Id, List<String>>();
		for (Campaign cmpg : cmpgList) {
			Set<String> uuids = new Set<String>();
			for (CampaignMember cm : cmpg.CampaignMembers) {
				Id accId = contactToAcc.get(cm.ContactId);
				if (accId == null) { continue; }
				List<Customer_External_Account__c> extAccs = accounts.get(accId);
				if (extAccs == null) { continue; }
				for (Customer_External_Account__c extA : extAccs) { uuids.add(extA.UUID__c); }
			}
			uuidMap.put(cmpg.Id, new List<String>(uuids));
		}

		for (Campaign cmpg : cmpgList) {
			String hookBody;
			if (callback.Event__c == 'REMOVE_MARKETING_CAMPAIGN') {
				RemoveCmpgPayload payload = new RemoveCmpgPayload(cmpg);
				RemoveCmpgWebHook hook = new RemoveCmpgWebHook(REM_EVENT, payload);
				hookBody = JSON.serialize(hook);
			} else {
				CmpgPayload payload = new CmpgPayload(cmpg, uuidMap.get(cmpg.Id));
				CmpgWebhook hook = new CmpgWebhook(EVENT_NAME, payload);
				hookBody = JSON.serialize(hook);
			}
			CustAppAPI.sendWebhook(hookBody);
		}
	}

	global class RemoveCmpgWebHook {
		public String event;
		public RemoveCmpgPayload payload;
		global RemoveCmpgWebHook(String event, RemoveCmpgPayload payload) {
			this.event = event;
			this.payload = payload;
		}
	}

	global class RemoveCmpgPayload {
		public RemoveCmpgInfo campaign;
		public RemoveCmpgPayload(Campaign cmpg) {
			this.campaign = new RemoveCmpgInfo(cmpg);
		}
	}

	global class RemoveCmpgInfo {
		public String name;
		public RemoveCmpgInfo(Campaign cmpg) {
			this.name = cmpg.Name;
		}
	}

	global class CmpgWebHook {
		public String event;
		public CmpgPayload payload;
		global CmpgWebhook(String event, CmpgPayload payload) {
			this.event = event;
			this.payload = payload;
		}
	}

	global class CmpgPayload {
		public CmpgInfo campaign;
		public CmpgPayload(Campaign cmpg, List<String> uuids) {
			this.campaign = new CmpgInfo(cmpg, uuids);
		}
	}

	global class CmpgInfo {
		public String name;
		public List<String> accountUuids;
		public CmpgInfo(Campaign cmpg, List<String> uuids) {
			this.name = cmpg.Name;
			this.accountUuids = uuids;
		}
	}
}