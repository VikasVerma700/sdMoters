/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 07-19-2023
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class VehicleResource extends Resource implements Database.AllowsCallouts, Queueable {
  public List<CustomerVehicleService.Vehicle> gdmsVehicleList;
  public List<CareService.VehicleResponse> careVehicleList;

  public String lastRowId;

  Set<String> makeNameSet;
  Set<String> missingMakeNameSet;
  Map<String, Vehicle_Make__c> name2make;

  Set<String> modelKeySet;
  Set<String> modelNameSet;
  Set<String> missingModelNameSet;
  Set<String> missingModelKeySet;
  Map<String, Vehicle_Model__c> key2Model; //  Vehicle_Model__c.Vehicle_Make__c.Name + Vehicle_Model__c.Name

  Set<String> modelRangeNameSet;
  Set<String> missingModelRangeNameSet;
  Set<String> missingModelRangeKeySet;
  Map<String, Vehicle_Model_Range__c> key2ModelRange; //Vehicle_Model_Range__c.Name

  Set<String> variantNameSet;
  Set<String> missingVariantNameSet;
  Set<String> variantKeySet;
  Set<String> missingVariantKeySet;
  Map<String, VehicleVariant__c> name2Variant; // VehicleVariant__c.Make__c.Name + VehicleVariant__c.Model__c.Name + VehicleVariant__c.Name

  Set<String> colourNameSet;
  Set<String> missingColourNameSet;
  Set<String> missingColourKeySet;
  Map<String, Vehicle_Colour__c> name2Colour; // Vehicle_Colour__c.Name

  Set<String> trimNameSet;
  Set<String> missingTrimNameSet;
  Set<String> missingTrimKeySet;
  Map<String, Vehicle_Trim__c> name2Trim; // Vehicle_Trim__c.Name

  Set<String> typeNameSet;
  Set<String> missingTypeNameSet;
  Map<String, Vehicle_Type__c> name2Type; // Vehicle_Type__c.Name

  Set<Long> numberSet;
  Map<Long, Vehicle__c> number2Vehicle; // Vehicle__c.Vehicle_Number__c

  Set<String> vinSet;
  Map<String, Vehicle__c> name2Vehicle;

  Set<String> workshopNameSet;
  WorkshopLookup workshopLkp;

  public static String joinKeys(List<String> keyList) {
    if (keyList.size() == 1) {
      return keyList[0];
    }
    String key = String.join(keyList, '_').toUpperCase();
    return key;
  }

  public static List<Database.UpsertResult> prepareVehicle(
    List<CustomerVehicleService.Vehicle> vehicleResponeList
  ) {
    String companyCode = vehicleResponeList[0].CompanyCode; //company code must be common in all vehicles
    ExternalSystem responseExtSystem = new ExternalSystem(companyCode);

    VehicleResource vehResource = new VehicleResource();
    vehResource.setExternalSystem(responseExtSystem);
    vehResource.gdmsVehicleList = vehicleResponeList;
    vehResource.initMaps();
    List<Database.UpsertResult> vehUpsertResultList = vehResource.upsertVehicles();
    return vehUpsertResultList;
  }

  public VehicleResource() {
    this.gdmsVehicleList = new List<CustomerVehicleService.Vehicle>();
    this.careVehicleList = new List<CareService.VehicleResponse>();
    this.makeNameSet = new Set<String>();
    this.modelNameSet = new Set<String>();
    this.modelRangeNameSet = new Set<String>();
    this.colourNameSet = new Set<String>();
    this.variantNameSet = new Set<String>();
    this.variantKeySet = new Set<String>();
    this.trimNameSet = new Set<String>();
    this.typeNameSet = new Set<String>();
    this.numberSet = new Set<Long>();
    this.vinSet = new Set<String>();
    this.workshopNameSet = new Set<String>();
  }

  private Vehicle__c prepareVehicle(
    CustomerVehicleService.Vehicle vehicleResponse
  ) {
    List<String> keyList;
    Vehicle__c vehicle = this.name2Vehicle.get(vehicleResponse.ChassisNumber);
    if (vehicle == null) {
      vehicle = new Vehicle__c(
        Name = vehicleResponse.ChassisNumber,
        Full_Chassis__c = vehicleResponse.ChassisNumber
      );
    }
    try {
      if (
        vehicle.Company__c == null ||
        CompanyRepository.id2Company.get(vehicle.Company__c).Name ==
        this.extSystem.companyName
      ) {
        vehicle.Company__c = CompanyRepository.name2Company.get(
            vehicleResponse.CompanyCode
          )
          .Id;
        String vehicleType = 'N';
        if (vehicleResponse.VehicleType != null) {
          if (
            vehicleResponse.VehicleType.indexOf('u') != -1 ||
            vehicleResponse.VehicleType.indexOf('U') != -1
          ) {
            vehicleType = 'U';
          }
        }
        vehicle.Vehicle_Type__c = this.name2Type.get(vehicleType).Id;
        vehicle.Type__c = vehicleType;
        keyList = new List<String>{ vehicleResponse.Make };
        vehicle.Vehicle_make__c = this.name2make.get(joinKeys(keyList)).Id;
        keyList = new List<String>{
          vehicleResponse.Make,
          vehicleResponse.ModelRange,
          vehicleResponse.Model
        };
        vehicle.Vehicle_Model__c = this.key2Model.get(joinKeys(keyList)).Id;
        keyList = new List<String>{
          vehicleResponse.Make,
          vehicleResponse.Model,
          vehicleResponse.Variant
        };
        vehicle.VehicleVariant__c = this.name2Variant.get(joinKeys(keyList)).Id;
        try {
          keyList = new List<String>{
            vehicleResponse.Make,
            vehicleResponse.Trims
          };
          vehicle.Vehicle_Trim__c = this.name2Trim.get(joinKeys(keyList)).Id;
        } catch (Exception trimException) {
          String message = trimException.getMessage() + '\n';
          message += joinKeys(keyList);
          trimException.setMessage(message);
          ApplicationLogUtility.insertApexErrorLog(
            this.jobName,
            trimException,
            ApplicationLogUtility.PRIORITY_LOW,
            false
          );
        }

        try {
          keyList = new List<String>{
            vehicleResponse.Make,
            vehicleResponse.ColourName
          };
          vehicle.Vehicle_Colour__c = this.name2Colour.get(joinKeys(keyList))
            .Id;
        } catch (Exception colourException) {
          String message = colourException.getMessage() + '\n';
          message += joinKeys(keyList);
          colourException.setMessage(message);
          ApplicationLogUtility.insertApexErrorLog(
            this.jobName,
            colourException,
            ApplicationLogUtility.PRIORITY_LOW,
            false
          );
        }
        vehicle.Stock_Number__c = vehicleResponse.StockNo;
        vehicle.Engine_Number__c = vehicleResponse.EngineNumber;
        if (String.isNotBlank(vehicleResponse.EngineCapacity)) {
          vehicle.EngineCapacity__c = Integer.valueOf(
            vehicleResponse.EngineCapacity.replace(',', '')
          );
        }
        vehicle.SellingDealer__c = vehicleResponse.SellingDealerName;
        vehicle.SellingDealerCode__c = vehicleResponse.SellingDealerCode;
        /*
                vehicle.Production_Date__c = vehicleResponse.ProductionDate;
                String productionDate = String.valueOf(vehicleResponse.ProductionDate);
                if(productionDate.length()==6){
                    vehicle.Production_Year__c = productionDate.substring(0,4);
                    vehicle.Production_Month__c = productionDate.substring(4,6);
                }
                */
        vehicle.Production_Month__c = String.valueOf(
          vehicleResponse.ProductionMonth
        );
        vehicle.Production_Year__c = String.valueOf(
          vehicleResponse.ProductionYear
        );
        vehicle.Warranty_Expiry_Date__c = vehicleResponse.WarrantyValidity;
        vehicle.Extended_Warranty_Date__c = vehicleResponse.ExtendedWarrantyValidity;
        vehicle.DmsDocumentNumber__c = vehicleResponse.SSN;
        vehicle.DmsCustomerNumber__c = String.valueOf(
          vehicleResponse.CustomerNo
        );
        vehicle.DmsCustomerPin__c = vehicleResponse.CustomerPIN;
        vehicle.DmsCustomerType__c = vehicleResponse.CustomerType;
        vehicle.DmsCustomerName__c = vehicleResponse.CustomerName;
        vehicle.DmsDriverNumber__c = String.valueOf(vehicleResponse.DriverID);
        vehicle.DmsDriverPin__c = vehicleResponse.DriverPIN;
        vehicle.Registration_Date__c = vehicleResponse.RegistrationDate;
        vehicle.Registration_Number__c = vehicleResponse.RegistrationNumber;
        //vehicle.Status__c = String.valueOf(vehicleResponse.Stat_x);
        //vehicle.Status__c = vehicleResponse.Stat;
        vehicle.Running_Mileage__c = vehicleResponse.Mileage;
        vehicle.VSB_Reference_Company__c = vehicleResponse.SellingDealerCode;
        vehicle.Fuel__c = vehicleResponse.Fuel;
        vehicle.CreatedFrom__c = ExternalSystem.Type.GDMS.name();
        return vehicle;
      } else {
        return null;
      }
    } catch (Exception prepareException) {
      System.debug(prepareException);
      System.debug(prepareException.getStackTraceString());
      String message = prepareException.getMessage() + '\n';
      if (keyList != null) {
        message += joinKeys(keyList);
      }

      prepareException.setMessage(message);
      ApplicationLogUtility.insertApexErrorLog(
        this.jobName,
        prepareException,
        ApplicationLogUtility.PRIORITY_MEDIUM,
        false
      );
    }
    return null;
  }

  private Vehicle__c prepareVehicle(
    CareService.VehicleResponse vehicleResponse
  ) {
    List<String> keyList;
    try {
      Vehicle__c vehicle = this.name2Vehicle.get(vehicleResponse.chassis);
      if (vehicle == null) {
        vehicle = new Vehicle__c(Name = vehicleResponse.chassis);
      }
      vehicle.Company__c = CompanyRepository.name2Company.get(
          vehicleResponse.companyCode
        )
        .Id;
      String vehicleType = 'N';
      if (String.isNotBlank(vehicleResponse.vehType)) {
        if (
          vehicleResponse.vehType.indexOf('u') != -1 ||
          vehicleResponse.vehType.indexOf('U') != -1
        ) {
          vehicleType = 'U';
        }
      }
      vehicle.Vehicle_Type__c = this.name2Type.get(vehicleType).Id;
      vehicle.Type__c = vehicleType;
      keyList = new List<String>{ vehicleResponse.vehMake };
      vehicle.Vehicle_make__c = this.name2make.get(joinKeys(keyList)).Id;
      keyList = new List<String>{
        vehicleResponse.vehMake,
        vehicleResponse.vehModelRange,
        vehicleResponse.vehModelCode
      };
      vehicle.Vehicle_Model__c = this.key2Model.get(joinKeys(keyList)).Id;
      keyList = new List<String>{
        vehicleResponse.vehMake,
        vehicleResponse.vehModelCode,
        vehicleResponse.vehVariantCode
      };
      vehicle.VehicleVariant__c = this.name2Variant.get(joinKeys(keyList)).Id;
      try {
        keyList = new List<String>{
          vehicleResponse.vehMake,
          vehicleResponse.vehTrim
        };
        vehicle.Vehicle_Trim__c = this.name2Trim.get(joinKeys(keyList)).Id;
      } catch (Exception trimException) {
        String message = trimException.getMessage() + '\n';
        message += joinKeys(keyList);
        trimException.setMessage(message);
        ApplicationLogUtility.insertApexErrorLog(
          this.jobName,
          trimException,
          ApplicationLogUtility.PRIORITY_LOW,
          false
        );
      }

      try {
        keyList = new List<String>{
          vehicleResponse.vehMake,
          vehicleResponse.vehColor
        };
        vehicle.Vehicle_Colour__c = this.name2Colour.get(joinKeys(keyList)).Id;
      } catch (Exception colourException) {
        String message = colourException.getMessage() + '\n';
        message += joinKeys(keyList);
        colourException.setMessage(message);
        ApplicationLogUtility.insertApexErrorLog(
          this.jobName,
          colourException,
          ApplicationLogUtility.PRIORITY_LOW,
          false
        );
      }
      vehicle.Stock_Number__c = null;
      vehicle.Engine_Number__c = vehicleResponse.engineNum;
      vehicle.EngineCapacity__c = vehicleResponse.engineCap;
      vehicle.SellingDealer__c = vehicleResponse.sellingDealer;
      //vehicle.Production_Date__c = vehicleResponse.productionDate.addHours(-8).date();
      vehicle.Production_Year__c = vehicleResponse.productionYear;
      vehicle.Production_Month__c = vehicleResponse.productionMonth;
      vehicle.Warranty_Expiry_Date__c = vehicleResponse.warrantyExDate.addHours(
          -8
        )
        .date();
      vehicle.Extended_Warranty_Date__c = vehicleResponse.extendedWarrantyDate.addHours(
          -8
        )
        .date();
      /*
            vehicle.DmsDocumentNumber__c = null;
            vehicle.DmsCustomerNumber__c = null;
            vehicle.DmsCustomerPin__c = null;
            vehicle.DmsCustomerType__c = null;
            vehicle.DmsCustomerName__c = null;
            vehicle.DmsDriverNumber__c = null;
            vehicle.DmsDriverPin__c = null;
            vehicle.Status__c =null;
            */
      vehicle.Registration_Date__c = vehicleResponse.regDate.addHours(-8)
        .date();
      vehicle.Registration_Number__c = vehicleResponse.regNum;
      vehicle.Running_Mileage__c = vehicleResponse.mileage;
      vehicle.VSB_Reference_Company__c = vehicleResponse.vsbRefCmp;
      vehicle.CreatedFrom__c = vehicleResponse.source;
      return vehicle;
    } catch (Exception prepareException) {
      System.debug(prepareException);
      System.debug(prepareException.getStackTraceString());
      String message = prepareException.getMessage() + '\n';
      message += joinKeys(keyList);
      prepareException.setMessage(message);
      ApplicationLogUtility.insertApexErrorLog(
        this.jobName,
        prepareException,
        ApplicationLogUtility.PRIORITY_MEDIUM,
        false
      );
    }
    return null;
  }

  private List<Database.UpsertResult> upsertVehicles() {
    List<Vehicle__c> vehicleList = new List<Vehicle__c>();
    if (
      CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(
          ExternalSystem.Type.GDMS
        )
        .contains(this.extSystem.companyName)
    ) {
      for (CustomerVehicleService.Vehicle vehicle : this.gdmsVehicleList) {
        u.add(vehicleList, prepareVehicle(vehicle));
      }
    }

    if (this.extSystem.companyName == CompanyRepository.C028) {
      for (CareService.VehicleResponse vehicle : this.careVehicleList) {
        u.add(vehicleList, prepareVehicle(vehicle));
      }
    }

    if (vehicleList.size() > 0) {
      List<Database.UpsertResult> vehicleUpsertResultList = new List<Database.UpsertResult>();
      vehicleUpsertResultList = Database.upsert(vehicleList, false);
      for (
        Database.UpsertResult vehicleUpsertResult : vehicleUpsertResultList
      ) {
        if (!vehicleUpsertResult.isSuccess()) {
          for (Database.Error dbError : vehicleUpsertResult.getErrors()) {
            ApplicationLogUtility.insertApexErrorLog(
              this,
              dbError,
              ApplicationLogUtility.PRIORITY_LOW,
              false
            );
          }
        }
      }
      return vehicleUpsertResultList;
    }
    return null;
  }

  public void initMaps() {
    Id companyId = CompanyRepository.name2Company.get(
        this.extSystem.companyName
      )
      .Id;
    List<String> keyList;

    if (
      CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(
          ExternalSystem.Type.GDMS
        )
        .contains(this.extSystem.companyName)
    ) {
      for (CustomerVehicleService.Vehicle vehicle : this.gdmsVehicleList) {
        String temp = '';
        //exchange values for colour name and colour code
        temp = vehicle.ColourName;
        vehicle.ColourName = vehicle.ColourCode;
        vehicle.ColourCode = temp;

        //put model range in response as model's name
        //!TODO what to do for model range?
        //following is strange but..
        temp = vehicle.Model;
        vehicle.Model = vehicle.ModelRange;
        vehicle.ModelDesc = vehicle.ModelRangeDesc;
        vehicle.ModelRange = vehicle.ModelRangeDesc;

        u.add(this.makeNameSet, vehicle.Make);
        u.add(this.modelNameSet, vehicle.Model);
        u.add(this.modelRangeNameSet, vehicle.ModelRange);
        u.add(this.variantNameSet, vehicle.Variant);
        u.add(this.trimNameSet, vehicle.Trims);
        u.add(this.colourNameSet, vehicle.ColourName);
        u.add(this.typeNameSet, vehicle.VehicleType);
        u.add(this.vinSet, vehicle.ChassisNumber);
        u.add(this.workshopNameSet, vehicle.Workshop.trim().toUpperCase());
      }
    }

    if (this.extSystem.companyName == CompanyRepository.C028) {
      for (CareService.VehicleResponse vehicle : this.careVehicleList) {
        u.add(this.makeNameSet, vehicle.vehMake.toUpperCase());
        u.add(this.modelNameSet, vehicle.vehModelCode);
        u.add(this.modelRangeNameSet, vehicle.vehModelRange);
        u.add(this.variantNameSet, vehicle.vehVariantCode);
        u.add(this.trimNameSet, vehicle.vehTrim);
        u.add(this.colourNameSet, vehicle.vehColor);
        u.add(this.typeNameSet, vehicle.vehType);
        u.add(this.vinSet, vehicle.chassis);
      }
    }

    //prepare Make Map
    this.name2make = new Map<String, Vehicle_Make__c>();
    this.missingMakeNameSet = new Set<String>(this.makeNameSet);
    for (Vehicle_Make__c make : [
      SELECT Id, Name, Description__c, Company__r.DmsCompanyCode__c, Key__c
      FROM Vehicle_Make__c
      WHERE Name IN :this.makeNameSet
    ]) {
      this.missingMakeNameSet.remove(make.Name.toUpperCase());
      keyList = new List<String>{ make.Name.toUpperCase() };
      this.name2make.put(joinKeys(keyList), make);
    }
    // missing make is not allowed. if make is missing insert make immediately
    if (this.missingMakeNameSet.size() > 0) {
      List<Vehicle_Make__c> missingVehicleMakeList = new List<Vehicle_Make__c>();
      for (String makeName : this.missingMakeNameSet) {
        Vehicle_Make__c vehMake = new Vehicle_Make__c(Name = makeName);
        vehMake.Company__c = companyId;
        vehMake.Description__c = makeName;
        missingVehicleMakeList.add(vehMake);
      }
      //fail if makes are not inserted
      Database.insert(missingVehicleMakeList, true);
      for (Vehicle_Make__c make : [
        SELECT Id, Name, Description__c, Company__r.DmsCompanyCode__c, Key__c
        FROM Vehicle_Make__c
        WHERE Name IN :this.missingMakeNameSet
      ]) {
        keyList = new List<String>{ make.Name };
        this.name2make.put(joinKeys(keyList), make);
        this.missingMakeNameSet.remove(make.Name);
      }
    }

    //prepare range map
    this.key2ModelRange = new Map<String, Vehicle_Model_Range__c>();
    this.missingModelRangeNameSet = new Set<String>(modelRangeNameSet);
    for (Vehicle_Model_Range__c modelRange : [
      SELECT
        Id,
        Name,
        Description__c,
        Company__r.DmsCompanyCode__c,
        Vehicle_Make__r.Name,
        Key__c
      FROM Vehicle_Model_Range__c
      WHERE
        Vehicle_Make__r.Name IN :this.makeNameSet
        AND Name IN :this.modelRangeNameSet
    ]) {
      keyList = new List<String>{
        modelRange.Vehicle_Make__r.Name,
        modelRange.Name
      };
      this.key2ModelRange.put(joinKeys(keyList), modelRange);
      this.missingModelRangeNameSet.remove(modelRange.Name);
    }
    //insert missing range by name
    if (this.missingModelRangeNameSet.size() > 0) {
      List<Vehicle_Model_Range__c> missingModelRangeList = new List<Vehicle_Model_Range__c>();
      this.missingModelRangeKeySet = new Set<String>();
      for (String rangeName : this.missingModelRangeNameSet) {
        Vehicle_Model_Range__c modelRange = new Vehicle_Model_Range__c(
          Name = rangeName
        );
        modelRange.Description__c = rangeName;
        modelRange.Company__c = companyId;
        missingModelRangeList.add(modelRange);
      }
      if (
        CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(
            ExternalSystem.Type.GDMS
          )
          .contains(this.extSystem.companyName)
      ) {
        for (CustomerVehicleService.Vehicle vehicle : this.gdmsVehicleList) {
          if (this.missingModelRangeNameSet.contains(vehicle.ModelRange)) {
            keyList = new List<String>{ vehicle.Make, vehicle.ModelRange };
            String key = joinKeys(keyList);
            if (!this.missingModelRangeKeySet.contains(key)) {
              this.missingModelRangeKeySet.add(key);
              Vehicle_Model_Range__c modelRange = new Vehicle_Model_Range__c(
                Name = vehicle.ModelRange
              );
              modelRange.Description__c = vehicle.ModelRange;
              modelRange.Company__c = companyId;
              keyList = new List<String>{ vehicle.Make };
              modelRange.Vehicle_Make__c = this.name2make.get(joinKeys(keyList))
                .Id;
              missingModelRangeList.add(modelRange);
            }
          }
        }
      }
      if (this.extSystem.companyName == CompanyRepository.C028) {
        for (CareService.VehicleResponse vehicle : this.careVehicleList) {
          if (this.missingModelRangeNameSet.contains(vehicle.vehModelRange)) {
            keyList = new List<String>{
              vehicle.vehMake,
              vehicle.vehModelRange
            };
            String key = joinKeys(keyList);
            if (!this.missingModelRangeKeySet.contains(key)) {
              this.missingModelRangeKeySet.add(key);
              Vehicle_Model_Range__c modelRange = new Vehicle_Model_Range__c(
                Name = vehicle.vehModelRange
              );
              modelRange.Company__c = companyId;
              //keyList = new List<String>{vehicle.vehModelCode};
              modelRange.Vehicle_Make__c = this.name2make.get(vehicle.vehMake)
                .Id;
              missingModelRangeList.add(modelRange);
            }
          }
        }
      }
      //fail if model range is can  not be inserted (important for model to be inserted)
      Database.insert(missingModelRangeList, true);
      for (Vehicle_Model_Range__c modelRange : [
        SELECT
          Id,
          Name,
          Description__c,
          Company__r.DmsCompanyCode__c,
          Vehicle_Make__r.Name
        FROM Vehicle_Model_Range__c
        WHERE
          Name IN :this.missingModelRangeNameSet
          AND Vehicle_Make__r.Name IN :this.makeNameSet
      ]) {
        keyList = new List<String>{
          modelRange.Vehicle_Make__r.Name,
          modelRange.Name
        };
        this.key2ModelRange.put(joinKeys(keyList), modelRange);
        this.missingModelRangeNameSet.remove(modelRange.Name);
      }
    }
    //prepare model map
    this.key2Model = new Map<String, Vehicle_Model__c>();
    this.missingModelNameSet = new Set<String>(this.modelNameSet);
    for (Vehicle_Model__c model : [
      SELECT
        Id,
        Name,
        Description__c,
        Manufacturer_Year_From__c,
        Company__r.DmsCompanyCode__c,
        Vehicle_Make__r.Name,
        Vehicle_Model_Range__r.Name
      FROM Vehicle_Model__c
      WHERE
        Vehicle_Make__r.Name IN :this.makeNameSet
        AND Name IN :this.modelNameSet
        AND Vehicle_Model_Range__r.Name IN :this.modelRangeNameSet
    ]) {
      keyList = new List<String>{
        model.Vehicle_Make__r.Name,
        model.Vehicle_Model_Range__r.Name,
        model.Name
      };
      this.key2Model.put(joinKeys(keyList), model);
      this.missingModelNameSet.remove(model.Name);
    }
    //prepare missing models
    //model will require lookups to company, make and range objects
    if (this.missingModelNameSet.size() > 0) {
      this.missingModelKeySet = new Set<String>();
      List<Vehicle_Model__c> missingModelList = new List<Vehicle_Model__c>();
      // 099
      if (
        CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(
            ExternalSystem.Type.GDMS
          )
          .contains(this.extSystem.companyName)
      ) {
        for (CustomerVehicleService.Vehicle vehicle : this.gdmsVehicleList) {
          if (this.missingModelNameSet.contains(vehicle.Model)) {
            keyList = new List<String>{
              vehicle.Make,
              vehicle.ModelRange,
              vehicle.Model
            };
            if (!this.missingModelKeySet.contains(joinKeys(keyList))) {
              this.missingModelKeySet.add(joinKeys(keyList));
              Vehicle_Model__c vehModel = new Vehicle_Model__c(
                Name = vehicle.Model
              );
              vehModel.Company__c = companyId;
              vehModel.Description__c = vehicle.ModelDesc;
              keyList = new List<String>{ vehicle.Make, vehicle.ModelRange };
              vehModel.Vehicle_Model_Range__c = this.key2ModelRange.get(
                  joinKeys(keyList)
                )
                .Id;
              keyList = new List<String>{ vehicle.Make };
              vehModel.Vehicle_Make__c = this.name2make.get(joinKeys(keyList))
                .Id;
              missingModelList.add(vehModel);
            }
          }
        }
      }

      //028 and 001
      if (this.extSystem.companyName == CompanyRepository.C028) {
        for (CareService.VehicleResponse vehicle : this.careVehicleList) {
          if (this.missingModelNameSet.contains(vehicle.vehModelCode)) {
            keyList = new List<String>{
              vehicle.vehMake,
              vehicle.vehModelRange,
              vehicle.vehModelCode
            };
            String missingModelKey = joinKeys(keyList);
            if (!this.missingModelKeySet.contains(missingModelKey)) {
              this.missingModelKeySet.add(missingModelKey);
              Vehicle_Model__c vehModel = new Vehicle_Model__c(
                Name = vehicle.vehModelCode
              );
              vehModel.Company__c = companyId;
              vehModel.Description__c = vehicle.vehModelDesc;
              keyList = new List<String>{
                vehicle.vehMake,
                vehicle.vehModelRange
              };
              vehModel.Vehicle_Model_Range__c = this.key2ModelRange.get(
                  joinKeys(keyList)
                )
                .Id;
              keyList = new List<String>{ vehicle.vehMake };
              vehModel.Vehicle_Make__c = this.name2make.get(joinKeys(keyList))
                .Id;
              missingModelList.add(vehModel);
            }
          }
        }
      }
      //fail if model is not inserted
      Database.insert(missingModelList, true);
      for (Vehicle_Model__c model : [
        SELECT
          Id,
          Name,
          Description__c,
          Manufacturer_Year_From__c,
          Company__r.DmsCompanyCode__c,
          Vehicle_Make__r.Name,
          Vehicle_Model_Range__r.Name
        FROM Vehicle_Model__c
        WHERE
          Vehicle_Make__r.Name IN :this.makeNameSet
          AND Name IN :this.missingModelNameSet
          AND Vehicle_Model_Range__r.Name IN :this.modelRangeNameSet
      ]) {
        keyList = new List<String>{
          model.Vehicle_Make__r.Name,
          model.Vehicle_Model_Range__r.Name,
          model.Name
        };
        this.key2Model.put(joinKeys(keyList), model);
        this.missingModelNameSet.remove(model.Name);
      }
    }

    //prepare maps for variant
    this.name2Variant = new Map<String, VehicleVariant__c>();
    this.missingVariantNameSet = new Set<String>(this.variantNameSet);
    for (VehicleVariant__c variant : [
      SELECT
        Id,
        Name,
        Company__r.DmsCompanyCode__c,
        Make__r.Name,
        Model__r.Name,
        Key__c
      FROM VehicleVariant__c
      WHERE
        Make__r.Name IN :this.makeNameSet
        AND Model__r.Name IN :this.modelNameSet
        AND Name IN :this.variantNameSet
    ]) {
      keyList = new List<String>{
        variant.Make__r.Name,
        variant.Model__r.Name,
        variant.Name
      };
      String variantKey = joinKeys(keyList);
      this.name2Variant.put(variantKey, variant);
      this.missingVariantNameSet.remove(variant.Name);
    }
    //prepare variants
    //variant will require lookups to make and model objects
    if (this.missingVariantNameSet.size() > 0) {
      this.missingVariantKeySet = new Set<String>();
      List<VehicleVariant__c> missingVariantList = new List<VehicleVariant__c>();
      if (
        CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(
            ExternalSystem.Type.GDMS
          )
          .contains(this.extSystem.companyName)
      ) {
        for (CustomerVehicleService.Vehicle vehicle : this.gdmsVehicleList) {
          if (this.missingVariantNameSet.contains(vehicle.Variant)) {
            keyList = new List<String>{
              vehicle.Make,
              vehicle.Model,
              vehicle.Variant
            };
            if (!this.missingVariantKeySet.contains(joinKeys(keyList))) {
              this.missingVariantKeySet.add(joinKeys(keyList));
              VehicleVariant__c vehVariant = new VehicleVariant__c(
                Name = vehicle.Variant
              );
              vehVariant.Company__c = companyId;
              vehVariant.Description__c = vehicle.VariantDesc;
              keyList = new List<String>{ vehicle.Make };
              vehVariant.Make__c = this.name2make.get(joinKeys(keyList)).Id;
              keyList = new List<String>{
                vehicle.Make,
                vehicle.ModelRange,
                vehicle.Model
              };
              vehVariant.Model__c = this.key2Model.get(joinKeys(keyList)).Id;
              missingVariantList.add(vehVariant);
            }
          }
        }
      }
      if (this.extSystem.companyName == CompanyRepository.C028) {
        for (CareService.VehicleResponse vehicle : this.careVehicleList) {
          if (this.missingVariantNameSet.contains(vehicle.vehVariantCode)) {
            keyList = new List<String>{
              vehicle.vehMake,
              vehicle.vehModelCode,
              vehicle.vehVariantCode
            };
            if (!this.missingVariantKeySet.contains(joinKeys(keyList))) {
              this.missingVariantKeySet.add(joinKeys(keyList));
              VehicleVariant__c vehVariant = new VehicleVariant__c(
                Name = vehicle.vehVariantCode
              );
              vehVariant.Company__c = companyId;
              vehVariant.Description__c = vehicle.vehVariantDesc;
              keyList = new List<String>{ vehicle.vehMake };
              vehVariant.Make__c = this.name2make.get(joinKeys(keyList)).Id;
              keyList = new List<String>{
                vehicle.vehMake,
                vehicle.vehModelRange,
                vehicle.vehModelCode
              };
              vehVariant.Model__c = this.key2Model.get(joinKeys(keyList)).Id;
              missingVariantList.add(vehVariant);
            }
          }
        }
      }
      Database.insert(missingVariantList, false);
      for (VehicleVariant__c variant : [
        SELECT
          Id,
          Name,
          Company__r.DmsCompanyCode__c,
          Make__r.Name,
          Model__r.Name,
          Key__c
        FROM VehicleVariant__c
        WHERE
          Make__r.Name IN :this.makeNameSet
          AND Model__r.Name IN :this.modelNameSet
          AND Name IN :this.missingVariantNameSet
      ]) {
        keyList = new List<String>{
          variant.Make__r.Name,
          variant.Model__r.Name,
          variant.Name
        };
        String variantKey = joinKeys(keyList);
        this.name2Variant.put(variantKey, variant);
        this.missingVariantNameSet.remove(variant.Name);
      }
    }

    //prepare color maps
    this.name2Colour = new Map<String, Vehicle_Colour__c>();
    this.missingColourNameSet = new Set<String>(colourNameSet);
    for (Vehicle_Colour__c colour : [
      SELECT
        Id,
        Name,
        Company__r.DmsCompanyCode__c,
        Vehicle_Make__r.Name,
        Key__c
      FROM Vehicle_Colour__c
      WHERE
        Vehicle_Make__r.Name IN :this.makeNameSet
        AND Name IN :this.colourNameSet
    ]) {
      keyList = new List<String>{ colour.Vehicle_Make__r.Name, colour.Name };
      this.name2Colour.put(joinKeys(keyList), colour);
      this.missingColourNameSet.remove(colour.Name);
    }
    //prepare missing color records
    if (this.missingColourNameSet.size() > 0) {
      this.missingColourKeySet = new Set<String>();
      List<Vehicle_Colour__c> missingColourList = new List<Vehicle_Colour__c>();
      if (
        CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(
            ExternalSystem.Type.GDMS
          )
          .contains(this.extSystem.companyName)
      ) {
        for (CustomerVehicleService.Vehicle vehicle : this.gdmsVehicleList) {
          keyList = new List<String>{ vehicle.Make, vehicle.ColourName };
          String missingColourKey = joinKeys(keyList);
          if (
            this.missingColourNameSet.contains(vehicle.ColourName) &&
            !this.missingColourKeySet.contains(missingColourKey)
          ) {
            Vehicle_Colour__c colour = new Vehicle_Colour__c(
              Name = vehicle.ColourName
            );
            colour.Company__c = companyId;
            colour.Description__c = vehicle.ColourCode;
            keyList = new List<String>{ vehicle.Make };
            colour.Vehicle_Make__c = this.name2make.get(joinKeys(keyList)).Id;
            missingColourList.add(colour);
            missingColourKeySet.add(missingColourKey);
          }
        }
      }
      if (this.extSystem.companyName == CompanyRepository.C028) {
        for (CareService.VehicleResponse vehicle : this.careVehicleList) {
          keyList = new List<String>{ vehicle.vehMake, vehicle.vehColor };
          String missingColourKey = joinKeys(keyList);
          if (
            this.missingColourNameSet.contains(vehicle.vehColor) &&
            !this.missingColourKeySet.contains(missingColourKey)
          ) {
            Vehicle_Colour__c colour = new Vehicle_Colour__c(
              Name = vehicle.vehColor
            );
            colour.Company__c = companyId;
            colour.Description__c = vehicle.vehColorCode;
            keyList = new List<String>{ vehicle.vehMake };
            colour.Vehicle_Make__c = this.name2make.get(joinKeys(keyList)).Id;
            missingColourList.add(colour);
            missingColourKeySet.add(missingColourKey);
          }
        }
      }
      Database.insert(missingColourList, false);
      for (Vehicle_Colour__c colour : [
        SELECT
          Id,
          Name,
          Company__r.DmsCompanyCode__c,
          Vehicle_Make__r.Name,
          Key__c
        FROM Vehicle_Colour__c
        WHERE
          Vehicle_Make__r.Name IN :this.makeNameSet
          AND Name IN :this.missingColourNameSet
      ]) {
        keyList = new List<String>{ colour.Vehicle_Make__r.Name, colour.Name };
        this.name2Colour.put(joinKeys(keyList), colour);
        this.missingColourNameSet.remove(colour.Name);
      }
    }

    //prepare trim maps
    this.name2Trim = new Map<String, Vehicle_Trim__c>();
    this.missingTrimNameSet = new Set<String>(trimNameSet);
    for (Vehicle_Trim__c trim : [
      SELECT
        Id,
        Name,
        Company__r.DmsCompanyCode__c,
        Vehicle_Make__r.Name,
        Key__c
      FROM Vehicle_Trim__c
      WHERE
        Vehicle_Make__r.Name IN :this.makeNameSet
        AND Name IN :this.trimNameSet
    ]) {
      keyList = new List<String>{ trim.Vehicle_Make__r.Name, trim.Name };
      this.name2Trim.put(joinKeys(keyList), trim);
      this.missingTrimNameSet.remove(trim.Name);
    }
    //insert missing trim
    if (this.missingTrimNameSet.size() > 0) {
      List<Vehicle_Trim__c> missingVehicleTrimList = new List<Vehicle_Trim__c>();
      this.missingTrimKeySet = new Set<String>();
      if (
        CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(
            ExternalSystem.Type.GDMS
          )
          .contains(this.extSystem.companyName)
      ) {
        for (CustomerVehicleService.Vehicle vehicle : this.gdmsVehicleList) {
          keyList = new List<String>{ vehicle.Make, vehicle.Trims };
          String missingTrimKey = joinKeys(keyList);
          if (
            this.missingTrimNameSet.contains(vehicle.Trims) &&
            !this.missingTrimKeySet.contains(missingTrimKey)
          ) {
            String trimName = String.valueOf(vehicle.Trims);
            Vehicle_Trim__c trim = new Vehicle_Trim__c(Name = trimName);
            trim.Company__c = companyId;
            trim.Description__c = vehicle.TrimsDesc;
            keyList = new List<String>{ vehicle.Make };
            trim.Vehicle_Make__c = this.name2make.get(joinKeys(keyList)).Id;
            missingVehicleTrimList.add(trim);
            this.missingTrimKeySet.add(missingTrimKey);
          }
        }
      }
      if (this.extSystem.companyName == CompanyRepository.C028) {
        for (CareService.VehicleResponse vehicle : this.careVehicleList) {
          keyList = new List<String>{ vehicle.vehMake, vehicle.vehTrim };
          String missingTrimKey = joinKeys(keyList);
          if (
            this.missingTrimNameSet.contains(vehicle.vehTrim) &&
            !this.missingTrimKeySet.contains(missingTrimKey)
          ) {
            Vehicle_Trim__c trim = new Vehicle_Trim__c(Name = vehicle.vehTrim);
            trim.Company__c = companyId;
            trim.Description__c = vehicle.vehTrimCode;
            keyList = new List<String>{ vehicle.vehMake };
            trim.Vehicle_Make__c = this.name2make.get(joinKeys(keyList)).Id;
            missingVehicleTrimList.add(trim);
            this.missingTrimKeySet.add(missingTrimKey);
          }
        }
      }
      Database.insert(missingVehicleTrimList, false);
      for (Vehicle_Trim__c trim : [
        SELECT
          Id,
          Name,
          Company__r.DmsCompanyCode__c,
          Vehicle_Make__r.Name,
          Key__c
        FROM Vehicle_Trim__c
        WHERE
          Vehicle_Make__r.Name IN :this.makeNameSet
          AND Name IN :this.missingTrimNameSet
      ]) {
        keyList = new List<String>{ trim.Vehicle_Make__r.Name, trim.Name };
        this.name2Trim.put(joinKeys(keyList), trim);
        this.missingTrimNameSet.remove(trim.Name);
      }
    }

    //prepare type maps
    this.name2Type = new Map<String, Vehicle_Type__c>();
    this.missingTypeNameSet = new Set<String>(typeNameSet);
    for (Vehicle_Type__c vehicleType : [
      SELECT Id, Name, Company__r.DmsCompanyCode__c, Key__c
      FROM Vehicle_Type__c
    ]) {
      keyList = new List<String>{ vehicleType.Name };
      this.name2Type.put(joinKeys(keyList), vehicleType);
      this.missingTypeNameSet.remove(vehicleType.Name);
    }

    //prepare vehicle maps
    this.name2Vehicle = new Map<String, Vehicle__c>();
    for (Vehicle__c vehicle : [
      SELECT Id, Name, Vehicle_Number__c, Company__c
      FROM Vehicle__c
      WHERE Name IN :vinSet
    ]) {
      VehicleTriggerHandler.dmsVehicleIds.add(vehicle.Id);
      keyList = new List<String>{ vehicle.Name };
      this.name2Vehicle.put(joinKeys(keyList), vehicle);
    }

    /*
        List<Workshop__c> workshopList = [
            SELECT Id,Name,Company__c
            FROM Workshop__c
            WHERE Name IN :this.workshopNameSet
                AND IsActive__c = true
        ];
        workshopLkp = new WorkshopLookup(workshopList);
        workshopLkp.lookAll(workshopNameSet, this.extSystem.companyName);
        workshopLkp.insertMissingWorkshops();
        */
  }
  public void execute(QueueableContext qContext) {
    if (
      CompanyRepository.EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(
          ExternalSystem.Type.GDMS
        )
        .contains(this.extSystem.companyName)
    ) {
      try {
        CustomerVehicleService vehService = new CustomerVehicleService(
          this.extSystem.companyName
        );
        String searchField = 'mod_datetime';
        String searchValue = this.dateFrom?.format('dd/MM/yyyy HH:mm:ss.SSS');
        if (String.isNotBlank(searchValue)) {
          searchValue += '-' + this.dateTo?.format('dd/MM/yyyy HH:mm:ss.SSS');
        }
        System.debug(searchValue);
        String request = this.extSystem.companyName + '| mod_datetime:\n';
        request += searchValue;
        request += '\nlastRowId:\n';
        request += this.lastRowId;

        if (!Test.isRunningTest()) {
          CustomerVehicleService.QueryVehicleResponse qVehResp = vehService.QueryVehicle(
            this.extSystem.companyName,
            searchField,
            searchValue,
            this.lastRowId,
            this.batchSize
          );
          this.lastRowId = qVehResp.LastRowID;
          if (qVehResp.Vehicles.Vehicle != null) {
            this.gdmsVehicleList = qVehResp.Vehicles.Vehicle;
          }
        }

        this.initMaps();
        this.upsertVehicles();

        String response = 'Size: ' + this.gdmsVehicleList.size();
        response += '\nLastRowId: ' + this.lastRowId;

        ApplicationLogUtility.insertCalloutSuccessLog(
          this.className,
          request,
          response,
          null,
          false
        );
        //requeue the same class or next resource
        Boolean requeueItself = this.isSelfQueueable;
        if (
          this.gdmsVehicleList.size() < this.batchSize || Test.isRunningTest()
        ) {
          requeueItself = false;
        }

        if (requeueItself) {
          this.gdmsVehicleList.clear();
          System.enqueueJob(this);
        } else {
          this.updateLastRun();
          if (this.followOn) {
            this.queueNext(true);
          }
        }
      } catch (CalloutException e) {
        ApplicationLogUtility.insertCalloutErrorLog(
          this.jobName,
          e,
          ApplicationLogUtility.PRIORITY_HIGH,
          false
        );
        Resource.queueStart(this.extSystem.companyName);
      } catch (Exception e) {
        ApplicationLogUtility.insertApexErrorLog(
          this.jobName,
          e,
          ApplicationLogUtility.PRIORITY_HIGH,
          false
        );
        Resource.queueStart(this.extSystem.companyName);
      }
    }

    if (this.extSystem.companyName == CompanyRepository.C028) {
      try {
        Http http = new Http();
        HttpRequest hreq = new HttpRequest();
        hreq.setEndpoint(CareService.ENDPOINT + 'v3/vehicle/list');
        hreq.setMethod('POST');
        hreq.setHeader('Content-Type', 'application/json');
        CareService.VehicleRequest req = new CareService.VehicleRequest();
        req.Company = new List<String>{
          CompanyRepository.C028,
          CompanyRepository.C001
        };
        req.UserName = CareService.USERNAME;
        req.Password = CareService.PASSWORD;
        req.DateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ'); // Timezone adjusted based on calling user profile
        req.DateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ'); // Timezone adjusted based on calling user profile
        req.vehNo = null;
        req.ChassisNo = null;
        req.RegNo = null;
        if (this.lastRowId != null) {
          req.LastId = Long.valueOf(this.lastRowId);
        }
        req.RowCount = 50;
        hreq.setBody(JSON.serialize(req, false));
        hreq.setTimeout(120000);
        HttpResponse hres;

        if (!Test.isRunningTest()) {
          hres = http.send(hreq);
          this.careVehicleList = (CareService.VehicleResponse[]) JSON.deserialize(
            hres.getBody(),
            CareService.VehicleResponse[].class
          );
          this.lastRowId = String.valueOf(this.careVehicleList[-1].vehNo);
        }
        this.initMaps();
        this.upsertVehicles();
        String response = 'Size : ' + this.careVehicleList.size();
        response += 'last row Id: ' + this.lastRowId;
        ApplicationLogUtility.insertCalloutSuccessLog(
          Util.getClassname(this),
          JSON.serialize(req),
          response,
          null,
          false
        );

        //requeue the same class or next resource
        Boolean requeueItself = this.isSelfQueueable;
        if (
          this.careVehicleList.size() < this.batchSize || Test.isRunningTest()
        ) {
          requeueItself = false;
        }

        if (requeueItself) {
          this.careVehicleList.clear();
          System.enqueueJob(this);
        } else {
          this.updateLastRun();
          if (this.followOn) {
            this.queueNext(true);
          }
        }
      } catch (CalloutException e) {
        ApplicationLogUtility.insertCalloutErrorLog(
          this.jobName,
          e,
          ApplicationLogUtility.PRIORITY_HIGH,
          false
        );
        Resource.queueStart(this.extSystem.companyName);
      } catch (Exception e) {
        ApplicationLogUtility.insertApexErrorLog(
          this.jobName,
          e,
          ApplicationLogUtility.PRIORITY_HIGH,
          false
        );
        Resource.queueStart(this.extSystem.companyName);
      }
    }
    ApplicationLogUtility.insertLogs();
  }
}
