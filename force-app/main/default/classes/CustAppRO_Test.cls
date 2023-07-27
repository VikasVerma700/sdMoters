@IsTest
public class CustAppRO_Test {
	@TestSetup
	public static void setup() {
		SQL_API_Base_Test.makeData();
		TestFactory.genTriggerSettings('Customer App Callback', true);
		TestFactory.genTriggerSettings('Vehicle', true);
		Customer_External_Account__c extAcc = TestFactory.genCustExtAcc(1, true)[0];
		Service_Appointment__c appt = TestFactory.genSvcAppt(1, true)[0];
		update new Service_Appointment__c(Id = appt.Id, Account__c = extAcc.Account__c);
		Vehicle_Ownership__c vo = [SELECT Id, Customer__c FROM Vehicle_Ownership__c WHERE Id = :appt.Vehicle_Ownership__c];
		vo.Customer__c = extAcc.Account__c;
		update vo;
		Alternative_Driver__c ad = TestFactory.genAltDriver(1, false)[0];
		ad.Account__c = extAcc.Account__c;
		ad.Vehicle_Ownership__c = vo.Id;
		insert ad;

		Set<String> ws = CustAppAppt.ALLOWED_WS.get('028');
		update new Workshop__c(Id = appt.Workshop__c, Name = new List<String>(ws)[0]);
	
		ServiceOrder__c[] ros = TestFactory.genRepairOrder(5, false);
		for (ServiceOrder__c ro :ros) {
			ro.Account__c = extAcc.Account__c;
			ro.ServiceAppointment__c = appt.Id;
			ro.VehicleOwnership__c = appt.Vehicle_Ownership__c;
			ro.Workshop__c = appt.Workshop__c;
		}
		insert ros;
		ServiceInvoice__c[] sis = TestFactory.genServiceInvoice(5, false);
		for (Integer i = 0; i < ros.size(); i++) {
			sis[i].Workshop__c = ros[i].Workshop__c;
			sis[i].RepairOrder__c = ros[i].Id;
			sis[i].VehicleOwnership__c = ros[i].VehicleOwnership__c;
			sis[i].Account__c = ros[i].Account__c;
			sis[i].PaymentRequired2__c = true;
		}
		insert sis;
		Attachment[] atts = TestFactory.genAttachment(sis.size());
		for (Integer i = 0; i < atts.size(); i++) {
			atts[i].ParentId = sis[0].Id;
			atts[i].Name = 'Service Invoice ' + i;
		}
		insert atts;
	}

	// @IsTest
	// public static void testTrigger() {
	// 	EventBusSubscriber sub = [SELECT Name, Position, Retries, LastError FROM EventBusSubscriber WHERE Topic='Customer_App_Callback__e' AND
	// 								Type='ApexTrigger'];
	// 	Test.startTest();
	// 	List<ServiceOrder__c> roList = [SELECT Id, Account__c, Company__c, Date_Cancelled__c FROM ServiceOrder__c];
	// 	CustAppRO.createAppCallbackFromRO(roList);
	// 	Test.stopTest();
	// 	EventBusSubscriber subNew = [SELECT Name, Position, Retries, LastError FROM EventBusSubscriber WHERE Topic='Customer_App_Callback__e' AND
	// 								Type='ApexTrigger'];
	// 	System.assertNotEquals(subNew.Position, sub.Position);
	// }

