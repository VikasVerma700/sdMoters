@IsTest
public class Util_Test {

	@isTest
	static void testCheckEmail() {
		string email;
		boolean expected, actual;

		email = '';
		expected = false;
		actual = Util.checkEmail(email);
		System.assertEquals(expected, actual);

		email = 'cw.tham@simedarby.com';
		expected = true;
		actual = Util.checkEmail(email);
		System.assertEquals(expected, actual);
	}

	@isTest
	static void testSendEmail() {
		Test.startTest();
		Util.sendEmail('body');
		Util.sendEmail('subject', 'body');
		Util.sendEMail(Envir.USER_ADMINS, 'subject', 'body');
		Test.stopTest();
	}

	@isTest
	static void testPurifyName() {
		Test.startTest();
		string name, actual, expected;
		name = 'Ibrahim B Talib';
		expected = 'Ibrahim Talib';
		actual = Util.purifyName(name);
		System.assertEquals(expected, actual);
		name = 'Raja Shahrul Shawal B. Raja Mukhtaruddin';
		expected = 'Raja Shahrul Shawal Raja Mukhtaruddin';
		actual = Util.purifyName(name);
		System.assertEquals(expected, actual);
		name = 'Latifah bt Udin';
		expected = 'Latifah Udin';
		actual = Util.purifyName(name);
		System.assertEquals(expected, actual);
		name = 'Sumathy A/P M.Dorasamy';
		expected = 'Sumathy M.Dorasamy';
		actual = Util.purifyName(name);
		System.assertEquals(expected, actual);
		name = 'R Thamilselvi Ap Ramasamy';
		expected = 'R Thamilselvi Ramasamy';
		actual = Util.purifyName(name);
		System.assertEquals(expected, actual);
		Test.stopTest();
	}

	@IsTest
	static void testGetBirthdate() {
		string nric = '800101102030';
		Date expected = Date.newInstance(1980, 1, 1);
		Test.startTest();
		Date actual = Util.getBirthdate(nric);
		Test.stopTest();
		System.assertEquals(expected, actual);
	}

	@IsTest
	static void testGetBirthdate2() {
		string nric = '120229-10-2030';
		Date expected = Date.newInstance(2012, 2, 29);
		Test.startTest();
		Date actual = Util.getBirthdate(nric);
		Test.stopTest();
		System.assertEquals(expected, actual);
	}

	@IsTest
	static void testGetBirthdateEmpty() {
		string nric = '';
		Date expected = null;
		Test.startTest();
		Date actual = Util.getBirthdate(nric);
		Test.stopTest();
		System.assertEquals(expected, actual);
	}

	@isTest
	static void testIdent() {
		string idno1 = '222391-P';
		string expected1 = 'Company Reg No.';
		Util.Identification id1 = Util.getIdent(idno1);
		System.assertEquals(expected1, id1.DocType);

		string idno2 = '800101-10-2030';
		string expected2 = 'Malaysian NRIC';
		Util.Identification id2 = Util.getIdent(idno2);
		System.assertEquals(expected2, id2.DocType);

		string idno3 = 'A123456';
		string expected3 = 'Passport No.';
		Util.Identification id3 = Util.getIdent(idno3);
		System.assertEquals(expected3, id3.DocType);

		string idno4 = '20180104';
		string expected4 = 'Unidentified';
		Util.Identification id4 = Util.getIdent(idno4);
		System.assertEquals(expected4, id4.DocType);

		string idno5 = '201801000001';
		string expected5 = 'Company Reg No.';
		Util.Identification id5 = Util.getIdent(idno5);
		System.assertEquals(expected5, id5.DocType);

		string idno6 = '';
		string expected6 = 'Invalid';
		Util.Identification id6 = Util.getIdent(idno6);
		System.assertEquals(expected6, id6.DocType);

		string idno7 = '20180104ABCD';
		string expected7 = 'Unidentified';
		Util.Identification id7 = Util.getIdent(idno7);
		System.assertEquals(expected7, id7.DocType);
	}

	@IsTest
	static void testGenBasicAuthHeader() {
		string username = 'username';
		string password = 'password';
		string expected = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(String.join(new string[] { username, password }, ':')));
		Test.startTest();
		string actual = Util.genBasicAuthHeader(username, password);
		Test.stopTest();
		System.assertEquals(expected, actual);
	}

	@IsTest
	static void testPadSapId() {
		Integer sapId = 1234;
		string expected = String.valueOf(sapId).leftPad(8, '0');
		Test.startTest();
		string actual = Util.padSapId(sapId);
		Test.stopTest();
		System.assertEquals(expected, actual);
	}

	@IsTest
	static void testGetSapId() {
		string sapId = '00001234';
		Integer expected = Integer.valueOf(sapId);
		Integer actual = Util.getSapId(sapId);
		System.assertEquals(expected, actual);
		sapId = '1234ABCD';
		Util.getSapId(sapId);
	}

	@IsTest
	static void testValidDate() {
		Date inDate1;
		Date expected1;
		Date inDate2 = Date.newInstance(1699, 12, 31);
		Date expected2;
		Date inDate3 = Date.newInstance(4001, 12, 13);
		Date expected3;
		Date inDate4 = Date.today();
		Date expected4 = inDate4;
		Date inDate5 = null;
		Date expected5  =inDate5;
		Date inDate6 = Date.today();
		Date expected6 = inDate6;
		Test.startTest();
		Date actual1 = Util.validDate(inDate1);
		Date actual2 = Util.validDate(inDate2);
		Date actual3 = Util.validDate(inDate3);
		Date actual4 = Util.validDate(inDate4);
		Date actual5 = Util.validDate(String.valueOf(inDate5));
		Date actual6 = Util.validDate(String.valueOf(inDate6));
		Test.stopTest();
		System.assertEquals(expected1, actual1);
		System.assertEquals(expected2, actual2);
		System.assertEquals(expected3, actual3);
		System.assertEquals(expected4, actual4);
		System.assertEquals(expected5, actual5);
		System.assertEquals(expected6, actual6);
	}

	/** Stringify with default. */
	@isTest static void strTest() {
		datetime now = datetime.now();
		system.assertEquals(Util.str(now), Util.str(now, 'bar'));
		system.assertEquals(Util.str((datetime)null), '');
		system.assertEquals(Util.str((datetime)null, 'bar'), 'bar');
		system.assertEquals(Util.str(now, '', 'bar'), '');
	}
	
	/** Strigify picklist */
	// @isTest
	// static void valTest() {
	// 	System.assertEquals('AB Ara Damansara', Util.val(Case.Incident_Location__c, 'AbAraDamansara'));
	// }

}