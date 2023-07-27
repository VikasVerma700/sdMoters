/**
	Author	: Cw Tham (cw.tham@hyundai.com.my)	
	Date	: 2019-07-31
	Name	: ServiceOrderThankYouSms
	Function:
		Retrieve all service history with:
			CheckOutDate__c	= :YESTERDAY 
			SmsRetCode__c	= ""
		Send Thank You sms.
		Batch size: 10.
	Changelog:
	20190731	Creation of class.
 */

global class ServiceOrderThankYouSms implements Database.Batchable<SObject>,
												Database.AllowsCallouts,
												Database.Stateful,
												Schedulable {
	private final static String CTRY_PREFIX = '+60';
	private final static String DEF_NUM = '+60192651650';
	// private final static String DEF_TXT = 'Dear Valued Customer, Thank you for your recent BMW service visit. Please rate us ‘10’ in the customer survey if our service has met your satisfaction.';
	private final static String DEF_TXT = 'Thank you for servicing your vehicle with Auto Bavaria. Feel free to contact us at 1300133338 if you have any feedback.';
	private final static String REC_LINK = URL.getSalesforceBaseUrl().toExternalForm() + '/';

/** Batch size. */
	public static final integer scopeSize = 10;
	public string query;

/** Private variables. */
	private string mailBody;

/** Create Schedule Job */
	public static string scheduleJob() {
		string name = 'Thank You SMS';
		string jobName = (Test.isRunningTest() ? '[Test] ' + name: name);
		return System.schedule(jobName, '0 0 10 * * ?', new ServiceOrderThankYouSms());
	}

/** Constructors */
	global ServiceOrderThankYouSms() {
		mailBody = '';
		query = Database.getQueryLocator([
			SELECT
				Id, Name, ContactPhone__c, SmsRetCode__c, SmsStatus__c
				, WorkshopCode__c, ExternalId__c, CompanyCode__c, ChassisNo__c
				, RepairOrderNo__c, ContactAccNumber__c
			FROM ServiceOrder__c
			WHERE CheckOut__c = YESTERDAY
			AND SmsRetCode__c = ''
			LIMIT 10
		]).getQuery().replace('LIMIT 10', ' ');
	}

/** Scheduler methods. */
	global void execute(SchedulableContext sc) {
		ServiceOrderThankYouSms a = new ServiceOrderThankYouSms();
		Database.executeBatch(a, scopeSize);
	}

/** Database.Batchable methods. */
	global Database.QueryLocator start(Database.BatchableContext BC) {
		mailBody += 'Service Order Thank You SMS sender:\n\n' +
			'Name\tPhone No.\tStatus\tRemark\n';
		return Database.getQueryLocator(query);
	}

	global void execute(Database.BatchableContext BC, List<SObject> scope) {
		Map<Id, RepoObj> mapRepoObj = new Map<Id, RepoObj>();
		Task[] tasks = new List<Task>();
		for (SObject s :scope) {
			ServiceOrder__c so = (ServiceOrder__c) s;
			mapRepoObj.put(so.Id, new RepoObj(so));
System.debug('test: ' + JSON.serialize(so));
			string smsRet;
			try {
				if (so.WorkshopCode__c == 'AK' || so.WorkshopCode__c == 'AQ' || so.WorkshopCode__c == 'AY') {
					smsRet = so.WorkshopCode__c;
				}
				else if (String.isBlank(so.ContactPhone__c) || (so.ContactAccNumber__c != null && so.ContactAccNumber__c.startsWith('I'))) {
					smsRet = 'Sk';
				}
				else {
					smsRet = sendSms(so, DEF_TXT);
					/** Create Activity for actual SMS sent. */
					Task task = CommonMethodsLibrary.createTask(null, so.Id, Envir.USER_CUR.Id, 'Automated Tasks', 'System Generated Tasks', '', 'Low',
										'Thank You SMS', false, null);
					task.Status = 'Completed';
					task.ActivityDate = Date.today();
					task.Description = 'Result:' + smsRet + '\nText:' + DEF_TXT;
					tasks.add(task);
				}
				so.SmsRetCode__c = smsRet.length() > 2 ? smsRet.left(2) : smsRet;
			}
			catch (Exception e) { mapRepoObj.get(so.Id).Remark += '\tError: ' + e.getMessage(); }
			finally {}
		}
		/** Update ServiceOrder__c batch with SMS status code. */
		Database.SaveResult[] sr;
		sr = Database.update(scope, false);
		sr = Database.insert(tasks);

		/** Retrieve updated ServiceOrder__c for mailBody */
		ServiceOrder__c[] sos = [
			SELECT
				Id, Name, ContactPhone__c, SmsRetCode__c, SmsStatus__c
				, WorkshopCode__c, ExternalId__c, CompanyCode__c, ChassisNo__c
				, RepairOrderNo__c, ContactAccNumber__c
			FROM ServiceOrder__c
			WHERE Id IN :mapRepoObj.keySet()
		];
		for (ServiceOrder__c so :sos) {
			RepoObj ro = mapRepoObj.get(so.Id);
			mailBody += String.format('{0}\t{1}\t{2} - {3}\t{4}\n', new object[] {
							so.Name, so.ContactPhone__c, so.SmsRetCode__c, so.SmsStatus__c, mapRepoObj.get(so.Id).Remark
						});
		}
	}

	global void finish(Database.BatchableContext BC) {
		mailBody += '\nDone!';
		Messaging.Singleemailmessage em = new Messaging.Singleemailmessage();
		string senderName = '';
		string recipient = '';
		if (Envir.isSandbox) {
			senderName = 'ABD Sandbox';
			recipient = String.format('rx0ug.sfdx+abd.{0}@gmail.com', new string[] { Envir.sbSuffix });
			// recipient = String.format('cw.tham@simedarby.com', new string[] { Envir.sbSuffix });
		}
		else {
			senderName = 'ABD Production';
			// recipient = 'rx0ug.sfdx+abd.prd@gmail.com';
			recipient = String.format('cw.tham@simedarby.com', new string[] { Envir.sbSuffix });
		}
		em.setSenderDisplayName(senderName);
		em.setToAddresses(new string[] { recipient });
		em.setSubject('ServiceOrderThankYouSms Batch');		
		em.setPlainTextBody(mailBody);
		
		if (!Test.isRunningTest()) { Messaging.sendEmail(new Messaging.Singleemailmessage[] { em }); }
	}

/** Send SMS wrapper method. */
	@TestVisible private static string sendSms(ServiceOrder__c so, string smsText) {
		/** Compose key. */
		string shortVin = '';
		try {
			if (so.ChassisNo__c.trim().length() >= 6) { shortVin = so.ChassisNo__c.right(6); }
			else { shortVin = so.ChassisNo__c.right(so.ChassisNo__c.trim().length()); }
		}
		catch (Exception e) { }
		// string key = string.format('TQ{0}{1}{2}{3}', new string[] { so.CompanyCode__c, so.WorkshopCode__c, so.RepairOrderNo__c, shortVin }).trim();
		string key = string.format('TQ{0}{1}{2}{3}', new string[] { Datetime.now().format('yyMMdd'), so.CompanyCode__c, so.WorkshopCode__c, so.RepairOrderNo__c, shortVin }).trim();
		/** Service Id. */
		string serviceId = string.format('{0}_{1}_{2}_TQ', new string[] { (Envir.isSandbox ? 'Sbox' : 'Prod'), so.CompanyCode__c, so.WorkshopCode__c });
		/** Recipient number. */	
		string recipientNumber = u.sandboxPhone(String.valueOf(u.onlyPrefix(so.ContactPhone__c)), u.onlyNumber(so.ContactPhone__c), Envir.isSandbox, new List<String>{ DEF_NUM });

		string ret;
		if (Envir.isSandbox && !Test.isRunningTest()) { ret = '00,sbox'; }
		else {
			ret = M3TechApiWrapper.deliverMessage2(key, serviceId, smsText, recipientNumber);
		}
		return string.format('{0} ({1})', new string[] { ret, recipientNumber });
	}
	
	private class RepoObj {
		public string Remark;
		public ServiceOrder__c SvcOrd;
		public RepoObj(ServiceOrder__c so) {
			this.Remark = String.format('{0}{1}', new string[] { REC_LINK, so.Id });
			this.SvcOrd = so;
		}
	}
}