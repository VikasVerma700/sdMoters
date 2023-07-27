global without sharing class CustAppRO {
	public final static String EVENT_NAME = 'UPSERT_VEHICLE_APPOINTMENT';
	public final static String REM_EVENT_NAME = 'REMOVE_VEHICLE_REPAIR_ORDER';
	public static List<String> RO_FIELDS;
	public static List<String> INV_FIELDS;
	public static List<String> PYMT_FIELDS;
	private final static Map<string, string> mapStatus;
	static {
		RO_FIELDS = new List<String> { 'Id', 'Name', 'Service_Order_Date__c', 'ACP_Service_Started__c', 'ACP_Service_Started_Remarks__c', 'Date_Cancelled__c',
										'ACP_Service_Completed__c', 'ACP_Service_Completed_Remarks__c', 'ACP_Ready_For_Collection__c', 'Closed_Date__c',
										'ACP_Ready_For_Collection_Remarks__c', 'Workshop__c', 'Remarks_for_Customer__c', 'VehicleOwnership__c',
										'Company__r.AbAppCompany__c', 'Account__c', 'Company__r.Name', 'CSA__c', 'Workshop__r.Name',
										'Workshop__r.Center_Description_for_Customer__c', 'Car_Released_Date__c', 'ContactName__c', 'ContactPhone__c',
										'ACP_Service_Started_DateTime__c', 'ACP_Service_Completed_DateTime__c', 'ACP_Ready_For_Collection_DateTime__c',
										'Status__c', 'StatusApp__c', 'CheckIn__c', 'CheckOut__c', 'RegistrationNo__c', 'PreRegService__c', 'CsaName__c',
										// 'OwnerId', // removed due to Lookup -> Master-Detail 
										'VehicleOwnership__r.OwnerId',
										'ServiceAppointment__c', 'ServiceAppointment__r.Id',
										'ContactAccNumber__c'
		};
		INV_FIELDS = new List<String> {
			'Id', 'Name', 'InvoiceDate__c', 'InvoiceValue__c', 'AccountNumber__c', 'RegistrationNumber__c',
			'ServiceDetails__c', 'Company__c', 'Workshop__c', 'RepairOrder__c', 'VehicleOwnership__c',
			'Account__c', 'Vehicle__c', 'PaymentRequired2__c', 'PaymentStatus__c', 'PaymentTimestamp__c',
			'PaymentMethod__c', 'PaymentTotal__c', 'PaymentReference__c', 'InvoiceReady__c', 'PaymentRequired__c',
			'InvoiceNumber__c', 'InvoiceKey__c', 'RoKey__c', 'ExternalId__c', 'CreatedFrom__c', 'OwnerId' };
		PYMT_FIELDS = new List<String> { 'Id', 'Name', 'Company__c', 'Workshop__c', 'Account__c', 'Amount__c', 'AuthCode__c', 'BankRefNumber__c', 'CurrencyCode__c', 'Gateway__c', 'HashValue1__c', 'HashValue2__c', 'IssuingBank__c', 'OrderNumber__c', 'PaymentMethod__c', 'QueryDescription__c', 'RespTime__c', 'ServiceId__c', 'SessionId__c', 'TotalRefundAmount__c', 'TxnExists__c', 'TxnId__c', 'TxnMessage__c', 'TxnStatus__c', 'TxnType__c' };
		RO_FIELDS.addAll(CustAppAPI.prefixFields(CustAppUser.EMPMASTER_FIELDS, 'CSA__r.'));
		RO_FIELDS.addAll(CustAppAPI.prefixFields(CustAppVehicle.VO_FIELDS, 'VehicleOwnership__r.'));
		// RO_FIELDS.addAll(CustAppAPI.prefixFields(CustAppAppt.APPT_FIELDS, 'ServiceAppointment__r.'));
		// INV_FIELDS.addAll(CustAppAPI.prefixFields(CustAppRO.PYMT_FIELDS, 'PaymentDetailEghl__r.'));
		mapStatus = new Map<string, string>{
			'Vehicle Check-In' => 'Your vehicle is checked-in.',
			'Service In Progress' => 'Service is in progress.',
			'Ready For Collection' => 'Your vehicle is ready for collection.',
			'Completed' => 'Thank you for servicing your vehicle with us, hope to see you soon again!'
		};
	}

	// called from trigger
	public static void pushNotificationOnStatusChange(Map<Id, ServiceOrder__c> newMap, Map<Id, ServiceOrder__c> oldMap) {
		System.debug('pushNotificationOnStatusChange.trigger');
		try {
			Set<Id> roId = new Set<Id>(newMap.keySet());
			String query =	'SELECT ' + String.join(RO_FIELDS, ',') + ' ' +
							'FROM ServiceOrder__c ' +
							'WHERE CheckIn__c != null ' +
							'AND ContactAccNumber__c = \'C0000002\' ' +
							// 'AND CSA__c != null ' +
							'AND StatusApp__c != null ' +
							'AND VehicleOwnership__c != null ' +
							'AND VehicleOwnership__r.Status__c = \'Active\' ' +
							'AND Id IN :roId ';
			// System.debug('query: ' + query.replace(':roId', JSON.serialize(roId)
			// 													.replace('[', '(')
			// 													.replace('"', '\'')
			// 													.replace(']', ')')));
			ServiceOrder__c[] roList = Database.query(query);
			Set<String> types = new Set<String>();
			Map<Id, Set<Id>> mapRoId = new Map<Id, Set<Id>>(); // VehicleOwnership__r.Id, AlternateDriver__r.Id, Account.Id
			for (ServiceOrder__c ro : roList) {
				if (ro.Service_Order_Date__c == null || ro.Service_Order_Date__c.daysBetween(Date.today()) >= 365) { continue; } // we dont send if > 1 yr
				Set<String> wsName = CustAppAppt.ALLOWED_WS.get(ro.Company__r.Name);
				if (wsName == null) { continue; }
				if (wsName.contains(ro.Workshop__r.Name)) {
					String curType = CustAppAccount.EXT_ACC_TYPE.get(ro.Company__r.Name);
					if (String.isNotBlank(curType)) { types.add(curType); }
					/** Gather per Repair Order VehicleOwnership__r.Id */
					if (mapRoId.containsKey(ro.Id)) { mapRoId.get(ro.Id).add(ro.VehicleOwnership__c); }
					else { mapRoId.put(ro.Id, new Set<Id>(new Id[] { ro.VehicleOwnership__c })); }
					/** Gather per Repair Order VehicleOwnership__r.Customer__r.Id */
					if (ro.VehicleOwnership__r.Customer__c != null) {
						if (mapRoId.containsKey(ro.Id)) { mapRoId.get(ro.Id).add(ro.VehicleOwnership__r.Customer__c); }
						else { mapRoId.put(ro.Id, new Set<Id>(new Id[] { ro.VehicleOwnership__r.Customer__c })); }
					}
				}
			}
			/** Prep Alt Driver account list for Push Notification */
			Set<Id> voSet = new Set<Id>();
			for (Set<Id> ids : mapRoId.values()) { voSet.addAll(ids); }
			Map<Id, Set<Id>> mapVoAcc = new Map<Id, Set<Id>>();
			Alternative_Driver__c[] altDList = [SELECT Id, Vehicle_Ownership__c, Account__c, Account__r.Mobile_Preferred__pc FROM Alternative_Driver__c WHERE
												Vehicle_Ownership__c = :voSet AND Status__c = 'Active' AND Type__c IN :types];
			for (Alternative_Driver__c altD :altDList) {
				if (altD.Account__c != null) {
					for (Id sid : mapRoId.keySet()) {
						Set<Id> subRo = (Set<Id>)mapRoId.get(sid);
						if (subRo.contains(altD.Vehicle_Ownership__c)) { subRo.add(altD.Account__c); }
					}
				}
			}
			/** Pull Ext. Account to determine if PN is necessary */
			Set<Id> accSet = new Set<Id>();
			for (Set<Id> ids: mapRoId.values()) { accSet.addAll(ids); }
			Map<Id, List<Customer_External_Account__c>> extAccMap = CustAppAccount.getExtAccounts(new List<Id>(accSet), types);

			Customer_App_Callback__e[] callback = new Customer_App_Callback__e[]{};
			Notification__c[] nts = new Notification__c[]{};
			for (ServiceOrder__c ro : roList) {
				ServiceOrder__c oldRO = (oldMap != null && oldMap.containsKey(ro.Id)) ? oldMap.get(ro.Id) : null;
				if (ro.Service_Order_Date__c == null || ro.Service_Order_Date__c.daysBetween(Date.today()) >= 365) { continue; } // we dont send if > 1 yr

				// /** Loop for Callback */
				// for (Id ids : mapRoId.get(ro.Id)) {
				// 	if (extAccMap.containsKey(ids)) {
				// 		// we create call back for new RO, if user triggered the change and if RO details changed via the refresh
				// 		if (oldRO == null || (!System.isBatch() && !System.isQueueable()) || isChanged(ro, oldRO)) {
				// 			Customer_App_Callback__e cb = new Customer_App_Callback__e();
				// 			cb.Id__c = ro.Id;
				// 			cb.Event__c = (ro.Date_Cancelled__c == null) ? CustAppRO.EVENT_NAME : CustAppRO.REM_EVENT_NAME;
				// 			callback.add(cb);
				// 		}
				// 		break; // 1 cb per loop is suffice;
				// 	}
				// }

				/** Loop for Push Notification */
				if (String.isBlank(ro.StatusApp__c) || ro.StatusApp__c == oldRO?.StatusApp__c) { continue; }
				Set<Id> idss = mapRoId.get(ro.Id);
				if (idss == null) { continue; }
				for (Id ids : mapRoId.get(ro.Id)) {
					if (!extAccMap.containsKey(ids)) { continue; }
					for (Customer_External_Account__c extAcc : extAccMap.get(ids)) {
						// string contactInRo = u.beautifyPhone(u.onlyPrefix(ro.ContactPhone__c), u.onlyNumber(ro.ContactPhone__c));
						// string contactInAcc = u.beautifyPhone(extAcc.Account__r.Mobile_Country_Code_1__pc, extAcc.Account__r.Mobile_Preferred__pc);
						// System.debug('(RO) ' + contactInRo + ' == ' + contactInAcc + ' (ACC) : ' + Boolean.valueOf(contactInRo == contactInAcc));
						// if (contactInRo != contactInAcc) { continue; }
						UtilPhone upPhoneInRo = new UtilPhone(ro.ContactPhone__c);
						UtilPhone upPhoneInAcc = new UtilPhone(extAcc.Account__r.PersonMobilePhone); 
						System.debug('(RO) ' + upPhoneInRo.toE164() + ' == ' + upPhoneInAcc.toE164() + ' (ACC) : ' + Boolean.valueOf(upPhoneInRo.toE164() == upPhoneInAcc.toE164()));
						if (upPhoneInRo.isMatch(upPhoneInAcc.toE164())) { continue; }
						/** Repair Order Status change. */
						Id recordTypeId = Schema.SObjectType.Notification__c.getRecordTypeInfosByName().get('Notification - Repair Order').getRecordTypeId();

						Notification__c nt = new Notification__c();
						nt.RecordTypeId = recordTypeId;
						nt.RepairOrder__c = ro.id;
						nt.Name = ro.Workshop__r.Center_Description_for_Customer__c;
						// nt.User__c = ro.VehicleOwnership__r.OwnerId;  // ro.OwnerId;
						nt.User__c = ro.OwnerId;
						nt.Company__c = ro.Company__c;
						nt.Account__c = extAcc.Account__c;
						nt.App_ID__c = CustAppAccount.EXT_ACC_TYPE.get(ro.Company__r.Name);
						nt.Ext_UUID__c = extAcc.UUID__c;
						nt.Message__c = mapStatus.get(ro.StatusApp__c);
						if (Envir.isSandbox) { nt.Message__c = ro.RegistrationNo__c + '/' + ro.Name + '/' + nt.Message__c; }
						/** Nav: pending discussion - relook into this later. */
						// CustAppNotification.NavCls nav = new CustAppNotification.NavCls();
						// nav.screen = 'SERVICE_ORDER_DETAILS';
						// nav.payload = new Map<string, string>{ 'uuid' => ''};
						// nt.Action__c = JSON.serialize(nav);
						nt.Data__c = JSON.serialize(new Map<string, string>{ 'Id' => ro.Id });
						nts.add(nt);
					}
				}
			}

			// if (callback.size() > 0) { 
			// 	System.debug('callback: ' + JSON.serialize(callback));
			// 	EventBus.publish(callback); 
			// }
			System.debug('RO Notification(s) to be sent (' + nts.size() + '): ' + JSON.serialize(nts));
			if (nts.size() > 0) {
				Database.SaveResult[] srs = Database.insert(nts);
			}
		} catch (Exception e) {
			String emailBody = CommonMethodsLibrary.constructErrEmail('Error from pushNotificationOnStatusChange', e.getStackTraceString(), e.getMessage());
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
		}
	}

	public static void sendWebhook(Customer_App_Callback__e callback) {
		String roId = callback.Id__c;
		String query =	'SELECT ' + String.join(RO_FIELDS, ',') + ' ' +
						', (SELECT Id, AccountNumber__c FROM ServiceInvoices__r WHERE AccountNumber__c = \'C0000002\') ' +
						'FROM ServiceOrder__c ' +
						'WHERE Id = :roId ' +
						// 'AND ContactAccNumber__c = \'C0000002\' ' +	// fix for RO changed Acc. Code to W before check-out as C
						'AND CSA__c != null ' +
						'AND StatusApp__c != null ' +
						'';
						// (NOT (ContactAccNumber__c LIKE \'I%\' OR ContactAccNumber__c IN (\'C0000001\', \'C1000009\')))';
		System.debug('RO query: ' + query);
		List<ServiceOrder__c> roList = Database.query(query);
		if (roList.size() <= 0) { return; }
		List<ServiceOrder__c> cleanRO = new List<ServiceOrder__c>();
		System.debug('RO: loop start');
		for (ServiceOrder__c ro : roList) {
			System.debug('RO: checks validity date.');
			if (ro.Service_Order_Date__c == null || ro.Service_Order_Date__c.daysBetween(Date.today()) >= 365) { continue; } // we dont send if > 1 yr
			System.debug('RO: date valid ' + ro.Service_Order_Date__c);

			System.debug('RO: checks allowed workshops.');
			Set<String> wsName = CustAppAppt.ALLOWED_WS.get(ro.Company__r.Name);
			if (wsName == null) { continue; }
			System.debug('RO: workshop allowed: ' + wsName);

			System.debug('RO: checks valid workshops.');
			if (!wsName.contains(ro.Workshop__r.Name)) { continue; }
			System.debug('RO: workshop valid ' + ro.Workshop__r.Name);

			/* Determine if RO & Invoice qualified to be sent to WHIP (Acc. No = C0000002 OR Invoice Acc. No = C0000002) */
			ServiceInvoice__c[] sis = ro.ServiceInvoices__r;

			System.debug('RO: check account number.');
			System.debug('ro: ' + ro.ContactAccNumber__c);
			if (sis.size() > 0) { System.debug('si: ' + sis[0]?.AccountNumber__c); }
			if (ro.ContactAccNumber__c != 'C0000002' && sis.size() == 0) { continue; }
			System.debug('RO: account number valid ' + ro.ContactAccNumber__c);
			if (sis.size() > 0) { System.debug('RO invoice acc. number valid: ' + sis[0]?.AccountNumber__c); }

			cleanRO.add(ro);
		}
		if (cleanRO.size() <= 0) { return; }
		Set<String> types = new Set<String>();
		Set<Id> saSet = new Set<Id>();
		Set<String> cmpName = new Set<String>();
		Set<Id> voSet = new Set<Id>();
		Set<Id> ownerIdSet = new Set<Id>();
		Set<Id> roIdSet = new Set<Id>();
		for (ServiceOrder__c ro : cleanRO) {
			String curType = CustAppAccount.EXT_ACC_TYPE.get(ro.Company__r.Name);
			if (String.isNotBlank(curType)) { types.add(curType); }
			if (ro.ServiceAppointment__c != null) { saSet.add(ro.ServiceAppointment__r.Id); }
			cmpName.add(ro.Company__r.Name);
			voSet.add(ro.VehicleOwnership__c);
			if (ro.VehicleOwnership__r.Customer__c != null)  { ownerIdSet.add(ro.VehicleOwnership__r.Customer__c); }
			roIdSet.add(ro.Id);
		}
		/** Service Invoice + Attachments - Only C0000002 */
		String sinvQuery =	'SELECT ' + String.join(CustAppRO.INV_FIELDS, ',') + ', ' +
							'(SELECT ' + String.join(CustAppFile.ATT_FIELDS, ',') + ' FROM Attachments WHERE Name LIKE \'Service Invoice%\') ' +
							'FROM ServiceInvoice__c ' +
							'WHERE AccountNumber__c = \'C0000002\' ' +
							'AND InvoiceReady__c = true ' +
							'AND InvoiceValue__c > 0 ' +
							'AND RepairOrder__c IN :roIdSet '
							;
		ServiceInvoice__c[] sis = Database.query(sinvQuery);
		System.debug('sis: ' + JSON.serialize(sis));
		Map<Id, ServiceInvoice__c[]> mapRoInv = new Map<Id, ServiceInvoice__c[]>();
		for (ServiceInvoice__c si :sis) {
			if (mapRoInv.containsKey(si.RepairOrder__c)) { mapRoInv.get(si.RepairOrder__c).add(si); }
			else { mapRoInv.put(si.RepairOrder__c, new ServiceInvoice__c[] { si }); }
		}
		// System.debug('mapRoInv: ' + JSON.serialize(mapRoInv));
		/** Service Appointment */
		String apptQuery = 'SELECT ' + String.join(CustAppAPPT.APPT_FIELDS, ',') + ' FROM Service_Appointment__c WHERE Id IN :saSet AND ' +
							'Company__r.Name IN :cmpName';
		List<Service_Appointment__c> apptList = Database.query(apptQuery);
		Map<String, Service_Appointment__c> roToApptMap = new Map<String, Service_Appointment__c>();
		for (Service_Appointment__c sa : apptList) {
			for (ServiceOrder__c ro : cleanRO) {
				if (sa.Id == ro.ServiceAppointment__r.Id) {
					roToApptMap.put(ro.Id, sa);
					break;
				}
			}
		}
		/** Include Alt D when sync to WHIP */
		Set<Id> altDSet = new Set<Id>();
		Alternative_Driver__c[] altDList = [SELECT Id, Account__c, Account__r.Mobile_Preferred__pc FROM Alternative_Driver__c WHERE
											Vehicle_Ownership__c = :voSet AND Status__c = 'Active' AND Type__c IN :types];
		for (Alternative_Driver__c altD :altDList) { altDSet.add(altD.Account__c); }
		Set<Id> accIdSet = new Set<Id>(ownerIdSet);
		accIdSet.addAll(altDSet);
		Map<Id, List<Customer_External_Account__c>> extAccMap = CustAppAccount.getExtAccounts(new List<Id>(accIdSet), types);
		List<Customer_External_Account__c> accounts = new List<Customer_External_Account__c>();
		for (Id accId : ownerIdSet) {
			List<Customer_External_Account__c> curExtAccList = extAccMap.get(accId);
			if (curExtAccList == null) { continue; }
			for (Customer_External_Account__c extAcc : curExtAccList) { accounts.add(extAcc); }
		}
		// if (accounts.size() <= 0) {
		for (Id accId : altDSet) {
			List<Customer_External_Account__c> curExtAccList = extAccMap.get(accId);
			if (curExtAccList == null) { continue; }
			for (Customer_External_Account__c extAcc : curExtAccList) { accounts.add(extAcc); }
		}
		// }
		if (accounts.size() <= 0) { return; }
		// System.debug('accounts: ' + JSON.serialize(accounts));

		// string[] hookBodies = new string[]{};
		Task[] tasks = new Task[]{};
		for (ServiceOrder__c ro : cleanRO) {
			for (Customer_External_Account__c custAcc : accounts) {
				String cmp = CustAppAccount.REV_TYPE.get(custAcc.Type__c);
				if (cmp == null) { continue; }

				// if (ro.VehicleOwnership__r.Customer__c != custAcc.Account__c
				// 	&& u.beautifyPhone(u.onlyPrefix(ro.ContactPhone__c), u.onlyNumber(ro.ContactPhone__c)) != u.beautifyPhone(custAcc.Account__r.Mobile_Country_Code_1__pc, custAcc.Account__r.Mobile_Preferred__pc)) { continue; }
				UtilPhone upContact = new UtilPhone(ro.ContactPhone__c);
				if (ro.VehicleOwnership__r.Customer__c != custAcc.Account__c && upContact.isMatch(custAcc.Account__r.PersonMobilePhone)) { continue; }
				String hookBody;
				String eventName;
				if (ro.Date_Cancelled__c != null || ro.VehicleOwnership__r.Status__c != 'Active') {
					RemoveROPayload payload = new RemoveROPayload(new List<ServiceOrder__c> { ro });
					RemoveROWebhook hook = new RemoveROWebhook(REM_EVENT_NAME, payload);
					eventName = hook.event;
					hookBody = JSON.serialize(hook);
				} else {
					Service_Appointment__c sa = roToApptMap.get(ro.Id);
					ServiceInvoice__c[] sinvs = mapRoInv.get(ro.Id);
					System.debug('ro.Id: ' + ro.Id);
					System.debug('sa: ' + JSON.serialize(sa));
					System.debug('sinvs: ' + JSON.serialize(sinvs));
					ROPayload payload = new ROPayload(ro, sa, sinvs);
					ROWebHook hook = new ROWebHook(EVENT_NAME, payload);
					eventName = hook.event;
					hookBody = JSON.serialize(hook, true);
				}
				// hookBodies.add(hookBody);
				CustAppAPI.sendWebhook(hookBody);
				
				/** Log API request/response as Task */
				string subj = eventName;
				Task task = CommonMethodsLibrary.createTask(custAcc.Account__r.PersonContactId, ro.Id, UserInfo.getUserId(), 'Automated Tasks',
															'System Generated Tasks', '', 'Low', subj, false, null);
				task.Status = 'Completed';
				task.ActivityDate = Date.today();
				task.Description = CustAppAPI.api?.toString();
				tasks.add(task);
				System.debug('task: ' + JSON.serialize(task));
			}
		}
		System.debug('Tasks: ' + JSON.serialize(tasks));
		if (tasks.size() > 0) {	Database.insert(tasks); }
	}

	// public static Boolean isChanged(ServiceOrder__c newRO, ServiceOrder__c oldRO) {
	// 	if (oldRO == null || oldRO.Id == null) { return true; }
	// 	List<String> fieldsToCheck = new List<String>();
	// 	// for (String f : RO_FIELDS) {
	// 	// 	if (!f.contains('.')) { fieldsToCheck.add(f); } // related fields not included
	// 	// }
	// 	fieldsToCheck = new string[] { 'StatusApp__c' };
	// 	for (String f : fieldsToCheck) {
	// 		if (!newRO.isSet(f) || !oldRO.isSet(f)) { return true; }
	// 		Object curVal = newRO.get(f);
	// 		Object prevVal = oldRO.get(f);
	// 		if (curVal != prevVal) { return true; }
	// 	}
	// 	return false;
	// }

	public static void processUpdateCallback() {
		String rtName = 'Service Invoice (ePG)';
		RestRequest req = RestContext.request;
		UpdateROWebhook reqBody = (UpdateROWebhook) JSON.deserialize(req.requestBody.toString(), UpdateROWebhook.class);
		if (reqBody == null) { throw new CustAppAPI.CustAppException('Empty request body.'); }
		if (reqBody.payload == null) { throw new CustAppAPI.CustAppException('Empty request payload.'); }
		if (reqBody.payload.repairOrder == null) { throw new CustAppAPI.CustAppException('Empty request payload repair order.'); }
		if (reqBody.payload.repairOrder.invoices == null) { throw new CustAppAPI.CustAppException('Empty request payload repair order invoice.'); }
		SvcInvCls[] invoices = reqBody.payload.repairOrder.invoices;
		Set<Id> setInvs = new Set<Id>();
		Set<String> setPymtId = new Set<String>();
		for (SvcInvCls invoice :invoices) {
			setInvs.add(invoice.id);
			if (invoice?.payment?.payload?.PaymentID != null) {
				setPymtId.add(invoice?.payment?.payload?.PaymentID);
			} 
		}
		Id rtEpay = Schema.SObjectType.PaymentDetail__c.getRecordTypeInfosByName().get(rtName).getRecordTypeId();
		string sinvQuery =	'SELECT ' + String.join(INV_FIELDS, ',') + ' ' +
							// ', (SELECT ' + String.join(PYMT_FIELDS, ',') + ' FROM PaymentDetails__r WHERE RecordTypeId = :rtEpay) ' +
							'FROM ServiceInvoice__c WHERE Id IN :setInvs';
		ServiceInvoice__c[] sis = Database.query(sinvQuery);
		Map<Id, ServiceInvoice__c> mapSvcInv = new Map<Id, ServiceInvoice__c>();
		for (ServiceInvoice__c si :sis) { mapSvcInv.put(si.Id, si);	}
		string pymtQuery =	'SELECT ' + String.join(PYMT_FIELDS, ',') + ' ' +
							'FROM PaymentDetail__c ' +
							'WHERE Name IN :setPymtId ' +
							'AND RecordTypeId = :rtEpay';
		PaymentDetail__c[] pyms = Database.query(pymtQuery);
		Map<string, PaymentDetail__c> mapPayment = new Map<String, PaymentDetail__c>();
		for (PaymentDetail__c pym :pyms) { mapPayment.put(pym.Name, pym); }
		/** Start updating PaymentDetail__c */
		for (SvcInvCls invoice :invoices) {
			ServiceInvoice__c si = mapSvcInv.get(invoice.id);
			PaymentDetail__c pym = new PaymentDetail__c();
			if (mapPayment.containsKey(invoice.payment.payload.PaymentID)) {
				/** Update */
				pym = mapPayment.get(invoice.payment.payload.PaymentID);
				MapToSObject(si.Company__c, si.Workshop__c, si.Account__c, invoice.payment.gateway, invoice.payment.payload, pym);
			}
			else {
				/** Create new */
				MapToSObject(si.Company__c, si.Workshop__c, si.Account__c, invoice.payment.gateway, invoice.payment.payload, pym);
				pym.PayForServiceInvoice__c = si.Id;
				pym.ReferenceNumber__c = invoice.payment.reference;
				pym.CreatedFrom__c = CustAppAccount.EXT_ACC_TYPE.get('028');
				mapPayment.put(pym.Name, pym);
			}
		}
		Database.UpsertResult[] urs = Database.upsert(mapPayment.values(), false);
		/** Start updating ServiceInvoice__c */
		for (SvcInvCls invoice :invoices) {
			ServiceInvoice__c si = mapSvcInv.get(invoice.id);
			PaymentDetail__c pym = mapPayment.get(invoice.payment.payload.PaymentID);
			si.PaymentStatus__c = invoice.payment.status == null ? si.PaymentStatus__c : invoice.payment.status;
			si.PaymentTimestamp__c = invoice.payment.dateAndTime;
			si.PaymentReference__c = invoice.payment.reference;
			si.PaymentMethod__c = invoice.payment.method; // Online payment
			// if (invoice.payment?.status?.equalsIgnoreCase('SUCCESS')) { si.PaymentRequired2__c = false; }
		}
		Database.SaveResult[] srs = Database.update(mapSvcInv.values(), false);
	}

	private static void MapToSObject(Id companyId, Id workshopId, Id accountId, string gateway, PaymentPayloadCls objFr, PaymentDetail__c objTo) {
		objTo.Company__c = companyId == null ? objTo.Company__c : companyId;
		objTo.Workshop__c = workshopId == null ? objTo.Workshop__c : workshopId;
		objTo.Account__c = accountId == null ? objTo.Account__c : accountId;
		objTo.Name = objFr.PaymentID;
		objTo.Amount__c = objFr.Amount;
		objTo.AuthCode__c = objFr.AuthCode;
		objTo.BankRefNumber__c = objFr.BankRefNo;
		objTo.CurrencyCode__c = objFr.CurrencyCode;
		objTo.Gateway__c = gateway;
		objTo.HashValue1__c = objFr.HashValue;
		objTo.HashValue2__c = objFr.HashValue2;
		objTo.IssuingBank__c = objFr.IssuingBank;
		objTo.OrderNumber__c = objFr.OrderNumber;
		objTo.PaymentMethod__c = objFr.PymtMethod;
		objTo.QueryDescription__c = objFr.QueryDesc;
		objTo.RespTime__c = objFr.RespTime;
		objTo.ServiceId__c = objFr.ServiceID;
		objTo.SessionId__c = objFr.SessionID;
		objTo.TotalRefundAmount__c = objFr.TotalRefundAmount;
		objTo.TxnExists__c = objFr.TxnExists;
		objTo.TxnId__c = objFr.TxnID;
		objTo.TxnMessage__c = objFr.TxnMessage;
		objTo.TxnStatus__c = objFr.TxnStatus;
		objTo.TxnType__c = objFr.TransactionType;
	}

	/** Button: Resync To AB App (ServiceOrder__c) */
	Webservice static string pushToAbApp(Id roId) {
		try {
			Customer_App_Callback__e cb = new Customer_App_Callback__e();
			cb.Id__c = roId;
			cb.Event__c = EVENT_NAME;
			EventBus.publish(new List<Customer_App_Callback__e>{ cb });
			return 'Done!';
		}
		catch (Exception e) {
			return 'Error: ' + e.getMessage() + (Envir.isSandbox ? '\n\n' + e.getStackTraceString() : '');
		}
	}
	global class ROWebHook {
		public String event;
		public ROPayload payload;
		global ROWebHook(String event, ROPayload payload) {
			this.event = event;
			this.payload = payload;
		}
	}

	global class ROPayload {
		public ROInfo vehicle;
		public ROPayload(ServiceOrder__c ro, Service_Appointment__c sa) {
			this.vehicle = new ROInfo(ro, sa);
		}
		public ROPayload(ServiceOrder__c ro, Service_Appointment__c sa, ServiceInvoice__c[] sis) {
			this(ro, sa);
			this.vehicle.repairOrder = new ROCls(ro, sis);
		}
	}

	global class RemoveROWebhook {
		public String event;
		public RemoveROPayload payload;
		global RemoveROWebhook(String event, RemoveROPayload payload) {
			this.event = event;
			this.payload = payload;
		}
	}

	global class RemoveROPayload {
		public List<RemoveROInfo> vehicles;
		global RemoveROPayload(List<ServiceOrder__c> roList) {
			this.vehicles = new List<RemoveROInfo>();
			for (ServiceOrder__c ro : roList) {
				this.vehicles.add(new RemoveROInfo(ro));
			}
		}
	}

	global class RemoveROInfo {
		public String identificationNumber;
		public String id;
		global RemoveROInfo(ServiceOrder__c ro) {
			this.identificationNumber = ro.VehicleOwnership__r.Vehicle__r.Name;
			this.id = ro.Id;
		}
	}

	global class ROInfo {
		public String identificationNumber;
		public CustAppAppt.ApptCls appointment;
		public ROCls repairOrder;
		public ROInfo(ServiceOrder__c ro, Service_Appointment__c appt) {
			this.identificationNumber = ro.VehicleOwnership__r.Vehicle__r.Name;
			this.repairOrder = new ROCls(ro);
			if (appt != null) {
				this.appointment = new CustAppAppt.ApptCls(appt);
				this.repairOrder.appointmentId = appt.Id;
			}
		}
		public ROInfo(ServiceOrder__c ro, Service_Appointment__c appt, ServiceInvoice__c[] sis) {
			this(ro, appt);
			this.repairOrder = new ROCls(ro, sis);
		}
		public ROInfo() {}
	}

	global class ROCls {
		public transient ServiceOrder__c ro;
		public String appointmentId;
		public String id;
		public String name;
		public DateTime dateAndTime;
		public List<ROStatusCls> statuses;
		public Boolean displayInProgress;
		public String workshopId;
		public CustAppUser.UserCls serviceAdvisor;
		public String company;
		public List<CustAppFile.FileCls> documents;
		public List<SvcInvCls> invoices;
		public String paymentType;
		public String paymentStatus;
		public String remarks;
		public CustAppAppt.AltDriverCls alternateDriver;
		public CustAppSurvey.SurveyCls eSurvey;
		global ROCls() {}
		global ROCls(ServiceOrder__c ro) {
			if (ro == null) { return; }
			this.ro = ro;
			this.id = ro.Id;
			this.name = ro.Name;
			this.appointmentId = (ro.ServiceAppointment__c == null) ? null : ro.ServiceAppointment__c;
			this.dateAndTime = (ro.Service_Order_Date__c == null) ? null : DateTime.newInstance(ro.Service_Order_Date__c, Time.newInstance(0,0,0,0));
			this.displayInProgress = /* ro.Car_Released_Date__c == null && */ ro.CheckOut__c == null;
			if (/* ro.Service_Order_Date__c == Date.today() && */ this.displayInProgress) {
				this.statuses = this.listStatuses(ro);
			} else {
				this.statuses = this.completedStatus(ro);
			}
			this.workshopId = ro.Workshop__c;
			// this.serviceAdvisor = (ro.CSA__c != null) ? new CustAppUser.UserCls(ro.CSA__r) : null;
			if (ro.CSA__c != null) { this.serviceAdvisor = new CustAppUser.UserCls(ro.CSA__r); }
			else {
				CustAppUser.UserCls em = new CustAppUser.UserCls();
				em.name = ro.CsaName__c;
				this.serviceAdvisor = em;
			}
			this.alternateDriver = new CustAppAppt.AltDriverCls(ro.ContactName__c, ro.ContactPhone__c, '');
			this.company = ro.Company__r.AbAppCompany__c;
			this.documents = this.listDocs(ro);
			this.remarks = (String.isBlank(ro.Remarks_for_Customer__c)) ? '' : ro.Remarks_for_Customer__c;
			// this.displayInProgress = (ro.CheckOut__c == null);
			/* 2020-01-29: AB's request to hide status progression. */
			// this.displayInProgress = false;
		}
		global ROCls(ServiceOrder__c ro, ServiceInvoice__c[] sis) {
			this(ro);
			CustAppRO.SvcInvCls[] invoices = new CustAppRO.SvcInvCls[]{};
			CustAppFile.FileCls[] documents = new CustAppFile.FileCls[]{};
			if (sis != null) {
				for (ServiceInvoice__c si :sis) {
					invoices.add(new CustAppRO.SvcInvCls(si));
					for (Attachment att :si.Attachments) { documents.add(new CustAppFile.FileCls(att)); }
				}
			}
			this.invoices = invoices;
			this.documents = documents;
		}

		public List<ROStatusCls> listStatuses(ServiceOrder__c ro) {
			// TODO: add datetime for updates in the future
			List<ROStatusCls> statuses = new List<ROStatusCls>{
				new ROStatusCls('Vehicle Check-In', ro.ACP_Service_Started_Remarks__c, ro.ACP_Service_Started_DateTime__c, ro.ACP_Service_Completed__c || ro.ACP_Service_Started_DateTime__c != null),
				// new ROStatusCls('Service Started', ro.ACP_Service_Started_Remarks__c, ro.ACP_Service_Started_DateTime__c, ro.ACP_Service_Completed__c || ro.ACP_Service_Started_DateTime__c != null),
				new ROStatusCls('Service In Progress', ro.ACP_Service_Completed_Remarks__c, ro.ACP_Service_Completed_DateTime__c, ro.ACP_Ready_for_Collection__c || ro.ACP_Service_Completed_DateTime__c != null),
				new ROStatusCls('Ready For Collection', ro.ACP_Ready_For_Collection_Remarks__c, ro.ACP_Ready_For_Collection_DateTime__c, ro.CheckOut__c != null || ro.ACP_Ready_For_Collection_DateTime__c != null),
				new ROStatusCls('Completed','', null, false)
			};
			return statuses;
		}

		public List<ROStatusCls> completedStatus(ServiceOrder__c ro) {
			List<ROStatusCls> statuses = new List<ROStatusCls>{
				new ROStatusCls('Completed','', null, true)
			};
			return statuses;
		}

		public List<CustAppFile.FileCls> listDocs(ServiceOrder__c ro) {
			List<CustAppFile.FileCls> res = new List<CustAppFile.FileCls>();
			for (Attachment att : ro.Attachments) {
				if (isROFile(att)) { res.add(new CustAppFile.FileCls(att)); }
			}
			return res;
		}

		public Boolean isROFile(Attachment att) {
			return false; // TODO
		}
	}

	global class ROStatusCls {
		public String title;
		public String message;
		public DateTime dateAndTime;
		public String status;
		global ROStatusCls(String title, String message, DateTime dateAndTime, Boolean completed) {
			this.title = title;
			this.message = message;
			this.dateAndTime = dateAndTime;
			this.status = (completed) ? 'COMPLETED' : '';
		}
	}
	public class SvcInvCls {
		public string id;
		public string name;
		public string documentId;
		public PaymentCls payment;
		public SvcInvCls(ServiceInvoice__c si) {
			this.id = si.Id;
			this.name = si.Name;
			/** Get associated Service Document id. */
			Attachment[] atts = si.Attachments;
			if (atts != null && atts.size() > 0) {
				for (Attachment att :atts) {
					if (att.Name.startsWith('Service Invoice')) {
						this.documentId = att.Id;
						break;
					}
				}
			}
			this.payment = new PaymentCls(si);
		}
	}
	public class PaymentCls {
		public Boolean isRequired;
		public string status;
		public Datetime dateAndTime;
		public string method;
		public CurrencyCls payableAmount;
		public PaymentPayloadCls payload; // = new PaymentPayloadCls();
		public string reference; // receipt reference #
		public string gateway;	// payment gateway name
		public PaymentCls(ServiceInvoice__c si) {
			isRequired = si.PaymentRequired2__c;
			status = si.PaymentStatus__c == null ? 'PENDING' : si.PaymentStatus__c;
			dateAndTime = si.PaymentTimestamp__c; // si.InvoiceDate__c;
			method = si.PaymentMethod__c;
			payableAmount = new CurrencyCls('MYR', si.InvoiceValue__c);
		}
	}
	public class CurrencyCls {
		public Decimal value;
		public string valueCurrency;
		public CurrencyCls(string curCode, Decimal value) {
			this.valueCurrency = curCode;
			this.value = value;
		}
	}
	public class PaymentPayloadCls {
		public decimal Amount;
		public string AuthCode;
		public string BankRefNo;
		public string CurrencyCode;
		public string HashValue;
		public string HashValue2;
		public string IssuingBank;
		public string OrderNumber;
		public string PaymentID;
		public string PymtMethod;
		public string QueryDesc;
		public string RespTime;
		public string ServiceID;
		public string SessionID;
		public decimal TotalRefundAmount;
		public string TransactionType;
		public string TxnExists;
		public string TxnID;
		public string TxnMessage;
		public string TxnStatus;
	}
	public class UpdateROWebhook {
		public string event;
		public ROInfo payload;
	}
}