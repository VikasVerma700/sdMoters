@RestResource(urlMapping='/care/user/login')
global without sharing class CareLogin {
    private final static Map<String, String> CMP_APP_NAME = new Map<String, String> { '028' => 'Auto Bavaria Care' };
	private final static Map<String, String> DIV_APP_NAME = new Map<String, String>();
	private final static Map<String, Set<String>> DIV_MAP = new Map<String, Set<String>>();
	private final static Set<String> DEFAULT_FILTER = new Set<String> { 'M', 'C', 'E', 'B', 'MINI', 'MRAD', 'BMW', 'MIN' };
	// private final static List<String> PML_TEAM = new List<String> { 'BMW', 'BMW Motorrad' };
	// private final static Map<String, List<String>> TEAM_MAP = new Map<String, List<String>>();
	public final static Set<String> VIP_STATUS = new Set<String> { 'VIP', 'VVIP' };
	public final static Boolean IS_NEW_PROXY = true;
	public static Boolean HAS_2FA; // = (Test.isRunningTest() || false); /** false to bypass 2FA in Prod. */
	static {
		try { HAS_2FA = (Test.isRunningTest() || CareAppConfig__c.getInstance('HAS_2FA').Value__c); }
		catch (Exception e) { HAS_2FA = (Test.isRunningTest() || false); }
	}

	@HttpPost
	global static void login(String mobOrCmpRegNum, String regNum, String company, String division) {
		RestResponse res = RestContext.response;
		try {
			if (String.isBlank(mobOrCmpRegNum)) { throw new ServiceApptBooking.ApptException('Mobile or Cmp Reg Num needed.'); }
			if (String.isBlank(regNum)) { throw new ServiceApptBooking.ApptException('No Registration Number provided.'); }
			if (String.isBlank(company)) { throw new ServiceApptBooking.ApptException('No Company provided.'); }
			UtilPhone up = new UtilPhone(mobOrCmpRegNum);
			string phoneText = up.toE164();
			string mobWoPrefix = up.toNoPrefixNumber();
			string mobWPrefix = '0' + mobWoPrefix;
			string cmpRegNum = mobOrCmpRegNum.replaceAll('[^A-Za-z0-9]', '');
			Vehicle_Ownership__c[] vos = [
				SELECT
					Id, Name, Registration_No__c, Customer__c
					, Customer__r.PersonMobilePhone
					, Customer__r.Mobile_Country_Code_1__pc, Customer__r.Mobile_Preferred__pc
				FROM Vehicle_Ownership__c
				WHERE Status__c = 'Active'
				AND Registration_No__c = :regNum
				AND (
					(
						Customer__r.IsPersonAccount = true
						AND (
							(
								Customer__r.PersonMobilePhone != ''
								AND Customer__r.PersonMobilePhone = :phoneText
							)
							OR (
								Customer__r.Mobile_Preferred__pc != ''
								AND (
									Customer__r.Mobile_Preferred__pc = :mobWoPrefix
									OR Customer__r.Mobile_Preferred__pc = :mobWPrefix
								)
							)
						)
					)
					OR (
						Customer__r.IsPersonAccount = FALSE
						AND Customer__r.NRIC_Number__c != null
						AND Customer__r.NRIC_Number__c = :cmpRegNum
					)
				)
			];
			System.debug('mobOrCmpRegNum: ' + mobOrCmpRegNum);
			System.debug('regNum: ' + regNum);
			System.debug('phoneText: ' + phoneText);
			System.debug('mobWoPrefix: ' + mobWoPrefix);
			System.debug('mobWPrefix: ' + mobWPrefix);
			System.debug('cmpRegNum: ' + cmpRegNum);
			if (vos.size() <= 0) { throw new ServiceApptBooking.ApptException('Invalid Login: No matching vehicle ownership.'); }
			List<Account> accList = [
				SELECT
					Id, IsPersonAccount, PersonMobilePhone, Mobile_Country_Code_1__pc
					, Mobile_Preferred__pc, X2FA_Verified_List__c, Skip_2FA_ACP__c
				FROM Account
				WHERE Id = :vos[0].Customer__c
			];
			// string mobWoPrefix = mobOrCmpRegNum.replaceFirst('^0+', '');
			// string mobWPrefix = string.format('0{0}', new string[] { mobOrCmpRegNum.replaceFirst('^0+', '') });
			// List<Account> accList = [SELECT Id, IsPersonAccount, Mobile_Country_Code_1__pc, Mobile_Preferred__pc, X2FA_Verified_List__c, Skip_2FA_ACP__c FROM Account WHERE
			// 						// (IsPersonAccount = TRUE AND Mobile_Preferred__pc != NULL AND Mobile_Preferred__pc = :mobOrCmpRegNum)
			// 						(IsPersonAccount = TRUE AND Mobile_Preferred__pc != NULL AND (Mobile_Preferred__pc = :mobWoPrefix OR Mobile_Preferred__pc = :mobWPrefix))
			// 						OR (IsPersonAccount = FALSE AND NRIC_Number__c != null AND NRIC_Number__c = :mobOrCmpRegNum)
			// 						// OR (IsPersonAccount = FALSE AND NRIC_Number_wo_Prefix__c != null AND NRIC_Number_wo_Prefix__c = :mobOrCmpRegNum)
			// 						LIMIT 1];
			if (accList.size() <= 0) { throw new ServiceApptBooking.ApptException('Invalid Login'); }
			List<Veh> vehList = getVehList(company, division, accList[0].Id);
			Boolean existingOwner = false;
			for (Veh v : vehList) {
				if (v.regNum == regNum) {
					existingOwner = true;
					break;
				}
			}
			if (!existingOwner) { throw new ServiceApptBooking.ApptException('Invalid Login'); }
			if (HAS_2FA && accList[0].IsPersonAccount && !accList[0].Skip_2FA_ACP__c) {
				if (hasRegistered(accList[0], company)) {
					DateTime now = DateTime.now();
					CareToken.VerificationResp verifyResp = CareToken.issuePartialToken(company, division, acclist[0], now);
					String code = CareToken.generateVerificationCode(accList[0].Id, now);
					sendVerificationSMS(code, company, division, accList[0].Mobile_Preferred__pc);
					res.responseBody = Blob.valueOf(JSON.serialize(verifyResp));
					res.statusCode = 202;
				} else {
					CareToken.RegistrationResp regResp = CareToken.issuePartialTokenForReg(company, division, accList[0], DateTime.now());
					res.responseBody = Blob.valueOf(JSON.serialize(regResp));
					res.statusCode = 206;
				}
			} else {
				UserResp user = getLoginInfo(company, division, accList[0].Id, vehList);
				if (!IS_NEW_PROXY) {
					res.responseBody = Blob.valueOf(JSON.serialize(user));
				} else {
					LoginResp loginBody = new LoginResp();
					loginBody.token = CareToken.issueJWTToken(company, division, accList[0], DateTime.now());
					loginBody.user = user;
					res.responseBody = Blob.valueOf(JSON.serialize(loginBody));
				}
				res.statusCode = 200;
			}
			res.addHeader('Content-Type', 'application/json');
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new LoginResp(e)));
			res.statusCode = 400;
		}
	}

	public static void sendVerificationSMS(String code, String company, String division, String mobile) {
		mobile = u.beautifyPhone('60', mobile);
		String smsText = 'Your ';
		String cmpName = CMP_APP_NAME.get(company);
		smsText += String.isBlank(cmpName) ? '' : cmpName;
		String divName = DIV_APP_NAME.get(division);
		smsText += String.isBlank(divName) ? '' : (' ' + divName);
		smsText += ' verification code is: ' + code;
		//SendSMS sms = new SendSMS(smsText, new List<String> { mobile }, company);
		//sms.send();
		// TODO: send SMS
		String msgId = string.format('{0}{1}', new string[] { Datetime.now().format('yyMMddHHmmss'), '2FA' });
		String serviceId = string.format('{0}_{1}_2FA', new string[] { ( Envir.isSandbox ? 'Sbox' : 'Prod'), company });
		String ret = M3TechApiWrapper.deliverMessage(msgId, serviceId, smsText, mobile);
	}

	public static List<Veh> getVehList(String company, String division, Id accountId) {
		Set<String> curFilter = (company == '03') ? DIV_MAP.get(division) : DEFAULT_FILTER;
		List<Vehicle_Ownership__c> voList = [SELECT Id, Customer__c, Vehicle__r.Name, Chassis_No__c, Registration_No__c, Vehicle__c, VehicleModelDescription__c,
											// Vehicle_Make__r.Name, (SELECT Id FROM Vehicle_Ownership_Link_Vehicle_Stock__r WHERE Company__c = :company)
											Vehicle__r.Vehicle_Make__r.Name
											FROM Vehicle_Ownership__c WHERE Status__c = 'Active' AND Customer__c = :accountId];
		List<Veh> rv = new List<Veh>();
		Veh curVeh;
		for (Vehicle_Ownership__c vo : voList) {
			//if (curFilter != null && !curFilter.contains(vo.Vehicle_Make__r.Name)) { continue; }
			if (curFilter != null && !curFilter.contains(vo.Vehicle__r.Vehicle_Make__r.Name)) { continue; }
			// if (vo.Vehicle_Ownership_Link_Vehicle_Stock__r.size() <= 0) { continue; }
			curVeh = new Veh(vo, company);
			rv.add(curVeh);
		}
		return rv;
	}

	public static UserResp getLoginInfo(String company, String division, Id accountId, List<Veh> vehList) {
		// List<String> team = PML_TEAM;
		// String divCentre = '%';
		// if (company == '03') {
		// 	if (division == 'QUICK LANE') {
		// 		team = new List<String>();
		// 		for (String div : TEAM_MAP.keySet()) {
		// 			team.addAll(TEAM_MAP.get(div));
		// 		}
		// 	} else {
		// 		team = TEAM_MAP.get(division);
		// 	}
		// 	divCentre = '%' + division + '%';
		// }
		List<Account> accList = [
			SELECT
				Id, IsPersonAccount, Name, Account_Name__c, LastName, NRIC_Number_wo_Prefix__c, NRIC_Number__c, Salutation
				, Default_Email__c, PersonMobilePhone, PhoneCountryCode__c, Phone, Mobile_Country_Code_1__pc
				, Mobile_Preferred__pc, PDPA_Consent_Status__c, PDPA_Consent_Version__c
				, (
					SELECT Id, Account_Status__c FROM Account_Profile_with_Business_Units__r
					WHERE Category__c = 'Aftersales Related Matters' AND Company__r.Name = :company
					/*AND Make_Variant__c = :team*/ LIMIT 1)
				, (
					SELECT Id, Vehicle_Ownership__c, Vehicle_Ownership__r.Customer__c, Workshop__c, Workshop__r.Name
						, Employee_Master__c, Employee_Master__r.Name, Appointment_Date__c, Service_Request__c
						, Vehicle_Ownership__r.Registration_No__c, Special_Req_for_CSA__c, Workshop__r.Auto_Assign_CSA__c
						, Company__r.Name, Contact_No__c, Contact_Name__c, Created_From__c, Email_Address_Notification__c
						, Vehicle_Ownership__r.Vehicle__c, Vehicle_Ownership__r.Vehicle__r.Name, Customer_Comment__c
						, /*,GDMS_Repair_Order_Number__c,*/ Alternate_Transport__c, Alternate_Transport_Remarks__c
					FROM Service_Appointment__r
					WHERE Apppointment_Status__c NOT IN ('CANCELLED', 'NO SHOW')
					AND DAY_ONLY(convertTimeZone(Appointment_Date__c)) >= LAST_N_DAYS:2
					AND Company__r.Name = :company /*AND Workshop__r.Service_Centre_Name__c LIKE :divCentre*/),
								(SELECT Name, ACP_Status_Update_By__c, ACP_Service_Started__c, Vehicle__c, Workshop__c,
								ACP_Service_Started_Remarks__c, ACP_Service_Completed__c, ACP_Service_Completed_Remarks__c,
								ACP_Ready_for_Collection__c, ACP_Ready_for_Collection_Remarks__c, ACP_Final_Inspection__c,
								ACP_Final_Inspection_Remarks__c, Workshop__r.Contact_Number__c, RegistrationNo__c, CSA__r.Mobile_Number__c,
								VehicleOwnership__r.Vehicle__c, Company__r.Name, Service_Order_Date__c FROM ServiceOrders__r
								WHERE Stop_Status_Update__c = FALSE AND ACP_Service_Started__c = TRUE AND Service_Order_Date__c >= LAST_N_MONTHS:6
								AND Workshop__r.Allow_Appt_External__c = TRUE
								AND Company__r.Name = :company ORDER BY LastModifiedDate DESC)
								FROM Account WHERE Id = :accountId];
		if (accList.size() <= 0) { throw new ServiceApptBooking.ApptException('Invalid account Id.'); }
		UserResp resp = new UserResp(accList[0]);
		resp.vehicles = vehList;
		// we find out which cars are tagged to existing appointments
		Map<Id, Service_Appointment__c> apptVeh = new Map<Id, Service_Appointment__c>();
		for (Service_Appointment__c sa : accList[0].Service_Appointment__r) {
			apptVeh.put(sa.Vehicle_Ownership__r.Vehicle__c, sa);
		}
		resp.serviceList = new List<ServiceStatus>();
		Map<Id, ServiceOrder__c> roVeh = new Map<Id, ServiceOrder__c>();
		Service_Appointment__c curSA;
		for (ServiceOrder__c so : accList[0].ServiceOrders__r) {
			Service_Appointment__c appt = apptVeh.get(so.VehicleOwnership__r.Vehicle__c);
			if (appt != null /* && appt.RepairOrderNumber__c == so.Name &&
				((so.Company__r.Name == '02' && so.Service_Order_Date__c == Date.today()) */
				/*|| so.Company__r.Name == '03' && so.Service_Order_Date__c >= System.today().addDays(-1)) */) {
				// && apptVeh.get(so.VehicleOwnership__r.Vehicle__c).AutolineWipNo__c == so.Name
				curSA = apptVeh.get(so.Vehicle__c);
				resp.serviceList.add(new ServiceStatus(so, curSA != null && curSA.Workshop__c == so.Workshop__c));
				roVeh.put(so.Vehicle__c, so);
			}
		}

		resp.apptList = new List<ServiceApptBooking.APIBooking>();
		ServiceOrder__c curSO;
		ServiceApptBooking.APIBooking curBooking;
		for (Service_Appointment__c sa : accList[0].Service_Appointment__r) {
			curSO = roVeh.get(sa.Vehicle_Ownership__r.Vehicle__c);
			// only add in the appt if there is no open RO yet
			if ((curSO != null && curSO.Workshop__c == sa.Workshop__c) || sa.Appointment_Date__c.date() < System.today()) { continue; }
			curBooking = new ServiceApptBooking.APIBooking(sa);
			resp.apptList.add(curBooking);
		}
		return resp;
	}

	private static Boolean hasRegistered(Account acc, String cmp) {
		if (String.isBlank(acc.X2FA_Verified_List__c)) { return false; }
		Set<String> verifications = new Set<String>(acc.X2FA_Verified_List__c.split(';'));
		return verifications.contains(cmp);
	}

	global class LoginResp extends ServiceApptBooking.ApiResp {
		public LoginResp() { super(); }
		public LoginResp(Exception e) { super(e); }
		public UserResp user;
		public String token;
	}

	global class UserResp {
		public String accId;
		public String salutation;
		public String email;
		public String surname;
		public String fullName;
		public String mobile;
		public Boolean isBusiness;
		public Boolean hasPDPA;
		public String acctStatus;
		public List<Veh> vehicles;
		public List<ServiceApptBooking.APIBooking> apptList;
		public List<ServiceStatus> serviceList;

		public UserResp(Account a) {
			this.accId = a.Id;
			this.salutation = a.Salutation;
			this.email = a.Default_Email__c;
			this.surname = (a.IsPersonAccount) ? a.Account_Name__c : '';
			this.fullName = (a.IsPersonAccount) ? a.LastName : a.Name;
			if (a.IsPersonAccount) {
				this.mobile = (a.Mobile_Preferred__pc == 'CRM') 
							? '' 
							: UtilPhone.toE164(String.valueOf(a.Mobile_Country_Code_1__pc) + a.Mobile_Preferred__pc)
									.replace('+', '');
			}
			else {
				if (String.isNotBlank(a.Phone) && a.Phone.startsWith('+')) {
					this.mobile = UtilPhone.toE164(a.Phone).replace('+', '');
				}
				else {
					this.mobile = UtilPhone.toE164(a.PhoneCountryCode__c + a.Phone).replace('+', '');
				}
			}
			this.isBusiness = !a.IsPersonAccount;
			this.hasPDPA = (a.PDPA_Consent_Status__c == 'Consent') && (a.PDPA_Consent_Version__c == '2');
			if (a.Account_Profile_With_Business_Units__r.size() > 0 && VIP_STATUS.contains(a.Account_Profile_With_Business_Units__r[0].Account_Status__c)) {
				this.acctStatus = 'VIP';
			} else {
				this.acctStatus = 'Ordinary';
			}
		}
	}

	global class Veh {
		public String regNum;
		public String chassis;
		public String vehId;
		public String vo;
		public String make;
		public String model;
		public String qrUrl;

		public Veh(Vehicle_Ownership__c vo, String company) {
			this.regNum = vo.Registration_No__c;
			this.chassis = vo.Chassis_No__c;
			this.vehId = vo.Vehicle__c;
			this.vo = vo.Id;
			this.make = vo.Vehicle__r.Vehicle_Make__r.Name;
			//this.make = vo.Vehicle_Make__r.Name;
			this.model = vo.VehicleModelDescription__c;
			List<String> qrUrl = ServiceApptBooking.getVOQR(new List<Vehicle_Ownership__c> { vo }, company);
			this.qrUrl = (qrUrl.size() > 0) ? qrUrl[0] : null;
		}
	}

	global class ServiceStatus {
		public String roId;
		public String name;
		public String contact;
		public String regNum;
		public List<Status> stateList;
		public Boolean isAppt;
		public ServiceStatus(ServiceOrder__c so, Boolean isAppt) {
			this.roId = so.Id;
			this.name = so.Name;
			this.contact = so.CSA__r.Mobile_Number__c;
			this.regNum = so.RegistrationNo__c;
			this.isAppt = isAppt;
			this.stateList = new List<Status>();
			this.stateList.add(new Status(so.ACP_Service_Started__c, 'Service Started', so.ACP_Service_Started_Remarks__c));
			this.stateList.add(new Status(so.ACP_Service_Completed__c, 'Service In Progress', so.ACP_Service_Completed_Remarks__c));
			this.stateList.add(new Status(so.ACP_Ready_for_Collection__c, 'Ready For Collection', so.ACP_Ready_for_Collection_Remarks__c));
		}
	}

	global class Status {
		public String status;
		public String remarks;
		public Boolean isDone;
		public Status(Boolean done, String status, String rem) {
			this.isDone = done;
			this.status = status;
			this.remarks = rem;
		}
	}

}