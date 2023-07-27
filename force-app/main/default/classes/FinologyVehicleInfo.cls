public without sharing class FinologyVehicleInfo {
    private final static Boolean IS_SANDBOX = Envir.IsSandbox;
    private final static String ORG_ID = UserInfo.getOrganizationId();
    private final static String UAT_BASE = 'https://uat-insurance-api.finology.com.my';
    private final static String UAT_KEY = '3c5eae2454fe4ec4a3c42fa2d5831e3f';
    
    private final static String PRD_BASE = 'https://insurance-api.finology.com.my';
    private final static String PRD_KEY = '';
    
    public static String CUST_DOC_NO;
    public static String VEH_OWNER_ID;
    public static boolean Is_BATCH = false;
    public static boolean IS_VO_VALID = false;
    Public static List<Vehicle__c> vehicleList = new List<Vehicle__c>();
    Public static List<ApplicationLog__c> logList = new List<ApplicationLog__c>();
    Public static List<Insurance_Policy__c> policyList = new List<Insurance_Policy__c>();
    Public static List<Vehicle_Ownership__c> vehOwnerList = new List<Vehicle_Ownership__c>();
    
    public static String KEY;
    public static String URL_BASE;
    static {
        URL_BASE = IS_SANDBOX ? UAT_BASE : PRD_BASE;
        KEY = IS_SANDBOX ? UAT_KEY : PRD_KEY;
    } 
    
    private static String constructReqBody(PayloadRequest req){
        String reqBody = System.JSON.serialize(req);
        return reqBody;
    }
    
    private static HttpRequest createRequest(String method, String servicePath) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(servicePath);
        req.setMethod(method);
        return req;
    }
    
    private static HttpResponse invokeWebService(HttpRequest httpReq){          
        Http h = new Http();
        HttpResponse res; 
        if(Test.isRunningTest()){
            res = FinologyMockHttpResponseGenerator.respond(httpReq);     
        }else{
            res = h.send(httpReq);
        }
        return res;
    }
    
    public static String generateHashCode(String inputString){
        Blob digest = Crypto.generateDigest('SHA-512', Blob.valueOf(inputString));
        String hashCodeStr = EncodingUtil.convertToHex(digest);
        return hashCodeStr;
    }
    
    private static String getCurrentDateTime(){
        DateTime myDateTime = DateTime.newInstance(date.today().year(), date.today().month(), date.today().day(), DateTime.now().hour(), DateTime.now().minute(), DateTime.now().second());
        String formatted = myDateTime.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS');
        return formatted; 
    }
    
    private static PayloadRequest constructPayload(String vehRegNo, String idType, String docuNo, String postCode){
        PayloadRequest payload = new PayloadRequest();
        payload.ref_code = ORG_ID;
        payload.request_date_time = getCurrentDateTime();
        payload.hash_code = generateHashCode(KEY+'*'+ORG_ID+'*'+getCurrentDateTime()+'*'+vehRegNo);
        payload.vehicle_registration_no = vehRegNo;
        payload.id_type = idType;
        payload.identification_no = docuNo;
        payload.postcode = postCode;
        return payload;
        
    }
    
    public static void validateVo(String voReg ){
        if(voReg != null){
           List<Vehicle_Ownership__c> vehOwnershipRec = [Select Id, Name, Registration_No__c, Status__c, Customer__c, Customer__r.NRIC_Number__c from Vehicle_Ownership__c where
                                                          Registration_No__c =: voReg AND Status__c = 'Active' AND Customer__r.NRIC_Number__c != null WITH SECURITY_ENFORCED order by CreatedDate desc LIMIT 1];
            if(!vehOwnershipRec.IsEmpty()){ 
                CUST_DOC_NO = vehOwnershipRec[0].Customer__r.NRIC_Number__c;
                IS_VO_VALID = true;
                VEH_OWNER_ID = vehOwnershipRec[0].Id;
            }   
        }
    }
    
    public Static String getVehicleInfo(String vehRegNo, String idType, String postCode, Boolean fromBatch){
        Is_BATCH = fromBatch;
        String retMessage = 'error in call API';
        try{
            validateVo(vehRegNo);
            if(!IS_VO_VALID){
                retMessage = 'Empty Customer Document Number.';
            }else{
                String path = URL_BASE+'/api/v2.3.0/vix';
                HttpRequest req ;      
                HttpResponse res ;
                PayloadRequest payloadReq = constructPayload(vehRegNo, idType, CUST_DOC_NO, postCode);
                String payLoad = constructReqBody(payloadReq);
                req = createRequest('POST', path); 
                req.setHeader('Authorization-Token', KEY);
                req.setHeader('Content-Type', 'application/json;charset=UTF-8'); 
                req.setHeader('Accept', 'application/json');
                req.setTimeout(30000);
                system.debug('request Body:' + payLoad);
                req.setBody(payLoad); 
                res = invokeWebService(req);
                if(res.getStatusCode() == 200){  
                    GetResponse vehiResponse = (GetResponse) JSON.deserialize(res.getBody(), GetResponse.class);
                    
                    List<Vehicle__c> vehicleList = [Select Id from Vehicle__c where Name =: vehiResponse.response.vehicle_details.chassis_no AND 
                                                    InsuranceCurrentNcdExpiry__c =: Date.valueOf(vehiResponse.response.ncd_details.current_ncd_expiry_date) WITH SECURITY_ENFORCED LIMIT 1];
                    if(vehicleList.isEmpty()){
                        UpsertInsurancePolicy(vehiResponse.response , new Detail());
                    }
                    retMessage = vehiResponse.message;
                }
                if(res.getStatusCode() == 422 ){  
                    ErrorResponse errResponse = (ErrorResponse)JSON.deserialize(res.getBody(), ErrorResponse.class);
                    if(errResponse.errors.error_code == 'L58'){
                        upsertInsurancePolicy(new Response(), errResponse.errors.detail);
                    }
                    if(errResponse.errors.error_code == 'L44' || errResponse.errors.error_code == 'L07'){  
                        vehOwnerList = [Select Id, End_Date__c, Status__c from Vehicle_Ownership__c where Id =: VEH_OWNER_ID WITH SECURITY_ENFORCED LIMIT 1];
                        if(Is_BATCH){
                            ApplicationLog__c log = new ApplicationLog__c(
                                Type__c = 'Callout',
                                ErrorMessage__c = errResponse.errors.message,
                                StackTrace__c = errResponse.errors.error_code,
                                Status__c = 'ERROR',
                                ApexClassName__c = 'FinologyVehicleInfo',
                                TransactionId__c = Request.getCurrent().getRequestId(),
                                Priority__c = 'Medium');
                            logList.add(log);    
                        }else{
                            ApplicationLogUtility.insertCalloutErrorLog('FinologyVehicleInfo', errResponse.errors.error_code, errResponse.errors.message); 
                            deactivedVo();
                        }  
                    }
                    retMessage = errResponse.errors.message;
                }
            }
        }catch(Exception e){
            System.debug('Exception Error '+e.getCause()+' line no : '+e.getLineNumber()+' msg '+e.getMessage());
            FinologyVehicleInfo finVehInfo = new FinologyVehicleInfo();
            ApplicationLogUtility.insertApexErrorLog(finVehInfo, e, 'Low', False);
            ApplicationLogUtility.insertLogs();
        }
        return retMessage;
    }
    
    private Static void deactivedVo(){
        List<Vehicle_Ownership__c> owner = new List <Vehicle_Ownership__c>();
        for(Vehicle_Ownership__c ownr : vehOwnerList){ 
            ownr.End_Date__c = date.today();
            owner.add(ownr);
        }
        if(Vehicle_Ownership__c.SObjectType.getDescribe().isUpdateable() == false && Vehicle_Ownership__c.SObjectType.getDescribe().isAccessible() == false ) {
            throw new DmlException('No permissions to insert.');
        }else{
            Database.update(owner); 
        }
        
    }
    
    private static void upsertInsurancePolicy(Response response , Detail detail) {
        Vehicle_details vd = response.vehicle_details != null ? response.vehicle_details : detail.vehicle_details;
        Ncd_details ncd = response.ncd_details != null ? response.ncd_details : detail.ncd_details;
        
        List<Vehicle__c> oldVehRec = [Select Id from Vehicle__c where Name =: vd.chassis_no WITH SECURITY_ENFORCED LIMIT 1];       
        Vehicle__c vs = new Vehicle__c();
        if(oldVehRec.Size() > 0){
            vs.Id = oldVehRec[0].Id;
        }
        vs.InsuranceRegNumber__c = vd.vehicle_registration_no != 'None' ? vd.vehicle_registration_no : '';
        vs.InsuranceChassisNumber__c = vd.chassis_no != 'None' ? vd.chassis_no : '';
        vs.InsuranceEngineNumber__c = vd.engine_no != 'None' ? vd.engine_no : '';
        // vs. = vd.nvic_code; 
        vs.InsuranceVehicleMake__c = vd.vehicle_make != 'None' ? vd.vehicle_make : '';
        vs.InsuranceVehicleModel__c = vd.vehicle_model != 'None' ? vd.vehicle_model : '';
        vs.InsuranceVehicleModelCodeI__c = vd.vehicle_model_code != 'None' ? vd.vehicle_model_code : '';
        vs.InsuranceMakeYear__c = vd.vehicle_make_year != 'None' ? vd.vehicle_make_year : '';
        vs.InsuranceVehicleClass__c = vd.vehicle_class != 'None' ? vd.vehicle_class : '';
        vs.InsuranceTransmission__c = vd.vehicle_transmission_type != 'None' ? vd.vehicle_transmission_type : '';
        vs.InsuranceVehicleUse__c = vd.vehicle_use != 'None' ? vd.vehicle_use : '';
        vs.InsuranceFuel__c = vd.vehicle_fuel_type != 'None' ? vd.vehicle_fuel_type : '';
        vs.InsuranceBuildType__c = vd.vehicle_build_type != 'None' ? vd.vehicle_build_type : '';
        if(vd.vehicle_cc  != 'None'){
            vs.InsuranceEngineCapacity__c =  Integer.valueOf(vd.vehicle_cc); /** pending SF field name change */
        } 
        if(vd.ism_insured_value  != 'None'){
            vs.InsuranceInsuredValue__c = Decimal.valueOf(vd.ism_insured_value);
        } 
        if(vd.vehicle_seat  != 'None'){
            vs.InsuranceSeat__c = Integer.valueOf(vd.vehicle_seat);
        }
        if(vd.market_value  != 'None'){
            vs.InsuranceMarketValue__c = Decimal.valueOf(vd.market_value);
        }
        if(ncd.next_ncd_percent  != 'None'){
            vs.InsuranceNextNcd__c = Decimal.valueOf(ncd.next_ncd_percent);
        } 
        vs.InsuranceCurrentNcdExpiry__c = date.valueOf (ncd.current_ncd_expiry_date);
        
        try {
            if(Is_BATCH){
                vehicleList.add(vs);
            }else{
                if(Vehicle__c.SObjectType.getDescribe().isCreateable() == false && Vehicle__c.SObjectType.getDescribe().isUpdateable() == false &&  Vehicle__c.SObjectType.getDescribe().isAccessible() == false ) {
                    throw new DmlException('No permissions to insert.');
                }else{
                    Database.upsert(vs);
                } 
            }
        } catch (DmlException dmle) {
            system.debug('Failed to upsert vehicle record , error is: ' + dmle.getMessage() );
        }
        
        List<Insurance_Policy__c> oldPolicy = [Select Id from Insurance_Policy__c where Vehicle_Ownership__c =: VEH_OWNER_ID AND Active__c = true WITH SECURITY_ENFORCED order by CreatedDate desc LIMIT 1];
        Insurance_Policy__c policy = new Insurance_Policy__c();
        if(oldPolicy.size() > 0){
             policy.Id = oldPolicy[0].Id; 
        }
       
        policy.Vehicle__c = vs.Id;
        policy.Vehicle_Ownership__c = VEH_OWNER_ID;
        policy.Active__c = true;
        policy.Created_From__c = 'Finology';
        try {
            if(Is_BATCH){
                policyList.add(policy);
            }else{
                if(Insurance_Policy__c.SObjectType.getDescribe().isCreateable() == false && Insurance_Policy__c.SObjectType.getDescribe().isUpdateable() == false && Insurance_Policy__c.SObjectType.getDescribe().isAccessible() == false ) {
                    throw new DmlException('No permissions to insert.');
                }else{
                    Database.upsert(policy);
                }  
            }
        } catch (DmlException dmle) {
            system.debug('Failed to insert fileToUpload, error is: ' + dmle.getMessage() );
        }
		finally {
			System.debug('finally: upsertInsurancePolicy() : response : '+JSON.serialize(response)+' detail : '+JSON.serialize(detail));
		}
    }
    
    public class PayloadRequest {
        public String ref_code;
        public String request_date_time;
        public String hash_code;
        public String vehicle_registration_no;
        public String id_type;
        public String identification_no;
        public String postcode;   
    }
    
    public class GetResponse{
        public Integer code;
        public String message;
        public String ref_code;
        public String vix_transaction_code;
        public Response response;
        
    }
    
    public class Response {
        public Vehicle_details vehicle_details;
        public Ncd_details ncd_details;
    }
    
    public class Ncd_details {
        public String next_ncd_percent;
        public String current_ncd_expiry_date;
    }
    
    public class Vehicle_details {
        public String vehicle_registration_no;
        public String chassis_no;
        public String engine_no;
        public String nvic_code;
        public String vehicle_cc;
        public String vehicle_make;
        public String vehicle_model;
        public String vehicle_model_code;
        public String vehicle_make_year;
        public String ism_insured_value;
        public String vehicle_class;
        public String vehicle_seat;
        public String vehicle_transmission_type;
        public String vehicle_use;
        public String market_value;
        public String vehicle_fuel_type;
        public String vehicle_build_type;
    }
    
    public class ErrorResponse{  
        public Integer code;
        public Errors errors;
    }
    public class Errors {
        public String message;
        public String error_code;
        public Detail detail;
    }
    
    public class Detail {
        public Vehicle_details vehicle_details;
        public Ncd_details ncd_details;
    }
}