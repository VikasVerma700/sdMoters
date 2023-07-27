public with sharing class API_EmployeeMaster implements Queueable{
    public void execute(QueueableContext qContext){
        this.fetchGDMSUsers();
    }
    public List<Employee_Master__c> prepareEmployee(List<CustomerVehicleService.UserAccount> userAccountList, Id companyId){
        List<Employee_Master__c> empMasterList = new List<Employee_Master__c>();
        List<String> sapIdList = new List<String>();
        List<String> adUsernameList = new List<String>();
        List<String> blockedUsernameList = new List<String>{
            'gdms',null,''
        };
        List<String> workshopCodeList = new List<String>();
        for(CustomerVehicleService.UserAccount userAccount: userAccountList){
            if(String.isNotBlank(userAccount.SAPID)){
                sapIdList.add(Util.padSapId(Util.getSapId(userAccount.SAPID)));
            }
            if(!blockedUsernameList.contains(userAccount.UserName)){
                adUsernameList.add(userAccount.UserName);
            }
            if(String.isNotBlank(userAccount.DefWorkshop)){
                workshopCodeList.add(userAccount.DefWorkshop);
            }
        }
        List<Workshop__c> workshopList = [
            SELECT Id,Company__c,Name
            FROM Workshop__c
            WHERE Name IN :workshopCodeList
                AND Company__c = :companyId
        ];
        List<Workshop__c> missingWorkshopList = new List<Workshop__c>();

        WorkshopLookup workshopLkp = new WorkshopLookup(workshopList);
        for(String workshopCode: workshopCodeList){
            if(workshopLkp.lookWorkshop(workshopCode) == null){
                Workshop__c workshop = new Workshop__c(Name = workshopCode, Company__c = companyId);
                missingWorkshopList.add(workshop);
            }
        }
        if(missingWorkshopList.size() != 0){
            insert missingWorkshopList;
        }
        WorkshopLookup newWorkshopLkp = new WorkshopLookup(missingWorkshopList);

        String empMasterQuery = 'SELECT ';
        empMasterQuery += String.join(new List<String>(schema.SObjectType.Employee_Master__c.fields.getMap().keySet()),',');
        empMasterQuery += ' FROM Employee_Master__c';
        empMasterQuery += ' WHERE Employee_Reference__c IN :sapIdList';
        empMasterQuery += ' AND ActiveDirectoryUsername__c IN :adUsernameList';
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
            if(String.isNotBlank(userAccount.SAPID) && String.isBlank(empMaster.Employee_Reference__c)){
                empMaster.Employee_Reference__c = Util.padSapId(Util.getSapId(userAccount.SAPID));
            }
            if(!blockedUsernameList.contains(userAccount.UserName) && String.isBlank(empMaster.ActiveDirectoryUsername__c)){
                empMaster.ActiveDirectoryUsername__c = userAccount.UserName;
            }
            if(String.isNotBlank(userAccount.FullName)){
                empMaster.Name = Util.purifyName(userAccount.FullName);
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
            if(String.isNotBlank(userAccount.DefWorkshop )){
                Id workshopId = workshopLkp.lookWorkshop(userAccount.DefWorkshop);
                if(workshopId == null){
                    workshopId = newWorkshopLkp.lookWorkshop(userAccount.DefWorkshop);
                }
                empMaster.Workshop__c = workshopId;
            }
            empMasterList.add(empMaster);
        }
        return empMasterList;

    }

    public void fetchGDMSUsers(){
        CustomerVehicleService vehService = new CustomerVehicleService('callout:GdmsTrain');
        //vehService.inputHttpHeaders_x.put('Authorization',API_Setup__c.getInstance('GDMS Authorization Uat').Value__c);
        CustomerVehicleService.QueryUsersResponse queryUserResp = vehService.QueryUsers();
        List<CustomerVehicleService.UserAccount> userAccountList = queryUserResp.UserAccounts.UserAccount;
        Id companyId = CompanyRepository.getCompanyData().get(CompanyRepository.C099).Id;
        List<Employee_Master__c> empMasterList = prepareEmployee(userAccountList, companyId);
        for(Employee_Master__c empMaster: empMasterList){
            System.debug(empMaster);
        }
    }

    public class EmployeeMasterLookup{

		//case1  ActiveDirectoryUsername__c to EmployeeId 
		Map<String, Id> adUsername2EmployeeId;
		//case2 Employee_Reference__c to EmployeeId
		Map<String,Id> sapId2EmployeeId;

		public EmployeeMasterLookup(){
			this.refresh();
		}

		public EmployeeMasterLookup(List<Employee_Master__c> empMasterList){
			this.updateMaps(empMasterList,true);
		}

		public void refresh(){
			this.adUsername2EmployeeId = new Map<String, Id>();
			this.sapId2EmployeeId= new Map<String, Id>();
		}

		public void updateMaps(List<Employee_Master__c> empMasterList, Boolean refresh){
			if(refresh){
				this.refresh();
			}
			for(Employee_Master__c empMaster:empMasterList){
				String adUsername = empMaster.ActiveDirectoryUsername__c;
				String sapId = Util.padSapId(empMaster.Employee_Reference__c);

				if(String.isNotBlank(adUsername)){
					this.adUsername2EmployeeId.put(adUsername,empMaster.Id);
				}

				if(String.isNotBlank(sapId)){
					this.sapId2EmployeeId.put(sapId,empMaster.Id);
				}
			}
		}

		public Id lookEmployeeMaster(CustomerVehicleService.UserAccount userAccount){

			Id lookupEmpMasterId = null;
			String sapId = userAccount.SAPID;
			String adUsername = userAccount.UserName;

            if(String.isNotBlank(sapId)){
				sapId = Util.padSapId(Util.getSapId(sapId));
				lookupEmpMasterId = this.sapId2EmployeeId.get(sapId);
			}

			if(lookupEmpMasterId == null && String.isNotBlank(adUsername)){
				lookupEmpMasterId = this.adUsername2EmployeeId.get(adUsername);
			}

			return lookupEmpMasterId;
		}
	}

    public class WorkshopLookup{
		Map<String, Id> workshopName2Id;

		public WorkshopLookup(){
			this.refresh();
		}

		public WorkshopLookup(List<Workshop__c> workshopList){
			this.updateMaps(workshopList,true);
		}

		public void refresh(){
			this.workshopName2Id = new Map<String, Id>();
		}

		public void updateMaps(List<Workshop__c> workshopList, Boolean refresh){
			if(refresh){
				this.refresh();
			}
			for(Workshop__c workshop:workshopList){
				if(String.isNotBlank(workshop.Name)){
					this.workshopName2Id.put(workshop.Name, workshop.Id);
				}
			}
		}

		public Id lookWorkshop(String workshopName){
			Id workshopId = null;
            if(String.isNotBlank(workshopName)){
				workshopId = this.workshopName2Id.get(workshopName);
			}
			return workshopId;
		}
	}
}