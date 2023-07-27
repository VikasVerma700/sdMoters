// instance-specific configuration
public class z
{
	public static Map<string, object> pref = new Map<string, object> {
		'case:type'			=> new Map<string, string> {
			'closed'		=> 'Case Closed',
			'complaint'		=> 'Complaint',
			'draft'			=> 'Complaint (Draft)',
			'enquiry'		=> 'General Enquiry',
			'compliment'	=> 'Compliment'
		},
		'case:owner' => new List<string> { 'Queue', 'CFM_Owners' },
		'case:managing_director'	=> 'Vi Thim Juan',
		'case:creator_role'			=> 'Case Creator',
		'case:letterhead'			=> 'https://c.ap1.content.force.com/servlet/servlet.ImageServer?id=01590000000edl1&oid=00D90000000gD15',

		// notification

		'case:bcc' => new List<string> {
			'cw.tham@simedarby.com','harsh_c@iconresources.com'
		},

		'case:template' => new Map<string, string> {
			'draft'					=> 'Apex CFM Draft Mode',
			'open'					=> 'Apex CFM Creation',
			'hold'					=> 'Apex CFM On Hold',
			'notify'				=> 'Apex Notification Priority',
			'assign-complaint'		=> 'Apex CFM Assignment',
			'assign-noncomplaint'	=> 'Apex CFM Non-complaint',
			'no_md_comment'			=> 'Apex Reminder MD Comments',
			'new_md_comment'		=> 'Apex New Comment by MD',
			'escalate'				=> 'Apex CFM Escalation',
			'close'					=> 'Apex CFM Close'
		},

		// assignment

		'case:fieldmap'	=> new Map<string, string> {
			'company'	=> 'Operating_Unit__c',
			'branch'	=> 'Incident_Location__c',
			'dept'		=> 'Department__c',
			'make'		=> 'Make__c',
			'stage'		=> 'EscalationStage__c'
		},
		'case:pattern'				=> new List<string> { 'cbdms', 'cbds', 'cds', 'cbs', 'cs', 'cbdm', 'cbd','cd','cb' },
		'case:companies'			=> new Map<string, string> { null => null },
		'case:branches'				=> new Map<string, string> {
			'AB Ara Damansara'		=> 'ARAD',
			'AB Kuala Lumpur'		=> 'KL',
			'AB Sg Besi'			=> 'SB',
			'AB Balakong'			=> 'BLK',
			'AB Penang'				=> 'PNG',
			'AB Johor Bahru'		=> 'JB',
			'AB Tebrau'				=> 'TB',	// 3S

			'AB Chan Sow Lin'		=> 'CSL',	// 2S
			'AB Sungai Pinang'		=> 'SPNG',	// 2S
			
			'BMW Premium Selection'	=> 'BPS',

			'AB Glenmarie'			=> 'GLEN',	// deprecated
			null					=> 'ARAD'
		},
		'case:depts'				=> new Map<string, string> {
			'Aftersales - Service'	=> 'Aftersales - Service',
			'Aftersales - Parts'	=> 'Aftersales - Parts',
			'Aftersales - Motorrad'	=> 'Aftersales - Motorrad',
			'Aftersales - Bodyshop'	=> 'Aftersales - Bodyshop',
			'Sales - Retail'		=> 'Sales - Retail',
			'Sales - Corporate'		=> 'Sales - Corporate',
			'Sales - Motorrad'		=> 'Sales - Motorrad',
			'Sales - Mini'			=> 'Sales - Mini',
			'Customer Care Center'	=> 'Customer Care Center',
			'Marketing & Business Operations'
									=> 'Marketing & Business Operations',
			'Others'				=> 'Others',
			null					=> 'Customer Care Center'
		},
		'case:makes'				=> new Map<string, string> { null => null },

		// staging

		'case:stages'				=> new List<string> { 'Monitor', 'Stage 1', 'Stage 2', 'Stage 3', 'Stage 4', 'Stage 5' },
		'case:hours'				=> null,
		'case:timing'				=> new List<double> { 28.5, 19, 19, 19, 19, 19 }
	};

////// case ////////////////////////////////////////////////////////////////////

	/**
	 * Provide case-specific prefixes to deal with instance-sharing.
	 * Used in casePref as {prefix}-{key}.
	 *
	 * @return  case-specific prefix
	 */
	public static string casePrefix(Case c) { return null; }

