public class ServiceInvoiceHandler extends TriggerBase {
	public static final String TRIG_SETTING = 'Service Invoice';
	public static String[] INV_FIELDS = CustAppRO.INV_FIELDS;
	static {
		INV_FIELDS.addAll(new string[] { 'Company__r.Name', 'Workshop__r.Name', 'Workshop__r.Center_Description_for_Customer__c' });
		INV_FIELDS.addAll(CustAppAPI.prefixFields(CustAppRO.RO_FIELDS, 'RepairOrder__r.'));
		INV_FIELDS.addAll(CustAppAPI.prefixFields(CustAppVehicle.VO_FIELDS, 'VehicleOwnership__r.'));
	}

    public ServiceInvoiceHandler() { super(TRIG_SETTING, 6); }

	public override void afterInsert(Map<Id, SObject> triggerNew) {
		pushNotificationOnPaymentRequest((Map<Id, ServiceInvoice__c>) triggerNew, new Map<Id, ServiceInvoice__c>());
	}

	public override void afterUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
		pushNotificationOnPaymentRequest((Map<Id, ServiceInvoice__c>) triggerNew, (Map<Id, ServiceInvoice__c>) triggerOld);
	}

	public static void pushNotificationOnPaymentRequest(Map<Id, ServiceInvoice__c> newMap, Map<Id, ServiceInvoice__c> oldMap) {
		System.debug('pushNotificationOnPaymentRequest.trigger');
		try {
			Set<Id> sinvId = new Set<Id>(newMap.keySet());
			String query =	'SELECT ' + String.join(INV_FIELDS, ',') + ' ' +
							'FROM ServiceInvoice__c ' +
							'WHERE AccountNumber__c = \'C0000002\' ' +
							'AND InvoiceReady__c = true ' +
							'AND InvoiceValue__c > 0 ' + 
							'AND PaymentRequired2__c = true ' +
							'AND PaymentStatus__c != \'SUCCESS\' ' +
							'AND Id IN :sinvId '
							;
			System.debug('query: ' + query.replace(':sinvId', JSON.serialize(sinvId)
																	.replace('[', '(')
																	.replace('"', '\'')
																	.replace(']', ')')));
			ServiceInvoice__c[] sinvList = Database.query(query);
			System.debug('sinvList: ' + JSON.serialize(sinvList));
			Set<String> types = new Set<String>();
			Map<Id, Set<Id>> mapSinvId = new Map<Id, Set<Id>>(); // VehicleOwnership__r.Id, AlternateDriver__r.Id, Account.Id
			for (ServiceInvoice__c sinv : sinvList) {
				Set<String> wsName = CustAppAppt.ALLOWED_WS.get(sinv.Company__r.Name);
				if (wsName == null) { continue; }
				if (wsName.contains(sinv.Workshop__r.Name)) {
					String curType = CustAppAccount.EXT_ACC_TYPE.get(sinv.Company__r.Name);
					if (String.isNotBlank(curType)) { types.add(curType); }
					/** Gather per Service Invoice VehicleOwnership__r.Id */
					if (mapSinvId.containsKey(sinv.Id)) { mapSinvId.get(sinv.Id).add(sinv.VehicleOwnership__c); }
					else { mapSinvId.put(sinv.Id, new Set<Id>(new Id[] { sinv.VehicleOwnership__c })); }
					/** Gather per Service Invoice VehicleOwnership__r.Customer__r.Id */
					if (sinv.VehicleOwnership__r.Customer__c != null) {
						if (mapSinvId.containsKey(sinv.Id)) { mapSinvId.get(sinv.Id).add(sinv.VehicleOwnership__r.Customer__c); }
						else { mapSinvId.put(sinv.Id, new Set<Id>(new Id[] { sinv.VehicleOwnership__r.Customer__c })); }
					}
				}
			}
			/** Prep Alt Driver account list for Push Notification */
			Set<Id> voSet = new Set<Id>();
			for (Set<Id> ids : mapSinvId.values()) { voSet.addAll(ids); }
			Map<Id, Set<Id>> mapVoAcc = new Map<Id, Set<Id>>();
			Alternative_Driver__c[] altDList = [SELECT Id, Vehicle_Ownership__c, Account__c, Account__r.Mobile_Preferred__pc FROM Alternative_Driver__c WHERE
												Vehicle_Ownership__c = :voSet AND Status__c = 'Active' AND Type__c IN :types];
			for (Alternative_Driver__c altD :altDList) {
				if (altD.Account__c != null) {
					for (Id sid : mapSinvId.keySet()) {
						Set<Id> subRo = (Set<Id>)mapSinvId.get(sid);
						if (subRo.contains(altD.Vehicle_Ownership__c)) { subRo.add(altD.Account__c); }
					}
				}
			}
			/** Pull Ext. Account to determine if PN is necessary */
			Set<Id> accSet = new Set<Id>();
			for (Set<Id> ids: mapSinvId.values()) { accSet.addAll(ids); }
			Map<Id, List<Customer_External_Account__c>> extAccMap = CustAppAccount.getExtAccounts(new List<Id>(accSet), types);

			Customer_App_Callback__e[] callback = new Customer_App_Callback__e[]{};
			Notification__c[] nts = new Notification__c[]{};
			for (ServiceInvoice__c sinv : sinvList) {
				ServiceInvoice__c oldSinv = (oldMap != null && oldMap.containsKey(sinv.Id)) ? oldMap.get(sinv.Id) : null;
				System.debug(sinv.RepairOrder__r.Name + '/' + sinv.Name);
				if (sinv.RepairOrder__r.Service_Order_Date__c == null || sinv.RepairOrder__r.Service_Order_Date__c.daysBetween(Date.today()) >= 365) { continue; } // we dont send if > 1 yr

				// /** Loop for Callback */
				// for (Id ids : mapSinvId.get(sinv.Id)) {
				// 	if (extAccMap.containsKey(ids)) {
				// 		// we create call back for new RO, if user triggered the change and if RO details changed via the refresh
				// 		if (oldSinv == null || (!System.isBatch() && !System.isQueueable()) || isChanged(sinv, oldSinv)) {
				// 			Customer_App_Callback__e cb = new Customer_App_Callback__e();
				// 			cb.Id__c = sinv.Id;
				// 			cb.Event__c = (sinv.Date_Cancelled__c == null) ? CustAppRO.EVENT_NAME : CustAppRO.REM_EVENT_NAME;
				// 			callback.add(cb);
				// 		}
				// 		break; // 1 cb per loop is suffice;
				// 	}
				// }

				/** Loop for Push Notification */
				if (sinv.PaymentRequired2__c != true || sinv.PaymentRequired2__c == oldSinv?.PaymentRequired2__c) { continue; }
				Set<Id> idss = mapSinvId.get(sinv.Id);
				if (idss == null) { continue; }
				for (Id ids : mapSinvId.get(sinv.Id)) {
					if (!extAccMap.containsKey(ids)) { continue; }
					for (Customer_External_Account__c extAcc : extAccMap.get(ids)) {
						string contactInSinv = u.beautifyPhone(u.onlyPrefix(sinv.RepairOrder__r.ContactPhone__c), u.onlyNumber(sinv.RepairOrder__r.ContactPhone__c));
						string contactInAcc = u.beautifyPhone(extAcc.Account__r.Mobile_Country_Code_1__pc, extAcc.Account__r.Mobile_Preferred__pc);
						System.debug('(SInv) ' + contactInSinv + ' == ' + contactInAcc + ' (ACC) : ' + Boolean.valueOf(contactInSinv == contactInAcc));
						if (contactInSinv != contactInAcc) { continue; }

						/** Service Invoice Payment Required. */
						System.debug('Notification Payment (' + contactInSinv + '): ' + JSON.serialize(extAcc));
						Id recordTypeId = Schema.SObjectType.Notification__c.getRecordTypeInfosByName().get('Notification - Service Invoice').getRecordTypeId();

						Notification__c nt = new Notification__c();
						nt.RecordTypeId = recordTypeId;
						nt.ServiceInvoice__c = sinv.id;
						nt.Name = sinv.Workshop__r.Center_Description_for_Customer__c;
						nt.User__c = sinv.OwnerId;
						nt.Company__c = sinv.Company__c;
						nt.Account__c = extAcc.Account__c;
						nt.App_ID__c = CustAppAccount.EXT_ACC_TYPE.get(sinv.Company__r.Name);
						nt.Ext_UUID__c = extAcc.UUID__c;
						nt.Message__c = 'Your invoice is ready for payment';
						if (Envir.isSandbox) { nt.Message__c = sinv.RegistrationNumber__c + '/' + sinv.RepairOrder__r.Name + '/' + sinv.name + '/' + nt.Message__c; }
						/** Nav: pending discussion - relook into this later. */
						// CustAppNotification.NavCls nav = new CustAppNotification.NavCls();
						// nav.screen = 'SERVICE_ORDER_DETAILS';
						// nav.payload = new Map<string, string>{ 'uuid' => ''};
						// nt.Action__c = JSON.serialize(nav);
						nt.Data__c = JSON.serialize(new Map<string, string>{ 'Id' => sinv.Id });
						nts.add(nt);
					}
				}
			}
			// if (callback.size() > 0) { 
			// 	System.debug('callback: ' + JSON.serialize(callback));
			// 	EventBus.publish(callback); 
			// }
			System.debug('SInv Notification(s) to be sent (' + nts.size() + '): ' + JSON.serialize(nts));
			if (nts.size() > 0) {
				Database.insert(nts);
			}

		}
		catch (Exception e) {
			System.debug(e.getTypeName() + ': ' + e.getMessage() + '\n\n' + e.getStackTraceString());
			String emailBody = CommonMethodsLibrary.constructErrEmail('Error from pushNotificationOnPaymentRequest', e.getStackTraceString(), e.getMessage());
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
		}
	}
}