@isTest
public with sharing class SQL_File_Queue_Test {

    @TestSetup
    public static void makeData(){
        System.debug('SQL_File_Queue_Test.makeData()');
        SQL_SvcInv_Queue_Test.makeData();
		List<ServiceInvoice__c> sis =TestFactory.genServiceInvoice(1, false);
        //sis[0].AccountNumber__c = 'C0000003';
        insert sis;

		System.debug('SQL_File_Queue_Test.makeData(): sis (' + sis.size() + '): ' + JSON.serialize(sis));
        Attachment att = new Attachment();
        att.Name = 'att 01';
        att.Body = Blob.valueOf('Content');
        att.ParentId = sis[0].Id;
        insert att;
    }
    
    @isTest static void testPullFileList() {
        Test.startTest();
        ServiceInvoice__c[] sis = [
            SELECT
                Id, Name, Company__r.Name, Workshop__r.Name, Account__r.Name, Vehicle__r.Name
                , VehicleOwnership__r.Registration_No__c, AccountNumber__c, CreatedFrom__c
                , InvoiceDate__c, ExternalId__c, InvoiceKey__c, InvoiceReady__c, InvoiceValue__c
                , PaymentReference__c, PaymentStatus__c, PaymentRequired__c, PaymentRequired2__c, PaymentTimestamp__c
                , RegistrationNumber__c, RepairOrder__c, RoKey__c, ServiceDetails__c
				, RepairOrder__r.WipKey__c, RepairOrder__r.RegistrationNo__c, RepairOrder__r.RepairOrderNo__c
            FROM ServiceInvoice__c
        ];

        SQL_File_Queue.FileListObj[] res = new SQL_File_Queue.FileListObj[]{};
        for (ServiceInvoice__c si :sis) {
            SQL_File_Queue.FileListObj flo = new SQL_File_Queue.FileListObj();
            flo.UID = '1df637a2-6ca7-41e3-8105-7089e9dcf826' + TestFactory.getUnique();
            flo.WipKey = si.RepairOrder__r.WipKey__c;
            flo.RegNo = si.RepairOrder__r.RegistrationNo__c;
            flo.BranchCode = si.Workshop__r.Name;
            flo.DocNo = si.InvoiceKey__c.replace(si.Workshop__r.Name, '');
            flo.DocName = 'Service Invoice';
            flo.ChassisNumber = si.Vehicle__r.Name;
            flo.dtUpdated = Datetime.now();
            flo.WIP = si.RepairOrder__r.RepairOrderNo__c;
            flo.POS = si.Workshop__r.Name;
            flo.DocCode = 'SI';
            flo.DocMapName = flo.DocName.replace(' ', '').toUpperCase();
            flo.DocDescription = flo.DocName + ' From AB';
            flo.IsRequiredSign = true;
            flo.Status = 1;
            flo.StatusName = 'To Pick Up';
            flo.dtSigned = Datetime.now();
            flo.InvoiceNumber = null;
            flo.PrintedBy = 'PrintedByPrinter';
            flo.AssignedTo = 'AssignedToAssignee';
            flo.dtCreated = Datetime.now();
            res.add(flo);
			/** Service Invoice that doesn't match */
			flo = new SQL_File_Queue.FileListObj();
			flo.UID = '1df637a2-6ca7-41e3-8105-7089e9dcf826' + TestFactory.getUnique();
			flo.WipKey = si.RepairOrder__r.WipKey__c + '1';
			flo.RegNo = 'A' + si.RepairOrder__r.RegistrationNo__c;
			flo.BranchCode = si.Workshop__r.Name;
			flo.DocNo = si.InvoiceKey__c.replace(si.Workshop__r.Name, '') + 1;
			flo.DocName = 'Service Invoice';
			flo.ChassisNumber = si.Vehicle__r.Name;
			flo.dtUpdated = Datetime.now();
			flo.WIP = si.RepairOrder__r.RepairOrderNo__c;
			flo.POS = si.Workshop__r.Name;
			flo.DocCode = 'SI';
			flo.DocMapName = flo.DocName.replace(' ', '').toUpperCase();
			flo.DocDescription = flo.DocName + ' From AB';
			flo.IsRequiredSign = true;
			flo.Status = 1;
			flo.StatusName = 'To Pick Up';
			flo.dtSigned = Datetime.now();
			flo.InvoiceNumber = null;
			flo.PrintedBy = 'PrintedByPrinter';
			flo.AssignedTo = 'AssignedToAssignee';
			flo.dtCreated = Datetime.now();
			res.add(flo);
		}

        // TestWSMock.SQL_SF_FILELIST_PULL_API mock = new TestWSMock.SQL_SF_FILELIST_PULL_API(200, floss);
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
        Test.setMock(HttpCalloutMock.class, mock);
        
        SQL_File_Queue job = new SQL_File_Queue();
        System.enqueueJob(job);
        Test.stopTest();
    }

	@isTest static void testPullFileList_Update() {
        Test.startTest();
        ServiceInvoice__c[] sis = [
            SELECT
                Id, Name, Company__r.Name, Workshop__r.Name, Account__r.Name, Vehicle__r.Name
                , VehicleOwnership__r.Registration_No__c, AccountNumber__c, CreatedFrom__c
                , InvoiceDate__c, ExternalId__c, InvoiceKey__c, InvoiceReady__c, InvoiceValue__c
                , PaymentReference__c, PaymentStatus__c, PaymentRequired__c, PaymentRequired2__c, PaymentTimestamp__c
                , RegistrationNumber__c, RepairOrder__c, RoKey__c, ServiceDetails__c
				, RepairOrder__r.WipKey__c, RepairOrder__r.RegistrationNo__c, RepairOrder__r.RepairOrderNo__c
            FROM ServiceInvoice__c
        ];
        SQL_File_Queue.FileListObj[] res = new SQL_File_Queue.FileListObj[]{};
        for (ServiceInvoice__c si :sis) {
            SQL_File_Queue.FileListObj flo = new SQL_File_Queue.FileListObj();
            flo.UID = '1df637a2-6ca7-41e3-8105-7089e9dcf826' + TestFactory.getUnique();
            flo.WipKey = si.RepairOrder__r.WipKey__c;
            flo.RegNo = si.RepairOrder__r.RegistrationNo__c;
            flo.BranchCode = si.Workshop__r.Name;
            flo.DocNo = si.InvoiceKey__c.replace(si.Workshop__r.Name, '');
            flo.DocName = 'Service Invoice';
            flo.ChassisNumber = si.Vehicle__r.Name;
            flo.dtUpdated = Datetime.now();
            flo.WIP = si.RepairOrder__r.RepairOrderNo__c;
            flo.POS = si.Workshop__r.Name;
            flo.DocCode = 'SI';
            flo.DocMapName = flo.DocName.replace(' ', '').toUpperCase();
            flo.DocDescription = flo.DocName + ' From AB';
            flo.IsRequiredSign = true;
            flo.Status = 1;
            flo.StatusName = 'To Pick Up';
            flo.dtSigned = Datetime.now();
            flo.InvoiceNumber = null;
            flo.PrintedBy = 'PrintedByPrinter';
            flo.AssignedTo = 'AssignedToAssignee';
            flo.dtCreated = Datetime.now();
            res.add(flo);
			/** Service Invoice that doesn't match */
			flo = new SQL_File_Queue.FileListObj();
			flo.UID = '1df637a2-6ca7-41e3-8105-7089e9dcf826' + TestFactory.getUnique();
			flo.WipKey = si.RepairOrder__r.WipKey__c + '1';
			flo.RegNo = 'A' + si.RepairOrder__r.RegistrationNo__c;
			flo.BranchCode = si.Workshop__r.Name;
			flo.DocNo = si.InvoiceKey__c.replace(si.Workshop__r.Name, '') + 1;
			flo.DocName = 'Service Invoice';
			flo.ChassisNumber = si.Vehicle__r.Name;
			flo.dtUpdated = Datetime.now();
			flo.WIP = si.RepairOrder__r.RepairOrderNo__c;
			flo.POS = si.Workshop__r.Name;
			flo.DocCode = 'SI';
			flo.DocMapName = flo.DocName.replace(' ', '').toUpperCase();
			flo.DocDescription = flo.DocName + ' From AB';
			flo.IsRequiredSign = true;
			flo.Status = 1;
			flo.StatusName = 'To Pick Up';
			flo.dtSigned = Datetime.now();
			flo.InvoiceNumber = null;
			flo.PrintedBy = 'PrintedByPrinter';
			flo.AssignedTo = 'AssignedToAssignee';
			flo.dtCreated = Datetime.now();
			res.add(flo);
		}
		SQL_File_Queue q = new SQL_File_Queue();
		q.upsertFileList(res);

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
        Test.setMock(HttpCalloutMock.class, mock);
        
        SQL_File_Queue job = new SQL_File_Queue();
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPullFileListNoRow() {
        SQL_File_Queue.FileListObj[] res = new SQL_File_Queue.FileListObj[]{};
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_File_Queue job = new SQL_File_Queue();
		job.followOnToPayment = true;
		job.followOnToBatch = true;
		System.enqueueJob(job);
		job.dateFrom = job.dateTo = null;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPullFileListStatusNotOK() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
		SQL_File_Queue job = new SQL_File_Queue();
		job.followOnToPayment = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPullFileList_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SQL_File_Queue job = new SQL_File_Queue();
		job.followOnToPayment = true;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPullFileList_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_File_Queue job = new SQL_File_Queue();
		job.followOnToPayment = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPullFileList_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SQL_File_Queue job = new SQL_File_Queue();
		job.followOnToPayment = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest static void testPullFileBinary() {
        Test.startTest();
		ServiceInvoice__c[] sis = [
            SELECT
                Id, Name, Company__r.Name, Workshop__r.Name, Account__r.Name, Vehicle__r.Name
                , VehicleOwnership__r.Registration_No__c, AccountNumber__c, CreatedFrom__c
                , InvoiceDate__c, ExternalId__c, InvoiceKey__c, InvoiceReady__c, InvoiceValue__c
                , PaymentReference__c, PaymentStatus__c, PaymentRequired__c, PaymentRequired2__c, PaymentTimestamp__c
                , RegistrationNumber__c, RepairOrder__c, RoKey__c, ServiceDetails__c
				, RepairOrder__r.WipKey__c, RepairOrder__r.RegistrationNo__c, RepairOrder__r.RepairOrderNo__c
            FROM ServiceInvoice__c
        ];
        SQL_File_Queue.FileListObj[] floss = new SQL_File_Queue.FileListObj[]{};
        for (ServiceInvoice__c si :sis) {
            SQL_File_Queue.FileListObj fl = new SQL_File_Queue.FileListObj();
            fl.UID = '1df637a2-6ca7-41e3-8105-7089e9dcf826' + TestFactory.getUnique();
            fl.WipKey = si.RepairOrder__r.WipKey__c;
            fl.RegNo = si.RepairOrder__r.RegistrationNo__c;
            fl.BranchCode = si.Workshop__r.Name;
            fl.DocNo = si.InvoiceKey__c.replace(si.Workshop__r.Name, '');
            fl.DocName = 'Service Invoice';
            fl.ChassisNumber = si.Vehicle__r.Name;
            fl.dtUpdated = Datetime.now();
            fl.WIP = si.RepairOrder__r.RepairOrderNo__c;
            fl.POS = si.Workshop__r.Name;
            fl.DocCode = 'SI';
            fl.DocMapName = fl.DocName.replace(' ', '').toUpperCase();
            fl.DocDescription = fl.DocName + ' From AB';
            fl.IsRequiredSign = true;
            fl.Status = 1;
            fl.StatusName = 'To Pick Up';
            fl.dtSigned = Datetime.now();
            fl.InvoiceNumber = null;
            fl.PrintedBy = 'PrintedByPrinter';
            fl.AssignedTo = 'AssignedToAssignee';
            fl.dtCreated = Datetime.now();
            floss.add(fl);
		}
		SQL_File_Queue job = new SQL_File_Queue();
		Set<Id> setAttId = job.upsertFileList(floss);
		Attachment[] atts = [SELECT Id, Name, Description FROM Attachment WHERE Id IN :setAttId];
		SQL_File_Queue.Document doc = new SQL_File_Queue.Document();
		doc.Guid = '';
		doc.DocTypeUid = 3;
		doc.DocType = 'SERVICEINVOICE';
		doc.DocDate = Datetime.now();
		doc.DocStatusUid = 1;
		doc.DocStatusValue = 1;
		doc.DocStatusName = '';
		doc.FTPPath = '';
		doc.Filename = '';
		SQL_File_Queue.FileData res = new SQL_File_Queue.FileData();
		res.WipKey = 0;
		res.Wip = 0;
		res.RegNo = '';
		res.ChassisNo = null;
		res.Base64Content = 'VGhpcyBpcyBqdXN0IGEgbW9jayB0ZXN0Lg==';
		res.Document = doc;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
        
		job = new SQL_File_Queue(setAttId);
		job.followOnToPayment = true;
		job.sendCompletionEmail = true;
		Database.executeBatch(job, 10);
        Test.stopTest();
	}

	@isTest static void testPullFileBinary_NoDesc() {
        Test.startTest();
		ServiceInvoice__c[] sis = [
            SELECT
                Id, Name, Company__r.Name, Workshop__r.Name, Account__r.Name, Vehicle__r.Name
                , VehicleOwnership__r.Registration_No__c, AccountNumber__c, CreatedFrom__c
                , InvoiceDate__c, ExternalId__c, InvoiceKey__c, InvoiceReady__c, InvoiceValue__c
                , PaymentReference__c, PaymentStatus__c, PaymentRequired__c, PaymentRequired2__c, PaymentTimestamp__c
                , RegistrationNumber__c, RepairOrder__c, RoKey__c, ServiceDetails__c
				, RepairOrder__r.WipKey__c, RepairOrder__r.RegistrationNo__c, RepairOrder__r.RepairOrderNo__c
            FROM ServiceInvoice__c
        ];
		Set<Id> setAttId = new Set<Id>();
		Attachment[] atts = TestFactory.genAttachment(1);
		for (Attachment att :atts) {
			att.Description = TestFactory.getUnique();
			att.ParentId = sis[0].Id;
		}
		insert atts;
		for (Attachment att :atts) { setAttId.add(att.Id); }

		
		SQL_File_Queue job = new SQL_File_Queue(setAttId);
		job.followOnToPayment = true;
		job.sendCompletionEmail = true;
		Database.executeBatch(job, 10);
        Test.stopTest();
	}
	@isTest static void testPullFileBinary_Base64E() {
        Test.startTest();
		ServiceInvoice__c[] sis = [
            SELECT
                Id, Name, Company__r.Name, Workshop__r.Name, Account__r.Name, Vehicle__r.Name
                , VehicleOwnership__r.Registration_No__c, AccountNumber__c, CreatedFrom__c
                , InvoiceDate__c, ExternalId__c, InvoiceKey__c, InvoiceReady__c, InvoiceValue__c
                , PaymentReference__c, PaymentStatus__c, PaymentRequired__c, PaymentRequired2__c, PaymentTimestamp__c
                , RegistrationNumber__c, RepairOrder__c, RoKey__c, ServiceDetails__c
				, RepairOrder__r.WipKey__c, RepairOrder__r.RegistrationNo__c, RepairOrder__r.RepairOrderNo__c
            FROM ServiceInvoice__c
        ];
        SQL_File_Queue.FileListObj[] floss = new SQL_File_Queue.FileListObj[]{};
        for (ServiceInvoice__c si :sis) {
            SQL_File_Queue.FileListObj fl = new SQL_File_Queue.FileListObj();
            fl.UID = '1df637a2-6ca7-41e3-8105-7089e9dcf826' + TestFactory.getUnique();
            fl.WipKey = si.RepairOrder__r.WipKey__c;
            fl.RegNo = si.RepairOrder__r.RegistrationNo__c;
            fl.BranchCode = si.Workshop__r.Name;
            fl.DocNo = si.InvoiceKey__c.replace(si.Workshop__r.Name, '');
            fl.DocName = 'Service Invoice';
            fl.ChassisNumber = si.Vehicle__r.Name;
            fl.dtUpdated = Datetime.now();
            fl.WIP = si.RepairOrder__r.RepairOrderNo__c;
            fl.POS = si.Workshop__r.Name;
            fl.DocCode = 'SI';
            fl.DocMapName = fl.DocName.replace(' ', '').toUpperCase();
            fl.DocDescription = fl.DocName + ' From AB';
            fl.IsRequiredSign = true;
            fl.Status = 1;
            fl.StatusName = 'To Pick Up';
            fl.dtSigned = Datetime.now();
            fl.InvoiceNumber = null;
            fl.PrintedBy = 'PrintedByPrinter';
            fl.AssignedTo = 'AssignedToAssignee';
            fl.dtCreated = Datetime.now();
            floss.add(fl);
		}
		SQL_File_Queue job = new SQL_File_Queue();
		Set<Id> setAttId = job.upsertFileList(floss);
		Attachment[] atts = [SELECT Id, Name, Description FROM Attachment WHERE Id IN :setAttId];
		SQL_File_Queue.Document doc = new SQL_File_Queue.Document();
		doc.Guid = '';
		doc.DocTypeUid = 3;
		doc.DocType = 'SERVICEINVOICE';
		doc.DocDate = Datetime.now();
		doc.DocStatusUid = 1;
		doc.DocStatusValue = 1;
		doc.DocStatusName = '';
		doc.FTPPath = '';
		doc.Filename = '';
		SQL_File_Queue.FileData res = new SQL_File_Queue.FileData();
		res.WipKey = 0;
		res.Wip = 0;
		res.RegNo = '';
		res.ChassisNo = null;
		res.Base64Content = ''; // causes Exception on bsae64Decode.
		res.Document = doc;
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
        
		job = new SQL_File_Queue(setAttId);
		Database.executeBatch(job, 10);
        Test.stopTest();
	}

	@isTest static void testPullFileBinaryStatusNotOK() {
        Test.startTest();
		ServiceInvoice__c[] sis = [
            SELECT
                Id, Name, Company__r.Name, Workshop__r.Name, Account__r.Name, Vehicle__r.Name
                , VehicleOwnership__r.Registration_No__c, AccountNumber__c, CreatedFrom__c
                , InvoiceDate__c, ExternalId__c, InvoiceKey__c, InvoiceReady__c, InvoiceValue__c
                , PaymentReference__c, PaymentStatus__c, PaymentRequired__c, PaymentRequired2__c, PaymentTimestamp__c
                , RegistrationNumber__c, RepairOrder__c, RoKey__c, ServiceDetails__c
				, RepairOrder__r.WipKey__c, RepairOrder__r.RegistrationNo__c, RepairOrder__r.RepairOrderNo__c
            FROM ServiceInvoice__c
        ];
        SQL_File_Queue.FileListObj[] floss = new SQL_File_Queue.FileListObj[]{};
        for (ServiceInvoice__c si :sis) {
            SQL_File_Queue.FileListObj fl = new SQL_File_Queue.FileListObj();
            fl.UID = '1df637a2-6ca7-41e3-8105-7089e9dcf826' + TestFactory.getUnique();
            fl.WipKey = si.RepairOrder__r.WipKey__c;
            fl.RegNo = si.RepairOrder__r.RegistrationNo__c;
            fl.BranchCode = si.Workshop__r.Name;
            fl.DocNo = si.InvoiceKey__c.replace(si.Workshop__r.Name, '');
            fl.DocName = 'Service Invoice';
            fl.ChassisNumber = si.Vehicle__r.Name;
            fl.dtUpdated = Datetime.now();
            fl.WIP = si.RepairOrder__r.RepairOrderNo__c;
            fl.POS = si.Workshop__r.Name;
            fl.DocCode = 'SI';
            fl.DocMapName = fl.DocName.replace(' ', '').toUpperCase();
            fl.DocDescription = fl.DocName + ' From AB';
            fl.IsRequiredSign = true;
            fl.Status = 1;
            fl.StatusName = 'To Pick Up';
            fl.dtSigned = Datetime.now();
            fl.InvoiceNumber = null;
            fl.PrintedBy = 'PrintedByPrinter';
            fl.AssignedTo = 'AssignedToAssignee';
            fl.dtCreated = Datetime.now();
            floss.add(fl);
		}
		SQL_File_Queue job = new SQL_File_Queue();
		Set<Id> setAttId = job.upsertFileList(floss);

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        
		job.followOnToPayment = true;
		Database.executeBatch(job, 10);
        Test.stopTest();
	}

	@isTest static void testPullFileBinary_E() {
        Test.startTest();
		ServiceInvoice__c[] sis = [
            SELECT
                Id, Name, Company__r.Name, Workshop__r.Name, Account__r.Name, Vehicle__r.Name
                , VehicleOwnership__r.Registration_No__c, AccountNumber__c, CreatedFrom__c
                , InvoiceDate__c, ExternalId__c, InvoiceKey__c, InvoiceReady__c, InvoiceValue__c
                , PaymentReference__c, PaymentStatus__c, PaymentRequired__c, PaymentRequired2__c, PaymentTimestamp__c
                , RegistrationNumber__c, RepairOrder__c, RoKey__c, ServiceDetails__c
				, RepairOrder__r.WipKey__c, RepairOrder__r.RegistrationNo__c, RepairOrder__r.RepairOrderNo__c
            FROM ServiceInvoice__c
        ];
        SQL_File_Queue.FileListObj[] floss = new SQL_File_Queue.FileListObj[]{};
        for (ServiceInvoice__c si :sis) {
            SQL_File_Queue.FileListObj fl = new SQL_File_Queue.FileListObj();
            fl.UID = '1df637a2-6ca7-41e3-8105-7089e9dcf826' + TestFactory.getUnique();
            fl.WipKey = si.RepairOrder__r.WipKey__c;
            fl.RegNo = si.RepairOrder__r.RegistrationNo__c;
            fl.BranchCode = si.Workshop__r.Name;
            fl.DocNo = si.InvoiceKey__c.replace(si.Workshop__r.Name, '');
            fl.DocName = 'Service Invoice';
            fl.ChassisNumber = si.Vehicle__r.Name;
            fl.dtUpdated = Datetime.now();
            fl.WIP = si.RepairOrder__r.RepairOrderNo__c;
            fl.POS = si.Workshop__r.Name;
            fl.DocCode = 'SI';
            fl.DocMapName = fl.DocName.replace(' ', '').toUpperCase();
            fl.DocDescription = fl.DocName + ' From AB';
            fl.IsRequiredSign = true;
            fl.Status = 1;
            fl.StatusName = 'To Pick Up';
            fl.dtSigned = Datetime.now();
            fl.InvoiceNumber = null;
            fl.PrintedBy = 'PrintedByPrinter';
            fl.AssignedTo = 'AssignedToAssignee';
            fl.dtCreated = Datetime.now();
            floss.add(fl);
		}
		SQL_File_Queue job = new SQL_File_Queue();
		Set<Id> setAttId = job.upsertFileList(floss);
		Attachment[] atts = [SELECT Id, Name, Description FROM Attachment WHERE Id IN :setAttId];
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		
		job = new SQL_File_Queue(setAttId);
		job.followOnToPayment = true;
		Database.executeBatch(job, 10);
		Test.stopTest();
	}

	@isTest static void testPullFileBinary_ECallout() {
        Test.startTest();
		ServiceInvoice__c[] sis = [
            SELECT
                Id, Name, Company__r.Name, Workshop__r.Name, Account__r.Name, Vehicle__r.Name
                , VehicleOwnership__r.Registration_No__c, AccountNumber__c, CreatedFrom__c
                , InvoiceDate__c, ExternalId__c, InvoiceKey__c, InvoiceReady__c, InvoiceValue__c
                , PaymentReference__c, PaymentStatus__c, PaymentRequired__c, PaymentRequired2__c, PaymentTimestamp__c
                , RegistrationNumber__c, RepairOrder__c, RoKey__c, ServiceDetails__c
				, RepairOrder__r.WipKey__c, RepairOrder__r.RegistrationNo__c, RepairOrder__r.RepairOrderNo__c
            FROM ServiceInvoice__c
        ];
        SQL_File_Queue.FileListObj[] floss = new SQL_File_Queue.FileListObj[]{};
        for (ServiceInvoice__c si :sis) {
            SQL_File_Queue.FileListObj fl = new SQL_File_Queue.FileListObj();
            fl.UID = '1df637a2-6ca7-41e3-8105-7089e9dcf826' + TestFactory.getUnique();
            fl.WipKey = si.RepairOrder__r.WipKey__c;
            fl.RegNo = si.RepairOrder__r.RegistrationNo__c;
            fl.BranchCode = si.Workshop__r.Name;
            fl.DocNo = si.InvoiceKey__c.replace(si.Workshop__r.Name, '');
            fl.DocName = 'Service Invoice';
            fl.ChassisNumber = si.Vehicle__r.Name;
            fl.dtUpdated = Datetime.now();
            fl.WIP = si.RepairOrder__r.RepairOrderNo__c;
            fl.POS = si.Workshop__r.Name;
            fl.DocCode = 'SI';
            fl.DocMapName = fl.DocName.replace(' ', '').toUpperCase();
            fl.DocDescription = fl.DocName + ' From AB';
            fl.IsRequiredSign = true;
            fl.Status = 1;
            fl.StatusName = 'To Pick Up';
            fl.dtSigned = Datetime.now();
            fl.InvoiceNumber = null;
            fl.PrintedBy = 'PrintedByPrinter';
            fl.AssignedTo = 'AssignedToAssignee';
            fl.dtCreated = Datetime.now();
            floss.add(fl);
		}
		SQL_File_Queue job = new SQL_File_Queue();
		Set<Id> setAttId = job.upsertFileList(floss);
		Attachment[] atts = [SELECT Id, Name, Description FROM Attachment WHERE Id IN :setAttId];
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		
		job = new SQL_File_Queue(setAttId);
		job.followOnToPayment = true;
		Database.executeBatch(job, 10);
		Test.stopTest();
	}
}