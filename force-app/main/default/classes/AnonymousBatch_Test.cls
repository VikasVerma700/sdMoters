@isTest
private class AnonymousBatch_Test {

    @isTest static void testUpdateBusinessAccount() {
        Id busRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business Account').getRecordTypeId();

        Service_Appointment__c sa = TestFactory.genSvcAppt(1, false)[0];
        String key = '123';
        // Update RecordTypeId cannot update any other fields
        update new Account(Id = sa.Account__c, RecordTypeId = busRTId);
        update new Account(Id = sa.Account__c, DMS_Number__c = key + '|456');
        Id origVO = sa.Vehicle_Ownership__c;
        sa.Vehicle_Ownership__c = null;
        sa.Account__c = null;
        sa.CustomerKey__c = 'B' + key;
        insert sa;
        Service_Quota__c q = TestFactory.genServiceQuota(1, true)[0];
        insert new Appointment_Utilization__c(Service_Quota__c = q.Id, Service_Appointment__c = sa.Id);
        Test.startTest();
        AnonymousBatch batchJob = new AnonymousBatch();
        batchJob.query = batchJob.query5;
        Database.executeBatch(batchJob, 1);
        Test.stopTest();
        Service_Appointment__c newSA = [SELECT Id, Vehicle_Ownership__c FROM Service_Appointment__c WHERE Id = :sa.Id];
        System.assertEquals(newSA.Vehicle_Ownership__c, origVO);
    }

    @isTest static void testUpdatePersonAccount() {
        Service_Appointment__c sa = TestFactory.genSvcAppt(1, false)[0];
        String key = '123';
        // Update RecordTypeId cannot update any other fields
        update new Account(Id = sa.Account__c, DMS_Number__c = key + '|456');
        Id origVO = sa.Vehicle_Ownership__c;
        sa.Vehicle_Ownership__c = null;
        sa.Account__c = null;
        sa.CustomerKey__c = 'PA' + key;
        insert sa;
        Service_Quota__c q = TestFactory.genServiceQuota(1, true)[0];
        insert new Appointment_Utilization__c(Service_Quota__c = q.Id, Service_Appointment__c = sa.Id);
        Test.startTest();
        AnonymousBatch batchJob = new AnonymousBatch();
        batchJob.query = batchJob.query5;
        Database.executeBatch(batchJob, 1);
        Test.stopTest();
        Service_Appointment__c newSA = [SELECT Id, Vehicle_Ownership__c FROM Service_Appointment__c WHERE Id = :sa.Id];
        System.assertEquals(newSA.Vehicle_Ownership__c, origVO);
    }

	@isTest static void testUtilCreation() {
        Service_Appointment__c sa = TestFactory.genSvcAppt(1, false)[0];
        insert new User_Config__c(Name = 'Test', Employee_Master__c = sa.Employee_Master__c);
        delete [SELECT Id FROM Employee_Shift__c WHERE Id = :sa.Employee_Master__c AND Active_Date__c = :sa.Appointment_Date__c.date()];
        sa.Employee_Master__c = null;
        sa.Service_Request__c = 'Test';
        insert sa;
        Test.setCreatedDate(sa.Id, DateTime.now());
        update new Workshop__c(Id = sa.Workshop__c, Auto_Assign_CSA__c = true);
		Test.startTest();
		AnonymousBatch batchJob = new AnonymousBatch();
        batchJob.query = batchJob.query1;
		Database.executeBatch(batchJob, 1);
		Test.stopTest();
        Service_Appointment__c newSA = [SELECT Id, (SELECT Id FROM Appointment_Utilizations__r) FROM Service_Appointment__c WHERE Id = :sa.Id];
        System.assert(newSA.Appointment_Utilizations__r.size() > 0);
	}

    @isTest static void testUtilCreationWithCSA() {
        Service_Appointment__c sa = TestFactory.genSvcAppt(1, false)[0];
        insert new User_Config__c(Name = 'Test', Employee_Master__c = sa.Employee_Master__c);
        sa.Employee_Master__c = null;
        sa.Service_Request__c = 'Test';
        insert sa;
        Test.setCreatedDate(sa.Id, DateTime.now());
        update new Workshop__c(Id = sa.Workshop__c, Auto_Assign_CSA__c = true);
		Test.startTest();
		AnonymousBatch batchJob = new AnonymousBatch();
        batchJob.query = batchJob.query1;
		Database.executeBatch(batchJob, 1);
		Test.stopTest();
        Service_Appointment__c newSA = [SELECT Id, (SELECT Id FROM Appointment_Utilizations__r) FROM Service_Appointment__c WHERE Id = :sa.Id];
        System.assert(newSA.Appointment_Utilizations__r.size() > 0);
	}

