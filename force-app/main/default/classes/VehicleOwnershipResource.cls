public with sharing class VehicleOwnershipResource extends Resource{
    /*
    public Set<String> vinSet;
    private Set<String> docNumSet;
    private Set<String> custNumSet;
    public Map<String, Vehicle_Ownership__c> vin2Ownership;
    private List<CareVehOwnership> careVehOwnershipList;
    private Map<String,Vehicle__c> vin2Vehicle;
    private Map<Id,Vehicle__c> id2Vehicle;
    private ExtSysAccountLookup esaLookup;
    private List<Vehicle__c> relatedVehicleList;
    Long lastId;
    public VehicleOwnershipResource(ExternalSystem extSystem){
        super(extSystem);
        this.vin2Ownership = new Map<String,Vehicle_Ownership__c>();
        this.vin2Vehicle = new Map<String,Vehicle__c>();
        this.id2Vehicle = new Map<Id,Vehicle__c>();
        this.vinSet = new Set<String>();
        this.careVehOwnershipList = new List<CareVehOwnership>();
        this.docNumSet = new Set<String>();
        this.custNumSet = new Set<String>();
        this.relatedVehicleList = new List<Vehicle__c>();
    }

    public static List<String> careCompanyCodeList = new List<String>{
        CompanyRepository.C099, CompanyRepository.C001
    };

    private void initMaps(){
        if(this.extSystem.companyName == CompanyRepository.C028){
            for(CareVehOwnership vehOwnership: careVehOwnershipList){
                u.add(this.vinSet,vehOwnership.vehChassisNo);
                u.add(this.docNumSet,vehOwnership.custDocNo);
                u.add(this.custNumSet,String.valueOf(vehOwnership.custNo));
            }
        }

        //prepare vehicle maps
        Set<String> missingVinSet = new Set<String>(this.vinSet);
        List<Vehicle__c> vehicleList = [
            SELECT Id, Name,DmsDocumentNumber__c,DmsCustomerNumber__c,
            DmsCustomerPin__c,DmsCustomerType__c,DmsCustomerName__c,DmsDriverNumber__c,
            DmsDriverPin__c
            FROM Vehicle__c
            WHERE Name IN :this.vinSet
        ];

        for(Vehicle__c vehicle: vehicleList){
            missingVinSet.remove(vehicle.Name);
            this.vin2Vehicle.put(vehicle.Name,vehicle);
            this.id2Vehicle.put(vehicle.Id,vehicle);
        }
        //log missing vehicles
        if(missingVinset.size()>0){
            String message = 'Mssing Vehicles. Unable to create ownership records:\n';
            for(String missingVin: missingVinSet){
                message += missingVin + '\n';
            }

            String stackTrace = 'initMaps()';
            ApplicationLogUtility.insertApexErrorLog(this.className, message, stackTrace);
        }

        //prepare vo maps
        List<Vehicle_Ownership__c> vehOwnershipList = [
            SELECT ID,Start_Date__c,Vehicle__c,Customer__c,Registration_No__c,
                Condition__c,CreatedFrom__c,vehicle__r.Name,vehicle__r.Type__c
            FROM Vehicle_Ownership__c
            WHERE vehicle__r.Name IN :this.vinSet
        ];
        for(Vehicle_Ownership__c vehOwnerhip: vehOwnershipList){
            this.vin2Ownership.put(vehOwnerhip.vehicle__r.Name,vehOwnerhip);
        }

        //prepare esa lookup
        List<ExternalSystemAccount__c> esaList = [
            SELECT Id, DocumentNumber__c, CustomerNumber__c, GdmsPin__c, PreferredName__c,Account__c,
                FullName__c,CustomerType__c
            FROM ExternalSystemAccount__c
            WHERE Account__c != null
                AND (DocumentNumber__c IN :this.docNumSet
                    OR CustomerNumber__c IN :this.custNumSet
                )
        ];
        this.esaLookup = new ExtSysAccountLookup(esaList);
    }

    private Vehicle_Ownership__c prepareOwnership(CareVehOwnership ownershipResponse){
        Vehicle_Ownership__c vehOwnership = this.vin2Ownership.get(ownershipResponse.vehChassisNo);
        Vehicle__c vehicle = this.vin2Vehicle.get(ownershipResponse.vehChassisNo);
        if(vehOwnership == null || vehOwnership.Registration_No__c != ownershipResponse.vehRegNo){
            vehOwnership = new Vehicle_Ownership__c(Vehicle__c = vehicle.Id, Registration_No__c = ownershipResponse.vehRegNo);
        }
        vehicle.DmsDocumentNumber__c = ownershipResponse.custDocNo;
        vehicle.DmsCustomerNumber__c = String.valueOf(ownershipResponse.custNo);
        vehicle.DmsCustomerType__c = String.valueOf(!ownershipResponse.isBusiness);
        vehicle.DmsDriverNumber__c = String.valueOf(ownershipResponse.drvNo);
        this.relatedVehicleList.add(vehicle);
        vehOwnership.Start_Date__c = ownershipResponse.voStartDate.addHours(-8).date();
        vehOwnership.End_Date__c = ownershipResponse.voEndDate.addHours(-8).date();
        vehOwnership.Condition__c = vehicle.Type__c;
        vehOwnership.CreatedFrom__c = ownershipResponse.source;
        vehOwnership.Customer__c = this.esaLookup.lookup(ownershipResponse);
        return vehOwnership;
    }

    private void upsertVehOwnerships(){
        List<Vehicle_Ownership__c> vehOwnershipList = new List<Vehicle_Ownership__c>();
        if(this.extSystem.companyName == CompanyRepository.C028){
            for(CareVehOwnership vehOwnershipResponse: this.careVehOwnershipList){
                if(vin2Vehicle.containsKey(vehOwnershipResponse.vehChassisNo)){
                    Vehicle_Ownership__c vehOwnership = prepareOwnership(vehOwnershipResponse);
                    vehOwnershipList.add(vehOwnership);
                }
            }
        }
        if(vehOwnershipList.size()> 0){
            List<Database.UpsertResult> ownershipUpsertResultList;
            ownershipUpsertResultList = Database.upsert(vehOwnershipList,false);
            ApplicationLogUtility.logUpsertFailure(this.className,ownershipUpsertResultList,ApplicationLogUtility.PRIORITY_HIGH,false);
            if(this.extSystem.companyName == CompanyRepository.C028){
                /*
                Set<Id> vehicleIdSet = new Set<Id>();
                Set<Id> vehOwnershipSet = new Set<Id>();
                for(Database.UpsertResult ownershipUpsertResult: ownershipUpsertResultList){
                    if(ownershipUpsertResult.isSuccess()){
                        vehOwnershipSet.add(ownershipUpsertResult.getId());
                    }
                }
                for(Vehicle_Ownership__c vehOwnership: vehOwnershipList){
                    if(vehOwnershipIdList.contains(vehOwnership.Id)){
                        vehicleIdSet.add(vehOwnership.Vehicle__c);
                    }
                }
                //shorter comment ended here
                List<Database.UpsertResult> vehicleUpsertResultList;
                ownershipUpsertResultList = Database.upsert(this.relatedVehicleList,false);
                ApplicationLogUtility.logUpsertFailure(this.className,vehicleUpsertResultList,ApplicationLogUtility.PRIORITY_HIGH,false);
            }
        }
    }

    public void execute(QueueableContext qContext){
        if(this.extSystem.companyName == CompanyRepository.C028){
            try{
                Http http = new Http();
		        HttpRequest hreq = new HttpRequest();
		        hreq.setEndpoint(SQL_API_Base.ENDPOINT + 'v3/vo/list');
		        hreq.setMethod('POST');
		        hreq.setHeader('Content-Type', 'application/json');
		        CareRequestParam req = new CareRequestParam();
		        req.Company = careCompanyCodeList;
                req.UserName = careUsername;
		        req.Password = carePassword;
		        req.DateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
		        req.DateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
                req.VehOwnId = null;
                req.CustomerNo = null;
                req.VehNo = null;
                req.ChassisNo = null;
                req.LastId = this.lastId;
                req.RowCount = 50;
                hreq.setBody(JSON.serialize(req, false));
                hreq.setTimeout(120000);
		        HttpResponse hres;
                if(!Test.isRunningTest()){
                    hres = http.send(hreq);
                    this.careVehOwnershipList = (List<CareVehOwnership>) JSON.deserialize(hres.getBody(), List<CareVehOwnership>.class);
                    this.lastId = this.careVehOwnershipList[-1].vehOwnId;
                }

                this.initMaps();
                this.upsertVehOwnerships();
            }            
            catch(CalloutException e){
                ApplicationLogUtility.insertCalloutErrorLog(this, e,ApplicationLogUtility.PRIORITY_HIGH,false);
            }
            catch(Exception e){
                ApplicationLogUtility.insertApexErrorLog(this, e, ApplicationLogUtility.PRIORITY_HIGH,false);
            }
        }
    }

    public class CareRequestParam extends SQL_API_Base.CareReq {
		public long[] VehOwnId;
		public long[] CustomerNo;
		public long[] DocumentNo;
		public long[] VehNo;
		public string[] ChassisNo;
		public string[] RegistrationNo;
		public long LastId;
		public long RowCount;
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
    */
}