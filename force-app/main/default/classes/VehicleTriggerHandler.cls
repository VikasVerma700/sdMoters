public without sharing class VehicleTriggerHandler extends TriggerBase{
    public static final String TRIG_SETTING = 'Vehicle';
    public static final String EVENT_NAME = 'VEHICLE';
    public static set<Id> dmsVehicleIds = new Set<Id>();
    public VehicleTriggerHandler() {
        super(TRIG_SETTING);
    }

    public static String joinKeys(List<String> keyList){
		String key = String.join(keyList,'_').toUpperCase();
		return key;
	}

    public static boolean isPersonVehicle(Vehicle__c vehicle){
        return Util.isPersonEntity(vehicle.DmsCustomerType__c, vehicle.DmsDocumentNumber__c, vehicle.DmsCustomerName__c);
    }

    public override void afterInsert(Map<Id, SObject> triggerNew){
        List<Vehicle__c> createOwnershipVehicleList = new List<Vehicle__c>();
        Set<Id> altDriverRevisionVehicleIdSet = new Set<Id>();
        for(Vehicle__c vehicle: (List<Vehicle__c>)(triggerNew.values())){
            if(vehicle.Company__c == CompanyRepository.name2Company.get(CompanyRepository.C099).Id){
                if(vehicle.DmsCustomerNumber__c != '0'){
                    createOwnershipVehicleList.add(vehicle);
                }
                altDriverRevisionVehicleIdSet.add(vehicle.Id);
            }
        }
        createOwnership(createOwnershipVehicleList);
        AltDriverRepository.reviseAltDrivers(altDriverRevisionVehicleIdSet);
    }

    public override void afterUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {

        List<Vehicle__c> updateOwnershipVehicleList = new List<Vehicle__c>();
        List<Vehicle__c> deactivateOwnershipVehicleList = new List<Vehicle__c>();
        Set<Id> altDriverRevisionVehicleIdSet = new Set<Id>();
        for(Id vehicleId: triggerNew.keySet()){
            Vehicle__c vehicleNew = (Vehicle__c)triggerNew.get(vehicleId);
            Vehicle__c vehicleOld = (Vehicle__c)triggerOld.get(vehicleId);
            if(vehicleNew.Company__c == CompanyRepository.name2Company.get(CompanyRepository.C099).Id){
                Boolean regNumChanged = vehicleOld.Registration_Number__c != vehicleNew.Registration_Number__c;
                Boolean custNumChanged = vehicleOld.DmsCustomerNumber__c != vehicleNew.DmsCustomerNumber__c;
                Boolean custPresent = vehicleNew.DmsCustomerNumber__c != '0';
                //reselling cases
                if((regNumChanged || custNumChanged) && custPresent){
                    updateOwnershipVehicleList.add(vehicleNew);
                    altDriverRevisionVehicleIdSet.add(vehicleId);
                }
                //re-acquiring cases
                if((regNumChanged || custNumChanged) && !custPresent){
                    deactivateOwnershipVehicleList.add(vehicleNew);
                    altDriverRevisionVehicleIdSet.add(vehicleId);
                }
            }
        }
        if(updateOwnershipVehicleList.size()>0){
            deactivateOwnership(updateOwnershipVehicleList);//update vo
            createOwnership(updateOwnershipVehicleList);
        }
        if(deactivateOwnershipVehicleList.size()>0){
            deactivateOwnership(deactivateOwnershipVehicleList);
        }
        AltDriverRepository.reviseAltDrivers(altDriverRevisionVehicleIdSet);
        
        // Publish DMS platform  Events
        Set<Id> vehicleIdSet = new Set<Id> ();
        for(Vehicle__c vehicle : (List<Vehicle__c>) triggerNew.values()){
            vehicleIdSet.add(vehicle.Id);
        }
        system.debug('dmsVehicleIds :'+dmsVehicleIds);
        if(!vehicleIdSet.isEmpty()){
            publishPlatformEvent(vehicleIdSet);
            dmsVehicleIds = new Set<Id>();
        }

    }

    public static void publishPlatformEvent(Set<Id> vehicleIds){
        String cmpCode = CompanyRepository.C099 ;
        Map<String, Map<String, List<String>>> entityWithRecordIdMap = new Map<String, Map<String, List<String>>>();
        Map<String, List<String>> companyCodeWithVehicleMap = new Map<String, List<String>>();
	    for(Vehicle__c vehicle : [Select Id, Vehicle_Make__r.Company__r.Name from Vehicle__c where  Vehicle_Make__r.Company__r.Name != null AND Id IN : vehicleIds]){
            if(dmsVehicleIds.contains(vehicle.Id)){
                if(companyCodeWithVehicleMap.containsKey(CompanyRepository.getRelatedCompanyCode(vehicle.Vehicle_Make__r.Company__r.Name) ) ){
                    companyCodeWithVehicleMap.get(vehicle.Vehicle_Make__r.Company__r.Name).add(vehicle.Id);
                } else {
                    companyCodeWithVehicleMap.put(CompanyRepository.getRelatedCompanyCode(vehicle.Vehicle_Make__r.Company__r.Name), new List<String>{vehicle.Id});
                }
            }else{
                if(companyCodeWithVehicleMap.containsKey(vehicle.Vehicle_Make__r.Company__r.Name)){
                    companyCodeWithVehicleMap.get(vehicle.Vehicle_Make__r.Company__r.Name).add(vehicle.Id);
                } else {
                    companyCodeWithVehicleMap.put(vehicle.Vehicle_Make__r.Company__r.Name, new List<String>{vehicle.Id});
                }

                if(companyCodeWithVehicleMap.containsKey(CompanyRepository.getRelatedCompanyCode(vehicle.Vehicle_Make__r.Company__r.Name) ) ){
                    companyCodeWithVehicleMap.get(vehicle.Vehicle_Make__r.Company__r.Name).add(vehicle.Id);
                } else {
                    companyCodeWithVehicleMap.put(CompanyRepository.getRelatedCompanyCode(vehicle.Vehicle_Make__r.Company__r.Name), new List<String>{vehicle.Id});
                }  
            }
	    } 
        entityWithRecordIdMap.put(EVENT_NAME, companyCodeWithVehicleMap);
        DmsCallbackTriggerHandler handler = new DmsCallbackTriggerHandler(EVENT_NAME, entityWithRecordIdMap);
        handler.publishEvent(); 
    }

    public static void deactivateOwnership(List<Vehicle__c> vehicleList){
        System.debug(vehicleList);

        Set<String> regNumSet = new Set<String>();
        Set<Id> vehicleIdSet = new Set<Id>();
        for(Vehicle__c vehicle: vehicleList){
            u.add(regNumSet, vehicle.Registration_Number__c);
            vehicleIdSet.add(vehicle.Id);
        }
        List<Vehicle_Ownership__c> vehOwnershipList = [
            SELECT Id,Customer__c, Registration_No__c,Vehicle__c
            FROM Vehicle_Ownership__c
            WHERE End_Date__c = null
                AND (
                    Vehicle__c IN :vehicleIdSet
                    OR Registration_No__c IN :regNumSet
                )
        ];
        System.debug(vehicleIdSet);
        System.debug(vehOwnershipList);
        for(Vehicle_Ownership__c vehOwnership: vehOwnershipList){
            System.debug(vehicleList);
            vehOwnership.End_Date__c = Date.today();
        }
        update vehOwnershipList;
    }

    public static void createOwnership(List<Vehicle__c> vehicleList){
        String companyCode;
        List<Vehicle_Ownership__c> vehOwnershipList = new List<Vehicle_Ownership__c>();
        Set<String> custNumSet = new Set<String>();
        Set<String> custPinSet = new Set<String>();
        Set<String> docNumSet = new Set<String>();
        for(Vehicle__c vehicle: vehicleList){
            u.add(custNumSet,vehicle.DmsCustomerNumber__c);
            u.add(custPinSet,vehicle.DmsCustomerPin__c);
            u.add(docNumSet, vehicle.DmsDocumentNumber__c);
            companyCode = CompanyRepository.id2Company.get(vehicle.Company__c).DmsCompanyCode__c;
        }

        List<ExternalSystemAccount__c> esaList = [
            SELECT Id, DocumentNumber__c, CustomerNumber__c, GdmsPin__c, PreferredName__c,Account__c,
                FullName__c,CustomerType__c
            FROM ExternalSystemAccount__c
            WHERE CompanyCode__c = :companyCode
                AND (GdmsPin__c IN :custPinSet
                    OR DocumentNumber__c IN :docNumSet
                    OR CustomerNumber__c IN :custPinSet
                    OR CustomerNumber__c IN :custNumSet
                )
                AND Account__c != null
        ];
        ExtSysAccountLookup esaLkp = new ExtSysAccountLookup(esaList);
        System.debug(vehicleList.size());
        for(Vehicle__c vehicle: vehicleList){
            Vehicle_Ownership__c vehicleOwnership = new Vehicle_Ownership__c();
            vehicleOwnership.Start_Date__c = Date.today();
            vehicleOwnership.Vehicle__c = vehicle.Id;
            vehicleOwnership.Customer__c= esaLkp.lookup(vehicle);
            vehicleOwnership.Registration_No__c = vehicle.Registration_Number__c;
            vehicleOwnership.Condition__c = vehicle.Type__c;
            vehicleOwnership.CreatedFrom__c = 'GDMS';
            vehicleOwnership.SellingDealerCode__c = vehicle.SellingDealerCode__c;
            VehicleOwnership.SellingDealer__c = vehicle.SellingDealer__c;
            if(vehicleOwnership.Customer__c !=null){
                List<String> keyList = new List<String>{
                    String.valueOf(vehicleOwnership.Vehicle__c),
                    String.valueOf(vehicleOwnership.Customer__c)
                };
                String uniqueKey = joinKeys(keyList);
                vehicleOwnership.UniqueKey__c = uniqueKey;
                vehOwnershipList.add(vehicleOwnership);
            }
        }
        if(vehOwnershipList.size()>0){
            List<Database.UpsertResult> vehOwnershipUpsertResultList = Database.upsert(vehOwnershipList,Vehicle_Ownership__c.Fields.UniqueKey__c, false);
            ApplicationLogUtility.logUpsertFailure(Util.getClassname(new VehicleTriggerHandler()),vehOwnershipUpsertResultList,ApplicationLogUtility.PRIORITY_HIGH,false);
        }
    }
    
}