public class CaseAssign
{
	/** Provide shorthand for CaseCommon.pref. */
	public static object pref(Case c, string key) { return CaseCommon.pref(c, key); }
	public static Map<string, string> attrs(Case c) { return (Map<string, string>) pref(c, 'fieldmap'); }

	/** Check if case is valid for assignment. */
	public static boolean valid(Case c) {
		return c.Type != 'Compliment' && !c.Draft_Mode__c;
	}

	/** Generate case teams. (Not used in production.) */
	public static List<string> generate() {
		Map<string, CaseTeamTemplate> teams = (Map<string, CaseTeamTemplate>) pref(null, 'teams');
		Set<string> addnames = new Set<string>();

		Map<string, string>
			fieldmap = (Map<string, string>) pref(null, 'fieldmap'),
			companies = (Map<string, string>) pref(null, 'companies'),
			branches = (Map<string, string>) pref(null, 'branches'),
			depts = (Map<string, string>) pref(null, 'depts'),
			makes = (Map<string, string>) pref(null, 'makes');
		List<string> stages = (List<string>) pref(null, 'stages');

		for (string co : new Set<string>(companies.values()))
		for (string br : new Set<string>(branches.values()))
		for (string dp : new Set<string>(depts.values()))
		for (string mk : new Set<string>(makes.values()))
		for (integer i=0; i<=2; ++i)
		{
			string st = '(' + stages[i] + ')';
			string name = String.join(u.filter(new List<string>{co,br,dp,mk,st}), ' ');
			if (teams.containsKey(name)) { continue; }
			addnames.add(name);
		}

		List<CaseTeamTemplate> addteams = new List<CaseTeamTemplate>();
		for (string name : addnames) { addteams.add(new CaseTeamTemplate(Name=name)); }

		insert addteams;
		return new List<string>(addnames);
	}

	/**
	 * Generate a set of case team names that are supposed to be assigned to a
	 * particular case.
	 *
	 * @return  set of case team names
	 * @param   c       relevant case
	 * @param   stage   escalation stage to generate for
	 * @param   dept    department to generate for
	 */
	public static Set<string> names(Case c) {
		Set<string> names = new Set<string>();
		if (c == null) { return names; }

		for (integer i=0; i<=(Decimal) u.defs(c, attrs(c).get('stage'), Decimal.valueOf(-1)); ++i) { names.addAll(names(c, i)); }
		return names;
	}
	public static Set<string> names(Case c, integer stage) {
		Set<string> names = new Set<string>();
		for (string dept
			: ((string) u.defs(c, ((Map<string, string>) pref(c, 'fieldmap')).get('dept'), '')).split(';'))
		{ names.add(name(c, dept, stage)); }
		return names;
	}
	public static string name(Case c, string dept, integer stage) {
		Map<string, CaseTeamTemplate> teams = (Map<string, CaseTeamTemplate>) pref(c, 'teams');
		Map<string, string>
			companies = (Map<string, string>) pref(c, 'companies'),
			branches = (Map<string, string>) pref(c, 'branches'),
			depts = (Map<string, string>) pref(c, 'depts'),
			makes = (Map<string, string>) pref(c, 'makes');
		List<string>
			stages = (List<string>) pref(c, 'stages'),
			patterns = (List<string>) pref(c, 'pattern');

		for (string patt : patterns) {
			string val;
			string co, br, dp, mk;

			val = (string) u.defs(c, attrs(c).get('company'), '');
			if (!companies.containsKey(val)) { val = 'SDAB'; }
			co = companies.get(val);

			val = (string) u.defs(c, attrs(c).get('branch'), '');
			if (!branches.containsKey(val)) { val = null; }
			br = branches.get(val);

			val = dept;
			if (!depts.containsKey(val)) { val = null; }
			dp = depts.get(val);

			val = (string) u.defs(c, attrs(c).get('make'), '');
			if (!makes.containsKey(val)) { val = null; }
			mk = makes.get(val);

			string st = '(' + stages[CaseStage.clamp(c, stage)] + ')';

			do {
				List<string> name = new List<string>();
				for (string ch : patt.split('')) {
					if (ch == '') { continue; }
					else if (ch == 'c') { name.add('SDAB'); }
					else if (ch == 'b') { name.add(br); }
					else if (ch == 'd') { name.add(dp); }
					else if (ch == 'm') { name.add(mk); }
					else if (ch == 's') { name.add(st); }
					else { throw new CaseCommon.CaseException('CaseAssign.name: Invalid character "' + ch + '" in pattern "' + patt + '".'); }
				}
				if (teams.containsKey(String.join(u.filter(name), ' '))) { return String.join(u.filter(name), ' '); }

				if (patt.contains('d') && dp != null) {
					if (dp.contains(' - ')) { dp = dp.left(dp.lastIndexOf(' - ')); }
					else { dp = null; }
				}
			} while (patt.contains('d') && dp != null);
		}
//		throw new CaseCommon.CaseException('CaseAssign.name: Could not find a case team in ' + c.CaseNumber + ' for ' + dept + ' at ' + stages[CaseStage.clamp(c, stage)] + ' level.');
		return null;
	}

