global class AnonymousBatch implements Database.Batchable<sObject> {
    public Company__c cmp = [SELECT Id FROM Company__c WHERE Name = '028'];
    public String query;
    public String query1 = 'SELECT Id, (SELECT Id FROM Appointment_Utilizations__r) FROM Service_Appointment__c WHERE Appointment_Util_Count__c = 0 AND Apppointment_Status__c = \'ACTIVE\' and CreatedBy.name = \'ABD Admin\'';
    // public String query2 = 'SELECT Id, CustomerKey__c, Vehicle_Ownership__c, Account__c, Chassis__c, (SELECT Id FROM Appointment_Utilizations__r) FROM Service_Appointment__c WHERE Vehicle_Ownership__c = null AND Account__c != null AND Chassis__c != null';
    // public String query3 = 'SELECT Id, CustomerKey__c, Account__c, Chassis__c, Vehicle_Ownership__c, (SELECT Id FROM Appointment_Utilizations__r) FROM Service_Appointment__c WHERE Account__c = null AND Chassis__c != null AND CustomerKey__c != null';
    // public String query4 = 'SELECT Id, DMS_Cust_Co_Name__c, DMS_Cust_Co_Number__c, DMS_Cust_Co_Type__c, zz_Foreign_Field__c, Registration_Date__c, Registration_Number__c FROM Vehicle__c WHERE zz_Foreign_Field__c = \'SFDC - no VO\' OR zz_Foreign_Field__c = \'SFDC - Autoline Unmatched\'';
    public String query5 = 'SELECT Id, CustomerKey__c, Account__c, Chassis__c, Vehicle_Ownership__c, (SELECT Id FROM Appointment_Utilizations__r) FROM Service_Appointment__c WHERE Chassis__c != null AND CustomerKey__c != null';
	global Database.QueryLocator start(Database.BatchableContext BC) {
		return Database.getQueryLocator(query);
	}

	global void execute(Database.BatchableContext BC, List<SObject> scope) {
        if (scope == null || scope.size() <= 0) { return; }
        for (SObject curO : scope) {
            Service_Appointment__c sa = (Service_Appointment__c) curO;
            if (query == query5) {
                findAccWithBusiness(sa);
                findVO(new List<Service_Appointment__c>{sa});
            } else if (query == query1) {
                if (sa.Appointment_Utilizations__r.size() <= 0) {
                    createUtil(sa);
                }
            }
        }

        // if (scope[0].getSObjectType() == Vehicle__c.getSObjectType()) {
        //     List<Vehicle_Ownership__c> voList = new List<Vehicle_Ownership__c>();
        //     Vehicle_Ownership__c curVO;
        //     List<Vehicle__c> vehUpd = new List<Vehicle__c>();
        //     Vehicle__c v;
        //     for (SObject curO : scope) {
        //         v = (Vehicle__c) curO;
        //         curVO = createVO(v);
        //         if (curVO != null) {
        //             voList.add(curVO);
        //             v.zz_Foreign_Field__c = 'CK-ed ' + v.zz_Foreign_Field__c;
        //             vehUpd.add(v);
        //         }
        //     }
        //     upsert voList;
        //     update vehUpd;
        // } else if (scope[0].getSObjectType()  == Service_Appointment__c.getSObjectType()) {
            // Service_Appointment__c sa;
            // List<Service_Appointment__c> findVOAppt = new List<Service_Appointment__c>();
            // for (SObject curO : scope) {
            //     Sa = (Service_Appointment__c) curO;
            //     if (sa.Appointment_Utilizations__r.size() <= 0) {
            //         createUtil(sa);
            //     } else if (sa.Vehicle_Ownership__c == null && sa.Account__c != null && sa.Chassis__c != null) {
            //         findVOAppt.add(sa);
            //     } else if (sa.Vehicle_Ownership__c == null && sa.Account__c == null && sa.CustomerKey__c != null) {
            //         findAcc(sa);
            //     }
            // }
            // if (findVOAppt.size() > 0) { findVO(findVOAppt); }
        // }
    }

	global void finish(Database.BatchableContext BC) {}

    // global Vehicle_Ownership__c createVO(Vehicle__c v) {
    //     Boolean searchPerson = v.DMS_Cust_Co_Type__c == 'Person Account';
    //     String searchAutoline1 = ('%|' + v.DMS_Cust_Co_Number__c + '|%');
    //     String searchAutoline2 = (v.DMS_Cust_Co_Number__c + '|%');
    //     String searchAutoline3 = ('%|' + v.DMS_Cust_Co_Number__c);
    //     List<Account> accList = [SELECT Id, DMS_Number__c FROM Account WHERE IsPersonAccount = :searchPerson AND
    //                              (DMS_Number__c LIKE :searchAutoline1 OR DMS_Number__c LIKE :searchAutoline2 OR DMS_Number__c LIKE :searchAutoline3 OR
    //                               DMS_Number__c = :v.DMS_Cust_Co_Number__c)];

    //     Set<String> dmsString;
    //     Vehicle_Ownership__c vo = new Vehicle_Ownership__c(Vehicle__c = v.Id, Registration_No__c = v.Registration_Number__c, Start_Date__c = v.Registration_Date__c);
    //     if (v.zz_Foreign_Field__c == 'SFDC - Autoline Unmatched') {
    //         List<Vehicle_Ownership__c> voList = [SELECT Id, Customer__c, Vehicle__c, Registration_No__c, Start_Date__c FROM Vehicle_Ownership__c
    //                                              WHERE Vehicle__c = :v.Id ORDER BY CreatedDate DESC LIMIT 1];
    //         if (voList.size() > 0) {
    //             vo = voList[0];
    //             vo.Customer__c = null;
    //         }
    //     }
    //     for (Account a : accList) {
    //         dmsString = new Set<String>(a.DMS_Number__c.split('\\|'));
    //         if (!dmsString.contains(v.DMS_Cust_Co_Number__c)) { continue; }
    //         vo.Customer__c = a.Id;
    //         break;
    //     }
    //     if (vo.Customer__c == null && !String.isBlank(v.DMS_Cust_Co_Name__c)) {
    //         Account acc = new Account();
    //         acc.DMS_Number__c = v.DMS_Cust_Co_Number__c;
    //         acc.Created_From__c = 'Autoline Manual Migration';
    //         acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get(searchPerson ? 'Person Account' : 'Business Account').getRecordTypeId();
    //         if (searchPerson) {
    //             acc.LastName = v.DMS_Cust_Co_Name__c;
    //         } else {
    //             acc.Name = v.DMS_Cust_Co_Name__c;
    //         }
    //         insert acc;
    //         vo.Customer__c = acc.Id;
    //     }
    //     return (vo.Customer__c == null) ? null : vo;
    // }

    global void findVO(List<Service_Appointment__c> voAppt) {
        Map<String, Service_Appointment__c> apptMap = new Map<String, Service_Appointment__c>();
        Set<Id> accId = new Set<Id>();
        Set<Id> vehId = new Set<Id>();
        for (Service_Appointment__c sa : voAppt) {
            apptMap.put(String.valueOf(sa.Account__c) + String.valueOf(sa.Chassis__c), sa);
            accId.add(sa.Account__c);
            vehId.add(sa.Chassis__c);
        }
        List<Vehicle_Ownership__c> voList = [SELECT Id,Customer__c, Vehicle__c FROM Vehicle_Ownership__c WHERE Customer__c != null AND Customer__c IN :accId
                                             AND Vehicle__c IN :vehId AND Vehicle__c != null AND Status__c = 'Active'];
        Map<String, Vehicle_Ownership__c> voMap = new Map<String, Vehicle_Ownership__c>();
        List<Service_Appointment__c> updList = new List<Service_Appointment__c>();
        for (Vehicle_Ownership__c vo : voList) {
            Service_Appointment__c sa = apptMap.get(String.valueOf(vo.Customer__c) + String.valueOf(vo.Vehicle__c));
            if (sa == null) { continue; }
            sa.Vehicle_Ownership__c = vo.Id;
            updList.add(sa);
        }
        update updList;
    }

    // global void findAcc(Service_Appointment__c accAppt) {
    //     String accSearch = '%' + accAppt.CustomerKey__c + '%';
    //     List<Vehicle_Ownership__c> voList = [SELECT Id,Customer__c, Customer__r.DMS_Number__c, Vehicle__c FROM Vehicle_Ownership__c WHERE Customer__c != null
    //                                          AND Customer__r.DMS_Number__c LIKE :accSearch AND Vehicle__c != null AND Vehicle__c = :accAppt.Chassis__c AND
    //                                          Status__c = 'Active'];
    //     if (voList.size() <= 0) { return; }
    //     Set<String> dmsString = new Set<String>(voList[0].Customer__r.DMS_Number__c.split('\\|'));
    //     if (!dmsString.contains(accAppt.CustomerKey__c)) { return; }
    //     accAppt.Account__c = voList[0].Customer__c;
    //     accAppt.Vehicle_Ownership__c = voList[0].Id;
    //     update accAppt;
    // }

    global void findAccWithBusiness(Service_Appointment__c accAppt) {
        String custKey = accAppt.CustomerKey__c;
        Boolean searchPerson = custKey.containsIgnoreCase('PA');
        custKey = custKey.replaceAll('[B|PA]', '');

        String searchAutoline1 = ('%|' + custKey + '|%');
        String searchAutoline2 = (custKey + '|%');
        String searchAutoline3 = ('%|' + custKey);
        List<Account> accList = [SELECT Id, DMS_Number__c FROM Account WHERE IsPersonAccount = :searchPerson AND
                                 (DMS_Number__c LIKE :searchAutoline1 OR DMS_Number__c LIKE :searchAutoline2 OR DMS_Number__c LIKE :searchAutoline3 OR
                                  DMS_Number__c = :custKey)];

        for (Account a : accList) {
            Set<String> dmsString = new Set<String>(a.DMS_Number__c.split('\\|'));
            if (!dmsString.contains(custKey)) { continue; }
            accAppt.Account__c = a.Id;
            break;
        }
        update accAppt;
    }

    global void createUtil(Service_Appointment__c sa) {
        ServiceApptBooking.Booking curBooking = new ServiceApptBooking.Booking(sa.Id);
        if (curBooking.util != null) { delete curBooking.util; }

        Date searchD = curBooking.selectedTime.date();
        Date curD = searchD;
        List<Service_Slot__c> ssList = [SELECT Id FROM Service_Slot__c WHERE Workshop__c = :curBooking.ws.Id AND Company__r.Name = :curBooking.cmp AND Active_Date__c = :searchD];
        Service_Slot__c ss;
        List<Service_Quota__c> qList;
        if (ssList.size() <= 0) {
            ss = new Service_Slot__c();
            ss.Active_Date__c = searchD;
            ss.Company__c = cmp.Id;
            ss.Workshop__c = curBooking.ws.Id;
            insert ss;
            qList = new List<Service_Quota__c>();
            for (String s : curBooking.selectedTypes) { qList.add(genSlotSvcQuota(ss, searchD, s)); }
            insert qList;
        } else {
            ss = ssList[0];
            qList = new List<Service_Quota__c>();
            List<Service_Quota__c> ssQ = [SELECT Id, Max_Quota__c, Type__c, Available_Slots__c FROM Service_Quota__c WHERE Service_Slot__c = :ss.Id AND Type__c IN :curBooking.selectedTypes];
            for (String s : curBooking.selectedTypes) {
                Boolean needCreate = true;
                for (Service_Quota__c q : ssQ) {
                    if (q.Type__c == s) {
                        needCreate = false;
                        if (q.Available_Slots__c <= 0) {
                            q.Max_Quota__c++;
                        }
                        qList.add(q);
                    }
                }
                if (needCreate) { for (String sTotal : curBooking.selectedTypes) { qList.add(genSlotSvcQuota(ss, searchD, sTotal)); } }
            }
            upsert qList;
        }
        curBooking.slotQuota = qList;
        if (curBooking.csa == null) {
            List<Employee_Master__c> emList = [SELECT Id, Name, Workshop__c, Workshop__r.Name FROM Employee_Master__c WHERE Workshop__c = :curBooking.ws.Id];
            Map<Id, Employee_Master__c> userMap = new Map<Id, Employee_Master__c>();
            for (Employee_Master__c em : emList)  {
                userMap.put(em.Id, em);
            }

            List<User_Config__c> userList = [SELECT Id, User__c, Lead_Mark__c, Employee_Master__c FROM User_Config__c WHERE IsActive__c = true
                                            AND Department__c = 'Aftersales' AND Lead_Assignment_Opt_Out__c = false
                                            AND (User__c IN :userMap.keySet() OR Employee_Master__c IN :userMap.keySet())
                                            ORDER BY User__r.LastName, User__r.FirstName, Employee_Master__r.Name];
            Id csaId = CommonMethodsLibrary.assignSC(userList, 1)[0];
            curBooking.isAutoAssign = true;
            curBooking.csa = userMap.get(csaId);
        }
        List<Employee_Shift__c> esList = [SELECT Id FROM Employee_Shift__c WHERE Active_Date__c = :searchD AND Company__r.Name = :curBooking.cmp AND Workshop__c = :curBooking.ws.Id AND Employee_Master__c = :curBooking.csa.Id];
        Employee_Shift__c es;
        List<Service_Quota__c> esQ;
        if (esList.size() <= 0) {
            es = new Employee_Shift__c();
            es.Active_Date__c = searchD;
            es.Company__c = cmp.Id;
            es.Employee_Master__c = curBooking.csa.Id;
            es.Maximum_Appointment__c = 50;
            es.Workshop__c = curBooking.ws.Id;
            insert es;
            esQ = new List<Service_Quota__c>();
            for (String s : curBooking.selectedTypes) { esQ.add(genESSvcQuota(es, searchD, s)); }
        } else {
            es = esList[0];
            esQ = new List<Service_Quota__c>();
            List<Service_Quota__c> existingList = [SELECT Id, Max_Quota__c, Type__c, Available_Slots__c FROM Service_Quota__c WHERE Employee_Shift__c = :es.Id AND Type__c IN :curBooking.selectedTypes];
            for (String s : curBooking.selectedTypes) {
                Boolean needCreate = true;
                for (Service_Quota__c q : existingList) {
                    if (q.Type__c == s) {
                        if (q.Available_Slots__c <= 0) {
                            q.Max_Quota__c++;
                        }
                        needCreate = false;
                        esQ.add(q);
                    }
                }
                if (needCreate) { for (String esTotal : curBooking.selectedTypes) { esQ.add(genESSvcQuota(es, searchD, esTotal)); } }
            }
        }
        upsert esQ;
        curBooking.csaQuota = esQ;
        curBooking.genUtil(true);
        update new Service_Appointment__c(Id = curBooking.sa.Id, Employee_Master__c = curBooking.csa.Id);
    }

    public Service_Quota__c genSlotSvcQuota(Service_Slot__c ss, Date searchD, String s) {
        Service_Quota__c q = new Service_Quota__c();
        q.Service_Slot__c = ss.Id;
        q.Start_Time__c = DateTime.newInstance(searchD, Time.newInstance(8,0,0,0));
        q.End_Time__c = DateTime.newInstance(searchD, Time.newInstance(14, 00, 0,0));
        q.Max_Appt_Per_Timeslot__c = 50;
        q.Interval_Per_Appt__c = 3;
        q.Max_Quota__c = 1;
        q.Type__c = s;
        return q;
    }

    public Service_Quota__c genESSvcQuota(Employee_Shift__c es, Date searchD, String s) {
        Service_Quota__c q = new Service_Quota__c();
        q.Employee_Shift__c = es.Id;
        q.Start_Time__c = DateTime.newInstance(searchD, Time.newInstance(8,0,0,0));
        q.End_Time__c = DateTime.newInstance(searchD, Time.newInstance(14, 00, 0,0));
        q.Interval_Per_Appt__c = 3;
        q.Max_Quota__c = 1;
        q.Type__c = s;
        return q;
    }
}