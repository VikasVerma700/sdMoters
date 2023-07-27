@IsTest
public class CustAppAppt_Test {
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
			ro.ServiceAppointment__c = appt.Id;
			// ro.Account__c = extAcc.Account__c;
		}
		System.debug('ro appt: ' + JSON.serialize(ros));
		insert ros;

		ServiceInvoice__c[] sis = TestFactory.genServiceInvoice(ros.size(), false);
		for (Integer i = 0; i < ros.size(); i++) {
			sis[i].RepairOrder__c = ros[i].Id;
			// sis[i].Account__c = extAcc.Account__c;
		}
		insert sis;
	}

	@IsTest
	public static void testSendApptWebhook() {
		Service_Appointment__c appt = [SELECT Id FROM Service_Appointment__c LIMIT 1];
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = appt.Id, Event__c = CustAppAppt.EVENT_NAME);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppAppt.sendWebhook(callback);
		Test.stopTest();
		// refer to debug logs if there are any errors, no return value
	}

	@IsTest
	public static void testSendApptWebhookCancelled() {
		Service_Appointment__c appt = [SELECT Id FROM Service_Appointment__c LIMIT 1];
		appt.Apppointment_Status__c = 'CANCELLED';
		update appt;
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = appt.Id, Event__c = CustAppAppt.EVENT_NAME);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppAppt.sendWebhook(callback);
		Test.stopTest();
		// refer to debug logs if there are any errors, no return value
	}

	@IsTest
	public static void testSendApptWebhookCompleted() {
		Service_Appointment__c appt = [SELECT Id FROM Service_Appointment__c LIMIT 1];
		appt.Apppointment_Status__c = 'COMPLETED';
		update appt;
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = appt.Id, Event__c = CustAppAppt.EVENT_NAME);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppAppt.sendWebhook(callback);
		Test.stopTest();
		// refer to debug logs if there are any errors, no return value
	}

	@IsTest
	public static void testSendApptWebhookMissed() {
		Service_Appointment__c appt = [SELECT Id FROM Service_Appointment__c LIMIT 1];
		appt.Apppointment_Status__c = 'NO SHOW';
		update appt;
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = appt.Id, Event__c = CustAppAppt.EVENT_NAME);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppAppt.sendWebhook(callback);
		Test.stopTest();
		// refer to debug logs if there are any errors, no return value
	}

	@IsTest
	public static void testSendApptWebhookOther() {
		Service_Appointment__c appt = [SELECT Id FROM Service_Appointment__c LIMIT 1];
		appt.Apppointment_Status__c = 'NOT SPECIFIED';
		update appt;
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = appt.Id, Event__c = CustAppAppt.EVENT_NAME);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppAppt.sendWebhook(callback);
		Test.stopTest();
		// refer to debug logs if there are any errors, no return value
	}

	@isTest
	public static void testSendApptWebhookNoAccount() {
		Account ac = TestFactory.genAccount(1, true)[0];
		Vehicle_Ownership__c[] vos = [SELECT Id, Customer__c FROM Vehicle_Ownership__c];
		for (Vehicle_Ownership__c vo :vos) { vo.Customer__c = ac.Id; }
		update vos;

		Service_Appointment__c appt = [SELECT Id FROM Service_Appointment__c LIMIT 1];
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = appt.Id, Event__c = CustAppAppt.EVENT_NAME);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppAppt.sendWebhook(callback);
		Test.stopTest();
		
	}

	@IsTest
	public static void testSendRemoveWebhook() {
		Service_Appointment__c appt = [SELECT Id, Vehicle_Ownership__c FROM Service_Appointment__c LIMIT 1];
		update new Vehicle_Ownership__c(Id = appt.Vehicle_Ownership__c, End_Date__c = Date.today());
		Customer_App_Callback__e callback = new Customer_App_Callback__e(Id__c = appt.Id, Event__c = CustAppAppt.REM_EVENT);
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppAppt.sendWebhook(callback);
		Test.stopTest();
		// refer to debug logs if there are any errors, no return value
	}

	@IsTest
	public static void testApptCls() {
		String query = 'SELECT ' + String.join(CustAppAppt.APPT_FIELDS, ',') + ' FROM Service_Appointment__c';
		List<Service_Appointment__c> apptList = Database.query(query);
		Test.startTest();
		CustAppAppt.ApptCls res = new CustAppAppt.ApptCls(apptList[0]);
		Test.stopTest();
		System.assertEquals(res.id, apptList[0].Id);
		System.assertEquals(res.name, apptList[0].Name);
	}

	@isTest
	public static void testPushToAbApp() {
		Service_Appointment__c sa = [SELECT Id FROM Service_Appointment__c LIMIT 1];
		Test.startTest();
		CustAppAppt.pushToAbApp(sa.Id);
		Test.stopTest();
	}

	@isTest
	public static void testValetCls() {
		Test.startTest();
		CustAppLocation.LocationCls pick = new CustAppLocation.LocationCls('unit', 'block', 'address', 1.0, 2.0);
		CustAppLocation.LocationCls drop = new CustAppLocation.LocationCls('unit', 'block', 'address', 1.0, 2.0);
		CustAppAppt.ValetCls valet = new CustAppAppt.ValetCls(pick, drop);
		Test.stopTest();
	}

	@isTest
	public static void testAltDriveCls() {
		Test.startTest();
		CustAppAppt.AltDriverCls ad = new CustAppAppt.AltDriverCls();
		Test.stopTest();
	}
}