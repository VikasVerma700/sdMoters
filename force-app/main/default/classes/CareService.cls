public with sharing class CareService {

    public static final String USERNAME = (Envir.isSandbox) ? API_Setup__c.getInstance('Sync Care Dev Username').Value__c : API_Setup__c.getInstance('Sync Care Prd Username').Value__c;
    public static final String PASSWORD = (Envir.isSandbox) ? API_Setup__c.getInstance('Sync Care Dev Password').Value__c : API_Setup__c.getInstance('Sync Care Prd Password').Value__c;
    public static final String ENDPOINT = (Envir.isSandbox) ? API_Setup__c.getInstance('Sync Care Dev Endpoint').Value__c : API_Setup__c.getInstance('Sync Care Prd Endpoint').Value__c;

    public virtual class Request{
        public string Username;
		public string Password;
		public string DateFrom;
		public string DateTo;
		public string[] Company;
		public long RowCount;
    }

    public class ContactRequest extends Request{
        public long[] CustomerNo;
        public string[] DocumentNo;
        public long LastId;
    }
    public class ContactResponse{
        public long[] contactIds;
        public string companyCode;
        public string source;
        public long custNo;
        public string dmsNo;
        public boolean isBusiness;
        public string salutation;
        public string fullName;
        public string preferredName;
        public Datetime dateOfBirth;
        public string docNum;
        public string docNumRaw;
        public string gender;
        public string prefix;
        public string mobile;
        public string phone1raw;
        public string prefix2;
        public string mobile2;
        public string phone2raw;
        public string prefix3;
        public string mobile3;
        public string phone3raw;
        public string email;
        public string address1;
        public string address2;
        public string address3;
        public string postalCode;
        public string city;
        public string state;
        public boolean emailOptOut;
        public boolean letterOptOut;
        public boolean smsOptOut;

        public ContactResponse copy(){
            return (ContactResponse)JSON.deserialize(JSON.serialize(this),ContactResponse.class);
        }
    }

    public class VehicleRequest extends Request {
		public long[] vehNo;
		public string[] ChassisNo;
		public string[] RegNo;
		public long LastId;
	}

	public virtual class VehicleResponse{
		public string companyCode;
		public string company;
		public string chassis;
		public string engineNum;
		public Decimal engineCap;
		public string source;
		public Long vehNo;
		public string dmsNo;

		public string vehMakeCode;
		public string vehMake;

		public string vehModelCode;
		public string vehModelDesc;
		public Integer vehModelYear;
		public string vehModelRange;

		public string vehVariantCode;
		public string vehVariantDesc;

		public string vehType;

		public string vehColorCode;
		public string vehColor;
		public string vehTrimCode;
		public string vehTrim;

		public Datetime productionDate;
		public string productionMonth;
		public string productionYear;
		public string bodyStyle;
		public string description;
		public Datetime regDate;
		public string regNum;
		public Decimal mileage;
		public Datetime nextServiceDate;
		public string vsbRef;
		public string vsbRefCmp;
		public string sellingDealer;
		public Datetime warrantyExDate;
		public Datetime extendedWarrantyDate;

	}

    public class CareVehOwnership {
		public string companyCode;
		public string source;
		public Long vehOwnId;
		public Long vehNo;
		public string vehChassisNo;
		public string vehRegNo;
		public Boolean isBusiness;
		public Long custNo;
		public string custDocNo;
		public Long drvNo;
		public string drvDocNo;
		public DateTime voStartDate;
		public DateTime voEndDate;
	}
}