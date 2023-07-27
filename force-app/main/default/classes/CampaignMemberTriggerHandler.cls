public class CampaignMemberTriggerHandler extends TriggerBase {
	public static final string TRIG_SETTING = 'Campaign Member';
	public static final string[] trackFieldUpdate = new string[] {
		Util.str(CampaignMember.Status)
		, Util.str(CampaignMember.HasResponded)
		, Util.str(CampaignMember.FirstRespondedDate)
		, Util.str(CampaignMember.Attending__c)
		, Util.str(CampaignMember.CheckIn__c)
		, Util.str(CampaignMember.CheckInMethod__c)
	};

    public CampaignMemberTriggerHandler() {
		super(TRIG_SETTING, 1);
    }

	public override void afterInsert(Map<Id, SObject> triggerNew) {
		Map<Id, CampaignMember> id2CmpgMember = new Map<Id, CampaignMember>([SELECT Id, CampaignId, Campaign.Name, ContactId, Contact.Name FROM CampaignMember WHERE Id IN :triggerNew.keySet()]);

		List<CampaignMemberHistory__c> ch = new List<CampaignMemberHistory__c>(); 
		List<String> changes  = new List<String>();
		List<String> CampHisId  = new List<String>();

		for (CampaignMember cm :(CampaignMember[])triggerNew.values()) {
			ch.add(createActivity(cm.campaignId, id2CmpgMember.get(cm.Id).Campaign.Name, cm.Id, id2CmpgMember.get(cm.Id).Contact.Name));
		}
		insert ch;
	}

	public override void beforeUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
		Map<Id, CampaignMember> id2CmpgMember = new Map<Id, CampaignMember>([SELECT Id, CampaignId, Campaign.Name, ContactId, Contact.Name FROM CampaignMember WHERE Id IN :triggerNew.keySet()]);

		List<CampaignMemberHistory__c> ch = new List<CampaignMemberHistory__c>(); 
		List<CampaignMember> cmOld = triggerOld.values();

		for (CampaignMember cm :(CampaignMember[])triggerNew.values()) {
			CampaignMember cold = (CampaignMember)triggerOld.get(cm.Id);
			CampaignMember cmem = id2CmpgMember.get(cm.Id);

			for (string field :trackFieldUpdate) {
				if (u.chg(field, cm, cold)) {
					ch.add(updateActivity(cm.CampaignId, cmem.Campaign.Name, cm.Id, cmem.Contact.Name, field, cold.get(field), cm.get(field)));
				}
			}
		}
		insert ch;
	}

	public override void beforeDelete(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
		Map<Id, CampaignMember> id2CmpgMember = new Map<Id, CampaignMember>([SELECT Id, CampaignId, Campaign.Name, ContactId, Contact.Name FROM CampaignMember WHERE Id IN :triggerOld.keySet()]);

		List<CampaignMemberHistory__c> ch = new List<CampaignMemberHistory__c>(); 
		List<CampaignMember> cmOld = triggerOld.values();
		List<String> changes  = new List<String>();
		List<String> CampHisId  = new List<String>();

		for (CampaignMember cm :(CampaignMember[])triggerOld.values()) {
			ch.add(deleteActivity(cm.campaignId, id2CmpgMember.get(cm.Id).Campaign.Name, cm.Id, id2CmpgMember.get(cm.Id).Contact.Name));
		} 
		insert ch;
	}

	private CampaignMemberHistory__c createActivity(Id campaignId, string campaignName, Id memberId, string contactName) {
		string activityMessage = String.format('Added new Campaign Member id: {0} into Campaign id: {1}', new string[] { memberId, campaignId });
		return historyActivity(campaignId, campaignName, memberId, contactName, activityMessage);
	}

	private CampaignMemberHistory__c updateActivity(Id campaignId, string campaignName, Id memberId, string contactName, string fieldName, object objFrom, object objTo) {
		/** Determine objFrom/objTo type and convert accordingly */
		string textFrom, textTo;
		if (objFrom instanceof Datetime) {
			textFrom = ((Datetime)objFrom).format('yyyy-MM-dd HH:mm:ss ZZ');
		}
		else {
			textFrom = String.valueOf(objFrom);
		}
		if (objTo instanceof Datetime) {
			textTo = ((Datetime)objTo).format('yyyy-MM-dd HH:mm:ss ZZ');
		}
		else {
			textTo = String.valueOf(objTo);
		}
		string activityMessage = String.format('Changed {0} from {2} to {3}', new string[] { fieldName, String.valueOf(textFrom), String.valueOf(textTo) });
		return historyActivity(campaignId, campaignName, memberId, contactName, activityMessage);
	}

	private CampaignMemberHistory__c deleteActivity(Id campaignId, string campaignName, Id memberId, string contactName) {
		string activityMessage = String.format('Deleted Campaign Member id: {0} from Campaign id: {1}', new string[] { memberId, campaignId });
		return historyActivity(campaignId, campaignName, memberId, contactName, activityMessage);
	}

	private CampaignMemberHistory__c historyActivity(Id campaignId, string campaignName, Id memberId, string contactName, string activityMessage) {
		CampaignMemberHistory__c c = new CampaignMemberHistory__c();
		c.Campaign__c = campaignId;
		c.CampaignMember__c = memberId;
		c.CampaignMemberName__c = String.format('{0} ({1})', new string[] { contactName, campaignName });
		c.HistoryDetails__c = String.format('{0}: {1}: {2}.', new string[] { Datetime.now().format('yyyy-MM-dd HH:mm:ss ZZ'), UserInfo.getUserName(), activityMessage });

		return c;
	}
}