public with sharing class ImportCampaignMembers_Ctrl {

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

	public static String joinKeys(List<String> keyList){
		String key = String.join(keyList,'_').toUpperCase();
		return key;
	}
	public String importButttonValue{
		get{
			if(String.isBlank(this.importButttonValue)){
				return 'Import';
			}
			return this.importButttonValue;
		}
		set;
	}

	public String inputFileName {
		get;
		set{
			this.inputFileName = value;
			this.importButttonValue = 'Import ';
			this.importButttonValue += value;
		}
	}

	public Id campaignId{
		get;
		set{
			this.campaignId = value;

			Campaign currentCampagin = [
				SELECT Name,Company__c
				FROM Campaign
				WHERE Id = :this.campaignId
			][0];

			this.campaignCompanyId = currentCampagin.Company__c;
			this.campaignName = currentCampagin.Name;
			this.disableFileInput = false;
		}
	}

	public Boolean disableFileInput{
		get{
			if(this.disableFileInput == null){
				return true;
			}
			return this.disableFileInput;
		}
		set;
	}

	public Boolean disableImport{
		get{
			if(this.disableImport == null){
				return true;
			}
			return this.disableImport;
		}
		set;
	}

	public Id campaignCompanyId;
	public String campaignName {get;set;}

	//holds blob input from the visualforce page
	public Blob blobInput{get;set;}

	/**
	 * Constructor
	 * initialize campaignId class member from page's parameter
	 */
	public ImportCampaignMembers_Ctrl() {
		try{
			this.campaignId = Id.valueOf(ApexPages.currentPage().getParameters().get('campaignId'));
		}
		catch(Exception invalidCampaignIdException){
			ApplicationLogUtility.insertApexErrorLog('ImportCampaignMembers_Ctrl',
                'Invalid or null campaign Id',invalidCampaignIdException.getStackTraceString(),
                null,ApplicationLogUtility.PRIORITY_MEDIUM,true
            );
		}
	}

	public ImportCampaignMembers_Ctrl(Id campaignId){
		this.campaignId = campaignId;
	}

	public DataFrame csv { get; set; }

	/**
	 * verifies if the blob input can be converted to DataFrame instance
	 * and has content after conversion
	 * invoked from vfpage's action function
	 */
	public void verifyCsvInput(){
		if(this.blobInput!=null){
			try{
			   this.csv = new DataFrame(',',this.blobInput);
				if(this.csv.getLength()>0){
					this.disableImport = false;
				}
				else{
					this.disableImport = true;
				}
			}
			catch(Exception e){
                ApplicationLogUtility.insertApexErrorLog('ImportCampaignMembers_Ctrl',
                'Could not parse Blob into DataFrame',e.getStackTraceString(),
                null,ApplicationLogUtility.PRIORITY_MEDIUM,true
            );
				this.disableImport = true;
			}
		}
		else{
			this.disableImport = true;
		}
	}

    /**
	 * @param sourceMember member record to copy field values from
     * @param sinkMember member record to copy field values to.
	 * @return CampaignMember sObject record with touched field from
     * sourceMember and untouched fields like Id from sinkMember
     * sourceMember ==> sinkMember
	 */
    public CampaignMember prepareCmpMember(CampaignMember sourceMember,CampaignMember sinkMember){
        if(sinkMember.ContactId == null){
            sinkMember.ContactId = sourceMember.ContactId;
        }
        sinkMember.SalesAdvisor__c = sourceMember.SalesAdvisor__c;
        sinkMember.Showroom__c = sourceMember.Showroom__c;
        sinkMember.NumberOfPax__c = sourceMember.NumberOfPax__c;
        sinkMember.SourceId__c = sourceMember.SourceId__c;
        sinkMember.Source__c = 'Import List';
        sinkMember.CustomerName__c = sourceMember.CustomerName__c;
        sinkMember.CustomerContact__c = sourceMember.CustomerContact__c;
        sinkMember.CustomerEmail__c = sourceMember.CustomerEmail__c;
        sinkMember.SalesAdvisorName__c = sourceMember.SalesAdvisorName__c;
        sinkMember.SalesAdvisorContact__c = sourceMember.SalesAdvisorContact__c;
        sinkMember.SalesAdvisorEmail__c = sourceMember.SalesAdvisorEmail__c;
        sinkMember.BranchCode__c = sourceMember.BranchCode__c;
        sinkMember.SapId__c = sourceMember.SapId__c;
        return sinkMember;
    }

	/**
	 * @param cmpMemberMap map from String to String 
     * with field parameter as keys and field values as values
     * @param cmpMember sobject record for CampaignMember to be updated
     * from provided map
	 * @return CampaignMember sObject record build from provided map
	 */
    public CampaignMember prepareCmpMember(Map<String,String> cmpMemberMap, CampaignMember cmpMember){
        cmpMember.ContactId = cmpMemberMap.get(CONTACT_ID);
        cmpMember.SalesAdvisor__c = cmpMemberMap.get(EMPLOYEE_MASTER);
        cmpMember.Showroom__c = cmpMemberMap.get(SHOWROOM);
		if(cmpMemberMap.get(NEW_CONTACT)!=null){
			cmpMember.NewContact__c = true;
		}
		else{
			cmpMember.NewContact__c = false;
		}
        try{
            cmpMember.NumberOfPax__c = Decimal.valueOf(cmpMemberMap.get(H_GUESTS));
            //cmpMember.NumberOfGuest__c += 1;
        }
        catch(Exception invalidGuests){
            cmpMember.NumberOfPax__c = null;
        }
        cmpMember.SourceId__c = cmpMemberMap.get(H_ID);
        cmpMember.Source__c = 'Import List';

        cmpMember.CustomerName__c=cmpMemberMap.get(R_NAME);
        cmpMember.CustomerContact__c=cmpMemberMap.get(R_PHONE);
        cmpMember.CustomerEmail__c=cmpMemberMap.get(H_EMAIL);// emails are stored unaltered
        cmpMember.SalesAdvisorName__c=cmpMemberMap.get(R_S_ADVISOR);
        cmpMember.SalesAdvisorContact__c=cmpMemberMap.get(R_S_ADVISOR_PHONE);
        cmpMember.SalesAdvisorEmail__c=cmpMemberMap.get(H_S_ADVISOR_EMAIL);// emails are stored unaltered
        cmpMember.BranchCode__c=cmpMemberMap.get(H_P_S_B);// unaltered
        cmpMember.SapId__c=cmpMemberMap.get(R_SAP_ID);

        return cmpMember;
    }

	/**
	 * @param cmpMemberMapList list of map from String to String 
     * with field parameter as keys and field values as values
	 * @return return List of CampaignMember sObject record built from provided map
	 */
	public List<CampaignMember> prepareCmpMember(List<Map<String,String>> cmpMemberMapList){
		//List<CampaignMember> campaignMemberList = new List<CampaignMember>();
        List<ApplicationLog__c> comparisionAppLogList = new List<ApplicationLog__c>();
        List<ApplicationLog__c> noContactIdLogList = new List<ApplicationLog__c>();
        Map<String,CampaignMember> contactId2CampaignMember = new Map<String,CampaignMember>();
		for(Map<String,String> cmpMemberMap:cmpMemberMapList){
            String contactId = cmpMemberMap.get(CONTACT_ID);
            if(contactId != null){
                CampaignMember cmpMember = contactId2CampaignMember.get(contactId);
                if(cmpMember == null){
                    cmpMember = new CampaignMember(campaignId = this.campaignId);
                    contactId2CampaignMember.put(contactId,prepareCmpMember(cmpMemberMap,cmpMember));
                }
                else{
                    Integer currentRowId;
                    Integer oldRowId;
                    try{
                        currentRowId = Integer.valueOf(cmpMemberMap.get(H_ID));
                        oldRowId = Integer.valueOf(cmpMember.SourceId__c);
                    }
                    catch(Exception rowIdException){
                        String message = 'ID value invalid for comparision';
                        message += 'old row ID: '+cmpMember.SourceId__c;
                        message += 'current row ID: '+cmpMemberMap.get(H_ID);
                        comparisionAppLogList.add(
                            ApplicationLogUtility.insertApexErrorLog('ImportCampaignMembers_Ctrl',
                            message,rowIdException.getStackTraceString(),
                            null,ApplicationLogUtility.PRIORITY_LOW,false)
                        );
                    }
                    if(oldRowId != null && currentRowId != null){
                        if(currentRowId > oldRowId){
                            cmpMember = prepareCmpMember(cmpMemberMap,cmpMember);
                            contactId2CampaignMember.put(contactId,cmpMember);
                        }
                    }
                }
            }
            else{
                noContactIdLogList.add(
                    ApplicationLogUtility.insertApexErrorLog('ImportCampaignMembers_Ctrl',
                    'No contactId was send with Campaign Member','prepareCmpMember(List<Map<String,String>>)',
                    null,ApplicationLogUtility.PRIORITY_LOW,false)
                );
            }
		}
        if(comparisionAppLogList.size()>0){
            insert comparisionAppLogList;
            comparisionAppLogList.clear();
        }
        if(noContactIdLogList.size()>0){
            insert noContactIdLogList;
            noContactIdLogList.clear();
        }
		return contactId2CampaignMember.values();
	}

	/**
	 * deletes content data
	 */
	public void refreshInput(){
		this.blobInput = null;
		this.inputFileName = '';
		this.csv = null;
		this.verifyCsvInput();

	}
	/**
	 * creates campaign members from csv's rows
	 */
	public void importMembers(){
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

		//prepare value-sets and campaign member maps from csv's rows
		for(Integer i=0;i<this.csv.getLength();i++){
			Map<String,String> row = new Map<String,String>(this.csv.get(i));
			UtilPhone phone;
			
			phone = new UtilPhone(row.get(H_PHONE));
			if(phone.output != null){
				String phoneE164 = phone.toE164();
				phoneSet.add(phoneE164);
                row.put(R_PHONE,row.get(H_PHONE)); // place user input in R_PHONE
				row.put(H_PHONE,phoneE164); // update H_PHONE with formatted value
                
			}

			String name = row.get(H_NAME);
			//row.put(H_NAME, name);	// trim
			if(name!=null){
				name = name.trim();
				row.put(R_NAME,name);//store trimmed raw input for customer name

				nameSet.add(name);

				name = Util.purifyName(name);
				nameSet.add(name);
                row.put(H_NAME,name); // store purified name in H_NAME
			}

			String email = row.get(H_EMAIL);
			if(Util.checkEmail(email)){
				emailSet.add(email);
			}

			String empEmail = row.get(H_S_ADVISOR_EMAIL);
			if(Util.checkEmail(empEmail)){
				empEmailSet.add(empEmail);
			}

			String empName = row.get(H_S_ADVISOR);
			if(String.isNotBlank(empName)){
				empName = empName.trim();
				empNameSet.add(empName);
                row.put(R_S_ADVISOR,empName);

				empName = Util.purifyName(empName);
				empNameSet.add(empName);
                row.put(H_S_ADVISOR,empName);
			}

			String branchCode = row.get(H_P_S_B);
			if(String.isNotBlank(branchCode)){
				branchCode = branchCode.trim();
				branchCodeSet.add(branchCode);
				row.put(H_P_S_B, branchCode);
			}

			String sapId = row.get(H_SAP_ID);
			// if(String.isNotBlank(sapId)){
            //     row.put(R_SAP_ID,sapId);
            //     sapId = Util.padSapId(Util.getSapId(sapId));
            //     row.put(H_SAP_ID,sapId);
            //     sapIdSet.add(sapId);
			// }
			if(String.isNotBlank(sapId)){
				string tmpSapId = String.valueOf(Util.getSapId(sapId));
				row.put(R_SAP_ID,tmpSapId);
				sapIdSet.add(tmpSapId);
				tmpSapId = Util.padSapId(tmpSapId);
				row.put(H_SAP_ID,tmpSapId);
				sapIdSet.add(tmpSapId);
			}

			String adUsername = row.get(H_AD_USERNAME);
			if(String.isNotBlank(adUsername)){
				adUsernameSet.add(adUsername);
			}

			phone = new UtilPhone(row.get(H_S_ADVISOR_PHONE));
            row.put(R_S_ADVISOR_PHONE,row.get(H_S_ADVISOR_PHONE));
			if(phone.output != null){
				String phoneE164 = phone.toE164();
				empPhoneSet.add(phoneE164);
                row.put(H_S_ADVISOR_PHONE,phoneE164);
			}

			cmpMemberMapList.add(row);
		}		
		List<Account> accountList = [
			SELECT Id, LastName, isPersonAccount, Phone,Mobile_Country_Code_1__pc,
				PersonMobilePhone,Mobile_Preferred__pc,Office_Email__c,
				Home_Email__c,Other_Email__c,Default_Email__c, PersonEmail,PersonContactId
			FROM Account
			WHERE 
				PersonMobilePhone IN :phoneSet
				OR Default_Email__c IN :emailSet
				// (
				//     PersonMobilePhone IN :phoneSet
				//     OR Mobile_Preferred__pc != null
				// )
				// AND
				// (
				//     LastName IN :nameSet
				//     OR Default_Email__c IN :emailSet
				//     OR PersonEmail IN:emailSet
				// )
				// AND isPersonAccount = true
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
				// OR Name IN :nameSet
			ORDER BY LastModifiedDate DESC
		];
		ContactLookup contactIdLookup = new ContactLookup(contactList);

		String companyId;
		if(this.campaignCompanyId != null){
			companyId = String.valueOf(this.campaignCompanyId);
		}
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
		EmployeeMasterLookup empMasterIdLookup = new EmployeeMasterLookup(empMasterList);

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
		
		if(accountIdLookup.newAccountList.size()>0){
			//AccountHandler.preventDefaultSubs = true;
			Database.insert(accountIdLookup.newAccountList,false);
			Set<Id> accountIdSet = new Set<Id>();
			for(Account newAccount : accountIdLookup.newAccountList){
				accountIdSet.add(newAccount.Id);
			}
			SubsRepository.create(new Map<Id,Set<Id>>{this.campaignCompanyId => accountIdSet},true);
			//AccountHandler.preventDefaultSubs = false;
			/*
			List<Subscription__c> subList = new List<Subscription__c>();
			for(Account newAccount :accountIdLookup.newAccountList){
				String uniqueKey = String.join(new List<String> { this.campaignCompanyId,newAccount.Id}, '_');
				subList.addAll(SubsRepository.create(newAccount.Id, this.campaignCompanyId,null,false));
			}
			insert subList;
			System.debug(accountIdLookup.newAccountList[0]);
			*/
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
			
			for(Map<String,String> cmpMemberMap: cmpMemberMapList){
				if(cmpMemberMap.get(CONTACT_ID)== null){
					Id lookupContactId = newAccountLookup.lookAccount(cmpMemberMap);
					cmpMemberMap.put(CONTACT_ID,lookupContactId);
					cmpMemberMap.put(NEW_CONTACT,'YES');
				}
			}
		}

		List<CampaignMember> cmpMemberList = prepareCmpMember(cmpMemberMapList);

		List<Database.SaveResult> campaignInsertResultList = Database.insert(cmpMemberList,false);
        Integer rowIndex = 0;
        Set<Integer> dupIndexSet = new Set<Integer>();
        for(Database.SaveResult campaignInsertResult:campaignInsertResultList){
            if(!campaignInsertResult.isSuccess()){
                for(Database.Error insertError: campaignInsertResult.getErrors()){
                    String errorMessage = insertError.getMessage();
                    if(errorMessage.contains(DUP_CMP_MEMBER_MSG)){
                        dupIndexSet.add(rowIndex);
                    }
                }
            }
            rowIndex += 1;
        }
        if(dupIndexSet.size()>0){
            Map<Id,CampaignMember> contactId2DupCmpMember = new Map<Id,CampaignMember>();
            for(Integer dupRowIndex: dupIndexSet){
                CampaignMember dupCmpMember = cmpMemberList.get(dupRowIndex);
                contactId2DupCmpMember.put(dupCmpMember.ContactId,dupCmpMember);
            }

            List<CampaignMember> existingCmpMemberList = [
                SELECT Id, contactId, SalesAdvisor__c,Showroom__c,NumberOfPax__c,
                SourceId__c,Source__c, CustomerName__c, CustomerContact__c,
                CustomerEmail__c,SalesAdvisorName__c,SalesAdvisorContact__c,
                SalesAdvisorEmail__c,BranchCode__c,SapId__c
                FROM CampaignMember
                WHERE contactId IN :contactId2DupCmpMember.keySet()
                    AND campaignId = :this.campaignId
            ];

            for(CampaignMember cmpMember :existingCmpMemberList){
                CampaignMember dupCmpMember = contactId2DupCmpMember.get(cmpMember.contactId);
                cmpMember = prepareCmpMember(dupCmpMember,cmpMember);
                contactId2DupCmpMember.put(cmpMember.contactId,cmpMember);
            }
            List<Database.SaveResult> cmpUpdateResultList = Database.update(contactId2DupCmpMember.values(),false);
            for(Database.SaveResult campaignInsertResult:cmpUpdateResultList){
                if(!campaignInsertResult.isSuccess()){
                    for(Database.Error insertError: campaignInsertResult.getErrors()){
                        String errorMessage = insertError.getMessage();
                    }
                }
            }
        }
	}

	public void addImportedMessage(){
		ApexPages.Message membersAdded =
			new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Members Added to the Campaign');
		ApexPages.addMessage(membersAdded);
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

	public class EmployeeMasterLookup{
		//case1 name+email to EmployeeId
		Map<String, Id> nameEmail2EmployeeId;
		//case2  ActiveDirectoryUsername__c to EmployeeId 
		Map<String, Id> adUsername2EmployeeId;
		//case3 Employee_Reference__c to EmployeeId
		Map<String,Id> sapId2EmployeeId;

		public EmployeeMasterLookup(){
			this.refresh();
		}

		public EmployeeMasterLookup(List<Employee_Master__c> empMasterList){
			this.updateMaps(empMasterList,true);
		}

		public void refresh(){
			this.nameEmail2EmployeeId = new Map<String,Id>();
			this.adUsername2EmployeeId = new Map<String, Id>();
			this.sapId2EmployeeId= new Map<String, Id>();
		}

		public void updateMaps(List<Employee_Master__c> empMasterList, Boolean refresh){
			if(refresh){
				this.refresh();
			}
			for(Employee_Master__c empMaster:empMasterList){
				List<String> keyList;
				String name = Util.purifyName(empMaster.Name);
				String email = empMaster.Email__c;
				String adUsername = empMaster.ActiveDirectoryUsername__c;
				String sapId = Util.padSapId(empMaster.Employee_Reference__c);

				if(String.isNotBlank(name) && String.isNotBlank(email)){
					keyList = new List<String>{name,email};
					this.nameEmail2EmployeeId.put(joinKeys(keyList),empMaster.Id);
				}

				if(String.isNotBlank(adUsername)){
					this.adUsername2EmployeeId.put(adUsername,empMaster.Id);
				}

				if(String.isNotBlank(sapId)){
					this.sapId2EmployeeId.put(sapId,empMaster.Id);
				}
			}
		}

		public Id lookEmployeeMaster(Map<String,String> cmpMemberMap){
			List<String> keyList;
			Id lookupEmpMasterId = null;
			String email = cmpMemberMap.get(H_S_ADVISOR_EMAIL);
			String name = cmpMemberMap.get(H_S_ADVISOR);
			String sapId = cmpMemberMap.get(H_SAP_ID);
			String adUsername = cmpMemberMap.get(H_AD_USERNAME);
			
			if(String.isNotBlank(name) && String.isNotBlank(email)){
				keyList = new List<String>{name,email};
				lookupEmpMasterId = this.nameEmail2EmployeeId.get(joinKeys(keyList));
			}

			if(lookupEmpMasterId == null && String.isNotBlank(adUsername)){
				lookupEmpMasterId = this.adUsername2EmployeeId.get(adUsername);
			}

			if(lookupEmpMasterId == null && String.isNotBlank(sapId)){
				sapId = Util.padSapId(Util.getSapId(sapId));
				lookupEmpMasterId = this.sapId2EmployeeId.get(sapId);
			}
			return lookupEmpMasterId;
		}
	}
}