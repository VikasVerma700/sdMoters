@RestResource(urlMapping='/whip/v1/vehicle')
global without sharing class WhipVehicle {
    @HttpGet
    global static void getVehicles() {
        RestResponse res = RestContext.response;
        try {
            RestRequest req = RestContext.request;
            string reqRegNo = req.params.get('registration_number');
            string reqPreNo = req.params.get('country_code');
            string reqPhoNo = req.params.get('phone_number');
            string reqCoReg = req.params.get('company_registration');
            if (String.isBlank(reqRegNo) && (String.isBlank(reqPhoNo) && String.isBlank(reqCoReg))) { 
                throw new WhipVehicleException('Both vehicle registration number and phone number/company registration not specified.'); 
            }
            string sql = 
                'SELECT ' +
                '   Id, Name, Vehicle__c, Vehicle__r.Name ' +
                /** unit {} */
                '   , Vehicle__r.Vehicle_Make__r.Description__c ' +
                '   , Vehicle__r.Vehicle_Model__r.Name ' +
                '   , Vehicle__r.Vehicle_Model__r.ModelForWhip__c ' +
                '   , Vehicle__r.VehicleVariant__r.Name ' +
                '   , Vehicle__r.VehicleVariant__r.VariantForWhip__c ' +
                '   , Model_Description__c ' +
                '   , Vehicle__r.Production_Year__c ' +
                '   , Vehicle__r.Vehicle_Colour__r.Name ' +
                '   , Registration_Date__c ' +
                '   , Registration_No__c ' +
                '   , Customer__r.Mobile_Country_Code_1__pc ' +
                '   , Customer__r.Mobile_Preferred__pc ' +
                '   , Customer__r.NRIC_Number__c ' +
                /** Business */
                '   , Customer__r.Phone ' +
                'FROM Vehicle_Ownership__c ' +
                'WHERE Status__c = \'Active\' ';
            if (String.isNotBlank(reqRegNo)) {
                system.debug('+reqRegNo');
                sql += String.format('AND Registration_No__c = \'\'{0}\'\' ', new string[] { reqRegNo });
            }
            if (String.isNotBlank(reqCoReg)) {
                system.debug('+reqCoReg');
                sql += String.format('AND Customer__r.NRIC_Number__c = \'\'{0}\'\' ', new string[] { reqCoReg });
            }
            else {
                if (String.isNotBlank(reqPreNo) && String.isNotBlank(reqPhoNo)) {
                    system.debug('+reqPreNo +reqPhoNo');
                    sql += String.format(
                        'AND ((Customer__r.Mobile_Country_Code_1__pc = {0} AND (Customer__r.Mobile_Preferred__pc = \'\'{1}\'\' OR Customer__r.Mobile_Preferred__pc = \'\'0{1}\'\')) ' +
                        'OR (Customer__r.PhoneCountryCode__c = {0} AND (Customer__r.Phone = \'\'{1}\'\' OR Customer__r.Phone = \'\'0{1}\'\'))) '
                        , new string[] { reqPreNo, reqPhoNo }
                    );
                }
                else if (String.isNotBlank(reqPreNo) && String.isBlank(reqPhoNo)) {
                    system.debug('+reqPreNo -reqPhoNo');
                    sql += String.format('AND (Customer__r.Mobile_Country_Code_1__pc = {0} OR Customer__r.PhoneCountryCode__c = {0}) ', new string[] { reqPreNo });
                }
                else if (String.isBlank(reqPreNo) && String.isNotBlank(reqPhoNo)) {
                    system.debug('-reqPreNo +reqPhoNo');
                    sql += String.format(
                        'AND ((Customer__r.Mobile_Preferred__pc = \'\'{0}\'\' OR Customer__r.Mobile_Preferred__pc = \'\'0{0}\'\') ' +
                        ' OR (Customer__r.Phone = \'\'{0}\'\' OR Customer__r.Phone = \'\'0{0}\'\'))', new string[] { reqPhoNo }
                    );
                }
            }
            system.debug(sql);
            Vehicle_Ownership__c[] vos = Database.query(sql);
            Set<Id> setOfVehx = new Set<Id>();
            Set<string> setOfVin = new Set<string>();
            for (Vehicle_Ownership__c vo :vos) {
                system.debug(String.format('VO: {0}, Vehicle: {1}, {2}, Customer: {3}, {4}, {5}'
                    , new string[] {
                        vo.Name
                        , vo.Vehicle__r.Name
                        , vo.Registration_No__c
                        , String.valueOf(vo.Customer__r.Mobile_Country_Code_1__pc)
                        , vo.Customer__r.Mobile_Preferred__pc
                        , vo.Customer__r.NRIC_Number__c
                }));
                setOfVehx.add(vo.Vehicle__c);
                setOfVin.add(vo.Vehicle__r.Name);
            }
            /** Acquire latest mileage from Service History. */
            AggregateResult[] ars = [
                Select
                    ChassisNo__c, MAX(Mileage__c) Mileage
                From ServiceOrder__c 
                Where ChassisNo__c In :setOfVin
                Group By ChassisNo__c
            ];
            Map<string, integer> mapOfSvch = new Map<string, integer>();
            for (AggregateResult ar :ars) { mapOfSvch.put(String.valueOf(ar.get('ChassisNo__c')), Integer.valueOf(ar.get('Mileage'))); }
            /** Acquire warranty packages */
            VehicleWarranty__c[] vws = [
                Select
                    ChassisNo__c, ContractCode__c, ContractDescription__c
                    , DateEnd__c, DateStart__c, Distance__c, Duration__c
                    // , Vehicle__c, Vehicle__r.Name
                From VehicleWarranty__c
                Where Vehicle__c In :setOfVehx
            ];
            Map<string, List<VehicleWarranty__c>> mapOfWarr = new Map<string, List<VehicleWarranty__c>>();
            for (VehicleWarranty__c vw :vws) {
                if (!mapOfWarr.containsKey(vw.ChassisNo__c)) {
                    mapOfWarr.put(vw.ChassisNo__c, new List<VehicleWarranty__c> { vw });
                }
                else {
                    ((List<VehicleWarranty__c>)mapOfWarr.get(vw.ChassisNo__c)).add(vw);
                }
            }

            /** Prep response */
            List<VehicleResp> vehxRes = new List<VehicleResp>();
            for (Vehicle_Ownership__c vo :vos) {
                VehicleResp r = new VehicleResp();
                r.registrationNumber = vo.Registration_No__c;
                r.chassisNumber = vo.Vehicle__r.Name;
                r.vehicleOwner = vo.Id;
                r.unit.color = vo.Vehicle__r.Vehicle_Colour__r.Name;
                r.unit.brand = vo.Vehicle__r.Vehicle_make__r.Description__c;
                r.unit.model = String.isBlank(vo.Vehicle__r.Vehicle_Model__r.ModelForWhip__c) ? vo.Vehicle__r.Vehicle_Model__r.Name : vo.Vehicle__r.Vehicle_Model__r.ModelForWhip__c;
                r.unit.variant = String.isBlank(vo.Vehicle__r.VehicleVariant__r.VariantForWhip__c) ? vo.Vehicle__r.VehicleVariant__r.Name : vo.Vehicle__r.VehicleVariant__r.VariantForWhip__c;
                r.unit.manufacturerYear = vo.Vehicle__r.Production_Year__c == null ? null: Integer.valueOf(vo.Vehicle__r.Production_Year__c.trim());
                r.unit.registrationDate = vo.Registration_Date__c;
                r.unit.registrationYear = vo.Registration_Date__c == null ? null: vo.Registration_Date__c.Year();
                if (mapOfSvch.containsKey(vo.Vehicle__r.Name)) { r.unit.lastMileage = mapOfSvch.get(vo.Vehicle__r.Name); }
                else { r.unit.lastMileage = 0; }
                if (mapOfWarr.containsKey(vo.Vehicle__r.Name)) {
                    for (VehicleWarranty__c vw :(List<VehicleWarranty__c>)mapOfWarr.get(vo.Vehicle__r.Name)) {
                        VehicleWarranty wp = new VehicleWarranty();
                        wp.packageName = vw.ContractDescription__c;
                        wp.duration = Integer.valueOf(vw.Duration__c);
                        wp.mileage = Integer.valueOf(vw.Distance__c);
                        wp.dateRange.startDate = vw.DateStart__c;
                        wp.dateRange.endDate = vw.DateEnd__c;
                        r.warrantyPackages.add(wp);
                    }
                }
                vehxRes.add(r);
            }
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(vehxRes));
        }
        catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
            res.responseBody = Blob.valueOf(JSON.serialize(new QueryResp(e)));
            res.statusCode = 400;
        }
    }

    global class VehicleResp {
        global string chassisNumber;
        global string registrationNumber;
        global Id vehicleOwner;
        global Unit unit = new Unit();
        global List<VehicleWarranty> warrantyPackages = new List<VehicleWarranty>();
    }
    global class Unit {
        global string color;
        global string brand;
        global string model;
        global string variant;
        global integer manufacturerYear;
        global integer registrationYear;
        global Date registrationDate;
        global integer lastMileage;
    }
    global class VehicleWarranty {
        global string packageName;
        global integer duration;
        global integer mileage;
        global DateRange dateRange = new dateRange();
    }
    global class DateRange {
        global Date startDate;
        global Date endDate;
    }
    private class WhipVehicleException extends Exception {}
    private class QueryResp {
        public String err;
        public QueryResp(Exception e) { this.err = e.getMessage() + '|' + e.getStackTraceString(); }
        public QueryResp() { this.err = null; }
    }
}