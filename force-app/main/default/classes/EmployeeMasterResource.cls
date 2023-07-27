public with sharing class EmployeeMasterResource implements Queueable, Database.AllowsCallouts{
    ExternalSystem extSystem;

    public EmployeeMasterResource(ExternalSystem extSystem){
        this.extSystem = extSystem;
    }

    public List<Employee_Master__c> prepareEmployee(List<CustomerVehicleService.UserAccount> userAccountList, Id companyId){
        List<Employee_Master__c> empMasterList = new List<Employee_Master__c>();
        List<String> sapIdList = new List<String>();
        List<String> usernameList = new List<String>();
        Set<String> activeDirectorySet = new Set<String>();
        List<String> blockedUsernameList = new List<String>{
            null,''
        };
        Set<String> workshopCodeSet = new Set<String>();
        for(CustomerVehicleService.UserAccount userAccount: userAccountList){
            if(String.isNotBlank(userAccount.SAPID)){
                sapIdList.add(String.valueOf(Util.getSapId(userAccount.SAPID)));
            }
            if(!blockedUsernameList.contains(userAccount.UserName)){
                usernameList.add(userAccount.UserName);
            }
            if(String.isNotBlank(userAccount.DefWorkshop)){
                workshopCodeSet.add(userAccount.DefWorkshop);
            }
            if(String.isNotBlank(userAccount.WindowsID)){
                activeDirectorySet.add(userAccount.WindowsID);
            }
        }
        List<Workshop__c> workshopList = [
            SELECT Id,Company__c,Name
            FROM Workshop__c
            WHERE Name IN :workshopCodeSet
                AND Company__c = :companyId
                AND IsActive__c = true
        ];
        //List<Workshop__c> missingWorkshopList = new List<Workshop__c>();

        WorkshopLookup workshopLkp = new WorkshopLookup(workshopList);
        for(String workshopName: workshopCodeSet){
            workshopLkp.lookWorkshop(this.extSystem.companyName,workshopName);
        }
        workshopLkp.insertMissingWorkshops();

        String empMasterQuery = 'SELECT ';
        empMasterQuery += String.join(new List<String>(schema.SObjectType.Employee_Master__c.fields.getMap().keySet()),',');
        empMasterQuery += ' FROM Employee_Master__c';
        empMasterQuery += ' WHERE Employee_Reference__c IN :sapIdList';
        empMasterQuery += ' OR Employee_Number__c IN :usernameList';
        empMasterQuery += ' OR ActiveDirectoryUsername__c IN :activeDirectorySet';

        Map<Id,Employee_Master__c> id2EmpMasterMap = new Map<Id,Employee_Master__c>();
        for(Employee_Master__c empMaster: (List<Employee_Master__c>) Database.query(empMasterQuery)){
            id2EmpMasterMap.put(empMaster.Id,empMaster);
        }
        EmployeeMasterLookup empMasterLookup = new EmployeeMasterLookup(id2EmpMasterMap.values());

        for(CustomerVehicleService.UserAccount userAccount: userAccountList){
            Id empMasterId = empMasterLookup.lookEmployeeMaster(userAccount);
            Employee_Master__c empMaster = new Employee_Master__c();
            if(empMasterId != null){
                empMaster = id2EmpMasterMap.get(empMasterId);
            }
            if(String.isNotBlank(userAccount.SAPID)){
                empMaster.Employee_Reference__c = String.valueOf(Util.getSapId(userAccount.SAPID));
            }
            if(!blockedUsernameList.contains(userAccount.UserName)){
                empMaster.Employee_Number__c = userAccount.UserName;
            }
            if(String.isNotBlank(userAccount.FullName)){
                empMaster.Name = userAccount.FullName;
            }
            if(Util.checkEmail(userAccount.Email)){
                empMaster.Email__c = userAccount.Email;
            }
            if(userAccount.IsActive != null){
                empMaster.IsActive__c = userAccount.IsActive;
            }
            if(companyId != null){
                empMaster.Company__c = companyId;
            }
            empMaster.ActiveDirectoryUsername__c = userAccount.WindowsID;
            /*
            //csoSA ->  SA
            if(String.isNotBlank(userAccount.QueueRoleCode) && userAccount.QueueRoleCode.startsWith('cso')){
                empMaster.Employee_Status_Code__c = 'CA';
            }
            */
            if(userAccount.EmployeeStatusCode == 'SA'){
                empMaster.Employee_Status_Code__c = 'CA';
            }

            if(String.isNotBlank(userAccount.DefBranch)){
                empMaster.Branch_code__c = userAccount.DefBranch;
            }

            if(String.isNotBlank(userAccount.DefWorkshop )){
                empMaster.Workshop__c = workshopLkp.lookWorkshop(this.extSystem.companyName,userAccount.DefWorkshop).Id;
            }
            if(String.isNotBlank(userAccount.TeamCode)){
                empMaster.Team_Code__c = userAccount.TeamCode;
            }
            empMaster.CreatedFrom__c = ExternalSystem.Type.GDMS.name();
            empMaster.Mobile_Number__c = userAccount.MobileNumber;
            empMasterList.add(empMaster);
        }
        return empMasterList;

    }

    /*
    public void fetchGDMSUsers(){
        CustomerVehicleService vehService = new CustomerVehicleService(this.extSystem.companyName);
        CustomerVehicleService.QueryUsersResponse queryUserResp;
        System.debug('checkpoint 1');
        try{
            queryUserResp = vehService.QueryUsers();
            List<CustomerVehicleService.UserAccount> userAccountList = queryUserResp.UserAccounts.UserAccount;
            Id companyId = CompanyRepository.name2Company.get(this.extSystem.companyName).Id;
            List<Employee_Master__c> empMasterList = prepareEmployee(userAccountList, companyId);
            for(Employee_Master__c empMaster: empMasterList){
                System.debug(empMaster);
            }
            if(empMasterList.size()> 0){
                List<Database.UpsertResult> empMasterUpsertResultList = Database.upsert(empMasterList,false);
                for(Database.UpsertResult empMasterUpsertResult: empMasterUpsertResultList){
                    System.debug(empMasterUpsertResult);
                }
                ApplicationLogUtility.logUpsertFailure(Util.getClassname(this),empMasterUpsertResultList,ApplicationLogUtility.PRIORITY_HIGH,false);
            }
        }
        catch( CalloutException calloutError){
            ApplicationLogUtility.insertCalloutErrorLog(this,calloutError,ApplicationLogUtility.PRIORITY_HIGH,false);
        }
        catch(Exception apexError){
            ApplicationLogUtility.insertApexErrorLog(this, apexError, ApplicationLogUtility.PRIORITY_HIGH,false);
        }

    }
    */

    public void execute(QueueableContext qContext){
        if(CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(ExternalSystem.Type.GDMS).contains(this.extSystem.companyName)){
            try{
                CustomerVehicleService vehService = new CustomerVehicleService(this.extSystem.companyName);
                CustomerVehicleService.QueryUsersResponse queryUserResp;
                List<CustomerVehicleService.UserAccount> userAccountList;
                if(!Test.isRunningTest()){
                    queryUserResp = vehService.QueryUsers();
                    userAccountList = queryUserResp.UserAccounts.UserAccount;
                }
                Id companyId = CompanyRepository.name2Company.get(this.extSystem.companyName).Id;
                List<Employee_Master__c> empMasterList = prepareEmployee(userAccountList, companyId);
                for(Employee_Master__c empMaster: empMasterList){
                    System.debug(empMaster);
                }
                if(empMasterList.size()> 0){
                    List<Database.UpsertResult> empMasterUpsertResultList = Database.upsert(empMasterList,false);
                    for(Database.UpsertResult empMasterUpsertResult: empMasterUpsertResultList){
                        System.debug(empMasterUpsertResult);
                    }
                    ApplicationLogUtility.logUpsertFailure(Util.getClassname(this),empMasterUpsertResultList,ApplicationLogUtility.PRIORITY_HIGH,false);
                }
            }
            catch(CalloutException calloutError){
                ApplicationLogUtility.insertCalloutErrorLog(this,calloutError,ApplicationLogUtility.PRIORITY_HIGH,false);
            }
            catch(Exception apexError){
                ApplicationLogUtility.insertApexErrorLog(this, apexError, ApplicationLogUtility.PRIORITY_HIGH,false);
            }
        }
        ApplicationLogUtility.insertLogs();
    }

    public static List<Database.UpsertResult> upsertEmployees(List<CustomerVehicleService.UserAccount> userAccountList){
        List<Database.UpsertResult> empMasterUpsertResultList;
        try{
            String companyCode;
            if(userAccountList.size()>0){
                companyCode = userAccountList[0].CompanyCode;
                ExternalSystem gdmsSystem = new ExternalSystem(companyCode);
                EmployeeMasterResource empResource = new EmployeeMasterResource(gdmsSystem);
                Id companyId = CompanyRepository.name2Company.get(empResource.extSystem.companyName).Id;
                List<Employee_Master__c> empMasterList = empResource.prepareEmployee(userAccountList, companyId);
                for(Employee_Master__c empMaster: empMasterList){
                    System.debug(empMaster);
                }
                if(empMasterList.size()> 0){
                    empMasterUpsertResultList = Database.upsert(empMasterList,false);
                    for(Database.UpsertResult empMasterUpsertResult: empMasterUpsertResultList){
                        System.debug(empMasterUpsertResult);
                    }
                    ApplicationLogUtility.logUpsertFailure(Util.getClassname(empResource),empMasterUpsertResultList,ApplicationLogUtility.PRIORITY_HIGH,false);
                }
            }
        }
        catch(Exception ApexError){
            ApplicationLogUtility.insertApexErrorLog('EmployeeMasterResource', apexError, ApplicationLogUtility.PRIORITY_HIGH,false);
        }
        ApplicationLogUtility.insertLogs();
        return empMasterUpsertResultList;
    }

    public class EmployeeMasterLookup{

		//case1  Employee_Number__c to EmployeeId 
		Map<String, Id> username2EmployeeId;
        //case2 windowsId to employeeId
        Map<String, Id>  windowsId2EmployeeId;
		//case3 Employee_Reference__c to EmployeeId
		Map<String,Id> sapId2EmployeeId;
        

		public EmployeeMasterLookup(){
			this.refresh();
		}

		public EmployeeMasterLookup(List<Employee_Master__c> empMasterList){
			this.updateMaps(empMasterList,true);
		}

		public void refresh(){
			this.username2EmployeeId = new Map<String, Id>();
            this.windowsId2EmployeeId = new Map<String,Id>();
			this.sapId2EmployeeId= new Map<String, Id>();
		}

		public void updateMaps(List<Employee_Master__c> empMasterList, Boolean refresh){
			if(refresh){
				this.refresh();
			}
			for(Employee_Master__c empMaster:empMasterList){
				String username = empMaster.Employee_Number__c;
				String sapId = String.valueOf(empMaster.Employee_Reference__c);
                String windowsId = String.valueOf(empMaster.ActiveDirectoryUsername__c);

				if(String.isNotBlank(username)){
					this.username2EmployeeId.put(username,empMaster.Id);
				}

				if(String.isNotBlank(sapId)){
					this.sapId2EmployeeId.put(sapId,empMaster.Id);
				}

                if(String.isNotBlank(windowsId)){
                    this.windowsId2EmployeeId.put(windowsId,empMaster.Id);
                }
			}
		}

		public Id lookEmployeeMaster(CustomerVehicleService.UserAccount userAccount){

			Id lookupEmpMasterId = null;
			String sapId = userAccount.SAPID;
			String username = userAccount.UserName;
            String windowsId = userAccount.WindowsID;

            if(String.isNotBlank(username)){
				lookupEmpMasterId = this.username2EmployeeId.get(username);
			}

            if(lookupEmpMasterId == null && String.isNotBlank(windowsId)){
                lookupEmpMasterId = this.windowsId2EmployeeId.get(windowsId);
            }

            if(lookupEmpMasterId == null && String.isNotBlank(sapId)){
				sapId = String.valueOf(Util.getSapId(sapId));
				lookupEmpMasterId = this.sapId2EmployeeId.get(sapId);
			}

			return lookupEmpMasterId;
		}
	}
}