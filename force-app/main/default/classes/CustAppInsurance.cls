global without sharing class CustAppInsurance {
	public final static String ADD_EVENT = 'UPSERT_VEHICLE_INSURANCE';
	public final static String REM_EVENT = 'REMOVE_VEHICLE_INSURANCE';
	public static Company__c CONTEGO;
	public final static List<String> INS_FIELDS = new List<String> { 'Id', 'Covernote_No__c', 'Policy_Number__c', 'Policy_Inception_Date__c', 'Ext_UUID__c',
																	'Policy_Expiry_Date__c', 'Basic_Price__c', 'Excess__c', 'Windscreen_Excess__c',
																	'No_Claim_Discount_NCD__c', 'Has_NCD_Protector__c', 'Named_Driver_1__c',
																	'Named_Driver_1__r.LastName', 'Named_Driver_2__c', 'Named_Driver_2__r.LastName',
																	'Named_Driver_3__c', 'Named_Driver_3__r.LastName', 'Underwriter__c', 'Coverage__c',
																	'Insurance_Policy_Status__c', 'Vehicle_Ownership__c', 'Policy_Holder__c',
																	'Ext_Underwriter__c', 'Underwriter_Code__r.Hotline__c', 'User_Deleted__c',
																	'Created_From__c' };
	static {
		List<Company__c> cmpList = [SELECT Id FROM Company__c WHERE Name = '028' LIMIT 1];
		CONTEGO = (cmpList.size() > 0) ? cmpList[0] : null;
	}
	// organized by VO Id => Insurance[]
	public static Map<Id, List<InsuranceCls>> retrieveInsurance(Id accId, String cmp) {
		System.debug('accId: ' + accId);
		Alternative_Driver__c[] ads = [SELECT Id, Name, Vehicle_Ownership__c FROM Alternative_Driver__c WHERE Status__c = 'Active' AND Account__c = :accId];
		Set<Id> voIdset = new Set<Id>();
		for (Alternative_Driver__c ad :ads) { voIdset.add(ad.Vehicle_Ownership__c); }
		System.debug('voIdset: ' + JSON.serialize(voIdset));

		Vehicle_Ownership__c[] vos = [SELECT Id, Name, Vehicle__c FROM Vehicle_Ownership__c WHERE Status__c = 'Active' AND (Customer__c = :accId OR Id IN :voIdset)];
		Set<Id> fullVoIdset = new Set<Id>();
		for (Vehicle_Ownership__c vo :vos) { fullVoIdset.add(vo.Id); }
		System.debug('fullVoIdset: ' + JSON.serialize(fullVoIdset));

		List<String> custAccTypes = CustAppAccount.EXT_ACC_TYPE.values();
		String query = 'SELECT ';
		query += String.join(INS_FIELDS, ',');
		query += ',(SELECT ' + String.join(CustAppFile.ATT_FIELDS, ',') + ' FROM Attachments ORDER BY CreatedDate DESC)';
		query += ' FROM Insurance_Policy__c WHERE CreatedDate != null ' +
				// 'AND Policy_Holder__c = :accId ' +
				'AND Vehicle_Ownership__c IN :fullVoIdset ' +
				'AND Policy_Classification__c = \'Motor\' AND ((Created_From__c = :custAccTypes ' +
					'AND User_Deleted__c = FALSE) OR Created_From__c NOT IN :custAccTypes)';
		System.debug('retrieveInsurance: ' + query.replace(' = :accId', ' = \'' + accId + '\'')
												  .replace(' = :custAccTypes', ' = \'' + custAccTypes + '\'')
												  .replace(' IN :custAccTypes', ' IN (\'' + String.join(custAccTypes, '\',\'') + '\')')
												  .replace(' IN :fullVoIdset', ' IN ' + fullVoIdset)
		);
		List<Insurance_Policy__c> policies = Database.query(query);
		Map<Id, List<InsuranceCls>> res = new Map<Id, List<InsuranceCls>>();
		for (Insurance_Policy__c ins : policies) {
			List<InsuranceCls> insList = res.get(ins.Vehicle_Ownership__c);
			insList = (insList == null) ? new List<InsuranceCls>() : insList;
			insList.add(new InsuranceCls(ins, CustAppAccount.EXT_ACC_TYPE.get(cmp)));
			res.put(ins.Vehicle_Ownership__c, insList);
		}
		return res;
	}

	public static void processAddCallback() {
		RestRequest req = RestContext.request;
		AddInsurancePayload reqBody = (AddInsurancePayload) JSON.deserialize(req.requestBody.toString(), AddInsurancePayload.class);
		if (reqBody == null || reqBody.payload == null || reqBody.payload.insurance == null || reqBody.payload.vehicle == null) {
			throw new CustAppAPI.CustAppException('Empty payload.');
		}
		String uuid = reqBody.payload.vehicle.accountUuid;
		List<Customer_External_Account__c> custAccList = CustAppEnquiryBase.getCustAccList(uuid);
		if (custAccList.size() <= 0) { throw new CustAppAPI.CustAppException('Unknown customer UUID.'); }
		List<Vehicle_Ownership__c> voList = [SELECT Id, Vehicle__c, Vehicle__r.Name, Vehicle__r.Vehicle_Make__r.Name, Registration_No__c, Customer__c,
											Vehicle_Make__c, Vehicle_Make__r.Name
											FROM Vehicle_Ownership__c WHERE Status__c = 'Active' AND Customer__c = :custAccList[0].Account__c
											AND Vehicle__r.Name = :reqBody.payload.vehicle.identificationNumber ORDER BY Start_Date__c DESC LIMIT 1];
		Vehicle_Ownership__c vo;
		if (voList.size() > 0) {
			vo = voList[0];
		} else {
			List<Alternative_Driver__c> altDList = [SELECT Id, Account__c, Vehicle_Ownership__c, Vehicle_Ownership__r.Registration_No__c, Vehicle_Ownership__r.Customer__c,
													Vehicle_Ownership__r.Vehicle__r.Name, Vehicle_Ownership__r.Vehicle__r.Vehicle_Make__c, Vehicle_Ownership__r.Vehicle__r.Vehicle_Make__r.Name,
													Vehicle_Ownership__r.Vehicle_Make__c, Vehicle_Ownership__r.Vehicle_Make__r.Name,
													Vehicle_Ownership__r.Vehicle__r.Registration_Number__c FROM
													Alternative_Driver__c WHERE Status__c = 'Active' AND Vehicle_Ownership__r.Status__c = 'Active' AND
													Account__c = :custAccList[0].Account__c AND
													Vehicle_Ownership__r.Vehicle__r.Name = :reqBody.payload.vehicle.identificationNumber ORDER BY CreatedDate
													DESC LIMIT 1];
			if (altDList.size() > 0) {
				vo = altDList[0].Vehicle_Ownership__r;
			} else {
				throw new CustAppAPI.CustAppException('Vehicle ownership not found.');
			}
		}

		List<Insurance_Policy__c> existingPolicy = [SELECT Id, Underwriter_Code__c FROM Insurance_Policy__c WHERE Vehicle__c = :vo.Vehicle__c AND
													Policy_Holder__c = :vo.Customer__c AND Ext_UUID__c = :reqBody.payload.insurance.id ORDER BY
													Policy_Inception_Date__c DESC LIMIT 1];
		Insurance_Policy__c insPolicy = (existingPolicy.size() > 0) ? existingPolicy[0] : new Insurance_Policy__c();
		insPolicy.Ext_UUID__c = reqBody.payload.insurance.id;
		insPolicy.Created_From__c = custAccList[0].Type__c;
		insPolicy.Policy_Inception_Date__c = (reqBody.payload.insurance.startDate != null) ? reqBody.payload.insurance.startDate.date() : null;
		insPolicy.Policy_Expiry_Date__c = (reqBody.payload.insurance.endDate != null) ? reqBody.payload.insurance.endDate.date() : null;
		insPolicy.Policy_Number__c = reqBody.payload.insurance.policyNumber;
		insPolicy.Policy_Received_Date__c = Date.today();
		insPolicy.Excess__c = (reqBody.payload.insurance.excess != null) ? reqBody.payload.insurance.excess.amount : null;
		insPolicy.Basic_Price__c = (reqBody.payload.insurance.premium != null) ? reqBody.payload.insurance.premium.amount : null;
		insPolicy.Original_Basic_Price__c = insPolicy.Basic_Price__c;
		insPolicy.Policy_Holder__c = vo.Customer__c;
		insPolicy.Company__c = CONTEGO.Id;
		insPolicy.Full_Chassis__c = reqBody.payload.vehicle.identificationNumber;
		insPolicy.Vehicle_Make__c = vo.Vehicle_Make__c;
		insPolicy.Policy_Classification__c = 'Motor';
		insPolicy.Policy_Period_Override__c = true;
		insPolicy.Vehicle__c = vo.Vehicle__c;
		if (vo.Vehicle__r != null && vo.Vehicle__r.Vehicle_Make__r != null && vo.Vehicle__r.Vehicle_Make__r.Name.equalsIgnoreCase('C')) {
			insPolicy.Insurance_Product__c = 'Motor Cycle';
		} else {
			insPolicy.Insurance_Product__c = 'Passenger';
		}
		insPolicy.Insurance_Product__c += (insPolicy.Policy_Inception_Date__c != null && insPolicy.Policy_Expiry_Date__c != null &&
											insPolicy.Policy_Expiry_Date__c.daysBetween(insPolicy.Policy_Inception_Date__c) >= 730) ? ' - 2' : '';
		insPolicy.Registration_Number__c = vo.Registration_No__c;
		insPolicy.Vehicle_Ownership__c = vo.Id;
		if (insPolicy.Id == null || insPolicy.Underwriter_Code__c == null) {
			List<Insurance_Company__c> insCmpList = [SELECT Id FROM Insurance_Company__c WHERE Name = :reqBody.payload.insurance.underwriterName AND
													Company__r.Name = '05' LIMIT 1];
			Insurance_Company__c insCmp;
			if (insCmpList.size() <= 0) {
				insPolicy.Ext_Underwriter__c = reqBody.payload.insurance.underwriterName;
			} else {
				insPolicy.Underwriter_Code__c = insCmp.Id;
			}
		}
		upsert insPolicy;
	}

	public static void processRemoveCallback() {
		RestRequest req = RestContext.request;
		RemInsurancePayload reqBody = (RemInsurancePayload) JSON.deserialize(req.requestBody.toString(), RemInsurancePayload.class);
		if (reqBody == null || reqBody.payload == null || reqBody.payload.insuranceId == null || reqBody.payload.vehicle == null) {
			throw new CustAppAPI.CustAppException('Empty payload');
		}

		String uuid = reqBody.payload.vehicle.accountUuid;
		List<Customer_External_Account__c> custAccList = CustAppEnquiryBase.getCustAccList(uuid);
		if (custAccList.size() <= 0) { throw new CustAppAPI.CustAppException('Unknown customer UUID.'); }
		List<Insurance_Policy__c> policyList = [SELECT Id, Created_From__c FROM Insurance_Policy__c WHERE Ext_UUID__c = :reqBody.payload.insuranceId];
		if (policyList.size() <= 0) { throw new CustAppAPI.CustAppException('Unable to find policy.'); }
		if (policyList[0].Created_From__c != custAccList[0].Type__c) {
			throw new CustAppAPI.CustAppException('Policy not submitted via Customer App. Do not delete.');
		}
		policyList[0].User_Deleted__c = true;
		update policyList;
	}

	global class InsuranceCls {
		public String id;
		public string source;
		public Boolean isModifiable;
		public String policyNumber;
		public DateTime startDate;
		public DateTime endDate;
		public CustAppAPI.CurrencyCls premium;
		public CustAppAPI.CurrencyCls excess;
		public CustAppAPI.CurrencyCls windscreenExcess;
		public CustAppAccount.PhoneCls hotline; // TODO
		public Decimal noClaimDiscount;
		public Boolean noClaimDiscountProtector;
		public List<String> namedDrivers;
		public String underwriterName;
		public String coverage;
		public String status;
		public List<CustAppFile.FileCls> documents;
		global InsuranceCls(Insurance_Policy__c ins, string accountTypeName) {
			this.id = (String.isNotBlank(ins.Ext_UUID__c)) ? ins.Ext_UUID__c : ins.Id;
			this.source = (ins.Created_From__c == accountTypeName) ? 'USER' : 'DEALERSHIP';
			this.isModifiable = (ins.Created_From__c == accountTypeName && ins.Insurance_Policy_Status__c == 'In Force');
			this.policyNumber = (String.isBlank(ins.Covernote_No__c)) ? '' : ins.Covernote_No__c;
			this.policyNumber = (String.isBlank(ins.Policy_Number__c)) ? this.policyNumber : ins.Policy_Number__c;
			this.startDate = ins.Policy_Inception_Date__c;
			this.endDate = ins.Policy_Expiry_Date__c;
			if (ins.Basic_Price__c != null) { this.premium = new CustAppAPI.CurrencyCls(ins.Basic_Price__c); }
			if (ins.Excess__c != null) { this.excess = new CustAppAPI.CurrencyCls(ins.Excess__c); }
			if (ins.Windscreen_Excess__c != null) { this.windscreenExcess = new CustAppAPI.CurrencyCls(ins.Windscreen_Excess__c); }
			this.noClaimDiscount = ins.No_Claim_Discount_NCD__c;
			this.noClaimDiscountProtector = ins.Has_NCD_Protector__c;
			this.namedDrivers = new List<String>();
			if (ins.Named_Driver_1__c != null && ins.Named_Driver_1__c != ins.Policy_Holder__c) {
				this.namedDrivers.add(ins.Named_Driver_1__r.LastName);
			}
			if (ins.Named_Driver_2__c != null) {
				this.namedDrivers.add(ins.Named_Driver_2__r.LastName);
			}
			if (ins.Named_Driver_3__c != null) {
				this.namedDrivers.add(ins.Named_Driver_3__r.LastName);
			}
			this.underwriterName = (String.isBlank(ins.Underwriter__c)) ? ins.Ext_Underwriter__c : ins.Underwriter__c;
			this.coverage = ins.Coverage__c;
			/** +60 not included */
			this.hotline = new CustAppAccount.PhoneCls();
			this.hotline.phoneNumber = (String.isBlank(ins.Underwriter_Code__r?.Hotline__c)) ? '' : ins.Underwriter_Code__r.Hotline__c;
			switch on ins.Insurance_Policy_Status__c {
				when 'In Force' {
					this.status = 'ACTIVE';
				} when 'Cancelled', 'Lapsed' {
					this.status = ins.Insurance_Policy_Status__c.toUppercase();
				} when else {
					this.status = '';
				}
			}
			this.documents = this.listFiles(ins.Attachments);
		}

		public List<CustAppFile.FileCls> listFiles(List<Attachment> attList) {
			List<CustAppFile.FileCls> res = new List<CustAppFile.FileCls>();
			for (Attachment att: attList) {
				// we only send latest CI
				if (!String.isBlank(att.Name) && ((att.Name.containsIgnoreCase('CI') || att.Name.containsIgnoreCase('Certificate of Insurance')))) {
					CustAppFile.FileCls file = new CustAppFile.FileCls(att);
					file.name = 'Certificate of Insurance';
					res.add(file);
					break;
				}
			}
			return res;
		}
	}

	global class AddInsurancePayload {
		public String event;
		public AddInsuranceReq payload;
	}

	global class AddInsuranceReq {
		public AddInsuranceCls insurance;
		public VehOwnerCls vehicle;
	}

	global class AddInsuranceCls {
		public String underwriterName;
		public DateTime startDate;
		public DateTime endDate;
		public String id;
		public String policyNumber;
		public CustAppAPI.CurrencyCls excess;
		public CustAppAPI.CurrencyCls premium;
	}

	global class VehOwnerCls {
		public String accountUuid;
		public String identificationNumber;
		public String vehicleOwnerReference;
	}

	global class RemInsurancePayload {
		public String event;
		public RemInsuranceCls payload;
	}

	global class RemInsuranceCls {
		public String insuranceId;
		public VehOwnerCls vehicle;
	}
}