	/**
	 * Validation rules triggered in creating/modifying a case.
	 *
	 * @param   c   post-modification case
	 * @param   o   pre-modification case or null if insert
	 */
	public static void caseValidate(Case c, Case o, datetime now) {
		// requirements
		if (c.ContactId == null && u.def(c.Customer_Name_Manual__c, '') == '') { c.addError('Customer information must be keyed in either under the Account Information or Customer Manual Information section.'); }

		// creation
		if (u.trig('i') && u.usr().Common_Userid__c && u.def(c.Employee_Name1__c, '') == '') { c.Employee_Name1__c.addError('Please input your name here.'); }
		if (u.trig('u') && u.chg('Employee_Name1__c', c, o)) { c.Employee_Name1__c.addError('This name can only be modified during creation.'); }
	}

	/**
	 * Field updates triggered in creating/modifying a case.
	 * <strong>Note:</strong> Will override any standard rules.
	 *
	 * @param   c   post-modification case
	 * @param   o   pre-modification case or null if insert
	 */
	// public static void caseUpdate(Case c, Case o, datetime now) {
	// 	// defaults
	// 	if (u.def(c.OriginIncidentLocation__c, 'N / A') == 'N / A') { c.OriginIncidentLocation__c = c.Incident_Location__c; }
	// 	c.IncidentLocationLabel__c = Util.val(Case.Incident_Location__c, c.Incident_Location__c);
	// }

	/**
	 * Perform any instance-specific mail-merging.
	 * <strong>Note:</strong> Will override any standard replacements.
	 *
	 * @return          mail-merged text
	 * @param   c       relevant case
	 * @param   text    text to format
	 */
	public static string caseReplace(Case c, string text) { return text; }
	public static string caseReplaceKey(Case c, string key, string field) {
		if (key == '{!Case.Chassis__c}') { return (string) u.defs(u.vehx(c.Chassis__c), 'name', ''); }
		else if (field == 'Registration_Date__c') { return u.str(c.Registration_Date__c, 'yyyy-MM-dd', ''); }
		return null;
	}

	/**
	 * Provide the addresses to be sent emails in different situations.
	 * Refer to CaseMail.emails for more info.
	 *
	 * @return          list of recipient email addresses
	 * @param   c       relevant case
	 * @param   action  type of email being sent
	 * @param   teams   case team IDs (used only for assignment and escalation)
	 */
	// public static List<string> caseEmails(Case c, string action, Set<Id> teams) {
	// 	Set<string> emails = new Set<string>();
	// 	Set<string> names = new Set<string>();

	// 	if (action == 'draft') {
	// 		names.add('Sreedharan Kutty Krishnan'); // cfm owner
	// 	}
	// 	else if (action == 'open') {
	// 		names.add('Sreedharan Kutty Krishnan'); // cfm owner
	// 		// compliment to management
	// 		if (c.Type == 'Compliment') {
	// 			emails.addAll(new Set<string> {
	// 				u.sandboxEmail('vi.thim.juan@autobavaria.com.my'),
	// 				u.sandboxEmail('turse.zuhair@autobavaria.com.my'),
	// 				u.sandboxEmail('lee.se.juan@autobavaria.com.my'),				/** Added: 2018-07-30 */
	// 				u.sandboxEmail('choong.chin.seong@autobavaria.com.my'),
	// 				u.sandboxEmail('andy.tian@autobavaria.com.my')					/** Added: 2017-04-08 */
	// 				// 'kenneth.lai.km@autobavaria.com.my'			/** Removed: 2017-04-08 */
	// 				//'reuben.chirng.ch@autobavaria.com.my',
	// 				//'vi.thim.juan@autobavaria.com.my',
	// 				//'kulendran.p@autobavaria.com.my',
	// 				//'sreedharan.kutty@autobavaria.com.my',
	// 				//'tay.ee.ran@autobavaria.com.my'
	// 			});
	// 		}
	// 	}
	// 	else if (action == 'hold') {
	// 		names.add('Sreedharan Kutty Krishnan'); // cfm owner
	// 	}
	// 	else if (action == 'close') {
	// 		names.add('Sreedharan Kutty Krishnan'); // cfm owner
	// 	}
	// 	else if (action == 'assign') { }
	// 	else if (action == 'notify') { }
	// 	else if (action == 'escalate') { }

	// 	emails.addAll(u.key('Email', u.usrn(new List<string>(names)).values()).keySet()); // cfm owner
	// 	return new List<string>(emails);
	// }
}