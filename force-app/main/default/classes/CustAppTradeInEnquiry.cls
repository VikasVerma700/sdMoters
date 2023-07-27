global without sharing class CustAppTradeInEnquiry {
	public final static Map<String, String> TRADE_IN_CMP = new Map<String, String> { '02' => '05', '028' => '168' };
	public final static Set<String> BPS_TEAM = new Set<String> { 'BPS' };
	public static void processCallback() {
		RestRequest req = RestContext.request;
		EnquiryCallback reqBody = (EnquiryCallback) JSON.deserialize(req.requestBody.toString(), EnquiryCallback.class);
		if (reqBody == null || reqBody.payload == null || reqBody.payload.tradeIn == null) { throw new CustAppAPI.CustAppException('Empty payload.'); }
		String tradeInCmp = TRADE_IN_CMP.get(reqBody.payload.tradeIn.companyId);
		Company__c cmp = CustAppAPI.CMP_MAP.get(tradeInCmp);
		if (cmp == null) { throw new CustAppAPI.CustAppException('Invalid company Id.'); }
		String type = CustAppAccount.EXT_ACC_TYPE.get(reqBody.payload.tradeIn.companyId);
		String uuid = reqBody.payload.tradeIn.accountUuid;
		List<Customer_External_Account__c> extAcc = CustAppEnquiryBase.getCustAccList(uuid);
		if (extAcc.size() <= 0) { throw new CustAppAPI.CustAppException('Invalid account uuid.'); }
		List<Vehicle__c> veh = [SELECT Id, Registration_Number__c FROM Vehicle__c WHERE Name = :reqBody.payload.tradeIn.identificationNumber LIMIT 1];
		if (veh.size() <= 0) { throw new CustAppAPI.CustAppException('Cannot find vehicle.'); }
		Id sc = assignSC(cmp.Name, extAcc[0]);
		// User scUser = [SELECT Id, Company__c FROM User WHERE Id = :sc];
		// Lead_Traffic__c lt = CustAppEnquiryBase.createLeadTraffic(cmp, extAcc[0].Account__r, scUser, null);
		// Opportunity opp = CustAppEnquiryBase.findExistingOrCreateOpp(extAcc[0], lt.Id, scUser, cmp, null);
		// setOppDescription(extAcc[0].Account__r, veh[0], opp, reqBody.payload.tradeIn);
		// upsert opp;
		// CustAppEnquiryBase.createTask(cmp, opp, extAcc[0]);

	}

	public static String assignSC(String cmp, Customer_External_Account__c extAcc) {
		Set<String> team;
		if (cmp == '02') { // from bmw customer app
			team = BPS_TEAM;
		} else if (cmp == '028' || cmp == '168') {
		} else {
			throw new CustAppAPI.CustAppException('Unmapped team for SC assignment');
		}
		String source = 'Timestamp:' + System.now().format('dd/MM/yyyy HH:mm:ss') + '\n' + extAcc.Type__c + ' Trade In Request';
		return null; // Assignment.assignSC(extAcc.Account__r, team, null, null, source);
	}

	// public static void setOppDescription(Account acc, Vehicle__c veh, Opportunity opp, EnquiryPayload tradeIn) {
	// 	String oppDesc = '';
	// 	oppDesc += 'Dear SC, \n\n A customer has just submitted a Trade In Request\n';
	// 	oppDesc += 'Kindly follow-up with the details below: \n\n';
	// 	oppDesc += 'Email: ' + acc.Default_Email__c + '\n';
	// 	oppDesc += 'Mobile: ' + acc.Mobile_Preferred__pc + '\n';
	// 	oppDesc += 'Vehicle Reg. Number: ' + veh.Registration_Number__c + '\n';
	// 	oppDesc += 'Vehicle Owner: ' + acc.Name + '\n';
	// 	oppDesc += 'Mileage: ' + tradeIn.mileage + '\n';
	// 	oppDesc += 'Owner Document No.: ' + tradeIn.ownerNricFin + '\n';
	// 	oppDesc += 'Agent or Parallel: ' + tradeIn.source + '\n';
	// 	oppDesc += 'Date/Time of Enquiry: ' + Datetime.now().format('dd/MM/yyyy HH:mm:ss', 'Singapore') + '\n';
	// 	opp.Description = (!String.isBlank(opp.Description) ? opp.Description + '\n\n' : '') + oppDesc;
	// }

	global class EnquiryCallback {
		public String event;
		public EnquiryBody payload;
	}

	global class EnquiryBody {
		public EnquiryPayload tradeIn;
	}

	global class EnquiryPayload {
		public String accountUuid;
		public Boolean isOwner;
		public Decimal mileage;
		public String ownerNricFin;
		public String source;
		public String identificationNumber;
		public String companyId;
	}
}