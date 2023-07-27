global without sharing class CustAppTD {
	public static final String SIGNED_PDF = 'Test_Drive_Signed.pdf';
	public final static String PML_TEAM = 'BMW';
	public final static String PMA_TEAM = 'Team M';
	public final static Set<String> BMW_TEAM = new Set<String>{ PML_TEAM, PMA_TEAM };
	public final static String EVENT_NAME = 'UPSERT_TEST_DRIVE';
	public final static Map<String, String> CMP_EXT_ACC = new Map<String, String> { '02' => 'BMW Customer App', '05' => 'BMW Customer App',
																					'888' => 'BMW Customer App', '028' => 'BMW Customer App' };
	public final static Map<String, Set<String>> TD_CMP = new Map<String, Set<String>> { '02' => new Set<String> { '02', '888' }
																						  , '028' => new Set<String> { '028' } };
	public final static Map<String, Set<String>> TD_ADD_TEAM = new Map<String, Set<String>> { '02' => new Set<String> { 'BPS Team 315', 'BPS Team ECC' }};
	public static List<String> TD_FIELDS;
	static {
		TD_FIELDS = new List<String> { 'Id', 'Name', 'Opportunity__r.Company__r.AbAppCompany__c', 'Test_Drive_Address__c', 'Test_Drive_Status__c',
										'Test_Drive_Geolocation__Latitude__s', 'Test_Drive_Geolocation__Longitude__s', 'Scheduled_Start_DateTime__c',
										'Scheduled_End_DateTime__c', 'Vehicle_Out_DateTime__c', 'Vehicle_In_DateTime__c', 'Trade_Plate_Number__c', 'Account__c',
										'Opportunity__r.Request_Reference__c', 'Registration_Number__c', 'Model__c', 'Company__r.Name'
									};
		TD_FIELDS.addAll(CustAppAPI.prefixFields(CustAppUser.USER_FIELDS, 'Opportunity__r.Owner.'));
		TD_FIELDS.addAll(CustAppAPI.prefixFields(CustAppVehicle.VEH_FIELDS, 'Registration_Number__r.'));
		TD_FIELDS.addAll(CustAppAPI.prefixFields(CustAppVehicle.MODEL_FIELDS, 'Model__r.'));
	}

	public static void sendWebhook(Customer_App_Callback__e callback) {
		String testDriveId = callback.Id__c;
		// String query = 'SELECT ' + String.join(TD_FIELDS, ',') + ',(SELECT ' + String.join(CustAppFile.ATT_FIELDS, ',') + ' FROM Attachments) ';
		// query += 'FROM Test_Drive__c WHERE Id = :testDriveId';
		List<Test_Drive__c> tdList = null; //Database.query(query);
		if (tdList == null || tdList.size() <= 0) { return; }
		// Set<String> types = new Set<String>();
		// for (Test_Drive__c td : tdList) {
		// 	String curType = CMP_EXT_ACC.get(td.Company__r.Name);
		// 	if (!String.isBlank(curType)) { types.add(curType); }
		// }
		// List<Customer_External_Account__c> accounts = CustAppAccount.getExtAccounts(tdList[0].Account__c, types);
		// if (accounts.size() <= 0) { return; }
		// for (Customer_External_Account__c custAcc : accounts) {
		// 	String cmp = CustAppAccount.REV_TYPE.get(custAcc.Type__c);
		// 	if (cmp == null) { continue; }
		// 	for (Test_Drive__c td : tdList) {
		// 		TDPayload payload = new TDPayload(td);
		// 		TDWebhook hook = new TDWebhook(EVENT_NAME, payload);
		// 		CustAppAPI.sendWebhook(JSON.serialize(hook));
		// 	}
		// }
	}

	public static List<TDSync> retrieveTD(Id accId, String cmp) {
		// Set<String> allowedTD = TD_CMP.get(cmp);
		// Set<String> additionalTeam = TD_ADD_TEAM.get(cmp);
		// if (allowedTD == null) {
		// 	throw new CustAppAPI.CustAppException('TD CMP not mapped');
		// }
		// Set<String> disallowedStatus = new Set<String> { 'CANCELLED' };
		// String query = 'SELECT ';
		// query += String.join(TD_FIELDS, ',');
		// query += ',(SELECT ' + String.join(CustAppFile.ATT_FIELDS, ',') + ' FROM Attachments)';
		// query += ' FROM Test_Drive__c WHERE Opportunity__r.AccountId = :accId AND Test_Drive_Status__c NOT IN :disallowedStatus AND ';
		// query += '(Opportunity__r.Company__r.Name IN :allowedTD OR Opportunity__r.Owner.Team_Number_Mgr__c = :additionalTeam)';
		// List<Test_Drive__c> tdList = Database.query(query);
		List<TDSync> res = new List<TDSync>();
		// for (Test_Drive__c td : tdList) {
		// 	if (td.Registration_Number__c == null) { continue; } // todo: discuss with mahdi
		// 	TDSync tdData = new TDSync(td);
		// 	res.add(tdData);
		// }
		return res;
	}

	public static void processCallback() {
		RestRequest req = RestContext.request;
		TDReqCallback reqBody = (TDReqCallback) JSON.deserialize(req.requestBody.toString(), TDReqCallback.class);
		if (reqBody == null || reqBody.payload == null || reqBody.payload.testDrive == null) { throw new CustAppAPI.CustAppException('Empty payload.'); }
		String uuid = reqBody.payload.testDrive.accountUuid;
		List<Customer_External_Account__c> custAccList = CustAppEnquiryBase.getCustAccList(uuid);
		if (custAccList.size() <= 0) { throw new CustAppAPI.CustAppException('Unknown customer UUID.'); }

		String cmpName = CustAppAccount.REV_TYPE.get(custAccList[0].Type__c);
		Company__c cmp = CustAppAPI.CMP_MAP.get(cmpName);
		if (cmp == null) { throw new CustAppAPI.CustAppException('Unable to find company:' + cmpName); }
		if (String.isBlank(cmpName)) { throw new CustAppAPI.CustAppException('Unable to map customer UUID Type.'); }
		Vehicle_Model__c model;
		if (cmpName == '02') {
			// model = mapToBMWModel(cmpName, reqBody.payload.testDrive.unit);
		} else if (cmpName == '028') {

		} else {
			throw new CustAppAPI.CustAppException('Model Mapping not done yet.');
		}
		// String modelInt = mapModelToModelInterest(model);
		// Id sc = assignSC(cmp.Name, modelInt, custAccList[0]);
		// if (sc == null) { throw new CustAppAPI.CustAppException('Unable to map Sales Consultant. Should never reach here.'); }
		// User scUser = [SELECT Id, Company__c FROM User WHERE Id = :sc];
		// Lead_Traffic__c lt = CustAppEnquiryBase.createLeadTraffic(cmp, custAccList[0].Account__r, scUser, modelInt);
		// Opportunity opp = CustAppEnquiryBase.findExistingOrCreateOpp(custAccList[0], lt.Id, scUser, cmp, modelInt);
		// setOppDescription(opp, reqBody.payload.testDrive);
		// opp.Request_Reference__c = reqBody.payload.testDrive.referenceNumber;
		// upsert opp;
		// CustAppEnquiryBase.createTask(cmp, opp, custAccList[0]);
	}

	// public static Vehicle_Model__c mapToBMWModel(String cmp, ModelReqCls modelReq) {
	// 	if (modelReq == null || String.isBlank(modelReq.variant)) { throw new CustAppAPI.CustAppException('Invalid model or invalid variant.'); }
	// 	List<Vehicle_Model__c> modelList = [SELECT Id, Vehicle_Type__r.Name, Company__r.Name, Name, Series_Picklist__c FROM Vehicle_Model__c WHERE
	// 										Company__r.Name = :cmp AND Name = :modelReq.model];
	// 	if (modelList.size() <= 0) { throw new CustAppAPI.CustAppException('Unable to find specific model.'); }
	// 	Vehicle_Model__c model;
	// 	for (Vehicle_Model__c m : modelList) {
	// 		if (model == null) {
	// 			model = m; // take at least one
	// 		} else {
	// 			if (m.Vehicle_Type__r.Name == 'NC' && (m.Company__r.Name == cmp || model.Vehicle_Type__r.Name != 'NC')) {
	// 				model = m;
	// 			}
	// 		}
	// 	}
	// 	return model;
	// }

	// public static String mapModeltoModelInterest(Vehicle_Model__c model) {
	// 	if (model != null && (model.Company__r.Name == '02' || model.Company__r.Name == '888')) {
	// 		if (String.isBlank(model.Series_Picklist__c)) {
	// 			throw new CustAppAPI.CustAppException('Invalid Series Picklist for' + model.Name + ' (' + model.Id + ')');
	// 		}
	// 		// List<Schema.PicklistEntry> picklistsRaw = Account.Model_Interest_PML__c.getDescribe().getPicklistValues();
	// 		// picklistsRaw.addAll(Account.Model_Interest_PMA__c.getDescribe().getPicklistValues());
	// 		Set<String> picklist = new Set<String>();
	// 		// for (Schema.PicklistEntry p : picklistsRaw) { picklist.add(p.getValue()); }
	// 		// if (picklist.contains(model.Series_Picklist__c)) { return model.Series_Picklist__c; }
	// 		// if (model.Vehicle_Type__r.Name != null) {
	// 		// 	if (model.Vehicle_Type__r.Name.contains('C')) {
	// 		// 		String seriesType = model.Series_Picklist__c + ' Series';
	// 		// 		if (picklist.contains(seriesType)) { return seriesType; }
	// 		// 	}
	// 		// 	if (model.Vehicle_Type__r.Name.contains('B')) {
	// 		// 		String seriesType = 'Bike ' + model.Series_Picklist__c + ' Series';
	// 		// 		if (picklist.contains(seriesType)) { return seriesType; }
	// 		// 	}
	// 		// }
	// 	}
	// 	return ''; //model.Series_Picklist__c;
	// }

	// public static String assignSC(String cmp, String modelInt, Customer_External_Account__c extAcc) {
	// 	Set<String> team;
	// 	if (cmp == '02') {
	// 		team = BMW_TEAM;
	// 	} else if (cmp == '028') {
	// 	} else {
	// 		throw new CustAppAPI.CustAppException('Unmapped team for SC assignment');
	// 	}
	// 	String source = 'Timestamp:' + System.now().format('dd/MM/yyyy HH:mm:ss') + '\n' + extAcc.Type__c + ' Test Drive Request';
	// 	// return Assignment.assignSC(extAcc.Account__r, team, modelInt, null, source);
	// 	return null;
	// }


	// public static void setOppDescription(Opportunity opp, TDRequest req) {
	// 	String oppDesc = 'Date/Time of Enquiry: ' + Datetime.now().format('dd/MM/yyyy HH:mm:ss', 'Singapore') + '\n';
	// 	oppDesc += 'Type:' + req.type + '\n';
	// 	if (req.answers != null) {
	// 		for (AnsCls a : req.answers) {
	// 			oppDesc += a.question + ':' + a.answer + '\n';
	// 		}
	// 	}
	// 	List<String> preferredTime = new List<String>();
	// 	for (DateTime dt : req.selectedSlots) { preferredTime.add(dt.format('dd/MM/yyyy HH:mm')); }
	// 	if (req.branch != null) {
	// 		oppDesc += 'Location:' + req.branch.name + '\n';
	// 	} else {
	// 		oppDesc += 'Location:' + req.location.address + '(' + req.location.longitude + ',' + req.location.latitude + ')' + '\n';
	// 	}
	// 	oppDesc += 'Model:' + req.unit.brand + ' ' + req.unit.display + '(' + req.unit.variant + ')' + '\n';
	// 	oppDesc += 'Display Price:' + req.unit.price + '\n';
	// 	oppDesc += 'Preferred Time:' + String.join(preferredTime, ' or ');
	// 	oppDesc += (String.isBlank(req.remark)) ? '' : ('\n' + req.remark);
	// 	opp.Description = (!String.isBlank(opp.Description) ? opp.Description + '\n\n' : '') + oppDesc;
	// }


	global class TDReqCallback {
		public String event;
		public TDReqPayload payload;
	}

	global class TDReqPayload {
		public TDRequest testDrive;
	}

	global virtual class TDRequest {
		public List<DateTime> selectedSlots;
		public String companyId;
		public String referenceNumber;
		public String type;
		public String accountUuid;
		public List<AnsCls> answers;
		public CustAppLocation.LocationCls location;
		public CustAppLocation.BranchCls branch;
		public String remark;
		public ModelReqCls unit;
	}

	public class AnsCls {
		public String question;
		public String answer;
	}

	public class ModelReqCls {
		public String brand;
		public String series;
		public String model;
		public String variant;
		public String display;
		public Decimal price;
	}

	global class TDWebhook {
		public String event;
		public TDPayload payload;
		global TDWebhook(String event, TDPayload payload) {
			this.event = event;
			this.payload = payload;
		}
	}

	global class TDPayload {
		public TDSync testDrive;
		global TDPayload(Test_Drive__c td) {
			this.testDrive = new TDSync(td);
		}
		global TDPayload() {}
	}

	global class TDSync {
		public String id;
		public String referenceNumber;
		public String company;
		public CustAppUser.UserCls salesAdvisor;
		public TDVehCls unit;
		public CustAppLocation.LocationCls location;
		public TDTimeCls scheduledDateAndTime;
		public TDTimeCls actualDateAndTime;
		public List<CustAppFile.FileCls> documents;
		public String status;
		public string type;
		public string accountUuid;
		global TDSync(Test_Drive__c td) {
			// this.id = td.Id;
			// this.referenceNumber = td.Opportunity__r.Request_Reference__c;
			// this.company = td.Opportunity__r.Company__r.AbAppCompany__c;
			// this.salesAdvisor = new CustAppUser.UserCls(td.Opportunity__r.Owner);
			// if (td.Registration_Number__c != null) {
			// 	this.unit = new TDVehCls(td);
			// } else if (td.Model__c != null) {
			// 	this.unit = new TDVehCls(td.Model__r);
			// }
			// this.location = new CustAppLocation.LocationCls(td.Test_Drive_Address__c, td.Test_Drive_Geolocation__Latitude__s, td.Test_Drive_Geolocation__Longitude__s);
			// this.scheduledDateAndTime = new TDTimeCls(td.Scheduled_Start_DateTime__c, td.Scheduled_End_DateTime__c);
			// this.actualDateAndTime = new TDTimeCls(td.Vehicle_Out_DateTime__c, td.Vehicle_In_DateTime__c);
			this.documents = this.listDocs(td);
			// this.status = td.Test_Drive_Status__c;
		}
		global TDSync() {}

		public List<CustAppFile.FileCls> listDocs(Test_Drive__c td) {
			List<CustAppFile.FileCls> res = new List<CustAppFile.FileCls>();
			for (Attachment att : td.Attachments) {
				if (isTDFile(att)) { res.add(new CustAppFile.FileCls(att)); }
			}
			return res;
		}

		public Boolean isTDFile(Attachment att) {
			return att != null && !String.isBlank(att.Name) && att.Name == SIGNED_PDF; // TODO: add addendum
		}
	}

	global class TDTimeCls {
		public DateTime startTime;
		public DateTime endTime;
		global TDTimeCls(DateTime startTime, DateTime endTime) {
			this.startTime = startTime;
			this.endTime = endTime;
		}
	}

	global class TDVehCls extends CustAppVehicle.VehSpec {
		public String tradePlate;
		public String numberPlate;
		public String identificationNumber;
		public String inVehicularUnit;
		global TDVehCls(Test_Drive__c td) {
			// super(td.Registration_Number__r);
			// this.tradePlate = td.Trade_Plate_Number__c;
			// this.numberPlate = td.Registration_Number__r.Registration_Number__c;
			// this.identificationNumber = td.Registration_Number__r.Name;
			// this.inVehicularUnit = td.Registration_Number__r.IU_Number__c;
		}
		global TDVehCls(Vehicle_Model__c model) {
			super(model);
		}
		global TDVehCls() {}
	}
}