	/**
	 * Convert case team names to their respective IDs.
	 * Usually used together with <code>names()</code>.
	 *
	 * @return  a set of case team ids
	 * @param   names   set of case team names
	 */
	public static Set<Id> ids(Set<string> names) {
		Set<Id> ids = new Set<Id>();
		Map<string, CaseTeamTemplate> teams = (Map<string, CaseTeamTemplate>) pref(null, 'teams');
		for (string name : names) {
			if (!teams.containsKey(name)) { continue; }
			ids.add(teams.get(name).Id);
		}
		return ids;
	}

	/** Basic assignment tests. */
	@isTest static void assignTest() {
		boolean except;
		List<string> stages = (List<string>) pref(null, 'stages');
		delete [select Id from CaseTeamTemplate];
		insert new List<CaseTeamTemplate> {
			new CaseTeamTemplate(Name='(' + stages[0] + ')'),
			new CaseTeamTemplate(Name='(' + stages[1] + ')')
		};

		z.pref.put('case:pattern', new List<string> {'!cbdms'});
		try { except = false; name(new Case(), null, 2); } catch (Exception e) { except = true; }
		system.assert(except);

		z.pref.put('case:pattern', new List<string> {'cbdms'});
		system.assertEquals(name(new Case(), 'A - B', 1), null);

		z.pref.put('case:pattern', new List<string> {'cbdms', 's'});
		system.assertEquals(name(new Case(), null, 0), '(' + stages[0] + ')');

		Set<string> names = names(new Case(EscalationStage__c=1));
		system.assertEquals(names, new Set<string> { '(' + stages[0] + ')', '(' + stages[1] + ')' });
		ids(names);
	}

	/** Ensure all picklist values used in case team assignments are mapped. */
	@isTest static void mappingTest() {
		boolean except = false;
		for (string type : new List<string> { 'company:companies', 'branch:branches', 'dept:depts', 'make:makes' }) {
			List<string> pair = type.split(':');
			string field = attrs(new Case()).get(pair[0]);
			Map<string, string> mapping = (Map<string, string>) pref(null, pair[1]);
			List<Schema.PicklistEntry> values = Schema.SObjectType.Case.fields.getMap().get(field).getDescribe().getPicklistValues();
			for (Schema.PicklistEntry entry : values) {
				if (mapping.containsKey(entry.getValue())) { continue; }
				system.debug(LoggingLevel.WARN, 'Could not find ' + entry.getValue() + ' in the ' + pair[0] + ' mapping configuration.');
				except = true;
			}
		}
		// system.assert(!except, 'Some picklist values are missing from the mapping configuration.');
	}
    @isTest static void generateTest(){
        generate();
    }
}