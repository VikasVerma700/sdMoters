public without sharing class DmsVehicleOwnership {
    public static void sendWebhook(DmsCallBack__e callback) {
        try {
            Vehicle_Ownership__c owner = retrieveVehiOwnDetails( callback.Id__c );
            if (owner == null ) { return; }
            VehicleOwner payload = new VehicleOwner(owner);
            CustomerVehicleService service  = new CustomerVehicleService(payload.companyCode);

            try{
				
                VehicleOwnerWebhook hook = new VehicleOwnerWebhook(callback.Event__c.toLowercase(), new List<VehicleOwner>{ payload });
                string jsonHook = JSON.serialize(hook, true);
                System.debug('jsonHook : '+jsonHook);
                CustomerVehicleService.UpdateDataResponse resp = service.updateData(jsonHook);
                String response = JSON.serialize(resp);
                System.debug(' resp : '+ response);
                ApplicationLogUtility.insertCalloutSuccessLog('DmsVehicleOwnership', jsonHook, response.unescapeJava(), Request.getCurrent().getRequestId(), false);
			}
			catch(CallOutException callOutError){
				callOutError.setMessage('Error sending '+ String.valueOf(callback.Id__c)+' '+callback.CompanyCode__c + ' '+callOutError.getMessage());
				ApplicationLogUtility.insertCalloutErrorLog(new DmsVehicleOwnership(), callOutError, ApplicationLogUtility.PRIORITY_HIGH, false);
			} 
            
        } catch(Exception e){
            System.debug('Exception Error '+e.getCause()+' Error msg '+e.getMessage() +' line no. '+e.getLineNumber());
            DmsVehicleOwnership ownership = new DmsVehicleOwnership();
            e.setMessage('Exception : '+ String.valueOf(callback.Id__c)+' '+callback.CompanyCode__c +' '+e.getMessage());
            ApplicationLogUtility.insertApexErrorLog(ownership, e, ApplicationLogUtility.PRIORITY_HIGH, false);
        } 
        ApplicationLogUtility.insertLogs();
    }

    public static Vehicle_Ownership__c retrieveVehiOwnDetails(String vehOwnId) {
        String query = 'SELECT Id, Name, Vehicle__c, Vehicle__r.Type__c, Vehicle__r.Stock_Number__c, Vehicle_Make__c, Vehicle_Make__r.name, Vehicle_Model_Range__c, Vehicle__r.Name, '; 
        query += 'VehicleModelDescription__c, VehicleModelCode__c, VehicleVariantCode__c, VehicleVariantDescription__c, Vehicle__r.Vehicle_Trim__c, Vehicle__r.Vehicle_Trim__r.Name, ';
        query += 'Vehicle__r.Vehicle_Colour__c, Vehicle__r.Vehicle_Colour__r.Name, Vehicle__r.EngineCapacity__c, Vehicle__r.Fuel__c, Vehicle__r.SellingDealer__c, ';
        query += 'Vehicle__r.Production_Date__c, Vehicle__r.Warranty_Expiry_Date__c, Vehicle__r.DmsCustomerNumber__c, Vehicle__r.DmsCustomerPin__c, Vehicle__r.DmsDriverNumber__c, ';
        query += 'Vehicle__r.DmsDriverPin__c, Registration_No__c, Registration_Date__c, Vehicle__r.Running_Mileage__c, VehicleMakeCode__c, Vehicle__r.Extended_Warranty_Date__c, '; 
        query += 'Vehicle__r.VehicleVariant__r.Cylinder__c, Vehicle__r.Vehicle_Model__r.Body_Type__c, Vehicle__r.Vehicle_Model__r.Transmission__c, Vehicle__r.Vehicle_Make__r.Company__r.DmsCompanyCode__c ';
        query += 'FROM Vehicle_Ownership__c WHERE Id =: vehOwnId LIMIT 1';
        return Database.query(String.escapeSingleQuotes(query));
    }

    public class VehicleOwner {
        public String CompanyCode;	
		public String VIN;	
        //public String ChassisNumber;
		public String SellingDealerCode;	
		public String SellingDealerName;	
		public Integer CustomerNo;	
		public String CustomerPIN;	
		public String SSN;	
		public Integer DriverID;	
		public String DriverPIN;	
		public String RegistrationNumber;	
		public Date RegistrationDate;	
		
        public VehicleOwner(Vehicle_Ownership__c ownership) {
            this.CompanyCode = ownership.Vehicle__r.Vehicle_Make__r.Company__r.DmsCompanyCode__c;
            this.VIN = ownership.Vehicle__r.Name;
           // this.ChassisNumber = ownership.Vehicle__r.Name;
            this.SellingDealerCode = null;
            this.SellingDealerName = null;
            this.CustomerNo = ownership.Vehicle__r.DmsCustomerNumber__c != null ? Integer.valueOf(ownership.Vehicle__r.DmsCustomerNumber__c) : null;
            this.CustomerPIN = ownership.Vehicle__r.DmsCustomerPin__c;
            this.SSN = null;
            this.DriverID = ownership.Vehicle__r.DmsDriverNumber__c != null ? Integer.valueOf(ownership.Vehicle__r.DmsDriverNumber__c) : null;
            this.DriverPIN = ownership.Vehicle__r.DmsDriverPin__c;
            this.RegistrationNumber = ownership.Registration_No__c;
            this.RegistrationDate = ownership.Registration_Date__c;
        }
    }

    public class VehicleOwnerWebhook {
		public String event;
		public List<VehicleOwner> payload;
		public VehicleOwnerWebhook(String event, List<VehicleOwner> payloadList) {
			this.event = event;
			this.payload = payloadList;
		}
	}
}