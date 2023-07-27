public without sharing class OpportunityHandler extends TriggerBase {
	public class OpportunityException extends Exception{}

	public static final string TRIG_SETTING = 'Opportunity';
	public OpportunityHandler() { super(TRIG_SETTING); }

	
	/** Trigger.IsInsert */
	public override void beforeInsert(List<SObject> triggerNew) {
	}
	public override void afterInsert(Map<Id, SObject> triggerNew) {
		/** Determine if Account has to be excluded from SF MC */
		excludeSharkTankAccFromMC((Map<Id, Opportunity>) triggerNew);
	}

	/** Trigger.IsUpdate */
	public override void beforeUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
	}
	public override void afterUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
		/** Determine if Account has to be excluded from SF MC */
		excludeSharkTankAccFromMC((Map<Id, Opportunity>) triggerNew);
	}

	// excludeSharkTankAccFromMC((Map<Id, Opportunity>) triggerNew, (Map<Id, Opportunity>) triggerOld);

	public static void excludeSharkTankAccFromMC(Map<Id, Opportunity> triggerNew) {
		/** Only process integration data */
		// if (System.isQueueable() && System.isBatch()) {
			Set<Id> accountIds = new Set<Id>();
			for (Opportunity oppo :triggerNew.values()) {
				/** Identify Sharktank opportunities */
				// if (oppo.MobyRecordSource__c != null && oppo.MobyRecordSource__c.equalsIgnoreCase('Sharktank')) {
					accountIds.add(oppo.AccountId);
				// }
			}

			Opportunity[] oppos = [SELECT Id, Name, AccountId, Account.AccountSource, Account.MobySyncToMc__c, IsClosed, IsWon, Status__c, MobyRecordSource__c, MobyInsertDate__c, MobyUpdateDate__c, CreatedDate, LastModifiedDate FROM Opportunity WHERE AccountId IN :accountIds ORDER BY AccountId, CreatedDate];
			System.debug('oppos: ' + JSON.serialize(oppos));
			
			Map<Id, Opportunity[]> mapOppo = new Map<Id, Opportunity[]>();
			for (Opportunity oppo :oppos) {
				if (mapOppo.containsKey(oppo.AccountId)) {
					mapOppo.get(oppo.AccountId).add(oppo);
				}
				else {
					mapOppo.put(oppo.AccountId, new Opportunity[] { oppo });
				}
			}

			/** Iterate each Opportunities from Sharktank, to determine Account's eligibility to SF MC */
			Set<Id> accountToMc = new Set<Id>();
			long divider = 1000 * 60 * 60 * 24;	// return Day
			for (Id id :mapOppo.keySet()) {
				Opportunity[] opps = mapOppo.get(id);
				for (Opportunity oppo :opps) {
					Datetime createdDate = (oppo.MobyInsertDate__c != null) ? oppo.MobyInsertDate__c : oppo.CreatedDate;
					Datetime lastModifiedDate = (oppo.MobyUpdateDate__c != null) ? oppo.MobyUpdateDate__c : oppo.LastModifiedDate;
					decimal daysDiff = (Datetime.now().getTime() - createdDate.getTime()) / divider;
					decimal closedWithin = (lastModifiedDate.getTime() - createdDate.getTime()) / divider;

					/** Qualify Opportunity to be sync'ed to MC */
					if (oppo.MobyRecordSource__c == null || !oppo.MobyRecordSource__c.equalsIgnoreCase('Sharktank') // not Sharktank
						|| (!oppo.IsClosed && daysDiff > 5)	// Sharktank opens > 5 days
						|| (oppo.IsClosed && !oppo.IsWon && closedWithin > 5)	// Sharktank closed within > 5days
					) {
						/** Account is eligibile for sync'ing to SF MC */
						accountToMc.add(oppo.AccountId);
						break;
					}
				}
			}

			if (accountToMc.size() > 0) {
				Account[] acs = [SELECT Id, MobySyncToMc__c FROM Account WHERE Id IN :accountToMc];
				for (Account ac :acs) { ac.MobySyncToMc__c = true; }
				update acs;	
			}
		// }
	}


}