public without sharing class CampaignMemberCheckIn_Ctrl {

	public Id cmpgId{get;set;}
	public String cmpgName{get;set;}
    public String cmpgMemberId{get;set;}
    public String name{get;set;}
    public String phone{get;set;}
    public String email{get;set;}
    public String errMsg{get;set;}
    // public boolean isSuccess{get;set;}
    public string callfunc{get;set;}
	public string logoImgUrl {get;set;}
	public string backgroundImgUrl {get;set;}
	public string headerText {get;set;}
	public string subHeaderText {get;set;}
	public boolean isCampaignExist{ get; set; }
	public double checkInLimit {get;set;}

    public CampaignMember[] cmemList { get; set; }
    public Contact contact { get; set; }
	public Campaign[] cmpgList { get; set; }

    //strings to be used as csv headers
	//public static final string H_ID = 'ID';
	public static final String H_NAME = 'Customer Name';
	public static final String H_PHONE = 'Contact Number';
	public static final String H_EMAIL = 'Email';
	// public static final String H_P_S_B = 'Branch Code';
	// public static final String H_S_ADVISOR = 'Sales Advisor Name';
	// public static final String H_S_ADVISOR_EMAIL = 'Sales Advisor Email';
	// public static final String H_S_ADVISOR_PHONE = 'Sales Advisor Contact Number';
	// public static final String H_GUESTS = 'Number of Pax';
	// public static final String H_SAP_ID = 'SAP ID';
	// public static final String H_AD_USERNAME = 'Windows Login Id';

	//strings to be used as keys of campaign member map
    public static final String CMP_ID = 'CampaignId';
	public static final String CONTACT_ID = 'ContactId';
    public static final String CMPMEMBER_ID = 'CampaignMemberId';
	public static final String CHECKIN_COUNT = 'CheckInCount';
	// public static final String EMPLOYEE_MASTER = 'EmployeeMaster';
	// public static final String SHOWROOM = 'ShowroomId';

    //strings to be used as keys of raw user input
    public static final String R_NAME = 'CustomerName';
    public static final String R_PHONE = 'CustomerContact';
    // public static final String R_S_ADVISOR = 'SalesAdvisorName';
    // public static final String R_S_ADVISOR_PHONE = 'SalesAdvisorContact';
    // public static final String R_P_S_B = 'BranchCode';
    // public static final String R_SAP_ID = 'SapId';

	public static final String IMG_SERVLET_URL = '/servlet/servlet.ImageServer?id={0}&oid={1}';
	public static final String SHOW_HIDE_WELCOME_ALERT_SCRIPT= '<script> fncHideShowWelcomeAlert(); </script>';
	public static final String NOTIFY_NOT_IN_CAMPAIGN_SCRIPT= '<script> fncNotifyNotInCampaign(); </script>';
	public static final String MAX_CHECK_IN_ALERT_SCRIPT= '<script> fncShowMaxCheckInAlert(); </script>';
	public static final String SUCCESS_CHECK_IN_ALERT_SCRIPT= '<script> fncShowSuccessCheckIn(); </script>';
	public static final String SYS_ERR_ALERT_SCRIPT= '<script> fncShowSystemErrAlert(); </script>';
	public static final String SHOW_LOADER = '<script> fncShowLoader(); </script>';
	public static final String HIDE_LOADER = '<script> fncHideLoader(); </script>';
	public static final String DEFAULT_LOGO_APINAME = 'Sime_Darby_Motor_Logo';
    
    public static String joinKeys(List<String> keyList){
		String key = String.join(keyList,'_').toUpperCase();
		return key;
	}
   
    public CampaignMemberCheckIn_Ctrl() {

        cmpgId = ApexPages.currentPage().getParameters().get('id');
		fncCheckIsCampaignExist(cmpgId);
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
				system.debug(cmpgList[0].LogoImage__c);
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
				system.debug(cmpgList[0].BackgroundImage__c);
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
				if(String.isNotBlank(accnt.PersonMobilePhone)){
					accountPhoneList.add(accnt.PersonMobilePhone);
				}

				Set<String> accountNameSet = new Set<String>();
				if(String.isNotBlank(accnt.LastName)){
					accountNameset.add(Util.purifyName(accnt.LastName));
				}

				Set<String> accountEmailSet = new Set<String>();
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
					newAccount.Mobile_Preferred__pc = phone.toNoPrefixNumber();
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

    public class ContactLookup{
		//case1 name+email+E164phone to Contact's Id
		Map<String, Id> emailName2Contact;
		//case2 Name + E164phone to Contact's Id
		Map<String, Id> name2Contact;
		//case3 email+phone
		Map<String,Id> email2Contact;
		//case4 phone to Contact's Id
		Map<String,Id> phone2Contact;
		//case5 email to Contact's Id
		Map<String,Id> emailAddress2Contact;
		public ContactLookup(){
			this.refresh();
		}

		public ContactLookup(List<Contact> contactList){
			this();
			this.updateMaps(contactList);

		}
		public void refresh(){
			this.emailName2Contact = new Map<String, Id>();
			this.name2Contact= new Map<String, Id>();
			this.email2Contact= new Map<String, Id>();
			this.phone2Contact = new Map<String,Id>();
			this.emailAddress2Contact = new Map<String,Id>();
		}

		public void updateMaps(List<Contact> contactList){
			this.refresh();
			for(Contact cntct: contactList){
				List<String> keyList;

				List<String> contactPhoneList = new List<String>();
				if(String.isNotBlank(cntct.MobilePhone)){
					String phone = UtilPhone.toE164(cntct.MobilePhone);
					contactPhoneList.add(phone);
					this.phone2Contact.put(phone,cntct.Id);
				}

				Set<String> contactNameSet = new Set<String>();
				if(String.isNotBlank(cntct.Name)){
					contactNameSet.add(cntct.Name);
					contactNameSet.add(Util.purifyName(cntct.Name));
				}

				for(String contactName:contactNameSet){
					for(String phone: contactPhoneList){
						keyList = new List<String>();
						keyList.add(contactName);
						keyList.add(phone);
						this.name2Contact.put(joinKeys(keyList),cntct.Id);
					}
				}

				if(String.isNotBlank(cntct.Email)){
					for(String phone: contactPhoneList){
						keyList = new List<String>();
						keyList.add(cntct.Email);
						keyList.add(phone);
						this.email2Contact.put(joinKeys(keyList),cntct.Id);
						for(String contactName:contactNameSet){
							keyList = new List<String>();
							keyList.add(contactName);
							keyList.add(cntct.Email);
							keyList.add(phone);
							this.emailName2Contact.put(joinKeys(keyList),cntct.Id);
						}
					}
					this.emailAddress2Contact.put(cntct.Email,cntct.Id);
				}
			}
		}

		public Id lookContact(Map<String,String> cmpMember){
			List<String> keyList = new List<String>();
			Id lookupContactId = null;
			String email = cmpMember.get(H_EMAIL);
			String phone = cmpMember.get(H_PHONE);
			String name = cmpMember.get(H_NAME);
			if(String.isNotBlank(email) && String.isNotBlank(name) && String.isNotBlank(phone)){
				keyList = new List<String>();
				keyList.add(name);
				keyList.add(email);
				keyList.add(phone);
				lookupContactId = this.emailName2Contact.get(joinKeys(keyList));
			}

			if(lookupContactId == null && String.isNotBlank(email) && String.isNotBlank(phone)){
				keyList = new List<String>();
				keyList.add(email);
				keyList.add(phone);
				lookupContactId = this.email2Contact.get(joinKeys(keyList));
			}

			if(lookupContactId == null && String.isNotBlank(name) && String.isNotBlank(phone)){
				keyList = new List<String>();
				keyList.add(name);
				keyList.add(phone);
				lookupContactId = this.name2Contact.get(joinKeys(keyList));
			}

			if(lookupContactId == null && String.isNotBlank(phone)){
				lookupContactId = this.phone2Contact.get(phone);
			}

			if(lookupContactId == null && String.isNotBlank(email)){
				lookupContactId = this.emailAddress2Contact.get(email);
			}

			return lookupContactId;
		}
	}

    public class CampaignMemberLookUp
    {
        //case1 name+email+E164phone to CampaignMember's Id
		Map<String,String> emailNamePhone2Account;
		//case2 Name + E164phone to CampaignMember's Id
		Map<String,String> name2Account;
		//case3 email+phone to CampaignMember's Id
		Map<String,String> email2Account;
		//case4 phone to CampaignMember's Id
		Map<String,String> phone2Account;
		//case5 email to CampaignMember's Id
		Map<String,String> emailAddress2Account;
        Map<String,String> cmpMemberId2Account;
		// Map<String,String> checkInCount2Account;

        public CampaignMemberLookUp(){
			this.refresh();
		}

        public CampaignMemberLookUp(List<CampaignMember> cmpgMemberList){
			this.updateMaps(cmpgMemberList,true);
		}

        public void refresh(){
			this.emailNamePhone2Account = new Map<String,String>();
			this.email2Account = new Map<String,String>();
			this.name2Account = new Map<String,String>();
			this.phone2Account = new Map<String,String>();
			this.emailAddress2Account = new Map<String,String>();
            this.cmpMemberId2Account = new Map<String,String>();
			// this.checkInCount2Account = new Map<String, String>();
            // this.contactId2Account = new Map<String,String>();
		}

        public void updateMaps(List<CampaignMember> cmpgMemberList, Boolean refresh){
            if(refresh){
				this.refresh();
			}

	
            for(CampaignMember cmpgMember: cmpgMemberList){
                List<String> keyList;

                String contactId;
                String cmpMemberId;
				if(cmpgMember.ContactId != null){
					contactId = String.valueOf(cmpgMember.ContactId);
                    //this.contactId2Account.put(cmpgMember.Id, contactId);
				}

                if(cmpgMember.Id != null)
                {
                    cmpMemberId = String.valueOf(cmpgMember.Id);
                    this.cmpMemberId2Account.put(contactId, cmpMemberId);
                }

                Set<String> cmpgMemberPhoneList = new Set<String>();
                if(String.isNotBlank(cmpgMember.CustomerContact__c)){
					UtilPhone utilPhoneRst;
					utilPhoneRst = new UtilPhone(cmpgMember.CustomerContact__c);
					if(utilPhoneRst.output != null){
						String phoneE164 = utilPhoneRst.toE164();
						cmpgMemberPhoneList.add(phoneE164);
					}		                   
                }
    
                Set<String> cmpgMemberNameSet = new Set<String>();
                if(String.isNotBlank(cmpgMember.CustomerName__c)){
                    cmpgMemberNameSet.add(Util.purifyName(cmpgMember.CustomerName__c));
                    //cmpgMemberNameSet.add(cmpgMember.CustomerName__c);
                }
    
                Set<String> cmpgMemberEmailSet = new Set<String>();
                if(String.isNotBLank(cmpgMember.CustomerEmail__c)){
                    cmpgMemberEmailSet.add(cmpgMember.CustomerEmail__c);
                }
                // if(Util.checkEmail(accnt.PersonEmail)){
                //     accountEmailSet.add(accnt.PersonEmail);
                // }

				// Set<String> cmpMemberCheckInCountList = new Set <String>();
				// system.debug(cmpgMember.CheckInCount__c);
				// if(cmpgMember.CheckInCount__c == null)
				// {
				// 	system.debug('count null');
				// 	cmpMemberCheckInCountList.add('0');
				// }
				// else{
				// 	system.debug('count not null');
				// 	cmpMemberCheckInCountList.add(String.valueOf(cmpgMember.CheckInCount__c));
				// }
				// system.debug(cmpMemberCheckInCountList);
				

                for(String cmpgMemberName:cmpgMemberNameSet){
					for(String phone: cmpgMemberPhoneList){
						keyList = new List<String>();
						keyList.add(cmpgMemberName);
						keyList.add(phone);
						this.name2Account.put(joinKeys(keyList),contactId);
						for(String email:cmpgMemberEmailSet){
							keyList = new List<String>();
							keyList.add(cmpgMemberName);
							keyList.add(email);
							keyList.add(phone);
							this.emailNamePhone2Account.put(joinKeys(keyList),contactId);
						}
					}
				}		

				system.debug(keyList);

				for(String email:cmpgMemberEmailSet){
					for(String phone:cmpgMemberPhoneList){
						keyList = new List<String>();
						keyList.add(email);
						keyList.add(phone);
						this.email2Account.put(joinKeys(keyList),contactId);
					}
					this.emailAddress2Account.put(email,contactId);
				}

				for(String phone:cmpgMemberPhoneList){
					this.phone2Account.put(phone,contactId);
				}
            }
        }

        public Id LookCmpgMember(Map<String,String> cmpMemberMap)
        {
			system.debug(cmpMemberMap.get(H_EMAIL));
			system.debug(cmpMemberMap.get(R_PHONE));
			system.debug(cmpMemberMap.get(H_PHONE));
			system.debug(cmpMemberMap.get(H_NAME));

            List<String> keyList;
			String lookupContactId = null;
			String email = cmpMemberMap.get(H_EMAIL);
			String phone = cmpMemberMap.get(H_PHONE);
			// String phone = cmpMemberMap.get(R_PHONE);
			String name = cmpMemberMap.get(H_NAME);
    
                if(String.isNotBlank(email) && String.isNotBlank(name) && String.isNotBlank(phone)){
                    keyList = new List<String>();
                    keyList.add(name);
                    keyList.add(email);
                    keyList.add(phone);
					system.debug(phone);
                    lookupContactId = this.emailNamePhone2Account.get(joinKeys(keyList));
                }
    
                if(lookupContactId == null && String.isNotBlank(email) && String.isNotBlank(phone)){
                    keyList = new List<String>();
                    keyList.add(email);
                    keyList.add(phone);
                    lookupContactId = this.email2Account.get(joinKeys(keyList));
                }
    
                if(lookupContactId == null && String.isNotBlank(name) && String.isNotBlank(phone)){
                    keyList = new List<String>();
                    keyList.add(name);
                    keyList.add(phone);
                    lookupContactId = this.name2Account.get(joinKeys(keyList));
                }
    
                if(lookupContactId == null && String.isNotBlank(phone)){
                    lookupContactId = this.phone2Account.get(phone);
                }
    
                if(lookupContactId == null && String.isNotBlank(email)){
                    lookupContactId = this.emailAddress2Account.get(email);
                }

            return lookupContactId;
        }

        public Map<String,String> prepareCmpMemberMap(Map<String,String> cmpMemberMap){     
            String contactId = cmpMemberMap.get(CONTACT_ID);
            String cmpMemberId = this.cmpMemberId2Account.get(contactId);
			// String checkInCount = cmpMemberMap.get(CHECKIN_COUNT);
			// system.debug('checkInCount ' + checkInCount);

			CampaignMember cmpgMemberCheckInCount = [SELECT CheckInCount__c FROM CampaignMember WHERE Id = :cmpMemberId];
			
            cmpMemberMap.put(CMPMEMBER_ID, cmpMemberId);
			cmpMemberMap.put(CONTACT_ID, contactId);

			if(cmpgMemberCheckInCount.CheckInCount__c == null)
			{
				cmpMemberMap.put(CHECKIN_COUNT, '0');
			}
			else{
				cmpMemberMap.put(CHECKIN_COUNT, String.valueOf(cmpgMemberCheckInCount.CheckInCount__c));
			}			
            return cmpMemberMap;
        }
    
        public CampaignMember prepareWalkInCmpMember(Map<String,String> cmpMemberMap)
        {
			system.debug('prepareWalkInCmpMember');
            String campaignId = cmpMemberMap.get(CMP_ID);      
            String contactId = cmpMemberMap.get(CONTACT_ID);
            String email = cmpMemberMap.get(H_EMAIL);
			String phone = cmpMemberMap.get(H_PHONE);
			String name = cmpMemberMap.get(H_NAME);

            CampaignMember cmpMember = new CampaignMember();
            cmpMember.CampaignId = campaignId;
            cmpMember.ContactId = cmpMemberMap.get(CONTACT_ID);
            cmpMember.CustomerName__c=cmpMemberMap.get(R_NAME);
            cmpMember.CustomerContact__c=cmpMemberMap.get(R_PHONE);
            cmpMember.CustomerEmail__c=cmpMemberMap.get(H_EMAIL);// emails are stored unaltered
            cmpMember.Source__c = 'Walk-In';
            cmpMember.CheckIn__c  = true;
			cmpMember.CheckInCount__c = 1;
            cmpMember.CheckInDate__c = Datetime.now();
			cmpMember.Status = 'Attended';

            return cmpMember;
        }
    }

    //Update Campaign Member Check In Count
    public void fncUpdateCmpgMemberPax(Map<String,String> cmpgMemberMap)
    {
        String contactId = cmpgMemberMap.get(CONTACT_ID);
        String cmpMemberId = cmpgMemberMap.get(CMPMEMBER_ID);
		String checkInCount = cmpgMemberMap.get(CHECKIN_COUNT);
		
		CampaignMember cmpMember = new CampaignMember();
		if(checkInLimit == null || checkInLimit == 0)
		{
			cmpMember.ContactId = contactId;
			cmpMember.Id = cmpMemberId;
			cmpMember.CheckIn__c  = true;
			cmpMember.CheckInDate__c = Datetime.now();
			cmpMember.CheckInCount__c = Double.valueOf(checkInCount) + 1;
			cmpMember.Status = 'Attended';

			//Update!!
			Database.SaveResult sr = Database.update(cmpMember, false);

			if(sr.isSuccess())
			{
				// callfunc = HIDE_LOADER;
				callfunc = SHOW_HIDE_WELCOME_ALERT_SCRIPT;
			}
			else{
				// callfunc='<script> fncShowFailUpdatePax(); </script>';
				for(Database.Error err : sr.getErrors()) {
					System.debug('The following error has occurred.');                    
					System.debug(err.getStatusCode() + ': ' + err.getMessage());
					System.debug('Fields that affected this error: ' + err.getFields());
					errMsg = err.getStatusCode() + ': ' + err.getMessage();
					callfunc = SYS_ERR_ALERT_SCRIPT;
				}
			}
		}
		else{
			if(Double.valueOf(checkInCount) < checkInLimit)
			{
				cmpMember.ContactId = contactId;
				cmpMember.Id = cmpMemberId;
				cmpMember.CheckIn__c  = true;
				cmpMember.CheckInDate__c = Datetime.now();
				cmpMember.Status = 'Attended';
				cmpMember.CheckInCount__c = Double.valueOf(checkInCount) + 1;

				//Update!!
				Database.SaveResult sr = Database.update(cmpMember, false);
				if(sr.isSuccess())
				{
					// callfunc = HIDE_LOADER;
					callfunc = SHOW_HIDE_WELCOME_ALERT_SCRIPT;
				}
				else{
					// system.debug(sr);
					// callfunc='<script> fncShowFailUpdatePax(); </script>';
					for(Database.Error err : sr.getErrors()) {
						System.debug('The following error has occurred.');                    
						System.debug(err.getStatusCode() + ': ' + err.getMessage());
						System.debug('Fields that affected this error: ' + err.getFields());
						errMsg = err.getStatusCode() + ': ' + err.getMessage();
						callfunc = SYS_ERR_ALERT_SCRIPT;
					}
				}
			}
			else{
				// callfunc = HIDE_LOADER;
				system.debug('max check in');
				callfunc = MAX_CHECK_IN_ALERT_SCRIPT;
			}
		}
    }

    //Insert Walk in Campaign Member
    public void fncInsertWalkInCmpMember(CampaignMember cmpMember)
    {
        Database.SaveResult sr = Database.Insert(cmpMember, false);

        if(sr.isSuccess())
        {
			callfunc = HIDE_LOADER;
            callfunc= SUCCESS_CHECK_IN_ALERT_SCRIPT;
        }
        else{
			for(Database.Error err : sr.getErrors()) {
				System.debug('The following error has occurred.');                    
				System.debug(err.getStatusCode() + ': ' + err.getMessage());
				System.debug('Fields that affected this error: ' + err.getFields());
				errMsg = err.getStatusCode() + ': ' + err.getMessage();
				callfunc = SYS_ERR_ALERT_SCRIPT;
			}
			// system.debug(sr);
            // callfunc='<script> fncShowFailUpdatePax(); </script>';
        }
    }

    public void fncGetCmpgMemberDtl()
    {
        try{		
			Integer idx = cmpgMemberId.indexOf('?');
			String cmpMemIdB64 = cmpgMemberId.substring(++idx); 
			System.debug(cmpMemIdB64);
			String decodedCmpgMemberId  = EncodingUtil.base64decode(cmpMemIdB64).toString(); 
			System.debug(decodedCmpgMemberId);

			Blob cmpMemIdBlob = Blob.valueOf(decodedCmpgMemberId);
			System.debug(EncodingUtil.base64Encode(cmpMemIdBlob));
            cmemList = [SELECT Id, ContactId, CheckInCount__c FROM CampaignMember WHERE Id = : decodedCmpgMemberId AND CampaignId =: cmpgId];     
            if(cmemList.size() > 0)
            {
                contact = [SELECT Salutation, Name FROM Contact WHERE Id = : cmemList[0].ContactId];
                Map<String,String> cmpMemberMap = new Map<String,String>();
                cmpMemberMap.put(CONTACT_ID, cmemList[0].ContactId);
                cmpMemberMap.put(CMPMEMBER_ID, cmemList[0].Id);

				if(cmemList[0].CheckInCount__c == null)
				{
					cmpMemberMap.put(CHECKIN_COUNT, '0');
				}
				else{
					cmpMemberMap.put(CHECKIN_COUNT, String.valueOf(cmemList[0].CheckInCount__c));
				}

				fncUpdateCmpgMemberPax(cmpMemberMap);
            }
            else{
                callfunc= NOTIFY_NOT_IN_CAMPAIGN_SCRIPT;
            }
        }
        catch(exception ex)
        {
            system.debug(ex);
        }
    }

    public void fncManualInputSubmit()
    {
		system.debug('manual input');
        try{
            Set<String> phoneSet = new Set<String>();
		    Set<String> emailSet = new Set<String>();
            Set<String> nameSet = new Set<String>();
            Map<String,String> cmpMemberMap = new Map<String,String>();
            
            //Set Campaign Id
            cmpMemberMap.put(CMP_ID, cmpgId);

            UtilPhone utilPhoneRst;
			utilPhoneRst = new UtilPhone(phone);
			if(utilPhoneRst.output != null){
				String phoneE164 = utilPhoneRst.toE164();
				phoneSet.add(phoneE164);
                cmpMemberMap.put(R_PHONE,phone); // place user input in R_PHONE
				cmpMemberMap.put(H_PHONE,phoneE164); // update H_PHONE with formatted value
			}

            if(name!=null){
				name = name.trim();
				cmpMemberMap.put(R_NAME,name);//store trimmed raw input for customer name

				nameSet.add(name);

				name = Util.purifyName(name);
				nameSet.add(name);
                cmpMemberMap.put(H_NAME,name); // store purified name in H_NAME
			}

			if(Util.checkEmail(email)){
				emailSet.add(email);
				cmpMemberMap.put(H_EMAIL,email);
			}

            List<CampaignMember> CmpMemberList = [
                SELECT Id, contactId, SalesAdvisor__c,Showroom__c,NumberOfPax__c,
                SourceId__c,Source__c, CustomerName__c, CustomerContact__c,
                CustomerEmail__c,SalesAdvisorName__c,SalesAdvisorContact__c,
                SalesAdvisorEmail__c,BranchCode__c,SapId__c,CheckInCount__c
                FROM CampaignMember
                WHERE campaignId = :cmpgId
            ];
            CampaignMemberLookUp cmpgMemberLookUp = new CampaignMemberLookUp(CmpMemberList);
            Id contactId = cmpgMemberLookUp.LookCmpgMember(cmpMemberMap);
			system.debug(contactId);
            if(contactId == null)
            {              
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

                List<Contact> contactList = [
                SELECT Id,MobilePhone,Name,Email
                FROM Contact
                WHERE 
                    Email IN :emailSet
                    OR MobilePhone IN: phoneSet
                ORDER BY LastModifiedDate DESC
                ];
                ContactLookup contactIdLookup = new ContactLookup(contactList);

				Id lookupContactId = contactIdLookup.lookContact(cmpMemberMap);
				if(lookupContactId == null){
					lookupContactId = accountIdLookup.lookAccount(cmpMemberMap);
				}
				cmpMemberMap.put(CONTACT_ID,lookupContactId);

                if(accountIdLookup.newAccountList.size()>0){
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
                    PersonAccountLookup newAccountLookup = new PersonAccountLookup(newAccountList);
                    
					if(cmpMemberMap.get(CONTACT_ID)== null){
						lookupContactId = newAccountLookup.lookAccount(cmpMemberMap);
						cmpMemberMap.put(CONTACT_ID,lookupContactId);
					}
                }

                CampaignMember newCmpMember = cmpgMemberLookUp.prepareWalkInCmpMember(cmpMemberMap);
                fncInsertWalkInCmpMember(newCmpMember);
            }
            else{
				contact = [SELECT Salutation, Name FROM Contact WHERE Id = : contactId];
				system.debug('update memebr ' + contact.Name);
				// CampaignMember cmpgMemberCheckInCount = [SELECT CheckInCount__c FROM CampaignMember WHERE contactId = :contactId];
				// system.debug(cmpgMemberCheckInCount.CheckInCount__c);
                cmpMemberMap.put(CONTACT_ID,contactId);
				// cmpMemberMap.put(CHECKIN_COUNT, String.valueOf(cmpgMemberCheckInCount.CheckInCount__c));
                cmpMemberMap = cmpgMemberLookUp.prepareCmpMemberMap(cmpMemberMap);
				system.debug(cmpMemberMap);
                fncUpdateCmpgMemberPax(cmpMemberMap);
            }
        }
        catch(exception ex)
        {
            
        }
    }

	public void fncShowQrContainer()
	{
		callfunc = '<script>fncJsShowQrContainer();</script>';
	}
}