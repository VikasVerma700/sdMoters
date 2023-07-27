@RestResource(urlMapping='/care/user/pdpa')
global without sharing class CarePDPA {
	public final static Organization CUR_ORG = [SELECT Id, IsSandbox FROM Organization LIMIT 1];
	private final static Map<String, List<String>> ERR_USER = new Map<String, List<String>> {'028' => new List<String> { 'abcustomercare@autobavaria.com.my' }};
	private final static Site site;
	private final static SiteDetail siteDetail;
	private static String URL_BASE;
	static {
		try {
			site = [SELECT Id, Name, Description FROM Site WHERE Name = 'Care' AND Status = 'Active'];
			siteDetail = [SELECT Id, SecureUrl FROM SiteDetail WHERE DurableId = :site.Id LIMIT 1];
			Organization curOrg = [SELECT Id, IsSandbox FROM Organization LIMIT 1];
			// URL_BASE = (curOrg.IsSandbox) ? Force_com_Site_URL__c.getValues('Sandbox').URL__c : Force_com_Site_URL__c.getValues('Production').URL__c;
			URL_BASE = siteDetail.SecureUrl;
		}
		catch (Exception e) {}
	}

	@HttpGet
	global static void getTerms() {
		RestResponse res = RestContext.response;
		try {
			RestRequest req = RestContext.request;
			String cmp = req.params.get('cmp');
			if (String.isBlank(cmp)) { throw new ServiceApptBooking.ApptException('No Company defined.'); }
			String tnc = PDPA.getEmbeddedTNC(cmp);
			PDPA_Consent__mdt pdpaTerms = PDPA.consentTerms(cmp);
			if (String.isBlank(tnc) || pdpaTerms == null) { throw new ServiceApptBooking.ApptException('Unable to get PDPA Terms and Conditions'); }
			PDPATerms rv = new PDPATerms(tnc, pdpaTerms);
			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(rv));
		} catch (Exception e) {
			res.responseBody = Blob.valueOf(JSON.serialize(new PDPATerms(e)));
			res.statusCode = 400;
		}
	}

	@HttpPost
	global static void updatePDPA(String accId, String company, Boolean optIn, Boolean readTC, Boolean copy, DateTime consentDT, String regNum) {
		RestResponse res = RestContext.response;
		try {
			if (accId == null || accId == '') { throw new ServiceApptBooking.ApptException('No Account id specified'); }
			if (company == null || company == '') { throw new ServiceApptBooking.ApptException('No Company specified'); }
			if (consentDT == null) { throw new ServiceApptBooking.ApptException('No Consent Datetime provided'); }
			if (regNum == null || regNum == '') { throw new ServiceApptBooking.ApptException('No Reg Num provided'); }
			List<Account> curAcc = [SELECT Id, Default_Email__c, NRIC_Number__c, NRIC_Number_WO_Prefix__c, Salutation, Account_Name__c, Name, PDPA_Consent_Version__c,
									PDPA_Consent_Status__c, Doc_Type__c, Country__c FROM Account WHERE Id = :accId];
			if (curAcc.size() <= 0) { throw new ServiceApptBooking.ApptException('Invalid account id provided.'); }
			Local_Legislation__c newLeg = PDPA.createPDPA(curAcc[0], 'ACP', optIn, readTC, false);
			newLeg.Do_you_wish_to_have_copy_of_T_C__c = copy;
			newLeg.Registration_Number_Entered__c = regNum;
			insert newLeg;


			if (copy) {
				if (curAcc[0].Default_Email__c == null || curAcc[0].Default_Email__c == '') {
					String emailBody = CommonMethodsLibrary.constructErrEmail('Care App', 'AccountId:' + curAcc[0].Id,
																				'Unable to send copy of PDPA to:' + curAcc[0].Name);
					List<String> emailList = ERR_USER.get(company);
					if (emailList == null) { throw new ServiceApptBooking.ApptException('Unidentified company:' + company); }
					List<User> uList = [SELECT Id, Email FROM User WHERE Email IN :emailList];
					CommonMethodsLibrary.sendErrorEmail(uList, emailBody);
				} else {
					Attachment att = PDPA.getTNC(company);
					if (att == null) { throw new ServiceApptBooking.ApptException('Unable to get PDPA Terms and Conditions.'); }
					emailPDPA(curAcc[0], att, company);
				}
			}
			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(new ServiceApptBooking.APIResp()));
			return;
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.statusCode = 400;
			res.responseBody = Blob.valueOf(JSON.serialize(new PDPAResp(e)));
		}
	}

	private static void emailPDPA(Account acc, Attachment att, String company) {
		Messaging.reserveSingleEmailCapacity(1);
		Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
		email.setToAddresses(new List<String> { acc.Default_Email__c });
		email.setReplyTo('abcustomercare@autobavaria.com.my');
		email.setSenderDisplayName('Auto Bavaria Care');
		email.setSubject('[Auto Bavaria Care] Copy of Terms & Conditions (Version ' + PDPA.PDPA_VER + ')');
		email.setBccSender(false);
		email.setUseSignature(false);
		String body = 'Dear ' + (String.isBlank(acc.Salutation) ? '' : acc.Salutation + ' ') + ' ' 
								+ (String.isBlank(acc.Account_Name__c) ? acc.Name : acc.Account_Name__c) + ','
								+ '<br /><br />Thank you for accepting our Terms and Conditions. We have attached a copy of the Terms & Conditions for your reference '
								+ '<a href="' + URL_BASE + '/servlet/servlet.FileDownload?file='+ att.Id +'">here.</a><br /><br />Warmest Regards,<br/>' +
								'Auto Bavaria Care';
		email.setHtmlBody(body);
		if (Test.isRunningTest() || CUR_ORG.IsSandbox) {
			email.setToAddresses(new string[] { UserInfo.getUserEmail() });
			System.debug('emailPDPA(): ' + JSON.serialize(email));
		} else {
			Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
		}
	}

	global class PDPAReq {
		global String cmp;
	}

	global class PDPAResp extends ServiceApptBooking.ApiResp { public PDPAResp(Exception e) { super(e); } }

	global class PDPATerms extends ServiceApptBooking.ApiResp {
		global String terms;
		global List<String> consents;
		public PDPATerms(String tc, PDPA_Consent__mdt pdpaTerms) {
			this.terms = tc;
			if (String.isBlank(pdpaTerms.PDPA_Consent__c) || String.isBlank(pdpaTerms.Marketing_Consent__c)) {
				throw new ServiceApptBooking.ApptException('Invalid PDPA Terms and Conditions.');
			}
			this.consents = new List<String> { pdpaTerms.PDPA_Consent__c, pdpaTerms.Marketing_Consent__c };
		}
		public PDPATerms(Exception e) { super(e); }
	}
}