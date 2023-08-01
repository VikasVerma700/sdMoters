public with sharing class VehicleOwnershipHandler extends TriggerBase {
  public static final String TRIG_SETTING = 'Vehicle Ownership';
  public static final String EVENT_NAME = 'VEHICLE_OWNERSHIP';
  public static set<Id> dmsVehOwnerIds = new Set<Id>();
  public VehicleOwnershipHandler() {
    super(TRIG_SETTING);
  }

  public override void afterInsert(Map<Id, SObject> triggerNew) {
    Set<Id> vOwnerIdSet = new Set<Id>();
    for (
      Vehicle_Ownership__c owner : (List<Vehicle_Ownership__c>) triggerNew.values()
    ) {
      vOwnerIdSet.add(owner.Id);
    }

    if (!vOwnerIdSet.isEmpty()) {
      publishPlatformEvent(vOwnerIdSet);
    }
  }

  public override void afterUpdate(
    Map<Id, SObject> triggerNew,
    Map<Id, SObject> triggerOld
  ) {
    Set<Id> vOwnerIdSet = new Set<Id>();
    for (
      Vehicle_Ownership__c owner : (List<Vehicle_Ownership__c>) triggerNew.values()
    ) {
      Vehicle_Ownership__c ownerOld = (Vehicle_Ownership__c) triggerOld.get(
        owner.Id
      );
      if (owner.End_Date__c != ownerOld.End_Date__c) {
        vOwnerIdSet.add(owner.Id);
      }
    }

    Set<Id> dmsOwnerIds = new Set<Id>();
    for (Id ids : vOwnerIdSet) {
      system.debug('dmsVehOwnerIds :' + dmsVehOwnerIds);
      if (!dmsVehOwnerIds.contains(ids)) {
        dmsOwnerIds.add(ids);
      }
    }

    if (!dmsOwnerIds.isEmpty()) {
      publishPlatformEvent(dmsOwnerIds);
      dmsVehOwnerIds = new Set<Id>();
    }
  }

  public static void publishPlatformEvent(Set<Id> ownerIds) {
    Map<String, Map<String, List<String>>> entityWithRecordIdMap = new Map<String, Map<String, List<String>>>();
    Map<String, List<String>> companyCodeWithVehicleMap = new Map<String, List<String>>();
    for (Vehicle_Ownership__c owner : [
      SELECT Id, Vehicle__r.Vehicle_Make__r.Company__r.DmsCompanyCode__c
      FROM Vehicle_Ownership__c
      WHERE
        Vehicle__r.Vehicle_Make__r.Company__r.DmsCompanyCode__c != NULL
        AND Id IN :ownerIds
    ]) {
      if (
        companyCodeWithVehicleMap.containsKey(
          owner.Vehicle__r.Vehicle_Make__r.Company__r.DmsCompanyCode__c
        )
      ) {
        companyCodeWithVehicleMap.get(
            owner.Vehicle__r.Vehicle_Make__r.Company__r.DmsCompanyCode__c
          )
          .add(owner.Id);
      } else {
        companyCodeWithVehicleMap.put(
          owner.Vehicle__r.Vehicle_Make__r.Company__r.DmsCompanyCode__c,
          new List<String>{ owner.Id }
        );
      }
    }
    entityWithRecordIdMap.put(EVENT_NAME, companyCodeWithVehicleMap);
    DmsCallbackTriggerHandler handler = new DmsCallbackTriggerHandler(
      EVENT_NAME,
      entityWithRecordIdMap
    );
    handler.publishEvent();
  }
}
