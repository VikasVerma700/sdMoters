public without sharing class CampaignMemberNomination_Ctrl {
	public string params { get; set; }
	public Map<string, string> paramq { get; set; }
	public string name { get; set; }
	public string phone { get; set; }
	public string email { get; set; }
	public string empEmail { get; set; }
	public string empName { get; set; }
	public string branchCode { get; set; }
	public string sapId { get; set; }
	public string adUsername { get; set; }
	public string empPhone { get; set; }

	public Campaign[] cmpgList { get; set; }
	public String cmpgName{get;set;}
	public string logoImgUrl {get;set;}
	public string backgroundImgUrl {get;set;}
	public string headerText {get;set;}
	public string subHeaderText {get;set;}
	public boolean isCampaignExist{ get; set; }
	public double checkInLimit {get;set;}


	public string errMsg { get; set; }
	public string callfunc { get; set; }

	//strings to be used as csv headers
	public static final string H_ID = 'ID';
	public static final String H_NAME = 'Customer Name';
	public static final String H_PHONE = 'Contact Number';
	public static final String H_EMAIL = 'Email';
	public static final String H_P_S_B = 'Branch Code';
	public static final String H_S_ADVISOR = 'Sales Advisor Name';
	public static final String H_S_ADVISOR_EMAIL = 'Sales Advisor Email';
	public static final String H_S_ADVISOR_PHONE = 'Sales Advisor Contact Number';
	public static final String H_GUESTS = 'Number of Pax';
	public static final String H_SAP_ID = 'SAP ID';
	public static final String H_AD_USERNAME = 'Windows Login Id';

	//strings to be used as keys of campaign member map
	public static final String CONTACT_ID = 'ContactId';
	public static final String EMPLOYEE_MASTER = 'EmployeeMaster';
	public static final String SHOWROOM = 'ShowroomId';
	public static final String NEW_CONTACT = 'New Contact Created?';

	//strings to be used as keys of raw user input
	public static final String R_NAME = 'CustomerName';
	public static final String R_PHONE = 'CustomerContact';
	public static final String R_S_ADVISOR = 'SalesAdvisorName';
	public static final String R_S_ADVISOR_PHONE = 'SalesAdvisorContact';
	public static final String R_P_S_B = 'BranchCode';
	public static final String R_SAP_ID = 'SapId';

	public static final String DUP_CMP_MEMBER_MSG = 'Already a campaign member';
	public static final String NOMINATED_BY_MSG = ' Customer Already Nominated By ';
	public static final String NOMINATED_MSG = 'Customer Nominated';

	public static final String IMG_SERVLET_URL = '/servlet/servlet.ImageServer?id={0}&oid={1}';
	public static final String DEFAULT_LOGO_APINAME = 'Sime_Darby_Motor_Logo';
	public static final String HIDE_LOADER_SHOW_TOAST_SCRIPT= '<script> fncHideLoader();fncShowToast(); </script>';

	public static String joinKeys(List<String> keyList){
		String key = String.join(keyList,'_').toUpperCase();
		return key;
	}

    public CampaignMemberNomination_Ctrl() {
		params = JSON.serialize(ApexPages.currentPage().getParameters());
		paramq = ApexPages.currentPage().getParameters();

		if(paramq.containsKey('name')){
			empName = paramq.get('name');
			empEmail = paramq.get('email');
			empPhone = paramq.get('phone');
			sapId = paramq.get('sapid');
		}

		fncCheckIsCampaignExist((Id)paramq.get('Id'));	
    }

	public void resetFields()
	{
		callfunc ='';
		empName = '';
		empEmail = '';
		empPhone = '';
		sapId = '';
	}

	public Boolean fncCheckIsCampaignExist(Id cmpgId)
	{
		isCampaignExist = false;

		if(cmpgId == null)
        {
            errMsg = 'Campaign Id Not Exist or Inactive in URL.';
        }
		else{
			cmpgList = [SELECT Id, Name, LogoImage__c, BackgroundImage__c, Header__c, SubHeader__c, CheckInLimit__c FROM Campaign
			WHERE Id = :cmpgId];

			if(cmpgList.size() > 0)
			{
				isCampaignExist = true;
				Id OrgId = UserInfo.getOrganizationId();

				//Campaign Name
				cmpgName = cmpgList[0].Name;

				//Header Text
				headerText = cmpgList[0].Header__c;

				//Sub-Header Text
				subHeaderText = cmpgList[0].SubHeader__c;

				//Check In Limit
				checkInLimit = cmpgList[0].CheckInLimit__c;

				//Logo Image
				if(cmpgList[0].LogoImage__c == null)
				{
					Document defaultLogoImg = [SELECT Id FROM Document WHERE DeveloperName = :DEFAULT_LOGO_APINAME];	
					List<Object> defaultLogoImgParameters = new List<Object> {defaultLogoImg.Id, OrgId };
					logoImgUrl = constructImgUrl(IMG_SERVLET_URL, defaultLogoImgParameters);
				}
				else{
					List<Document> logoImg = [SELECT Id FROM Document WHERE DeveloperName = :cmpgList[0].LogoImage__c];
					
					if(logoImg.size() > 0)
					{
						List<Object> logoImgParameters = new List<Object> {logoImg[0].Id, OrgId };
						logoImgUrl = constructImgUrl(IMG_SERVLET_URL, logoImgParameters);
					}
					else{
						Document defaultLogoImg = [SELECT Id FROM Document WHERE DeveloperName = :DEFAULT_LOGO_APINAME];	
						List<Object> defaultLogoImgParameters = new List<Object> {defaultLogoImg.Id, OrgId };
						logoImgUrl = constructImgUrl(IMG_SERVLET_URL, defaultLogoImgParameters);
					}
				}

				//Background Image
				if(cmpgList[0].BackgroundImage__c == null)
				{
					backgroundImgUrl = null;
				}
				else{
					List<Document> backgroundImg = [SELECT Id FROM Document WHERE DeveloperName = :cmpgList[0].BackgroundImage__c];	

					if(backgroundImg.size() > 0)
					{
						List<Object> backgroundImgParameters = new List<Object> {backgroundImg[0].Id, OrgId };
						backgroundImgUrl = constructImgUrl(IMG_SERVLET_URL, backgroundImgParameters);
					}	
					else{
						backgroundImgUrl = null;
					}
				}
			}
			else{
				isCampaignExist = false;
				errMsg = 'Campaign Not Exist.';
			}
		}

		return isCampaignExist;
	}

	public String constructImgUrl(String servletUrl, List<Object> parameters)
	{
		return String.format(IMG_SERVLET_URL, parameters);
	}

	public PageReference importMembers()
	{
		Id cmpId = (Id)paramq.get('Id');
		ImportCampaignMembers_Ctrl importCmem = new ImportCampaignMembers_Ctrl(cmpId);

		//value-sets to hold values responsible for making queries selective
		Set<String> phoneSet = new Set<String>();
		Set<String> emailSet = new Set<String>();
		Set<String> nameSet = new Set<String>();
		Set<String> empEmailSet = new Set<String>();
		Set<String> empNameSet = new Set<String>();
		Set<String> branchCodeSet = new Set<String>();
		Set<String> sapIdSet = new Set<String>();
		Set<String> adUsernameSet = new Set<String>();
		Set<String> empPhoneSet = new Set<String>();

		List<Map<String,String>> cmpMemberMapList = new List<Map<String,String>>();

		Map<String,String> row = new Map<String,String>();

		UtilPhone uPhone;

		uPhone = new UtilPhone(phone);
		if(uPhone.output != null)
		{
			String phoneE164 = uPhone.toE164();
			phoneSet.add(phoneE164);
			row.put(R_PHONE, phone);
			row.put(H_PHONE, phoneE164);
		}
		// if(String.isNotBlank(phone))
		// {
		// 	phoneSet.add(phone);
		// 	row.put(R_PHONE, phone); //input value
		// 	row.put(H_PHONE, phone); //should be formatted value
		// }

		if(String.isNotBlank(name))
		{
			name = name.trim();
			row.put(R_NAME, name);

			nameSet.add(name);

			name = Util.purifyName(name);
			nameSet.add(name);
			row.put(H_NAME,name);
		}

		if(Util.checkEmail(email))
		{
			emailSet.add(email);
			row.put(H_EMAIL, email);
		}

		if(Util.checkEmail(empEmail))
		{
			empEmailSet.add(empEmail);
		}

		if(String.isNotBlank(empName))
		{
			empName = empName.trim();
			empNameSet.add(empName);
			row.put(R_S_ADVISOR,empName);

			empName = Util.purifyName(empName);
			empNameSet.add(empName);
			row.put(H_S_ADVISOR,empName);
		}

		if(String.isNotBlank(branchCode)){
			branchCode = branchCode.trim();
			branchCodeSet.add(branchCode);
			row.put(H_P_S_B, branchCode);
		}

		if(String.isNotBlank(sapId)){
			string tmpSapId = String.valueOf(Util.getSapId(sapId));
			row.put(R_SAP_ID,tmpSapId);
			sapIdSet.add(tmpSapId);
			tmpSapId = Util.padSapId(tmpSapId);
			row.put(H_SAP_ID,tmpSapId);
			sapIdSet.add(tmpSapId);
		}

		if(String.isNotBlank(adUsername)){
			adUsernameSet.add(adUsername);
		}

		// if(String.isNotBlank(empPhone))
		// {
		// 	empPhoneSet.add(phone);
		// 	row.put(H_S_ADVISOR_PHONE,phone);
		// }
		uPhone = new UtilPhone(empPhone);
		row.put(R_S_ADVISOR_PHONE, empPhone);
		if(uPhone.output != null)
		{
			String phoneE164 = uPhone.toE164();
			empPhoneSet.add(phoneE164);
			row.put(H_S_ADVISOR_PHONE, phoneE164);
		}

		cmpMemberMapList.add(row);

		// System.debug(cmpMemberMapList);
		// System.debug(phoneSet);
		// System.debug(emailSet);

		List<Account> accountList = [
			SELECT Id, LastName, isPersonAccount, Phone,Mobile_Country_Code_1__pc,
				PersonMobilePhone,Mobile_Preferred__pc,Office_Email__c,
				Home_Email__c,Other_Email__c,Default_Email__c, PersonEmail,PersonContactId
			FROM Account
			WHERE 
				PersonMobilePhone IN :phoneSet
				OR Default_Email__c IN :emailSet
			ORDER BY LastModifiedDate DESC
		];

	    PersonAccountLookup accountIdLookup = new PersonAccountLookup(accountList);
		accountIdLookup.placeholder = 'pendingInsert';	
		//System.debug(accountIdLookup);

		List<Contact> contactList = [
			SELECT Id,MobilePhone,Name,Email
			FROM Contact
			WHERE 
				Email IN :emailSet
				OR MobilePhone IN: phoneSet
			ORDER BY LastModifiedDate DESC
		];
		ImportCampaignMembers_Ctrl.ContactLookup contactIdLookup = new ImportCampaignMembers_Ctrl.ContactLookup(contactList);
		//System.debug(contactIdLookup);

		String companyId;
		if(importCmem.campaignCompanyId != null){
			companyId = String.valueOf(importCmem.campaignCompanyId);
		}
		//System.debug(importCmem.campaignCompanyId);

		String empMasterQuery = 'SELECT Id,Email__c,Name,Mobile_Number__c,';
		empMasterQuery += ' ActiveDirectoryUsername__c,Employee_Reference__c';
		empMasterQuery += ' FROM Employee_Master__c';
		empMasterQuery += ' WHERE (Name IN :empNameSet';
		empMasterQuery += ' OR Email__c IN :empEmailSet';
		empMasterQuery += ' OR Employee_Reference__c IN :sapIdSet';
		empMasterQuery += ' OR Mobile_Number__c IN :empPhoneSet';
		empMasterQuery += ' OR ActiveDirectoryUsername__c IN :adUsernameSet)';

		if(String.isNotBlank(companyId)){
			empMasterQuery += ' AND (Company__c = :companyId)';
		}

		List<Employee_Master__c> empMasterList = (List<Employee_Master__c>) Database.query(empMasterQuery);
		ImportCampaignMembers_Ctrl.EmployeeMasterLookup empMasterIdLookup = new ImportCampaignMembers_Ctrl.EmployeeMasterLookup(empMasterList);

		List<Showroom__c> showroomList = [
			SELECT Id,MobyBranchCode__c
			FROM Showroom__c
			WHERE MobyBranchCode__c IN :branchCodeSet
		];
		Map<String,Id> branchCode2ShowroomId = new Map<String,Id>();
		for(Showroom__c showroom: showroomList){
			branchCode2ShowroomId.put(showroom.MobyBranchCode__c, showroom.Id);
		}

		for(Map<String,String> cmpMemberMap: cmpMemberMapList){
			Id lookupContactId = contactIdLookup.lookContact(cmpMemberMap);
			if(lookupContactId == null){
				lookupContactId = accountIdLookup.lookAccount(cmpMemberMap);
			}
			cmpMemberMap.put(CONTACT_ID,lookupContactId);

			Id empMasterId = empMasterIdLookup.lookEmployeeMaster(cmpMemberMap);
			cmpMemberMap.put(EMPLOYEE_MASTER,empMasterId);

			String branchCode = cmpMemberMap.get(H_P_S_B);
			if(String.isNotBlank(branchCode)){
				cmpMemberMap.put(SHOWROOM,branchCode2ShowroomId.get(branchCode));
			}
		}

		// System.debug(accountIdLookup.newAccountList);
		if(accountIdLookup.newAccountList.size()>0){
			//System.debug('New Account');
			Database.insert(accountIdLookup.newAccountList,false);
			List<Account> newAccountList = [
				SELECT Id, LastName, isPersonAccount, Phone,Mobile_Country_Code_1__pc,
					PersonMobilePhone,Mobile_Preferred__pc,Office_Email__c,
					Home_Email__c,Other_Email__c,PersonEmail,Default_Email__c, PersonContactId
				FROM Account
				WHERE 
					(
						PersonMobilePhone IN :phoneSet
						OR Default_Email__c IN :emailSet
					)
					AND isPersonAccount = true
			];

			// System.debug(newAccountList);
			// System.debug(phoneSet);
			// System.debug(emailSet);
			PersonAccountLookup newAccountLookup = new PersonAccountLookup(newAccountList);
			
			for(Map<String,String> cmpMemberMap: cmpMemberMapList){
				if(cmpMemberMap.get(CONTACT_ID)== null){
					Id lookupContactId = newAccountLookup.lookAccount(cmpMemberMap);
					cmpMemberMap.put(CONTACT_ID,lookupContactId);
					cmpMemberMap.put(NEW_CONTACT,'YES');
				}
			}
		}


		List<CampaignMember> cmpMemberList =  importCmem.prepareCmpMember(cmpMemberMapList);
		// System.debug(cmpMemberMapList);
		//System.debug(cmpMemberList);
		Id contactId;
		for (CampaignMember cm :cmpMemberList) {
			cm.Source__c = 'Sales Nomination';
			contactId = cm.ContactId;
		}
		List<Database.SaveResult> campaignInsertResultList = Database.insert(cmpMemberList,false);

		for(Database.SaveResult campaignInsertResult:campaignInsertResultList){
            if(!campaignInsertResult.isSuccess()){
                for(Database.Error insertError: campaignInsertResult.getErrors()){
                    String errorMessage = insertError.getMessage();
                    if(errorMessage.contains(DUP_CMP_MEMBER_MSG)){
						callfunc = HIDE_LOADER_SHOW_TOAST_SCRIPT;
						Id cmpgId = paramq.get('Id');

						CampaignMember existingCmpMember = [SELECT SalesAdvisorName__c FROM CampaignMember WHERE CampaignId =: cmpId AND ContactId = :contactId];
						errMsg = errorMessage + NOMINATED_BY_MSG + existingCmpMember.SalesAdvisorName__c;
                        //errMsg = errorMessage;
						//System.debug(errorMessage);
                    }
                }
            }
			else{
				//System.debug('Campaign Member Nominated');
				callfunc = HIDE_LOADER_SHOW_TOAST_SCRIPT;
				errMsg = NOMINATED_MSG;
			}
        }		

		if(errMsg.contains(DUP_CMP_MEMBER_MSG))
		{
			return null;
		}
		else{
			return redirectWithQueryString();
		}
	}

	public PageReference redirectWithQueryString()
	{
		PageReference curPage = ApexPages.currentPage();
		string referer = curPage.getHeaders().get('Referer');
		string url = referer.subString(0, referer.indexOf('?'));

		//System.debug(url);
		
		PageReference pr = new PageReference(url);
		if(string.isNotBlank(empName))
		{
			pr.getParameters().put('Id', curPage.getParameters().get('Id'));
			pr.getParameters().put('name', empName);
			pr.getParameters().put('email', empEmail);
			pr.getParameters().put('phone', empPhone);
			pr.getParameters().put('sapid', sapId);
			pr.setRedirect(true);
			return pr;
		}
		else{
			pr.getParameters().put('Id', curPage.getParameters().get('Id'));
			return pr;
		}	
	}

	public class PersonAccountLookup{
		//case1 name+email+E164phone to Account's Id
		Map<String,String> emailName2Account;
		//case2 Name + E164phone to Account's Id
		Map<String,String> name2Account;
		//case3 email+phone to Account's Id
		Map<String,String> email2Account;
		//case4 phone to Account's Id
		Map<String,String> phone2Account;
		//case5 email to Account's Id
		Map<String,String> emailAddress2Account;
		//list of account which are added in maps one by one after init
		List<Account> newAccountList;
		// a string to show that an account (yet to be inserted) has been found
		public String placeholder;
		//map of accountId

		public PersonAccountLookup(){
			this.refresh();
		}

		public PersonAccountLookup(List<Account> accountList){
			this.updateMaps(accountList,true);
		}
		public void refresh(){
			this.emailName2Account = new Map<String,String>();
			this.email2Account = new Map<String,String>();
			this.name2Account = new Map<String,String>();
			this.phone2Account = new Map<String,String>();
			this.emailAddress2Account = new Map<String,String>();
			this.newAccountList = new List<Account>();
		}

		public void updateMaps(List<Account> accountList, Boolean refresh){
			if(refresh){
				this.refresh();
			}
			for(Account accnt: accountList){
				List<String> keyList;

				String personContactId = this.placeholder;
				if(accnt.PersonContactId != null){
					personContactId = String.valueOf(accnt.PersonContactId);
				}

				Set<String> accountPhoneList = new Set<String>();
				// if(String.isNotBlank(accnt.Mobile_Preferred__pc)){
				//     accountPhoneList.add(String.valueOf(accnt.Mobile_Country_Code_1__pc) + accnt.Mobile_Preferred__pc);
				// }
				if(String.isNotBlank(accnt.PersonMobilePhone)){
					accountPhoneList.add(accnt.PersonMobilePhone);
				}

				Set<String> accountNameSet = new Set<String>();
				if(String.isNotBlank(accnt.LastName)){
					// accountNameSet.add(accnt.LastName);
					accountNameset.add(Util.purifyName(accnt.LastName));
				}

				Set<String> accountEmailSet = new Set<String>();
				//	source fields are email validated fields
				// if(Util.checkEmail(accnt.Home_Email__c)){
				if(String.isNotBLank(accnt.Default_Email__c)){
					accountEmailSet.add(accnt.Default_Email__c);
				}
				if(Util.checkEmail(accnt.PersonEmail)){
					accountEmailSet.add(accnt.PersonEmail);
				}

				for(String accountName:accountNameSet){
					for(String phone: accountPhoneList){
						keyList = new List<String>();
						keyList.add(accountName);
						keyList.add(phone);
						this.name2Account.put(joinKeys(keyList),personContactId);
						for(String email:accountEmailSet){
							keyList = new List<String>();
							keyList.add(accountName);
							keyList.add(email);
							keyList.add(phone);
							this.emailName2Account.put(joinKeys(keyList),personContactId);
						}
					}
				}

				for(String email:accountEmailSet){
					for(String phone:accountPhoneList){
						keyList = new List<String>();
						keyList.add(email);
						keyList.add(phone);
						this.email2Account.put(joinKeys(keyList),personContactId);
					}
					this.emailAddress2Account.put(email,personContactId);
				}

				for(String phone:accountPhoneList){
					this.phone2Account.put(phone,personContactId);
				}
			}
		}

		public Id lookAccount(Map<String,String> cmpMember){
			List<String> keyList;
			String lookupAccountId = null;

			String email = cmpMember.get(H_EMAIL);
			String phone = cmpMember.get(H_PHONE);
			String name = cmpMember.get(H_NAME);

			// System.debug(email);
			// System.debug(phone);
			// System.debug(name);
			
			if(String.isNotBlank(email) && String.isNotBlank(name) && String.isNotBlank(phone)){
				keyList = new List<String>();
				keyList.add(name);
				keyList.add(email);
				keyList.add(phone);
				lookupAccountId = this.emailName2Account.get(joinKeys(keyList));
			}

			if(lookupAccountId == null && String.isNotBlank(email) && String.isNotBlank(phone)){
				keyList = new List<String>();
				keyList.add(email);
				keyList.add(phone);
				lookupAccountId = this.email2Account.get(joinKeys(keyList));
			}

			if(lookupAccountId == null && String.isNotBlank(name) && String.isNotBlank(phone)){
				keyList = new List<String>();
				keyList.add(name);
				keyList.add(phone);
				lookupAccountId = this.name2Account.get(joinKeys(keyList));
			}

			if(lookupAccountId == null && String.isNotBlank(phone)){
				lookupAccountId = this.phone2Account.get(phone);
			}

			if(lookupAccountId == null && String.isNotBlank(email)){
				lookupAccountId = this.emailAddress2Account.get(email);
			}

			if(lookupAccountId == null && String.isNotBlank(this.placeholder)){
				this.addPersonAccount(cmpMember);
			}

			if(lookupAccountId == this.placeholder){
				return null;
			}
			if(lookupAccountId != null){
				return Id.valueOf(lookupAccountId);
			}

			return null;
		}

		public void addPersonAccount(Map<String,String> accountMap){
			Account newAccount = new Account();
			// Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
			Id recordTypeId = Envir.recordTypeByDevName.get('PersonAccount').Id;
			newAccount.recordTypeId = recordTypeId;
			// String name = Util.purifyName(accountMap.get(H_NAME));
			String name = accountMap.get(H_NAME);
			if(String.isNotBlank(name)){
				newAccount.LastName = accountMap.get(H_NAME);
				newAccount.Account_Name__c = name;
				newAccount.OfficialName__c = name;
				newAccount.DisplayName__c = name;
				newAccount.Prefer_Name__pc = name;
			
				UtilPhone phone = new UtilPhone(accountMap.get(H_PHONE));
				if (phone.output != null)  {
					newAccount.PersonMobilePhone = phone.toE164();
					newAccount.Mobile_Country_Code_1__pc = phone.getCountryCode();
					//newAccount.Mobile_Preferred__pc = phone.toNoPrefixNumber();
				}

				String email = accountMap.get(H_EMAIL);
				if (Util.checkEmail(email)) {
					newAccount.PersonEmail = email;
					newAccount.Home_Email__c = email;
					newAccount.Active_Home__c = true;
				}
                if(phone.output != null || Util.checkEmail(email)){
                    this.newAccountList.add(newAccount);
                    this.updateMaps(new List<Account>{newAccount}, false);
                }
			}
		}

	}
}