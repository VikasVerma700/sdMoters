@isTest private class uTest {

////// environment /////////////////////////////////////////////////////////////
	// @isTest static void sbxTest() { u.sbx(); }


////// trigger /////////////////////////////////////////////////////////////////
	@isTest static void trigTest() {
		/* cannot be tested directly */
		u.trig('i');
		u.trig('u');
		u.trig('k');
	}
	@isTest static void chgTest() {
		system.assert(u.chg('Priority', new Case(Priority='1'), new Case(Priority='2')));
		system.assert(!u.chg('Priority', new Case(Priority='1'), new Case(Priority='1')));
	}

////// null ////////////////////////////////////////////////////////////////////
	@isTest static void defTest() {
		system.assertEquals(u.def('foo', 'bar'), 'foo');
		system.assertEquals(u.def(null, 'bar'), 'bar');
		system.assertEquals(u.def(0, 1), 0);
		system.assertEquals(u.def(null, 1), 1);

		system.assertEquals(u.defs(new Case(Priority='foo'), 'priority', 'bar'), 'foo');
		system.assertEquals(u.defs(null, 'priority', 'bar'), 'bar');
	}
	@isTest static void intTest() {
		system.assertEquals(u.int(1.5, 0), 1);
		system.assertEquals(u.int(null, 0), 0);
	}
	@isTest static void strTest() {
		datetime now = datetime.now();
		system.assertEquals(u.str(now), u.str(now, 'bar'));
		system.assertEquals(u.str((datetime)null), '');
		system.assertEquals(u.str((datetime)null, 'bar'), 'bar');
		system.assertEquals(u.str(now, '', 'bar'), '');
	}
	@isTest static void filterTest() {
		system.assertEquals(u.filter(new List<integer>{1,2,null,3,4}).size(), 4);
	}
	@isTest static void addTest() {
		string[] a = new string[]{};
		List<string> l = new List<string>();
		Set<object> so = new Set<object>();
		Set<string> ss = new Set<string>();
		Set<Id> si = new Set<Id>();
		system.assertEquals(a.size(), 0);
		system.assertEquals(l.size(), 0);

		system.assertEquals(u.add(a, 'foo'), true);
		system.assertEquals(u.add(l, 'foo'), true);
		system.assertEquals(u.add(so, 'foo'), true);
		system.assertEquals(u.add(ss, 'foo'), true);
		system.assertEquals(a.size(), 1);
		system.assertEquals(l.size(), 1);
		system.assertEquals(so.size(), 1);
		system.assertEquals(ss.size(), 1);
		system.assertEquals(si.size(), 0);

		system.assertEquals(u.add(a, null), false);
		system.assertEquals(u.add(l, null), false);
		system.assertEquals(u.add(so, null), false);
		system.assertEquals(u.add(ss, null), false);
		system.assertEquals(u.add(si, null), false);
		system.assertEquals(a.size(), 1);
		system.assertEquals(l.size(), 1);
		system.assertEquals(so.size(), 1);
		system.assertEquals(ss.size(), 1);
		system.assertEquals(si.size(), 0);

		a.add(null);
		system.assertEquals(u.addAll(l, a), 1);
		system.assertEquals(l.size(), 2);
	}

////// querying ////////////////////////////////////////////////////////////////
	@isTest static void keyTest() {
		List<RecordType> qry = [select Id from RecordType];
		system.assertEquals(u.key('id', qry), new Map<String, SObject>(qry));
	}
	@isTest static void hrsTest() {
		BusinessHours hours = [select Id from BusinessHours where IsDefault = true];
		Datetime inside = Datetime.newInstance(2013, 3, 29, 12, 0, 0);
		Datetime outside = Datetime.newInstance(2013, 3, 29, 0, 0, 0);
		system.assertEquals(u.hrs((object)hours.id, inside), true);
		system.assertEquals(u.hrs(hours.id, outside), false);
	}
	@isTest static void daysTest() {
		BusinessHours hours = [select Id from BusinessHours where IsDefault = true];
		Datetime now = Datetime.now();
		Datetime next = BusinessHours.add(hours.id, now, 30L * 24 * 60 * 60 * 1000);
		u.days((object)hours.id, now, next);
	}

////// user ////////////////////////////////////////////////////////////////////
	@isTest static void admTest() { u.adm(); /* can't be tested directly */ }
	@isTest static void usrTest() {
		system.assertEquals(u.usr().Id, UserInfo.getUserId());
		u.usr(new List<Id>{UserInfo.getUserId()});
		u.users.clear();
		u.userns.clear();
		u.usr(new List<Id>{UserInfo.getUserId()});
	}
	@isTest static void usrnTest() {
		system.assertEquals(u.usrn(UserInfo.getName()).Name, UserInfo.getName());
		u.usrn(new List<string>{UserInfo.getName()});
		u.users.clear();
		u.userns.clear();
		u.usrn(new List<string>{UserInfo.getName()});
	}
	@isTest static void acctTest() {
		insert new Account(Name='John Smith');
		u.acct([select Id from Account][0].Id);
		u.acct(new List<Id>(new Map<Id, Account>([select Id from Account]).keyset()));
	}

////// contact /////////////////////////////////////////////////////////////////
	@isTest static void contactTest() {
		insert new Contact(LastName='Smith');
		u.contact([select Id from Contact][0].Id);
		u.contact(new List<Id>(new Map<Id, Contact>([select Id from Contact]).keyset()));
	}

////// vehicle /////////////////////////////////////////////////////////////////
	@isTest static void vehxTest() {
		insert new Vehicle__c();
		u.vehx([select Id from Vehicle__c][0].Id);
		u.vehx(new List<Id>(new Map<Id, Vehicle__c>([select Id from Vehicle__c]).keyset()));
	}

///// mobile number ////////////////////////////////////////////////////////////
	@isTest static void onlyPrefixTest() {
		decimal pref = 60;
		string nmbr = '192651650';
		Test.startTest();
		decimal ret = u.onlyPrefix(pref + nmbr);
		Test.stopTest();
		System.AssertEquals(pref, ret, 'Mobile prefix don\'t match.');
	}
	@isTest static void onlyNumberTest() {
		string pref = '60';
		string nmbr = '192651650';
		Test.startTest();
		string ret = u.onlyNumber(pref + nmbr);
		Test.stopTest();
		System.AssertEquals(nmbr, ret, 'Mobile number don\'t match.');
	}
	@isTest static void beautifyPhoneDecimalTest() {
		string exp = '+60192651650';
		decimal pref = 60.0;
		string nmbr = '192651650';
		Test.startTest();
		string ret = u.beautifyPhone(pref, nmbr);
		Test.stopTest();
		System.AssertEquals(exp, ret, 'Beautify number don\'t match.');
	}
	@isTest static void sandboxPhoneTest() {
		string exp = '+60192651650';
		string pref = '60';
		string nmbr = '192651650';
		boolean isSandbox = Envir.isSandbox;
		string[] whitelist = new string[] { '+60192651650' };
		Test.startTest();
		string ret = u.sandboxPhone(pref, nmbr, isSandbox, whitelist);
		Test.stopTest();
		System.AssertEquals(exp, ret, 'Sandboxed number don\'t match.');
	}
///// Object type //////////////////////////////////////////////////////////////
	@isTest static void getTypeTest() {
		Boolean bool = false;
		Integer inte = 12345;
		Long lon = 2147483648L;
		Double doub = 123.45;
		Decimal deci = null;
		Time tim = Time.newInstance(1, 2, 3, 4);
		Date dat = Date.today();
		Datetime datet = Datetime.now();
		Id ids = '00300000003T2PGAA0';
		String stri = 'abcde';
		Blob blo = Blob.valueOf(stri);
		System.AssertEquals('Boolean', u.getType(bool), 'This should be boolean.');
		System.AssertEquals('Integer', u.getType(inte), 'This should be integer.');
		System.AssertEquals('Long', u.getType(lon), 'This should be long.');
		System.AssertEquals('Double', u.getType(doub), 'This should be double.');
		// System.AssertEquals('Decimal', u.getType(deci), 'This should be decimal.');
		System.AssertEquals('Time', u.getType(tim), 'This should be time.');
		System.AssertEquals('Date', u.getType(dat), 'This should be date.');
		System.AssertEquals('Datetime', u.getType(datet), 'This should be datetime.');
		System.AssertEquals('Id', u.getType(ids), 'This should be id.');
		System.AssertEquals('String', u.getType(stri), 'This should be string.');
		System.AssertEquals('Blob', u.getType(blo), 'This should be blob.');
	}

///// NRIC handling ////////////////////////////////////////////////////////////
	@isTest static void getBirthdate() {
		Date bday = Date.newInstance(1980, 12, 31);
		string nric = Datetime.newInstance(bday.year(), bday.month(), bday.day(), 1, 1, 1).format('yyMMdd101010');
		string invalid = nric + 'a';

		System.assertEquals(bday, u.getBirthdate(nric), 'Date should match.');
		System.assertNotEquals(bday, u.getBirthdate(invalid), 'Date shouldn\'t match.');
	}
}