    // @isTest static void testVOMatch() {
    //     Service_Appointment__c sa = TestFactory.genSvcAppt(1, false)[0];
    //     Id origVO = sa.Vehicle_Ownership__c;
    //     sa.Vehicle_Ownership__c = null;
    //     insert sa;
    //     Service_Quota__c q = TestFactory.genServiceQuota(1, true)[0];
    //     insert new Appointment_Utilization__c(Service_Quota__c = q.Id, Service_Appointment__c = sa.Id);
	// 	Test.startTest();
	// 	AnonymousBatch batchJob = new AnonymousBatch();
    //     batchJob.query = batchJob.query2;
	// 	Database.executeBatch(batchJob, 1);
	// 	Test.stopTest();
    //     Service_Appointment__c newSA = [SELECT Id, Vehicle_Ownership__c FROM Service_Appointment__c WHERE Id = :sa.Id];
    //     System.assertEquals(newSA.Vehicle_Ownership__c, origVO);
	// }

    // @isTest static void testAccMatch() {
    //     Service_Appointment__c sa = TestFactory.genSvcAppt(1, false)[0];
    //     String key = '123';
    //     update new Account(Id = sa.Account__c, DMS_Number__c = key + '|456');
    //     Id origVO = sa.Vehicle_Ownership__c;
    //     sa.Vehicle_Ownership__c = null;
    //     sa.Account__c = null;
    //     sa.CustomerKey__c = key;
    //     insert sa;
    //     Service_Quota__c q = TestFactory.genServiceQuota(1, true)[0];
    //     insert new Appointment_Utilization__c(Service_Quota__c = q.Id, Service_Appointment__c = sa.Id);
	// 	Test.startTest();
	// 	AnonymousBatch batchJob = new AnonymousBatch();
    //     batchJob.query = batchJob.query3;
	// 	Database.executeBatch(batchJob, 1);
	// 	Test.stopTest();
    //     Service_Appointment__c newSA = [SELECT Id, Vehicle_Ownership__c FROM Service_Appointment__c WHERE Id = :sa.Id];
    //     System.assertEquals(newSA.Vehicle_Ownership__c, origVO);
	// }

    // @isTest static void testVOCreate() {
    //     TestFactory.getCompany('028');
    //     String dmsNumber = '123';
    //     Vehicle__c veh = TestFactory.genVehicle(1, false)[0];
    //     veh.zz_Foreign_Field__c = 'SFDC - no VO';
    //     veh.DMS_Cust_Co_Number__c = dmsNumber;
    //     veh.DMS_Cust_Co_Type__c = 'Person Account';
    //     insert veh;
    //     Account bizAcc = new Account();
    //     bizAcc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business Account').getRecordTypeId();
    //     bizAcc.Name = 'Test Biz';
    //     bizAcc.DMS_Number__c = dmsNumber;
    //     List<Account> accList = new List<Account> { bizAcc };
    //     accList.addAll(TestFactory.genAccount(3, false));
    //     accList[1].DMS_Number__c = dmsNumber + '0';
    //     accList[2].DMS_Number__c = dmsNumber + '|456';
    //     insert accList;
    //     Test.startTest();
    //     AnonymousBatch b = new AnonymousBatch();
    //     b.query = b.query4;
    //     Database.executeBatch(b, 1);
    //     Test.stopTest();
    //     Vehicle_Ownership__c vo = [SELECT Id, Customer__c, Start_Date__c, Vehicle__c, Registration_No__c FROM Vehicle_Ownership__c WHERE Vehicle__c = :veh.Id];
    //     System.assertEquals(vo.Customer__c, accList[2].Id);
    //     System.assertEquals(vo.Start_Date__c, veh.Registration_Date__c);
    //     System.assertEquals(vo.Registration_No__c, veh.Registration_Number__c);
    // }

    // @isTest static void testVOCreateAcc() {
    //     TestFactory.getCompany('028');
    //     String dmsNumber = '123';
    //     Vehicle__c veh = TestFactory.genVehicle(1, false)[0];
    //     veh.zz_Foreign_Field__c = 'SFDC - Autoline Unmatched';
    //     veh.DMS_Cust_Co_Number__c = dmsNumber;
    //     veh.DMS_Cust_Co_Type__c = 'Business Account';
    //     veh.DMS_Cust_Co_Name__c = 'Test';
    //     insert veh;
    //     Test.startTest();
    //     AnonymousBatch b = new AnonymousBatch();
    //     b.query = b.query4;
    //     Database.executeBatch(b, 1);
    //     Test.stopTest();
    //     Vehicle_Ownership__c vo = [SELECT Id, Customer__r.Name, Customer__r.IsPersonAccount, Start_Date__c, Vehicle__c, Registration_No__c FROM
    //                                Vehicle_Ownership__c WHERE Vehicle__c = :veh.Id];
    //     System.assertEquals(vo.Customer__r.Name, veh.DMS_Cust_Co_Name__c);
    // }
}