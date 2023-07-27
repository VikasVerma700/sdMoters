global without sharing class CustAppAccount {
	public final static String AGREEMENT_TYPE = PDPA.PDPA_NAME;
	public final static String AGREEMENT_VER = PDPA.PDPA_VER;
	public final static String AGREEMENT_REF = AGREEMENT_TYPE + '_V' + AGREEMENT_VER;
	public final static String TOKEN_TYPE = 'Advertising ID';
	public final static String EVENT_NAME = 'UPDATE_ACCOUNT';
	public final static String IMG_ATT = 'Account Image';
	public final static Map<String, String> EXT_ACC_TYPE = new Map<String, String> { '028' => 'BMW Customer App' };
	public final static Id PERSON_RT = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
	public static Map<String, String> REV_TYPE;
	public static List<String> ACC_FIELDS = new List<String> { 'Id', 'LastName', 'Salutation', 'PersonMobilePhone', 'Mobile_Country_Code_1__pc', 'Mobile_Preferred__pc',
																'NRIC_Number_wo_Prefix__c', 'Partial_NRIC__c', 'Doc_Type__c', 'Default_Email__c',
																'Verified_With_NRIC__c', 'NRIC_Number__c', 'Home_Email__c', 'Office_Email__c',
																'Other_Email__c', 'Account_Name__c', 'Country__c', 'LicenseExpiryDate__pc', 'PersonBirthDate',
																'PersonContactId', 'Customer_Number__c', 'OfficialName__c', 'DisplayName__c'
															};
	public static List<String> EXT_ACC_FIELDS = new List<String> { 'UUID__c', 'Id', 'Account__c', 'Account__r.PersonContactId', 'Type__c', 'Name__c', 'Username__c', 'Account__r.Mobile_Country_Code_1__pc', 'Account__r.Mobile_Preferred__pc', 'Account__r.PersonMobilePhone' };
	public static List<String> LEGISLATION_FIELDS = new List<String> { 'Id', 'I_Have_Read_The_Consent_Provisions__c', 'Opt_In__c', 'Legislation_Type__r.Name',
																		'Consent_Status__c', 'Type_of_Legal_Legislation_Version__c' };
	public static List<String> DEVICE_FIELDS = new List<String> { 'Id', 'Token__c' };
	static {
		REV_TYPE = new Map<String, String>();
		for (String t : EXT_ACC_TYPE.keySet()) { REV_TYPE.put(EXT_ACC_TYPE.get(t), t); }
	}
	public static void sendWebhook(Customer_App_Callback__e callback) {
		string[] payloadEmail = new string[]{};
		List<Account> accList = retrieveAccDetails(new List<Id> { callback.Id__c }, new Set<String>(EXT_ACC_TYPE.values()));
		if (accList.size() <= 0 || accList[0].Customer_External_Accounts__r.size() <= 0) { return; }
		Account acc = accList[0];
		for (Customer_External_Account__c custAcc : acc.Customer_External_Accounts__r) {
			String cmp = REV_TYPE.get(custAcc.Type__c);
			if (cmp == null) { continue; }
			AccountPayLoad payload = new AccountPayLoad(acc, cmp, custAcc);
			AccountWebhook hook = new AccountWebhook(EVENT_NAME, payload);
			string jsonHook = JSON.serialize(hook, true);
			CustAppAPI.sendWebhook(jsonHook, cmp);
			/** Email payload to Admin */
			String emailBody = EVENT_NAME + ' Payload:<br /><br />' + jsonHook;
			System.debug(emailBody);
			payloadEmail.add(emailBody);
		}
		if (payloadEmail != null && payloadEmail.size() > 0) {
			String subject = Envir.subject + ' CustAppAccount Payload';
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, String.join(payloadEmail, '<br/>'), true, subject);
		}
	}

	public static List<Account> retrieveAccDetails(List<Id> idList, Set<String> types) {
		String query = 'SELECT ' + String.join(ACC_FIELDS, ',');
		query += ',(SELECT ' + String.join(CustAppAccount.EXT_ACC_FIELDS, ',');
		query += ' FROM Customer_External_Accounts__r WHERE Type__c IN :types AND IsActive__c = TRUE AND IsDefault__c = TRUE) ';
		query += 'FROM Account WHERE Id = :idList';
		return Database.query(query);
	}

	public static List<Customer_External_Account__c> getExtAccounts(Id accId, Set<String> types) {
		Map<Id, List<Customer_External_Account__c>> extAccs = getExtAccounts(new List<Id> { accId }, types);
		return (extAccs.size() <= 0) ? new List<Customer_External_Account__c>() : extAccs.values()[0];
	}

	public static Map<Id, List<Customer_External_Account__c>> getExtAccounts(List<Id> accIds, Set<String> types) {
		List<Account> accList = retrieveAccDetails(accIds, types);
		Map<Id, List<Customer_External_Account__c>> rv = new Map<Id, List<Customer_External_Account__c>>();
		for (Account acc : accList) { rv.put(acc.Id, acc.Customer_External_Accounts__r); }
		return rv;
	}

	public static void processV1Callback() {
		RestRequest req = RestContext.request;
		AccountV1Callback reqBody = (AccountV1Callback) JSON.deserialize(req.requestBody.toString(), AccountV1Callback.class);
		AccountReq convToNew = reqBody.payload.toAccountReq();
		System.debug(convToNew);
		saveCustAcc(convToNew);
	}

	public static void processCallback() {
		RestRequest req = RestContext.request;
		AccountCallback reqBody = (AccountCallback) JSON.deserialize(req.requestBody.toString(), AccountCallback.class);
		saveCustAcc(reqBody.payload);
	}

	public static Account saveCustAcc(AccountReq reqBody) {
		if (reqBody == null || String.isBlank(reqBody.uuid) || reqBody.identity == null || String.isBlank(reqBody.identity.fullName) ||
			String.isBlank(reqBody.email) || reqBody.agreement == null) {
			throw new CustAppAPI.CustAppException('Invalid request.' + reqBody);
		}
		Company__c companyInfo = [SELECT Id, Name FROM Company__c WHERE AbAppCompany__c = :reqBody.company LIMIT 1];
		String type = CustAppAccount.EXT_ACC_TYPE.get(companyInfo.Name);
		String uuid = reqBody.uuid;
		if (String.isBlank(type)) { throw new CustAppAPI.CustAppException('Invalid External account mapping.'); }
		String query = 'SELECT ' + String.join(CustAppAccount.EXT_ACC_FIELDS, ',') + ' FROM Customer_External_Account__c WHERE UUID__c = :uuid ' +
						'AND Type__c = :type';
		List<Customer_External_Account__c> extAccList = Database.query(query);
		Customer_External_Account__c extAcc = (extAccList.size() > 0) ? extAccList[0] : null;
		Account acc;
		if (extAcc == null) {
			String docType = '';
			String docId = '';
			if (reqBody.document != null) {
				docId = reqBody.document.id;
				docType = mapDocType(reqBody.document.type);
			}

			String phoneNum = (reqBody.phone != null) ? reqBody.phone.phoneNumber : '';
			phoneNum = (reqBody.phone != null) ? UtilPhone.toE164(reqBody.phone.code + reqBody.phone.phoneNumber) : '';
			acc = CustMatch.checkAcc(new Set<String> { companyInfo.Name }, docId, docType, phoneNum, reqBody.email, '', reqBody.identity.fullName);
			if (acc == null) {
				acc = new Account(RecordTypeId = PERSON_RT, Created_From__c = type);
			} else {
				acc = CustAppAccountAPI.retrieveAcc(acc.Id, companyInfo.Name, type, reqBody.uuid);
			}
		}
		else {
			acc = CustAppAccountAPI.retrieveAcc(extAcc.Account__c, companyInfo.Name, type, reqBody.uuid);
		}
		upsertAcc(acc, reqBody.identity, reqBody.email, reqBody.phone, reqBody.document, reqBody.drivingLicenseExpiry, reqBody.dateOfBirth);
		updatePDPA(acc, type, reqBody.agreement);
		updateDevices(acc, reqBody.devices);
		updateCustAcc(extAcc, acc.Id, type, reqBody.email, reqBody.uuid, reqBody.image, reqBody.identity.fullName);
		// if (!String.isBlank(reqBody.image)) {
		// 	String name = type + ' ' + CustAppAccount.IMG_ATT;
		// 	CustAppFile.saveFile(reqBody.image, name, acc.Id, CustAppAccount.EVENT_NAME, acc.Id);
		// }
		return acc;
	}

	public static AgreementCls retrieveLocalLegislation(List<Local_Legislation__c> legList) {
		return (legList.size() > 0) ? new AgreementCls(legList[0]) : null;
	}

	public static void upsertAcc(Account acc, CustAppAccount.IdentityCls identity, String email, CustAppAccount.PhoneCls phone,
								CustAppAccount.DocCls document, DateTime drivingLicenseExpiry, DateTime dateOfBirth) {
		switch on identity.salutation {
			when 'MR' {
				acc.Salutation = 'Mr';
			} when 'MS' {
				acc.Salutation = 'Ms';
			} when 'MRS' {
				acc.Salutation = 'Mrs';
			} when 'MDM' {
				acc.Salutation = 'Mdm';
			} when 'DR' {
				acc.Salutation = 'Dr';
			} when 'CAPTAIN' {
				acc.Salutation = 'Captain';
			} when 'DATO' {
				acc.Salutation = 'Dato\'';
			} when 'DATIN' {
				acc.Salutation = 'Datin';
			} when 'PROFESSOR' {
				acc.Salutation = 'Professor';
			} when 'JUS' {
				acc.Salutation = 'Jus';
			} when else {
				acc.Salutation = identity.salutation;
			}
		}
		if (acc.Id == null || !acc.Verified_With_NRIC__c) {
			acc.LastName = identity.fullName;
		} else {
			acc.Prefer_Name__pc =  identity.fullName;
		}
		acc.DisplayName__c = identity.fullName;
		CommonMethodsLibrary.setEmail(acc, email); // TODO: move to common methods library
		// TODO: check for country code?
		if (phone != null) {
			string e164 = UtilPhone.toE164(phone.code + phone.phoneNumber);
			Integer phoneCode = String.isBlank(phone.code) ? null : Integer.valueOf(phone.code.replaceAll('\\D', ''));
			if (!(phone.phoneNumber == acc.Mobile_Preferred__pc && phoneCode == acc.Mobile_Country_Code_1__pc
				  && e164 == acc.PersonMobilePhone)) {
				List<Account> updAcc = new List<Account>();
				acc.Mobile_Country_Code_1__pc = phoneCode;
				acc.Mobile_Preferred__pc = phone.phoneNumber;
				acc.PersonMobilePhone = e164;
				List<Account> accList = [
					SELECT
						Id, Account_Name__c, Mobile_Preferred__pc, LastName
					FROM Account
					WHERE
						IsPersonAccount = TRUE
						AND (
							Mobile_Preferred__pc = :phone.phoneNumber
							OR PersonMobilePhone = :e164
						)
				]; // TODO: sg uniquness doesnt factor country code
				for (Account a : accList) {
					if (a.Id == acc.Id) { continue; }
					a.Profile_Update_Duplicated_Mobile__c = true;
					a.Mobile_Preferred__pc = 'CRM';
					a.PersonMobilePhone = 'CRM';
					updAcc.add(a);
				}
				update updAcc;
			}

		}
		if (document != null) {
			if (acc.Customer_Number__c == null) {
				// update NRIC from AB app, because account not sync'ed from AL
				acc.Verified_With_NRIC__c = false;
				// acc.NRIC_Number__c = document?.id?.toUpperCase();
				acc.Partial_NRIC__c = document?.id?.toUpperCase();
				acc.Doc_Type__c = mapDocType(document.type); // remove existing nric if change doc type
			}
			else if (String.isBlank(acc.NRIC_Number__c)) {
				acc.Verified_With_NRIC__c = false;
				// acc.NRIC_Number__c = document?.id?.toUpperCase();
				acc.Partial_NRIC__c = document?.id?.toUpperCase();
				acc.Doc_Type__c = mapDocType(document.type); // remove existing nric if change doc type
			}
		}
		acc.PersonBirthDate = (dateOfBirth != null) ? dateOfBirth.date() : acc.PersonBirthDate;
		acc.LicenseExpiryDate__pc = (drivingLicenseExpiry != null) ? drivingLicenseExpiry.date() : acc.LicenseExpiryDate__pc;
		upsert acc;
	}

	public static String mapDocType(String custAppDocType) {
		switch on custAppDocType {
			when 'SINGAPORE_NRIC' {
				return 'Singapore NRIC (e.g. S1234567D)';
			}
			when 'FOREIGN_IDENTIFICATION_NUMBER' {
				return 'Foreign Identification Number (e.g. F/G1234567N)';
			}
			when 'MALAYSIA_NRIC' {
				return 'Malaysian NRIC';
			}
			when 'FOREIGN_PASSPORT' {
				return 'Passport No.';
			}
			when 'GOVERNMENT' {
				return 'Government Entity';
			}
			when 'BUSINESS', 'ORGANIZATION', 'COMPANY', 'FOREIGN_COMPANY', 'LIMITED_LIABILITY_PARTNERSHIP', 'LIMITED_PARTNERSHIP'
				 , 'PROFESSIONAL','STATUTORY_BOARD' {
				return 'Company Reg No.';
			} 
			when else {
				throw new CustAppAPI.CustAppException('Invalid Document Type:' + custAppDocType);
			}
		}
	}

	public static void updatePDPA(Account acc, String custAppType, CustAppAccount.AgreementCls agreement) {
		if (agreement.referenceId != CustAppAccount.AGREEMENT_REF) { return; }
		Boolean shouldCreate = true;
		for (Local_Legislation__c leg : acc.Local_Legislations__r) {
			if (!shouldCreate) { break; }
			shouldCreate = shouldCreate && !(leg.Legislation_Type__r.Name == CustAppAccount.AGREEMENT_TYPE &&
							leg.Type_of_Legal_Legislation_Version__c == CustAppAccount.AGREEMENT_VER);
		}
		if (!shouldCreate) { return; }
		if (agreement.clauses == null) { throw new CustAppAPI.CustAppException('No clauses provided for agreement ' + agreement.referenceId); }
		Boolean dataConsent, marketingConsent;
		for (CustAppAccount.ClauseCls c : agreement.clauses) {
			for (ElementCls e : c.elements) {
				switch on e.type {
					when 'DATA_CONSENT' {
						dataConsent = e.isChecked;
					} when 'MARKETING' {
						marketingConsent = e.isChecked;
					}
				}
			}
		}
		if (dataConsent == null || !dataConsent) { throw new CustAppAPI.CustAppException('isAgreed false for data consent'); }
		PDPA.createPDPA(acc, custAppType, marketingConsent, dataConsent, true);
		return;
	}

	public static void updateDevices(Account acc, List<CustAppAccount.DeviceCls> devices) {
		if (devices == null || devices.size() <= 0) { return; }
		Map<String, User_Message_Token__c> tokenMap = new Map<String, User_Message_Token__c>();
		for (User_Message_Token__c msg : acc.User_Message_Tokens__r) { tokenMap.put(msg.Token__c, msg); }
		List<User_Message_Token__c> tokens = new List<User_Message_Token__c>();
		Set<String> seenToken = new Set<String>();
		for (CustAppAccount.DeviceCls device : devices) {
			if (seenToken.contains(device.advertisingId)) { continue; }
			User_Message_Token__c curT = tokenMap.get(device.advertisingId);
			curT = (curT == null) ? new User_Message_Token__c() : curT;
			curT.IsActive__c = true;
			curT.Last_Active_DateTime__c = DateTime.now();
			curT.Token__c = device.advertisingId;
			curT.Token_Type__c = CustAppAccount.TOKEN_TYPE;
			curT.Account__c = acc.Id;
			curT.Device_Name__c = (String.isBlank(device.device) ? '' : device.device) + (String.isBlank(device.os) ? '' : '[' + device.os + ']');
			seenToken.add(device.advertisingId);
			tokens.add(curT);
		}
		upsert tokens;
	}

	public static void updateCustAcc(Customer_External_Account__c extAcc, String accId, String type, String username, String uuid, String image, String name) {
		extAcc = extAcc == null ? new Customer_External_Account__c() : extAcc;
		extAcc.UUID__c = uuid;
		extAcc.Type__c = type;
		extAcc.Account__c = accId;
		extAcc.Profile_Image__c = image;
		extAcc.Username__c = username;
		extAcc.Name__c = name;
		upsert extAcc;
	}

	// TODO move to new class along with CareQR
	public static String getAccQR(Account acc, String cmp) {
		ServiceApptBooking.CareQR qr = new ServiceApptBooking.CareQR(acc, cmp);
		return ServiceApptBooking.QR_SRC + EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(qr)));
	}

	public static String getAccQR(Id accId, String cmp) {
		Account acc = [SELECT Id, LastName, Mobile_Preferred__pc FROM Account WHERE Id = :accId];
		return getAccQR(acc, cmp);
	}

	/** Button: Resync To AB App (Customer_External_Account__c) */
	Webservice static string pushToAbApp(Id accountId) {
		String eventName = 'RESYNC_ACCOUNT';
		try {
			Customer_App_Callback__e cb = new Customer_App_Callback__e();
			cb.Id__c = accountId;
			cb.Event__c = eventName;
			EventBus.publish(new List<Customer_App_Callback__e>{ cb });
			return 'Done!';
		}
		catch (Exception e) {
			return 'Error: ' + e.getMessage() + (Envir.isSandbox ? '\n\n' + e.getStackTraceString() : '');
		}
	}

	global class AccountV1Callback {
		public String event;
		public AccountV1Req payload;
	}

	// first sync request payload
	global class AccountV1Req extends AccountBase {
		public String uuid;
		public String image;
		public String company;
		public List<DeviceCls> devices;
		public String facebookId;
		public List<AgreementClsV1> agreements;
		public AccountReq toAccountReq() {
			AccountReq r = new AccountReq();
			r.uuid = this.uuid;
			r.image = this.image;
			r.company = this.company;
			r.devices = this.devices;
			r.facebookId = this.facebookId;
			r.identity = this.identity;
			r.email = this.email;
			r.drivingLicenseExpiry = this.drivingLicenseExpiry;
			r.dateOfBirth = this.dateOfBirth;
			r.phone = this.phone;
			r.document = this.document;
			if (this.agreements != null && this.agreements.size() > 0) {
				AgreementClsV1 curAgreement = this.agreements[0];
				r.agreement = new AgreementCls();
				r.agreement.type = curAgreement.type;
				r.agreement.referenceId = curAgreement.referenceId;
				r.agreement.clauses = new List<ClauseCls>();
				if (curAgreement.clauses != null) {
					for (ClauseV1Cls c : curAgreement.clauses) {
						ClauseCls newC = new ClauseCls(c.type, c.type, c.isCompulsory, c.isAgreed);
						r.agreement.clauses.add(newC);
					}
				}
			}
			return r;
		}
	}
	
	global class AccountCallback {
		public String event;
		public AccountReq payload;
	}

	global virtual class AccountBase {
		public CustAppAccount.IdentityCls identity;
		public String email;
		public DateTime drivingLicenseExpiry;
		public DateTime dateOfBirth;
		public CustAppAccount.PhoneCls phone;
		public CustAppAccount.DocCls document;

		global AccountBase() {}
		global AccountBase(Account acc, String cmp) {
			this(acc, null, cmp);
		}

		global AccountBase(Account acc, Customer_External_Account__c extAcc, String cmp) {
			this.identity = new IdentityCls();
			this.identity.fullName = extAcc?.Name__c;
			if (String.isBlank(this.identity.fullName)) { this.identity.fullName = acc.DisplayName__c; }
			if (String.isBlank(this.identity.fullName)) { this.identity.fullName = acc.LastName; }
			switch on acc.Salutation {
				when 'Mr', 'Ms', 'Mrs', 'Mdm', 'Dr', 'Captain', 'Datin', 'Professor', 'Jus' {
					this.identity.salutation = acc.Salutation.toUppercase();
				} when 'Dato\'' {
					this.identity.salutation = 'DATO';
				} when else {
					this.identity.salutation = acc.Salutation;
				}
			}
			if (String.isNotBlank(acc.PersonMobilePhone)) {
				this.phone = new PhoneCls(acc.PersonMobilePhone);
			}
			if (!String.isBlank(acc.Mobile_Preferred__pc)) {
				this.phone = new PhoneCls();
				this.phone.code = String.valueOf(acc.Mobile_Country_Code_1__pc);
				this.phone.phoneNumber = (acc.Mobile_Preferred__pc == 'CRM') ? '' : acc.Mobile_Preferred__pc;
			}
			// if (String.isNotBlank(acc.DocumentNumberAlphaN__c) || String.isNotBlank(acc.NRIC_Number__c)) {
			// 	this.document = new DocCls();
			// 	// this.document.id = acc.NRIC_Number__c; // acc.Partial_NRIC__c; // requested for full NRIC
			// 	switch on acc.Doc_Type__c {
			// 		when 'Singapore NRIC (e.g. S1234567D)' {
			// 			this.document.type = 'SINGAPORE_NRIC';
			// 		}
			// 		when 'Foreign Identification Number (e.g. F/G1234567N)' {
			// 			this.document.type = 'FOREIGN_IDENTIFICATION_NUMBER';
			// 		}
			// 		when 'Company Reg No.' {
			// 			this.document.type = 'BUSINESS';
			// 		}
			// 		when 'Malaysian NRIC' { /** 20200630 - Malaysia implementation */
			// 			this.document.type = 'MALAYSIA_NRIC';
			// 		}
			// 		when 'Passport No.'  { //'Foreign Document/Passport' {
			// 			this.document.type = 'FOREIGN_PASSPORT';
			// 		}
			// 		when 'Singapore NRIC / FIN (e.g. S1234567D)' {
			// 			if (!String.isBlank(acc.NRIC_Number_wo_Prefix__c)) {
			// 				if (acc.NRIC_Number_wo_Prefix__c.startsWith('S') || acc.NRIC_Number_wo_Prefix__c.startsWith('T')) {
			// 					this.document.type = 'SINGAPORE_NRIC';
			// 				} else {
			// 					this.document.type = 'FOREIGN_IDENTIFICATION_NUMBER';
			// 				}
			// 			}
			// 		}
			// 		when else {
			// 			this.document.type = '';
			// 		}
			// 	}
			// }
			this.email = acc.Default_Email__c;
			this.drivingLicenseExpiry = acc.LicenseExpiryDate__pc;	
			this.dateOfBirth = acc.PersonBirthDate;
		}
	}

	// outgoing to whip account update webhook
	global class AccountWebhook {
		public String event;
		public AccountPayLoad payload;
		global AccountWebhook(String event, AccountPayLoad payload) {
			this.event = event;
			this.payload = payload;
		}
	}

	// outgoing to whip account update webhook payload
	global class AccountPayLoad extends AccountBase {
		public String uuid;
		public String qrCodeUrl;
		global AccountPayLoad() {}
		global AccountPayLoad(Account acc, String cmp, Customer_External_Account__c extAcc) {
			super(acc, extAcc, cmp);
			this.uuid = extAcc.UUID__c;
			this.qrCodeUrl = CustAppAccount.getAccQR(acc, cmp);
		}
	}

	// first sync request payload
	global class AccountReq extends AccountBase {
		public String uuid;
		public String image;
		public String company;
		public List<DeviceCls> devices;
		public String facebookId;
		public AgreementCls agreement;
	}

	// response to first sync
	global class AccountSync extends AccountBase {
		public String id;
		public String qrCodeUrl;
		public AgreementCls agreement;

		global AccountSync() {}
		global AccountSync(Account acc, Customer_External_Account__c extAcc, String cmp) {
			super(acc, extAcc, cmp);
			this.id = acc.id;
			this.qrCodeUrl = CustAppAccount.getAccQR(acc, cmp);
			this.agreement = CustAppAccount.retrieveLocalLegislation(acc.Local_Legislations__r);
		}
	}

	// resync payload
	global class AccountResync extends AccountBase {
		public String id;
		public String uuid;
		public String qrCodeUrl;

		global AccountResync() {}
		global AccountResync(Account acc, Customer_External_Account__c extAcc, String cmp) {
			super(acc, cmp);
			this.id = acc.id;
			this.qrCodeUrl = CustAppAccount.getAccQR(acc, cmp);
			this.uuid = extAcc.UUID__c;
		}
	}

	global class IdentityCls {
		public String salutation;
		public String fullName;
	}

	global class PhoneCls {
		public String code;
		public String phoneNumber;
		global PhoneCls() { this(''); }
		global PhoneCls(String phoneNum) {
			if (!String.isBlank(phoneNum)) {
				UtilPhone up = new UtilPhone(phoneNum);
				this.code = String.valueOf(up.getCountryCode());
				this.phoneNumber = (up.toE164() != null) ? up.toNoPrefixNumber() : '';
			}
			else {
				this.code = '';
				this.phoneNumber = '';
			}
		}
	}

	global class DocCls {
		public String type;
		public String id;
	}

	global class AgreementClsV1 {
		public String type;
		public String referenceId;
		public List<ClauseV1Cls> clauses;
		global AgreementClsV1() {}
		global AgreementClsV1(Local_Legislation__c legal) {
			if (legal.Legislation_Type__r.Name == AGREEMENT_TYPE && legal.Consent_Status__c == 'Consent') { this.setPDPAAgreement(legal); }
		}

		public void setPDPAAgreement(Local_Legislation__c legal) {
			this.type = 'USER_REGISTRATION';
			this.referenceId = AGREEMENT_REF;
			this.clauses = new List<ClauseV1Cls>();
			this.clauses.add(new ClauseV1Cls('DATA_CONSENT', true, legal.I_Have_Read_The_Consent_Provisions__c));
			this.clauses.add(new ClauseV1Cls('MARKETING', false, legal.Opt_In__c));
		}
	}

	global class ClauseV1Cls {
		public String type;
		public Boolean isCompulsory;
		public Boolean isAgreed;
		global ClauseV1Cls(String type, Boolean isCompulsory, Boolean isAgreed) {
			this.type = type;
			this.isAgreed = isAgreed;
			this.isCompulsory = isCompulsory;
		}
	}

	global class AgreementCls {
		public String type;
		public String referenceId;
		public List<ClauseCls> clauses;
		global AgreementCls() {}
		global AgreementCls(Local_Legislation__c legal) {
			if (legal.Legislation_Type__r.Name == AGREEMENT_TYPE && legal.Consent_Status__c == 'Consent') { this.setPDPAAgreement(legal); }
		}

		public void setPDPAAgreement(Local_Legislation__c legal) {
			this.type = 'USER_REGISTRATION';
			this.referenceId = AGREEMENT_REF;
			this.clauses = new List<ClauseCls>();
			this.clauses.add(new ClauseCls('Data Storage Privacy and Policy', 'DATA_CONSENT', true, legal.I_Have_Read_The_Consent_Provisions__c));
			this.clauses.add(new ClauseCls('Marketing', 'MARKETING', false, legal.Opt_In__c));
		}
	}

	global class ClauseCls {
		public String title;
		public List<ElementCls> elements;
		global ClauseCls(String title, String type, Boolean isCompulsory, Boolean isChecked) {
			this.title = title;
			this.elements = new List<ElementCls> { new ElementCls(title, type, isCompulsory, isChecked) };
		}
	}

	global class ElementCls {
		public String title;
		public String type;
		public Boolean isCompulsory;
		public Boolean isChecked;
		global ElementCls(String title, String type, Boolean isCompulsory, Boolean isChecked) {
			this.title = title;
			this.type = type;
			this.isCompulsory = isCompulsory;
			this.isChecked = isChecked;
		}
	}

	global virtual class DeviceCls {
		public String device;
		public String os;
		public String osVersion;
		public String appVersion;
		public String advertisingId;
	}
}