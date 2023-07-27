@RestResource(urlMapping='/cust/v1.0/enquiry')
global without sharing class CustAppEnquiry {
	public final static String EVENT_NAME = 'SEND_ENQUIRY';
	public final static String UPD_EVENT_NAME = 'UPDATE_ENQUIRY';
	public static List<String> CASE_FIELDS;
	public static Map<String, String> EDM_EMAIL_ADD = new Map<String, String> { '028' => 'Sime Darby Auto Bavaria' };
	public static Map<String, Map<String, String>> EDM_TEMPLATE_MAP;
	public final static Map<String, String> BMW_TEMPLATE_MAP = new Map<String, String> {
																'Sales-related feedback' => 'Sales_eDM', 'Request for product information' => 'Product_eDM',
																'Product feedback' => 'Product_eDM', 'BMW Motorrad-related feedback' => 'Customer_Service_eDM',
																'Aftersales-related feedback' => 'Aftersales_eDM',
																'Customer service feedback' => 'Customer_Service_eDM',
																'BMW Corporate/Diplomatic Sales' => 'Product_eDM', 'Others' => 'Customer_Service_eDM' };
	public static Map<string, string> WHIP_TO_Subject;
	public static Map<string, string> WHIP_TO_Division;
	public static Map<string, string> WHIP_TO_IncidentLocation;
	public static Map<string, string> CaseStatus_To_WHIP;
	public static User USER_CCC;
	static {
		CASE_FIELDS = new List<String> { 'CaseNumber', 'Status', 'Origin', 'Company__c', 'Company__r.Name', 'UUID__c' };
		EDM_TEMPLATE_MAP = new Map<String, Map<String, String>> { '028' => BMW_TEMPLATE_MAP };
		WHIP_TO_Subject = new Map<string, string>{
			'PRODUCT_FEEDBACK' => 'Product Feedback'
			, 'AFTER_SALES_FEEDBACK' => 'Aftersales-Related Feedback'
			, 'PRODUCT_INFORMATION' => 'Request For Product Information'
			, 'BMW_MOTORRAD_RELATED_FEEDBACK' => 'BMW Motorrad-Related Feedback'
			, 'SALES_FEEDBACK' => 'Sales-Related Feedback'
			, 'OTHERS' => 'Others'
			, 'CUSTOMER_SERVICE_FEEDBACK' => 'Customer Service Feedback'
		};
		/** Subject */

		WHIP_TO_Division = new Map<string, string>{
			'After Sales' => 'AftersalesService'
			, 'IT' => 'Others'
			, 'Marketing' => 'Others'
			, 'Sales' => 'SalesBmwRetail'
			, null => 'Others'
		};
		WHIP_TO_IncidentLocation = new Map<string, string>{
			'Auto Bavaria Ara Damansara' => 'AbAraDamansara'
			, 'Auto Bavaria Kuala Lumpur' => 'AbKualaLumpur'
			, 'Auto Bavaria Sungai Besi' => 'AbSungaiBesi'
			, 'Auto Bavaria Balakong' => 'AbBalakong'
			, 'Auto Bavaria Penang' => 'AbPenang'
			, 'Auto Bavaria Johor Bahru' => 'AbJohorBahru'
			, 'Auto Bavaria Skudai' => 'AbJohorBahru'
			, 'Auto Bavaria Tebrau' => 'AbTebrau'
			, 'Auto Bavaria Sg. Pinang' => 'AbSungaiPinang'
			, 'Auto Bavaria Chan Sow Lin' => 'AbChanSowLin'
			, null => 'AbAraDamansara'
		};
		CaseStatus_To_WHIP = new Map<string, string>{
			'Draft' => 'RECEIVED'
			, 'New' => 'IN_REVIEW'
			, 'On Hold' => 'IN_REVIEW'
			, 'Escalated' => 'IN_REVIEW'
			, 'Closed' => 'CLOSED'
		};
		USER_CCC = [SELECT Id FROM User WHERE Alias = 'abcc'];
	}

	public static void processCallback() {
		RestRequest req = RestContext.request;
		System.debug('CustAppEnquiry.processcCallback(): ' + req.requestBody.toString());
		EnquiryCallback reqBody = (EnquiryCallback) JSON.deserialize(req.requestBody.toString(), EnquiryCallback.class);
		if (reqBody == null || reqBody.payload == null || reqBody.payload.enquiry == null) { throw new CustAppAPI.CustAppException('Empty payload.'); }
		Account acc;
		Company__c cmp = CustAppAPI.CMP_MAP.get(reqBody.payload.enquiry.companyId);
		if (cmp == null) { throw new CustAppAPI.CustAppException('Invalid company Id.'); }

		String uuid = reqBody.payload.enquiry.accountUuid;
		EnquiryPayload enquiryBody = reqBody.payload.enquiry;

		string subject = WHIP_TO_Subject.get(enquiryBody.subject);
		string department = WHIP_TO_Division.get(enquiryBody.division);

		Case newCase = new Case();
		newCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('General Enquiry').getRecordTypeId();
		newCase.Type = 'General Enquiry';
		newCase.Status = 'Draft';
		newCase.Priority = 'Low';
		if (!String.isBlank(uuid)) {
			List<Customer_External_Account__c> custAccList = [SELECT Id, Type__c, Account__c, Account__r.PersonContactId FROM Customer_External_Account__c
																WHERE UUID__c = :uuid];
			if (custAccList.size() > 0) {
				newCase.AccountId = custAccList[0].Account__c;
				newCase.ContactId = custAccList[0].Account__r.PersonContactId;
			}
		}
		newCase.Subject = subject == null ? enquiryBody.subject : subject;
		newCase.Origin = CustAppAccount.EXT_ACC_TYPE.get('028');
		newCase.Description = enquiryBody.details;
		newCase.Customer_Name_Manual__c = enquiryBody.name;
		newCase.Email_Address_Manual__c = enquiryBody.email;
		newCase.Mobile_No_Manual__c = (enquiryBody.phone != null) ? enquiryBody.phone.code + enquiryBody.phone.phoneNumber : '';
		newCase.UniqueCaseIdentifier__c = newCase.Type + newCase.AccountId + newCase.Subject + String.valueOf(datetime.now().format('hh:mm dd-MM-yyyy'));
		// newCase.Company__c = reqBody.payload.enquiry.companyId;
		// newCase.Company__c = CustAppAPI.CMP_MAP.get(reqBody.payload.enquiry.companyId).Id;
		newCase.UUID__c = reqBody.payload.enquiry.uuid;
		if (USER_CCC != null) { newCase.OwnerId = USER_CCC.Id; }
		if (cmp.Name == '028') {
			newCase.Department__c = department;
			newCase.Operating_Unit__c = '028';
			if (String.isNotBlank(reqBody.payload.enquiry.branch?.name)) {
				newCase.Incident_Location__c = WHIP_TO_IncidentLocation.get(reqBody.payload.enquiry.branch.name);
			}
			else {
				newCase.Incident_Location__c = 'AbAraDamansara';
			}
			// newCase.ExternalReferenceNumber__c = reqBody.payload.enquiry.referenceNumber;
		}
		else {
			throw new CustAppAPI.CustAppException('Unmapped company for case creation');
		}

		insert newCase;
		sendEmail(cmp.Name, newCase);
	}
	
	public static void sendWebhook(Customer_App_Callback__e callback) {
		String caseId = callback.Id__c;
		String query = 	'SELECT ' + String.join(CASE_FIELDS, ',') + ' ' +
						'FROM Case ' +
						'WHERE Id = :caseId '
						;
		Case[] cases = Database.query(query);
		if (cases != null && cases.size() > 0) {
			for (Case cs :cases) {
				// String caseOrigin = CustAppAccount.EXT_ACC_TYPE.get(cs.Company__r.Name);
				// if (cs.Origin == caseOrigin) {
				// 	EnquiryCallback hook = new EnquiryCallback();
				// 	hook.event = UPD_EVENT_NAME;
				// 	hook.payload = new EnquiryBody();
				// 	hook.payload.enquiry = new EnquiryPayload();
				// 	hook.payload.enquiry.uuid = cs.UUID__C;
				// 	hook.payload.enquiry.caseNumber = cs.CaseNumber;
				// 	hook.payload.enquiry.status = CaseStatus_To_WHIP.get(cs.Status);
		
				// 	String hookBody = JSON.serialize(hook, true);
				// 	CustAppAPI.sendWebhook(hookBody);
				// }
			}
		}
	}

	public static void sendEmail(String cmp, Case newCase) {
		try {
			Map<String, String> templateMap = EDM_TEMPLATE_MAP.get(cmp);
			if (templateMap == null) { return; }
			String tempName = templateMap.get(newCase.Subject);
			if (tempName == null) { return; }
			String emailName = EDM_EMAIL_ADD.get(cmp);
			if (emailName == null) { return; }

			List<EmailTemplate> tempList = [SELECT Id, Name FROM EmailTemplate WHERE DeveloperName = :tempName];
			if (tempList.size() <= 0) { return; }

			List<OrgWideEmailAddress> emailList = [SELECT Id, DisplayName FROM OrgWideEmailAddress WHERE DisplayName = :emailName];
			if (emailList.size() <= 0) { return; }
			List<Messaging.SingleEmailMessage> msgList = CommonMethodsLibrary.sendEmail(newCase.ContactId, tempList[0].Id, emailList[0].Id, null, true);
		} catch (Exception e) {
			String emailBody = CommonMethodsLibrary.constructErrEmail('CustAppEnquiry Email', e.getStackTraceString(), e.getMessage());
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
		}
	}

	@HttpGet
	global static void getEnquiry() {
		RestResponse res = RestContext.response;
		RestRequest req = RestContext.request;
		try {
			string accountUuid = req.params.get('accountUuid');
			string page = req.params.get('page');
			string count = req.params.get('count');
			if (string.isBlank(accountUuid)) {
				InvalidParameterValueException e = new InvalidParameterValueException('', '');
				e.setMessage('accountUuid not specified.');
				throw e;
			}
			EnquiryRequest reqBody = new EnquiryRequest();
			reqBody.accountUuid = accountUuid;
			if (string.isBlank(page)) { reqBody.page = 1; }
			else { reqBody.page = Integer.valueOf(page); }
			if (string.isBlank(count)) { reqBody.count = 5; }
			else { reqBody.count = Integer.valueOf(count); }
			Customer_External_Account__c[] ceas = [
				SELECT Id, Account__c
				FROM Customer_External_Account__c
				WHERE Uuid__c = :reqBody.accountUuid
				LIMIT 1
			];
			EnquiryResponse[] resp = new List<EnquiryResponse>();
			res.headers.put('Record-Limit', String.valueOf(reqBody.count));
			res.headers.put('Pagination-Current', String.valueOf(reqBody.page));
			if (ceas != null && ceas.size() >= 1) {
				AggregateResult ar = [SELECT Count(Id) FROM Case WHERE AccountId = :ceas[0].Account__c];
				Integer rowCount = (Integer)ar.get('expr0');
				Integer totalPage = Integer.valueOf((Decimal.valueOf(rowCount) / Decimal.valueOf(reqBody.count)).round(RoundingMode.UP));
				res.headers.put('Record-Total', String.valueOf(rowCount));
				res.headers.put('Pagination-Total', String.valueOf(totalPage));

				if (rowCount > 0) {
					Integer offset = (reqBody.page - 1) * reqBody.count;
					Case[] cases = [
						SELECT
							Id, CaseNumber, AccountId, Account.Name
							, Subject, Description, Status, Resolution_Remarks__c
							, CreatedDate, LastModifiedDate
						FROM Case
						WHERE AccountId = :ceas[0].Account__c
						ORDER BY CreatedDate DESC
						LIMIT :reqBody.count
						OFFSET :offset
					];
					for (Case cs :cases) {
						EnquiryResponse eres = new EnquiryResponse();
						eres.caseId = cs.Id;
						eres.caseNumber = cs.CaseNumber;
						eres.subject = cs.Subject;
						eres.description = cs.Description;
						eres.status = cs.Status;
						eres.resolution = cs.Resolution_Remarks__c;
						eres.createdDate = cs.CreatedDate;
						eres.lastModifiedDate = cs.LastModifiedDate;
						resp.add(eres);
					}
				}
			}
			else {
				res.headers.put('Record-Total', '0');
				res.headers.put('Pagination-Total', '0');
			}
			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(resp));
		}
		catch (Exception e) {
			String emailBody = CommonMethodsLibrary.constructErrEmail(
				'Error from CustAppEnquiry.getEnquiry()'
				, e.getStackTraceString()
				, e.getMessage()
			);
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
			res.statusCode = 500;
			CustAppCallback.CallbackError err = new CustAppCallback.CallbackError();
			err.message = e.getMessage();
			res.responseBody = Blob.valueOf(JSON.serialize(err));
		}
	}

	global class EnquiryCallback {
		public String event;
		public EnquiryBody payload;
	}

	global class EnquiryBody {
		public EnquiryPayload enquiry;
	}

	global class EnquiryPayload {
		public String accountUuid;
		public String uuid;
		public String name;
		public String email;
		public CustAppAccount.PhoneCls phone;
		public String subject;
		public String details;
		public String companyId;
		public String division;
		/** UPDATE_ENQUIRY */
		public String status;
		public String caseNumber;
		/** v1.1 */
		public CustAppLocation.BranchCls branch;
		public String referenceNumber;
	}

	global class EnquiryRequest {
		public string accountUuid;
		public Integer page;
		public Integer count;
	}
	global class EnquiryResponse {
		public string caseId;
		public string caseNumber;
		public string subject;
		public string description;
		public string status;
		public string resolution;
		public Datetime createdDate;
		public Datetime lastModifiedDate;
	}
}