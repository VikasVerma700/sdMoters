public without sharing class InsuranceHandler {
	private final static Set<String> CMP_NAME = new Set<String>{ '028' };
	private final static List<User> ERR_USER = [SELECT Id, Email FROM User WHERE Profile.Name = 'Contego Managers' AND IsActive = TRUE];

	public static void assignUnderwriter(Insurance_Policy__c[] triggerNew) {
		Set<string> setUnderWriters = new Set<string>();
		for (Insurance_Policy__c ip :triggerNew) { setUnderWriters.add(ip.Underwriter__c); }

		Map<string, Insurance_Company__c> mapInsCo = new Map<string, Insurance_Company__c>();
		Insurance_Company__c[] insCos = [SELECT Id, Name, Description__c FROM Insurance_Company__c WHERE Name IN :setUnderWriters];
		for (Insurance_Company__c insCo :insCos) { if (!mapInsCo.containsKey(insCo.name)) { mapInsCo.put(insCo.name, insCo); } }

		for (Insurance_Policy__c insPol : triggerNew) {
			if (insPol.Underwriter_Code__c == null && String.isNotBlank(insPol.Underwriter__c)) {
				insPol.Underwriter_Code__c = mapInsCo.get(insPol.Underwriter__c)?.Id;
			}
		}
	}

	/**
	 * upon new ins biz, we generate a txn for that policy
	 * @param listIns [list of insurance policies that are being inserted]
	 */
	public static void createNewTransaction(List<Insurance_Policy__c> listIns) {
		List<Insurance_Transaction__c> listTrans = new List<Insurance_Transaction__c>();
		Map<Id, Company__c> cmpMap = new Map<Id, Company__c>([SELECT Id, Name FROM Company__c WHERE Name IN :CMP_NAME]);
		Map<Id, Insurance_Company__c> insCmp =  new Map<Id, Insurance_Company__c>([SELECT Id, Name FROM Insurance_Company__c WHERE SDSL_Partner__c = true
																					AND Company__r.Name = '05']);
		List<Id> oppId = new List<Id>();
		for (Insurance_Policy__c p : listIns) { oppId.add(p.Opportunity__c); }
		Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([SELECT Id, Payment_Type_Ins__c, Credit_Card_No_Ins__c, Credit_Card_BatchID_Ins__c,
																Approval_Code_Ins__c, Credit_Card_Txn_Remarks_Ins__c, Cheque_No_Ins__c
																FROM Opportunity WHERE Id IN :oppId]);

		Insurance_Transaction__c newTrans;
		Insurance_Company__c curIns;
		Company__c curCmp;
		Boolean isVSABiz;
		for (Insurance_Policy__c objIns : listIns) {
			newTrans = initNewTxn(objIns, oppMap.get(objIns.Opportunity__c));
			isVSABiz = isNewVSABiz(objIns);
			newTrans.Insurance_Transaction_Type_ID__c = (isVSABiz) ? '(+) NEW WITH VSA RETAIL' : null;
			curIns = insCmp.get(objIns.Underwriter_Code__c);
			curCmp = cmpMap.get(objIns.Company__c);
			newTrans.Agency_Code__c = (isVSABiz && curIns != null && curCmp != null) ? assignAgencyCode(objIns, curIns.Name, curCmp.Name) : null;
			listTrans.add(newTrans);
		}
		insert listTrans;
	}

	/**
	 * we create a task to track the initial stage where the policy is currently open for issuance
	 * @param listIns [list of insurance policies inserted]
	 */
	public static void createNewUWTask(List<Insurance_Policy__c> listIns) {
		Task uwTask = CommonMethodsLibrary.createTask(null, null, UserInfo.getUserId(), 'ABD UW Follow Up RT', 'Open for Issuance', '', 'Low', 'UW Stages', false, null);
		List<Task> listNewUWTask = new List<Task>();
		Task newTask;
		for (Insurance_Policy__c objIns : listIns) {
			newTask = uwTask.clone();
			newTask.WhatId = objIns.Id;
			newTask.Status = 'Completed';
			listNewUWTask.add(newTask);
		}
		insert listNewUWTask;
	}

	/**
	 * once policy received, we create a task for tracking
	 * @param listIns [list of insurance policies that will be updated]
	 */
	public static void createPolicyReceivedTask(List<Insurance_Policy__c> listIns) {
		String taskSubj = 'Policy received';
		Set<Id> policyId = new Set<Id>();
		for (Insurance_Policy__c p : listIns) { policyId.add(p.Id); }
		List<Task> taskList = [SELECT Id, WhatId FROM Task WHERE WhatId IN :policyId AND Subject = :taskSubj];
		Set<Id> seenPolicy = new Set<Id>();
		for (Task t : taskList) { seenPolicy.add(t.WhatId); }

		List<Task> insertList = new List<Task>();
		Task newTask = CommonMethodsLibrary.createTask(null, null, UserInfo.getUserId(), 'ABD UW Follow Up RT', taskSubj, '', 'Low', taskSubj, false, null);
		Task curTask;
		for (Insurance_Policy__c p : listIns) {
		if (p.Policy_Received_Date__c == null || seenPolicy.contains(p.Id)) { continue; }
			curTask = newTask.clone();
			curTask.WhatId = p.Id;
			curTask.Status = 'Completed';
			insertList.add(curTask);
		}

		insert insertList;
	}

	/**
	 * we tag the VO to the policy and also update the VO to show that it is with Existing Insurance Policy
	 * @param policies [list of insurance policies to be updated]
	 */
	public static void updateVO(List<Insurance_Policy__c> policies) {
		Set<Id> vehId = new Set<Id>();
		Set<Id> customerId = new Set<Id>();
		for (Insurance_Policy__c p : policies) {
		if (p.Insurance_Policy_Status__c != 'In Force') { continue; }
		if (p.Vehicle__c != null) { vehId.add(p.Vehicle__c); }
		if (p.Policy_Holder__c != null) { customerId.add(p.Policy_Holder__c); }
		}

		List<Vehicle_Ownership__c> voList = [SELECT Id, Name, Vehicle__c, Customer__c, With_Existing_Insurance_Policy__c FROM Vehicle_Ownership__c
											WHERE Vehicle__c IN :vehId AND Customer__c IN :customerId AND Status__c = 'Active' ORDER BY Start_Date__c DESC];
		Map<Id, List<Vehicle_Ownership__c>> voMap = new Map<Id, List<Vehicle_Ownership__c>>();
		List<Vehicle_Ownership__c> curList;
		for (Vehicle_Ownership__c vo : voList) {
			curList = voMap.get(vo.Customer__c);
			curList = (curList == null) ? new List<Vehicle_Ownership__c>() : curList;
			curList.add(vo);
			voMap.put(vo.Customer__c, curList);
		}

		Vehicle_Ownership__c curVO;
		List<Vehicle_Ownership__c> updVoList = new List<Vehicle_Ownership__c>();
		for (Insurance_Policy__c p : policies) {
			curList = voMap.get(p.Policy_Holder__c);
			if (curList == null || curList.size() <= 0) { continue; }
			curVO = null;
			for (Vehicle_Ownership__c vo : curList) {
				if (vo.Vehicle__c != p.Vehicle__c) { continue; }
				if (!vo.With_Existing_Insurance_Policy__c) { updVoList.add(new Vehicle_Ownership__c(Id = vo.Id, With_Existing_Insurance_Policy__c = true)); }
				curVO = (curVO == null) ? vo : curVO; // take the first one, rightfully there shld only be one anyway.
			}
			if (curVO == null) { continue; }
			p.Vehicle_Ownership__c = curVO.Id;
		}
		if (updVoList.size() > 0) {
			List<Database.SaveResult> srUpd = Database.update(updVoList, false);
			CommonMethodsLibrary.emailResultFailure(srUpd, updVoList, 'updateVO', 'InsuranceHandler', ERR_USER);
		}
	}

	/////////////////////
	// PRIVATE HELPERS //
	/////////////////////
	/** helper method to assign the agency code to the txn */
	public static String assignAgencyCode(Insurance_Policy__c insP, String insCmpName, String cmpName) {
		if (insCmpName == '106066') { //AXA code
			if (insP.Insurance_Product__c == 'Passenger') {
				if (cmpName == '02') { return 'AXA 11615'; }
				if (cmpName == '03') { return 'AXA 11625'; }
			}
			if (insP.Insurance_Product__c == 'Passenger - 2') {
				if (cmpName == '02') { return 'AXA 14235'; }
				if (cmpName == '03') { return 'AXA 14285'; }
			}
		}

		if (insCmpName == '113525') { //Lib Code
			if (cmpName == '02') { return 'LIB A1429-5'; }
			if (cmpName == '03') { return 'LIB A1429-3'; }
			if (cmpName == '888') { return 'LIB A1429-7'; }
		}
		return null;
	}

	private static Insurance_Transaction__c initNewTxn(Insurance_Policy__c objIns, Opportunity opp) {
		Insurance_Transaction__c newTrans = new Insurance_Transaction__c();
		newTrans.Basic_Price__c = objIns.Original_Basic_Price__c;
		newTrans.Commission_Percentage_M__c = objIns.Original_Commission_Percentage__c;
		newTrans.Company_ID__c = objIns.Company__c;
		newTrans.Commission__c = objIns.Original_Commission__c;
		newTrans.Discount__c = objIns.Original_Discount__c;
		newTrans.GST_Percentage__c = objIns.Original_GST_Percentage__c;
		newTrans.Insurance_Name_ID__c = objIns.Id;
		newTrans.No_Claim_Discount__c = objIns.Original_No_Claim_Discount_NCD__c;
		newTrans.Offence_Free_Discount_OFD__c = objIns.Original_Offence_Free_Discount_OFD__c;
		newTrans.Status_Code__c = 'OPEN';
		newTrans.Transaction_Date__c = Date.today();
		newTrans.Transaction_Type__c = 'DEBIT';
		newTrans.UW_Reference_No__c = objIns.UW_Reference_No__c;
		newTrans.Policy_Expiry_Date__c = objIns.Policy_Expiry_Date__c;
		newTrans.Paid_Amount__c = 0;
		newTrans.IsFirstTxn__c = true;
		if (opp != null) { // we copy the payment details from the opp if it is available
			newTrans.Payment_Type__c = opp.Payment_Type_Ins__c;
			newTrans.Credit_Card_No__c = opp.Credit_Card_No_Ins__c;
			newTrans.Credit_Card_Batch_Id__c = opp.Credit_Card_BatchId_Ins__c;
			newTrans.Payment_Approval_Code__c = opp.Approval_Code_Ins__c;
			newTrans.Cq_No__c = opp.Cheque_No_Ins__c;
			newTrans.Payment_Remarks__c = opp.Credit_Card_Txn_Remarks_Ins__c;
		}
		return newTrans;
	}

  /** we classify as new vsa biz if its passenger or passenger 2
    * and if there is no previous policy and it is attached to an evsa */
	private static Boolean isNewVSABiz(Insurance_Policy__c insP) {
		Set<String> passengerSet = new Set<String> { 'Passenger', 'Passenger - 2' };
		return (passengerSet.contains(insP.Insurance_Product__c) && (insP.Previous_Insurance_Policy__c == null &&
																	(insP.Sales_Order_PML__c != null
																	// || insP.Sales_Order_Used_Car__c != null ||
																	// insP.Sales_Order_VAL__c != null
																	)));
	}
}