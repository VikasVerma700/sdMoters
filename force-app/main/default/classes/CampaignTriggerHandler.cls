public class CampaignTriggerHandler extends TriggerBase {
	public static final string TRIG_SETTING = 'Campaign';
	
    public CampaignTriggerHandler() {
		super(TRIG_SETTING, 1);
    }

	public override void afterInsert(Map<Id, SObject> triggerNew) {
		CampaignTriggerHandler.injectUrl((Map<Id, Campaign>)triggerNew);
	}

	public override void beforeUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
		CampaignTriggerHandler.injectUrl((Map<Id, Campaign>)triggerNew);
	}

	public static void injectUrl(Map<Id, Campaign> triggerNew) {
		SiteDetail sdet = Envir.siteDetailList.get('Sales');
		if (sdet == null) {
			return;
		}
		
		string prefixUrl = sdet.SecureUrl;

		Campaign[] updateCampaigns = new Campaign[]{};
		for (Id id :triggerNew.keySet()) {
			string urlCheckIn = prefixUrl + '/?Id=' + id;
			string urlNominee = prefixUrl + '/CampaignMemberNomination?Id=' + id;
			Campaign campaign = triggerNew.get(id);
			Campaign camp = new Campaign(Id = id);

			if (String.isBlank(campaign.CheckInUrl__c)) {
				if (Trigger.isAfter && Trigger.isInsert) {
					camp.CheckInUrl__c = urlCheckIn;
				}
				if (Trigger.isBefore && Trigger.isUpdate) {
					campaign.CheckInUrl__c = urlCheckIn;
				}
			}
			if (String.isBlank(campaign.NominationUrl__c)) {
				if (Trigger.isAfter && Trigger.isInsert) {
					camp.NominationUrl__c = urlNominee;
				}
				if (Trigger.isBefore && Trigger.isUpdate) {
					campaign.NominationUrl__c = urlNominee;
				}
			}

			if (Trigger.isAfter && Trigger.isInsert) {
				updateCampaigns.add(camp);
				update updateCampaigns;
			}
		}

	}
}