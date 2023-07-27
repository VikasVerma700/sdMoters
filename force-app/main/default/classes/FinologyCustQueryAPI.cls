@RestResource(urlMapping='/v1/Finology/CustQuery')
global without sharing class FinologyCustQueryAPI {
    @httpGet
    global static ResponseResult getCustomerQuery() {
        ResponseResult response;
        try{
            Map<String,String> paramsMap = RestContext.request.params;
            String regisNo = paramsMap.get('regisNo');
            String docuNo = paramsMap.get('docuNo');
            String chassisNo = paramsMap.get('chassisNo');

            SalesDetails sdeatil;
            InsPolicyDetails insPolicy;
            List<Sales_Order__c> salesOrder;
            List<Insurance_Policy__c> policyList;
            Vehicle_Ownership__c vehOwnershipRec;
            
            if(retrieveVoDetails(regisNo, docuNo, chassisNo).isEmpty()){
              return response = new ResponseResult('Vehicle Ownership Record Not Found !!', null);
            }else{
                for(Vehicle_Ownership__c vehOwner : retrieveVoDetails(regisNo, docuNo, chassisNo)){
                    salesOrder = retrieveSalesDetails(vehOwner.Vehicle__c );
                    policyList = retrievePolicyDetails(vehOwner.Id);
                    vehOwnershipRec = vehOwner;
                }
            }
             
            if(!salesOrder.isEmpty()){
                for(Sales_Order__c order : salesOrder){
                    sdeatil = new SalesDetails(order); 
                }
            }
            if(!policyList.isEmpty()){
                for(Insurance_Policy__c policy : policyList){
                    insPolicy = new InsPolicyDetails(policy);
                }
            }
            
            AccountDetails acct = new AccountDetails(vehOwnershipRec);
            VehicleDetails vehic = new VehicleDetails(vehOwnershipRec, sdeatil);
            VehicleOwnershipDetails ownership = new VehicleOwnershipDetails(vehOwnershipRec, acct, vehic, insPolicy);
            response = new ResponseResult('Success', ownership);
            
        }catch(Exception e){
            System.debug('Exception Error '+e.getCause()+' Error msg '+e.getMessage() +' line no. '+e.getLineNumber());
            response = new ResponseResult('Error', null);
            FinologyCustQueryAPI finology = new FinologyCustQueryAPI();
            ApplicationLogUtility.insertApexErrorLog(finology, e, 'Low', False);
            ApplicationLogUtility.insertLogs();
        }
        
        return response;
    }

    public static List<Vehicle_Ownership__c> retrieveVoDetails(String regisNo, String docuNo, String chassisNo) {
        String voStatus = 'Active';
        String query = 'SELECT Id, Name, Registration_No__c, Status__c, Customer__c, Customer__r.Name, Customer__r.NRIC_Number__c, Vehicle__c, Vehicle__r.Name, ';
        query += ' Vehicle__r.Engine_Number__c, Vehicle__r.Vehicle_Model_Description__c, Vehicle__r.VSB_Reference__c, Vehicle__r.VSB_Reference_Company__c ';
        query += 'FROM Vehicle_Ownership__c WHERE Registration_No__c =: regisNo AND Customer__r.NRIC_Number__c =: docuNo AND Vehicle__r.Name =: chassisNo AND ';
        query += 'Status__c =: voStatus order by CreatedDate desc LIMIT 1 ';
        return Database.query(String.escapeSingleQuotes(query));

    }
    public static List<Sales_Order__c> retrieveSalesDetails(String vehId ) {
        String query = 'SELECT Id, Showroom__c, Showroom__r.Name, Booking__c, Booking__r.SalesAdvisor__c, Booking__r.SalesAdvisor__r.Name, ';
        query += 'Booking__r.SalesAdvisor__r.ActiveDirectoryUsername__c, Booking__r.SalesAdvisor__r.Employee_Reference__c ';
        query += 'FROM Sales_Order__c WHERE Vehicle__c =: vehId LIMIT 1';
        return Database.query(String.escapeSingleQuotes(query));
    }
    public static List<Insurance_Policy__c> retrievePolicyDetails(String vehOId) {
        String query = ' SELECT Id, Name, Company__c, Company__r.Name, Policy_Holder__c, Policy_Holder__r.Name, Insurance_Policy_Status__c, ';
        query += 'Claim_Amount__c, Veh_Reg_Date__c, Submission_Date__c, Policy_Expiry_Date__c, Policy_Received_Date__c ';
        query += 'FROM Insurance_Policy__c WHERE Vehicle_Ownership__c =: vehOId order by CreatedDate desc LIMIT 1';
        return Database.query(String.escapeSingleQuotes(query));
    }
    
    global class ResponseResult {
        public string msg;
        public VehicleOwnershipDetails detail;
        global ResponseResult(String msg, VehicleOwnershipDetails ownership ){
            this.msg = msg;
            this.detail = ownership;
        }
        
    }

    global class AccountDetails {
        public String name;
        public String docNo;
        global AccountDetails(Vehicle_Ownership__c vehOwnershipRec){
            this.name = vehOwnershipRec.Customer__r.Name;
            this.docNo = vehOwnershipRec.Customer__r.NRIC_Number__c;
        }        
    }
    
    global class VehicleOwnershipDetails {
        public String regNo;
        public String status;
        public String veOwnerId;
        public AccountDetails account;
        public VehicleDetails vehicle;
        public InsPolicyDetails policy;
        global VehicleOwnershipDetails(Vehicle_Ownership__c vehOwnershipRec, AccountDetails acct, VehicleDetails vehic, InsPolicyDetails insPolicy){
            this.regNo = vehOwnershipRec.Registration_No__c;
            this.status = vehOwnershipRec.Status__c;
            this.veOwnerId = vehOwnershipRec.Id;
            this.account = acct;
            this.vehicle = vehic;
            this.policy = insPolicy;
        }
    }
    
    global class VehicleDetails {
        public String chassis;
        public String engNo;
        public String modelDesc;
        public String vsbReference;
        public String vsbReferenceCompany;
        public SalesDetails salesDetail;
        global VehicleDetails(Vehicle_Ownership__c vehOwnershipRec, SalesDetails sdeatil){
            this.salesDetail = sdeatil;
            this.chassis = vehOwnershipRec.Vehicle__r.Name;
            this.engNo = vehOwnershipRec.Vehicle__r.Engine_Number__c;
            this.modelDesc = vehOwnershipRec.Vehicle__r.Vehicle_Model_Description__c;
            this.vsbReference = vehOwnershipRec.Vehicle__r.VSB_Reference__c;
            this.vsbReferenceCompany = vehOwnershipRec.Vehicle__r.VSB_Reference_Company__c;

        }
    }
    
    global class InsPolicyDetails {
        public String policyName;
        public String companyName;
        public String policyHolder;
        public String status;
        public Decimal claimAmount; 
        public Date vehRegDate;
        public Date submissionDate;
        public Date policyExpDate;
        public Date policyReceivedDate;   
        global InsPolicyDetails(Insurance_Policy__c policy){
            this.policyName = policy.Name;
            this.companyName = policy.Company__r.Name;
            this.policyHolder = policy.Policy_Holder__r.Name;
            this.status = policy.Insurance_Policy_Status__c;
            this.claimAmount = policy.Claim_Amount__c;
            this.vehRegDate = policy.Veh_Reg_Date__c;
            this.submissionDate = policy.Submission_Date__c;
            this.policyExpDate = policy.Policy_Expiry_Date__c;
            this.policyReceivedDate = policy.Policy_Received_Date__c;

        }
    }

    global class SalesDetails {
        public String showroom;
        public String salesAdvisorId;
        public String salesAdvisorName;
        public String salesAdvisorUserName;

        global SalesDetails(Sales_Order__c order){
            this.showroom = order.Showroom__r.Name;   
            this.salesAdvisorId =  order.Booking__r.SalesAdvisor__r.Employee_Reference__c;
            this.salesAdvisorName = order.Booking__r.SalesAdvisor__r.Name;
            this.salesAdvisorUserName =   order.Booking__r.SalesAdvisor__r.ActiveDirectoryUsername__c;
        } 
    }
}