	@IsTest
	public static void testSendWebhook() {
		ServiceOrder__c ro = [SELECT Id FROM ServiceOrder__c LIMIT 5][1];
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = ro.Id, Event__c = CustAppRO.EVENT_NAME);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppRO.sendWebhook(callback);
		Test.stopTest();
		// refer to debug logs if there are any errors, no return value
	}
	@isTest
	public static void testProcessUpdateCallback() {
		CustAppRO.UpdateROWebhook req = new CustAppRO.UpdateROWebhook();
		req.event = 'UPDATE_RO';
		
		string roQuery = 	'SELECT ' + String.join(CustAppRO.RO_FIELDS, ',') + ' ' +
							', (SELECT ' + String.join(CustAppRO.INV_FIELDS, ',') + ' FROM ServiceInvoices__r) ' +
							'FROM ServiceOrder__c ';
		ServiceOrder__c[] sos = Database.query(roQuery);
		System.debug('roQuery ret: ' + JSON.serialize(sos));
		Id saId = sos[0].ServiceAppointment__r.Id;
		string saQuery =	'SELECT ' + String.join(CustAppAppt.APPT_FIELDS, ',') + ' ' +
							'FROM Service_Appointment__c WHERE Id = :saId';
		Service_Appointment__c sa = Database.query(saQuery);
		ServiceInvoice__c[] sis = sos[0].ServiceInvoices__r;
		req.payload = new CustAppRO.ROInfo(sos[0], sa, sis);
		CustAppRO.PaymentPayloadCls pymtload = new CustAppRO.PaymentPayloadCls();
		pymtload.Amount = 100.00;
		pymtload.AuthCode = 'AuthCode';
		pymtload.BankRefNo = 'BankRefNo';
		pymtload.CurrencyCode = 'MYR';
		pymtload.HashValue = 'hash1';
		pymtload.HashValue2 = 'hash2';
		pymtload.IssuingBank = 'IssueBank';
		pymtload.OrderNumber = 'Order1';
		pymtload.PaymentID = 'PaymentId1';
		pymtload.PymtMethod = 'Method';
		pymtload.QueryDesc = 'Desc';
		pymtload.RespTime = String.valueOf(Datetime.now());
		pymtload.ServiceID = 'ServiceId1';
		pymtload.SessionID = 'SessionId1';
		pymtload.TotalRefundAmount = 0.0;
		pymtload.TransactionType = 'Card';
		pymtload.TxnExists = 'TxnE';
		pymtload.TxnID = 'TxnId';
		pymtload.TxnMessage = 'TxnMsg';
		pymtload.TxnStatus = 'TnxStat';
		for (CustAppRO.SvcInvCls si :req.payload.repairOrder.invoices) {
			si.payment.payload = pymtload;
		}
		System.debug('req: ' + JSON.serialize(req));

		RestContext.request = new RestRequest();
		RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
		Test.startTest();
		CustAppRO.processUpdateCallback();
		/** Call again to do coverage */
		CustAppRO.processUpdateCallback();
		Test.stopTest();
		// List<Alternative_Driver__c> altDList = [SELECT Id FROM Alternative_Driver__c WHERE Account__c = :extAcc.Account__c AND Vehicle_Ownership__c = :vo.Id];
		// System.assert(altDList.size() > 0);
	}

	@isTest
	public static void testSendApptWebhookNoAccount() {
		Account ac = TestFactory.genAccount(1, true)[0];
		Vehicle_Ownership__c[] vos = [SELECT Id, Customer__c FROM Vehicle_Ownership__c];
		for (Vehicle_Ownership__c vo :vos) { vo.Customer__c = ac.Id; }
		update vos;

		ServiceOrder__c ro = [SELECT Id FROM ServiceOrder__c LIMIT 5][1];
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = ro.Id, Event__c = CustAppAppt.EVENT_NAME);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppRO.sendWebhook(callback);
		Test.stopTest();
		
	}

	@IsTest
	public static void testSendCompleteWebhook() {
		ServiceOrder__c ro = [SELECT Id FROM ServiceOrder__c LIMIT 1];
		ro.CheckOut__c = Date.today();
		update ro;
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = ro.Id, Event__c = CustAppRO.EVENT_NAME);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppRO.sendWebhook(callback);
		Test.stopTest();
		// refer to debug logs if there are any errors, no return value
	}

	@IsTest
	public static void testSendWebhookWoCSA() {
		ServiceOrder__c ro = [SELECT Id, CSA__c FROM ServiceOrder__c LIMIT 1];
		ro.CSA__c = null;
		update ro;
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = ro.Id, Event__c = CustAppRO.EVENT_NAME);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppRO.sendWebhook(callback);
		Test.stopTest();
		// refer to debug logs if there are any errors, no return value
	}

	@IsTest
	public static void testSendRemoveWebhook() {
		ServiceOrder__c ro = [SELECT Id FROM ServiceOrder__c LIMIT 1];
		ro.Date_Cancelled__c = Datetime.now().date();
		update ro;
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = ro.Id, Event__c = CustAppRO.REM_EVENT_NAME);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppRO.sendWebhook(callback);
		Test.stopTest();
		// refer to debug logs if there are any errors, no return value
	}

	@isTest
	public static void testSendWebhookPushNotification() {
		TestFactory.genTriggerSettings(RepairOrderHandler.TRIG_SETTING, true);
		string queryRo =	'SELECT ' + String.join(CustAppRO.RO_FIELDS, ', ') + ' FROM ServiceOrder__c ' +
							'WHERE CheckIn__c != null AND CSA__c != null AND VehicleOwnership__c != null ' +
							'AND StatusApp__c != null AND ContactAccNumber__c = \'C0000002\' ';
		ServiceOrder__c[] ros = Database.query(queryRo);

		string queryAcc =	'SELECT ' + String.join(CustAppAccount.ACC_FIELDS, ', ') + ' FROM Account ';
		Account[] acc = Database.query(queryAcc);
		Map<Id, Account> mapAcc = new Map<Id, Account>();
		for (Account ac :acc) { if (!mapAcc.containsKey(ac.Id)) { mapAcc.put(ac.Id, ac); }}

		System.debug(JSON.serialize(ros));

		Test.startTest();
		for (ServiceOrder__c ro :ros) {
			Account ac = mapAcc.get(ro.Account__c);
			ro.ContactPhone__c = u.beautifyPhone(ac.Mobile_Country_Code_1__pc, ac.Mobile_Preferred__pc);
			ro.Status__c = 'Not Assigned';
		}
		Database.update(ros, false);
		Test.stopTest();

	}

	@isTest
	public static void testPushToAbApp() {
		ServiceOrder__c ro = [SELECT Id FROM ServiceOrder__c LIMIT 1];
		Test.startTest();
		CustAppRO.pushToAbApp(ro.Id);
		Test.stopTest();
	}

}