@isTest
public class UtilPhone_Test {

    @isTest
    static void testInitValid() {
        string phone = '012 345 6789';

		UtilPhone actual = new UtilPhone(phone);
        System.assert(actual != null);
		System.assert(actual.output != null);
    }

	@isTest
	static void testInitInvalid() {
		UtilPhone actual = new UtilPhone('');
		System.assert(actual != null);
		System.assert(actual.output == null);
	}

	@isTest
	static void testInitNull() {
		UtilPhone actual = new UtilPhone(null);
		System.assert(actual != null);
		System.assert(actual.output == null);
	}


	@isTest
	static void testSuperLongPhone() {
		string phone = '012345678901234567890';
		string expected = null;
		
		string actual = UtilPhone.toE164(phone);
		System.assertEquals(actual, expected);
	}

	@isTest
	static void testGetRegion() {
        string phone = '+60 12 345 6789';
        string expected = 'MY';

		UtilPhone uphone = new UtilPhone(phone);
		
        string actual = uphone.getRegion();
        System.assertEquals(expected, actual);
	}

	@isTest
	static void testGetCountryCode() {
        string phone = '+60 12 345 6789';
		Integer expected = 60;

		UtilPhone uphone = new UtilPhone(phone);

		Integer actual = uphone.getCountryCode();
		System.assertEquals(expected, actual);
	}

	@isTest
	static void testToE164() {
		string phone, expected, actual;

		phone = '012 345 6789';
		expected = '+6' + phone.replace(' ', '');
		UtilPhone up = new UtilPhone(phone);
		actual = up.toE164();
		System.assertEquals(expected, actual);
	
		phone = '65 123 456 789';
		expected = '+' + phone.replace(' ', '');
		up = new UtilPhone(phone);
		actual = up.toE164();
		System.assertEquals(expected, actual);
	}

	@isTest
	static void testToE164Static() {
		string phone, expected, actual;

		phone = '012 345 6789';
        expected = '+6' + phone.replace(' ', '');
		actual = UtilPhone.toE164(phone);
		System.assertEquals(expected, actual);

        phone = '1 300 33 7755';
        expected = '+60' + phone.replace(' ', '');
		actual = UtilPhone.toE164(phone);
		System.assertEquals(expected, actual);

    	phone = '60(12)3456789';
    	expected = '+' + phone.replaceAll('\\D', '');
		actual = UtilPhone.toE164(phone);
		System.assertEquals(expected, actual);

		phone = '+12345 6789';
    	expected = '+' + phone.replaceAll('\\D', '');
		actual = UtilPhone.toE164(phone);
		System.assertEquals(expected, actual);

		phone = 'CRM';
		expected = null; // phone;
		actual = UtilPhone.toE164(phone);
		System.assertEquals(expected, actual);
	}

	@isTest
	static void testToNational() {
		string phone, expected, actual;
		UtilPhone uphone = new UtilPhone();

		phone = '012 345 6789';
        expected = phone.replace('012 ', '012-');
		uphone.input = phone;
		actual = uphone.toNational();
		System.assertEquals(expected, actual);

        phone = '1 300 33 7755';
        expected = phone.replace(' ', '-');
		uphone.input = phone;
		actual = uphone.toNational();
		System.assertEquals(expected, actual);
	}


	@isTest
	static void testToInternational() {
		string phone, expected, actual;
		UtilPhone uphone = new UtilPhone();

		phone = '012 345 6789';
        expected = '+60 ' + phone.replace('012 ', '12-');
		uphone.input = phone;
		actual = uphone.toInternational();
		System.assertEquals(expected, actual);

        phone = '1 300 33 7755';
        expected = '+60 ' + phone.replace(' ', '-');
		uphone.input = phone;
		actual = uphone.toInternational();
		System.assertEquals(expected, actual);
	}

	@isTest
	static void testToNoPrefixNumber() {
		string phone, expected, actual;

		phone = '012 345 6789';
        expected = phone.replace(' ', '').removeStart('0');
		UtilPhone up = new UtilPhone(phone);
		actual = up.toNoPrefixNumber();
		System.assertEquals(expected, actual);

		phone = '6012 345 6789';
		expected = phone.replace(' ', '').removeStart('60');
		up = new UtilPhone(phone);
		actual = up.toNoPrefixNumber();
		System.assertEquals(expected, actual);
	}

	@isTest
	static void testGetType() {
		string phone = '+60 12 345 6789';
        string expected = 'MOBILE';

		UtilPhone uphone = new UtilPhone(phone);
        string actual = uphone.getType();

		System.assertEquals(expected, actual);
	}

	@isTest
	static void testIsMatchText() {
		string phone, phoneToMatch, expected, actual;
		UtilPhone uphone = new UtilPhone();

		phone = '+60 12 345 6789';
		phoneToMatch = '+6012 3456789';
        expected = 'EXACT_MATCH';
		uphone.input = phone;
		actual = uphone.isMatchText(phoneToMatch);
        System.assertEquals(expected, actual);

		phoneToMatch = '6012 3456789';
        expected = 'NSN_MATCH';
		uphone.input = phone;
		actual = uphone.isMatchText(phoneToMatch);
        System.assertEquals(expected, actual);

		phoneToMatch = '60123456780';
        expected = 'NO_MATCH';
		uphone.input = phone;
		actual = uphone.isMatchText(phoneToMatch);
        System.assertEquals(expected, actual);

		phoneToMatch = 'abcde';
        expected = 'NOT_A_NUMBER';
		uphone.input = phone;
		actual = uphone.isMatchText(phoneToMatch);
        System.assertEquals(expected, actual);
	}


	@isTest
	static void testIsMatch() {
		string phone, phoneToMatch;
		Boolean expected, actual;
		UtilPhone uphone = new UtilPhone();

		phone = '+60 12 345 6789';

		phoneToMatch = '012 3456789';
        expected = true;
		uphone.input = phone;
		actual = uphone.isMatch(phoneToMatch);
        System.assertEquals(expected, actual);

		phoneToMatch = '012 3456780';
        expected = false;
		uphone.input = phone;
		actual = uphone.isMatch(phoneToMatch);
        System.assertEquals(expected, actual);
	}

}