public with sharing class DmsEmployeeMaster {

    public static CallbackEmployeeResp checkExistingEmployeeMaster(List<CustomerVehicleService.UserAccount> payloadList) {
        List<Database.UpsertResult> resultList = EmployeeMasterResource.upsertEmployees(payloadList);
        if(resultList.isEmpty()){ return null; }

        Map<Id, String>employeeIdMap = new Map<Id, String>();
        for(Database.UpsertResult sr : resultList) {
            if(!sr.isSuccess()) {
                String error;
                for(Database.Error dbError : sr.getErrors()) {
                    error += dbError; 
                }
                employeeIdMap.put(sr.getId(), error);
            }else{
                employeeIdMap.put(sr.getId(), 'Success');
            }
        }

        List<Details> detailsList = new list<Details>();
        for(Employee_Master__c emp : [Select Id, Employee_Number__c, CreatedDate, LastModifiedDate from Employee_Master__c Where Id IN :employeeIdMap.keySet() WITH SECURITY_ENFORCED]){
            if(employeeIdMap.containsKey(emp.Id)){
                if(employeeIdMap.get(emp.Id) == 'Success'){
                    String message;
                    if(date.newInstance(emp.LastModifiedDate.year(), emp.LastModifiedDate.month(), emp.LastModifiedDate.day()) == date.newInstance(emp.CreatedDate.year(), emp.CreatedDate.month(), emp.CreatedDate.day()) && emp.CreatedDate.format('HH:mm') == emp.LastModifiedDate.format('HH:mm')){
                        message = 'Inserted';
                    }else{
                        message = 'Updated';
                    }
                    detailsList.add( new Details(emp.Id, emp.Employee_Number__c, 'Employee Master Successfully '+message));
                }else{
                    detailsList.add( new Details(emp.Id, '',  employeeIdMap.get(emp.Id)));
                }
            }
        }

        ApplicationLogUtility.insertLogs();
        return new CallbackEmployeeResp('UPDATE_EMPLOYEE_MASTER', detailsList);
    }

    public class CallbackEmployeeResp {
		public String event;
        public List<Details> details;
        public CallbackEmployeeResp(String evt, List<Details> detList) {
            this.event = evt;
            this.details = detList;
        }
    }

    public class Details {
        public String employeeId;
        public String username;
        public String message;
        public Details(String employeeId, String username, String msg) {
            this.employeeId = employeeId;
            this.username = username;
            this.message = msg;
            
        }
    }
}