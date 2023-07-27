@RestResource(urlMapping='/v1/Finology/salesAgent')
global without sharing class FinologySalesAgentAPI {
    @httpGet
    global static ResponseResult getSalesAgent() {
        ResponseResult response = new ResponseResult();
        try{
            Map<String,String> paramsMap = RestContext.request.params;
            String empNumber = paramsMap.get('empNumber');
            String empMasterId = paramsMap.get('empMasterId');

            List <Employee_Master__c> empMasterList = [Select Id, Name, EmployeeNumber__c, ActiveDirectoryUsername__c, Employee_Reference__c, Employee_Status_Code__c, Email__c,
                                            Team_Code__c, Employee_Number__c, Mobile_Number__c,Showroom__c, Showroom__r.MobyBranchCode__c FROM Employee_Master__c WHERE Id =: empMasterId 
                                            AND Employee_Reference__c =: empNumber AND Employee_Status_Code__c = 'SC' AND IsActive__c = true LIMIT 1];
            
            EmployeeMaster emp;  
            if(!empMasterList.isEmpty()){
                for(Employee_Master__c empMaster : empMasterList ){
                    emp = new EmployeeMaster(empMaster);
                }
                response.msg = 'Success';
            }else{
                response.msg = 'Sales Agent Not Found';
            }          
            response.employee = emp;                         

        } catch(Exception e){
            System.debug('Exception Error '+e.getCause()+' Error msg '+e.getMessage() +' line no. '+e.getLineNumber());
            response.employee = new EmployeeMaster(new Employee_Master__c());
            response.msg = 'Error';
            FinologySalesAgentAPI finology = new FinologySalesAgentAPI();
            ApplicationLogUtility.insertApexErrorLog(finology, e, 'Low', False);
            ApplicationLogUtility.insertLogs();
        }
        
        return response;
    }

    global class ResponseResult {
        public string msg;
        public EmployeeMaster employee;
    }
    global class EmployeeMaster{
        public string name;
        public string mobile;
        public string email;
        public string teamCode;
        public string empSapId;
        public string empDmsId;
        public string adUserName;
        public string statusCode;
        public string branchCode;
        global EmployeeMaster(Employee_Master__c salesAgent){
            this.name = salesAgent.Name;
            this.mobile = salesAgent.Mobile_Number__c;
            this.email = salesAgent.Email__c;
            this.teamCode = salesAgent.Team_Code__c;
            this.empSapId = salesAgent.Employee_Reference__c;
            this.empDmsId = salesAgent.Employee_Number__c;
            this.adUserName = salesAgent.ActiveDirectoryUsername__c;
            this.statusCode = salesAgent.Employee_Status_Code__c;
            this.branchCode = salesAgent.Showroom__r.MobyBranchCode__c;
        }
    }
}