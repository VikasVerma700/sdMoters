// utility functions to simplify logic
public without sharing class u
{

////// environment /////////////////////////////////////////////////////////////

	/** Check if running on sandbox. */
	// public static Organization org = [Select Id, Name, InstanceName, IsSandbox From Organization Limit 1];
    // public static Boolean isSandbox { get { return org.IsSandbox; } }
	// public static String sbSuffix { get {
	// 	if (isSandbox) return UserInfo.getUserName().substringAfterLast('.');
	// 	else return 'prod';
	// }}
	public static string developerEmail { get { return string.format('rx0ug.sfdc+abd.{0}@gmail.com', new string[] { Envir.sbSuffix }); }}
	public static string developerEmailCc(string name) { return string.format('rx0ug.sfdc+abd.{0}_{1}@gmail.com', new string[] { Envir.sbSuffix, name }); }
	public static string sandboxEmail(string email) { 
		if (Envir.isSandbox) { return string.format('{0}.{1}', new string[] { email, Envir.sbSuffix }); }
		else { return email; }
	}
    // public static boolean sbx() { return false; }

////// trigger /////////////////////////////////////////////////////////////////

    /** Check if trigger is an insert or update operation. */
    public static boolean trig(string t) {
        if (t == 'i') { return Trigger.isInsert; }
        else if (t == 'u') { return Trigger.isUpdate; }
        return false;
    }


    /** Check if a field has been changed between two objects. */
    public static boolean chg(string key, SObject a, SObject b) { return a.get(key) != b.get(key); }

////// null ////////////////////////////////////////////////////////////////////

    /** Check and provide default for null. */
    public static object def(object o, object d) { return o != null ? o : d; }
    public static object defs(SObject s, string a, object d) { return s != null ? def(s.get(a), d) : d; }

    /** Integerify with default. */
    public static integer int(Decimal o, integer i) { return o != null ? o.intValue() : i; }

    /** Stringify with default. */
    public static string str(DateTime o) { return o != null ? o.format() : ''; }
    public static string str(DateTime o, string d) { return o != null ? o.format() : d; }
    public static string str(DateTime o, string fmt, string d) { return o != null ? o.format(fmt) : d; }

    /** Filter nulls from list. */
    public static List<object> filter(List<object> a) {
        List<object> f = a.clone(); f.clear();
        for (object i : a) { u.add(f, i); }
        return f;
    }

    /** Add only non-null items. */
    public static boolean add(List<object> a, object v) { if (v == null) { return false; } a.add(v); return true; }
    public static boolean add(Set<object> s, object v) { if (v == null) { return false; } s.add(v); return true; }
    public static boolean add(Set<string> s, string v) { if (v == null) { return false; } s.add(v); return true; }
    public static boolean add(Set<Id> s, string v) { if (v == null) { return false; } s.add(v); return true; }
    public static integer addAll(List<object> a, List<object> b) {
        integer n = 0;
        for (object i : b) {
            if (add(a, i)) { ++n; }
        }
        return n;
    }

////// querying ////////////////////////////////////////////////////////////////

    /** Map a list of SObjects to a provided key. */
    public static Map<string, SObject> key(string key, List<SObject> qry) {
        Map<string, SObject> ret = new Map<string, SObject>();
        for (SObject o : qry) { ret.put((string)o.get(key), o); }
        return ret;
    }

////// business hours //////////////////////////////////////////////////////////

    /** Determine if in business hours using [open, close). */
    public static boolean hrs(object hours, datetime now) { return hrs((Id) hours, now); }
    public static boolean hrs(Id hours, datetime now) {
        double second = 1.0/24/60/60;
        long plus = BusinessHours.diff(hours, now, now + second), minus = BusinessHours.diff(hours, now, now - second);
        return plus != minus && plus > 0;
    }
    /** Calculate the number of business days between two datetimes. */
    public static integer days(object hours, datetime a, datetime b) { return days((Id) hours, a, b); }
    public static integer days(Id hours, datetime a, datetime b) {
        datetime ah = hrs(hours, a) ? a : BusinessHours.add(hours, a, 1);
        datetime bh = hrs(hours, b) ? b : BusinessHours.add(hours, b, 1);
        datetime start = ah > bh ? bh : ah;
        datetime finish = ah > bh ? ah : bh;

        string fmt = 'yyyy-MM-dd HH:mm:ss.SSS';
        system.debug(start.format(fmt) + ' --- ' + finish.format(fmt));

        integer cnt = 0;
        while (start != finish) {
            start = datetime.newinstance(start.date().addDays(1), start.time());
            if (start > finish) { break; }
            cnt += 1;
            system.debug(start.format(fmt) + ' --- ' + finish.format(fmt));
        }
        return cnt;
    }

////// user ////////////////////////////////////////////////////////////////////

    @TestVisible static Map<Id, User> users = new Map<Id, User>();
    @TestVisible static Map<string, User> userns = new Map<string, User>();
    @TestVisible static Set<Id> admins;

    /** Check if using an administrative account. */
    public static boolean adm() {
        if (admins == null) {
            admins = new Set<Id>();
            for (Profile p : [select id from Profile where Name = 'System Administrator']) { admins.add(p.Id); }
        }
        return admins.contains(UserInfo.getProfileId());
    }
    /**
     * Get users from the database.
     *
     * @return          user requested / void
     * @param   me      ID of user to retrieve
     * @param   ids     list of user IDs to retrieve
     */
    public static User usr() { return usr((Id) UserInfo.getUserId()); }
    public static User usr(Id me) {
        if (me == null) { return null; }
        else if (!users.containsKey(me)) {
            User u = [select Name, Email, Is_CFM_Owner__c, Common_Userid__c, Allowed_to_Close_Case__c from User where Id = :me];
            users.put(u.Id, u);
            userns.put(u.Name, u);
        }
        return users.get(me);
    }
    public static Map<Id, User> usr(List<Id> ids) {
        if (ids == null || ids.size() == 0) { return new Map<Id, User>(); }
        List<Id> rids = new List<Id>();
        for (Id id : ids) {
            if (users.containsKey(id)) { continue; }
            rids.add(id);
        }

        for (User u : [select Name, Email, Is_CFM_Owner__c, Common_Userid__c, Allowed_to_Close_Case__c from User where Id in :rids]) {
            users.put(u.Id, u);
            userns.put(u.Name, u);
        }

        Map<Id, User> ret = new Map<Id, User>();
        for (Id id : ids) { ret.put(id, users.get(id)); }
        return ret;
    }

    public static User usrn(string me) {
        if (me == null) { return null; }
        else if (!userns.containsKey(me)) {
            User u = [select Name, Email, Is_CFM_Owner__c, Common_Userid__c, Allowed_to_Close_Case__c from User where Name = :me];
			if (u == null) { System.debug('User.Name: ' + me + ' not found.'); }
            users.put(u.Id, u);
            userns.put(u.Name, u);
        }
        return userns.get(me);
    }
    public static Map<string, User> usrn(List<string> names) {
        if (names == null || names.size() == 0) { return new Map<string, User>(); }
        List<string> rnames = new List<string>();
        for (string name : names) {
            if (userns.containsKey(name)) { continue; }
            rnames.add(name);
        }

        for (User u : [select Name, Email, Is_CFM_Owner__c, Common_Userid__c, Allowed_to_Close_Case__c from User where Name in :rnames]) {
            users.put(u.Id, u);
            userns.put(u.Name, u);
        }

        Map<string, User> ret = new Map<string, User>();
        for (string name : names) { ret.put(name, userns.get(name)); }
        return ret;
    }


////// account /////////////////////////////////////////////////////////////////

    static Map<Id, Account> accounts = new Map<Id, Account>();

    /**
     * Get accounts from the database.
     *
     * @return          account requested / void
     * @param   me      ID of account to retrieve
     * @param   ids     list of account IDs to retrieve
     */
    public static Account acct(Id me) {
        if (me == null) { return null; }
        else if (!accounts.containsKey(me)) { accounts.put(me, [select Name from Account where Id = :me]); }
        return accounts.get(me);
    }
    public static void acct(List<Id> ids) {
        if (ids == null || ids.size() == 0) { return; }
        accounts.putAll([select Name from Account where Id in :ids]);
    }

////// contact /////////////////////////////////////////////////////////////////

    static Map<Id, Contact> contacts = new Map<Id, Contact>();

    /**
     * Get contacts from the database.
     *
     * @return          contact requested / void
     * @param   me      ID of contact to retrieve
     * @param   ids     list of contact IDs to retrieve
     */
    public static Contact contact(Id me) {
        if (me == null) { return null; }
        else if (!contacts.containsKey(me)) { contacts.put(me, [select Name, MobilePhone, Email from Contact where Id = :me]); }
        return contacts.get(me);
    }
    public static void contact(List<Id> ids) {
        if (ids == null || ids.size() == 0) { return; }
        contacts.putAll([select Name, MobilePhone, Email from Contact where Id in :ids]);
    }

////// vehicle /////////////////////////////////////////////////////////////////

    static Map<Id, Vehicle__c> vehicles = new Map<Id, Vehicle__c>();

    /**
     * Get vehicles from the database.
     *
     * @return          vehicle requested / void
     * @param   me      ID of vehicle to retrieve
     * @param   ids     list of vehicle IDs to retrieve
     */
    public static Vehicle__c vehx(Id me) {
        if (me == null) { return null; }
        else if (!vehicles.containsKey(me)) { vehicles.put(me, [select Name from Vehicle__c where Id = :me]); }
        return vehicles.get(me);
    }
    public static void vehx(List<Id> ids) {
        if (ids == null || ids.size() == 0) { return; }
        vehicles.putAll([select Name from Vehicle__c where Id in :ids]);
    }

///// mobile number management /////////////////////////////////////////////////
	public static Decimal onlyPrefix(decimal phoneNo) {
		return onlyPrefix(String.valueOf(Integer.valueOf(phoneNo)));
	}
	public static Decimal onlyPrefix(string phoneNo) {
		if (string.isBlank(phoneNo)) { return 60; }
		phoneNo = phoneNo.replace('+', '')
						 .replace('-', '')
						 .replace(' ', '');
		if (phoneNo.length() < 2) { return 60; }
		if (phoneNo.Substring(0, 1) == '0') { return 60; }
		if (phoneNo.Substring(0, 1) == '6') { 
			try { return Decimal.valueOf(phoneNo.Substring(0, 2)); }
			catch (Exception e) { return 60; }
		}
		return 60;
	}
	public static string onlyNumber(string phoneNo) {
		if (string.isBlank(phoneNo)) { return ''; }
		phoneNo = phoneNo.replace('+', '')
						 .replace('-', '')
						 .replace(' ', '');
		if (phoneNo.length() < 0) { return ''; }
		/** Determine if phoneNo is numbers only. */
		if (!phoneNo.isNumeric()) { return ''; }
		string pref = String.valueOf(Integer.valueOf(onlyPrefix(phoneNo)));
		if (phoneNo.Substring(0, 1) == '6') { return phoneNo.Substring(pref.length(), phoneNo.length()).replaceFirst('^0+', ''); }
		if (phoneNo.Substring(0, 1) == '0') { return phoneNo.replaceFirst('^0+', ''); }
		return phoneNo;
	}

	public static string beautifyPhone(decimal prefix, string phoneNo) {
		if (prefix == null) {
			return u.beautifyPhone('', phoneNo);
		}
		else {
			return u.beautifyPhone(String.valueOf(Integer.valueOf(prefix)), phoneNo);
		}
	}
	public static string beautifyPhone(string prefix, string phoneNo) {
		// phoneNo = phoneNo.replace('+', '');
		// if (String.isBlank(phoneNo)) { return null; }
		// /** Default prefix: 60 */
		// if (string.isBlank(prefix)) { prefix = '60'; }

		// string ret;
		// if (phoneNo.startsWith('6')) { /** Phone already has prefix, append '+' */ ret = String.format('+{0}', new string[] { phoneNo }); }
		// else { ret = String.format('+{0}{1}', new string[] { prefix, phoneNo.replaceFirst('^0+', '') }); }

		// return ret;
		string pref = String.valueOf(onlyPrefix(phoneNo));
		string nmbr = onlyNumber(phoneNo);
		string phone = String.isBlank(prefix) ? '+' + pref + nmbr : '+' + prefix + nmbr;
		return phone;
	}

    public static string sandboxPhone(Decimal prefix, string phoneNo, Boolean isSandbox, string[] whitelist) {
        return sandboxPhone(String.valueOf(prefix), phoneNo, isSandbox, whitelist);
    }
	public static string sandboxPhone(string prefix, string phoneNo, Boolean isSandbox, string[] whitelist) {
        prefix = prefix == null ? '' : prefix.replaceAll('\\D', '');
		string ret = beautifyPhone(prefix, phoneNo);
		if (ret == null) { return null; }
		// phoneNo = phoneNo.replace('+', '');
		// if (String.isBlank(phoneNo)) { return null; }

		// string ret;
		// if (phoneNo.startsWith('6')) { /** Phone already has prefix, append '+' */ ret = String.format('+{0}', new string[] { phoneNo }); }
		// else { ret = String.format('{0}{1}', new string[] { prefix, phoneNo.replaceFirst('^0+', '') }); }
		
		if (isSandbox && whitelist == null) {
			/** Default to +60192651650 when isSandbox and whitelist is null. */
			ret = '+60192651650';
		}
		else if (isSandbox && whitelist != null) {
			/** Return whitelist 1st index if phoneNo not in whitelist. */
			ret = whitelist.contains(ret) ? ret : whitelist[0];
		}

		return ret;
	}

///// Object type //////////////////////////////////////////////////////////////
	public static string getType(Object obj) {
		if (obj instanceof Boolean) { return 'Boolean'; }
		if (obj instanceof Integer) { return 'Integer'; }
		if (obj instanceof Long) { return 'Long'; }
		if (obj instanceof Double) { return 'Double'; }
		if (obj instanceof Decimal) { return 'Decimal'; }
		if (obj instanceof Time) { return 'Time'; }
		if (obj instanceof Date) { return 'Date'; }
		if (obj instanceof Datetime) { return 'Datetime'; }
		if (obj instanceof Id) { return 'Id'; }
		if (obj instanceof String) { return 'String'; }
		if (obj instanceof Blob) { return 'Blob'; }
		return 'Undefined';
	}

///// NRIC handling ////////////////////////////////////////////////////////////
	public static Date getBirthdate(String nric) {
		/** Return null if doesn't meet initial criteria of Malaysian NRIC. */
		if (!nric.isNumeric() || nric.trim().length() != 12) { return null; }
		string y2d = String.valueOf(Date.today().year()).substring(2, 4);
		string by2d = nric.left(2);
		string bmn = nric.substring(2, 4);
		string bdy = nric.substring(4, 6);
		/** Determine year prefix. */
		string byr = (by2d >= y2d) ? '19' + by2d : '20' + by2d;

		return Date.newInstance(Integer.valueOf(byr), Integer.valueOf(bmn), Integer.valueOf(bdy)); 
	}
}