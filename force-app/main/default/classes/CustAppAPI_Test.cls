@IsTest
public class CustAppAPI_Test {
	@TestSetup
	public static void setup() {
		TestFactory.genTriggerSettings('Customer App Callback', true);
	}

	@IsTest
	public static void testPrefix() {
		List<String> testList = new List<String> { 'test', 'test2' };
		String prefix = 'abc';
		Test.startTest();
		List<String> res = CustAppAPI.prefixFields(testList, prefix);
		Test.stopTest();
		for (Integer i = 0; i < testList.size(); i++) {
			System.assertEquals(res[i], 'abc' + testList[i]);
		}
	}

	@IsTest
	public static void testLogin() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		String res = CustAppAPI.login('038');
		Test.stopTest();
		System.assert(!String.isBlank(res));
	}

	@IsTest
	public static void testLoginResEmpty() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHookLoginResEmpty());
		Test.startTest();
		String res;
		try { res = CustAppAPI.login('038'); }
		catch (Exception e) {
			System.assertEquals(CustAppAPI.CustAppException.class.getName(), e.getTypeName());
			System.assertEquals('Invalid response.', e.getMessage());
		}
		Test.stopTest();
		// System.assert(!String.isBlank(res));
	}

	@IsTest
	public static void testLoginInvalidJWT() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHookLoginInvalidJWT());
		Test.startTest();
		String res;
		try { res = CustAppAPI.login('038'); }
		catch (Exception e) { 
			System.assertEquals(CustAppAPI.CustAppException.class.getName(), e.getTypeName());
			System.assertEquals('Invalid JWT Token.', e.getMessage());
		}
		Test.stopTest();
		// System.assert(!String.isBlank(res));
	}

	@IsTest
	public static void testLoginInvalid() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHookLoginInvalid());
		Test.startTest();
		String res;
		try { res = CustAppAPI.login('038'); }
		catch (Exception e) { 
			System.assertEquals(CustAppAPI.CustAppException.class.getName(), e.getTypeName());
			System.assert(e.getMessage().contains('Invalid status code from CustAppAPI:login'));
		}
		Test.stopTest();
		// System.assert(!String.isBlank(res));
	}

	@IsTest
	public static void testSendWebhook() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHook());
		Test.startTest();
		CustAppAPI.sendWebhook('{ "test": "abc" }', '038');
		Test.stopTest();
		// check debug logs
	}

	@IsTest
	public static void testSendWebhookResEmpty() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHookResEmpty());
		Test.startTest();
		try { CustAppAPI.sendWebhook('{ "test": "abc" }'); }
		catch (Exception e) {
			System.assertEquals(CustAppAPI.CustAppException.class.getName(), e.getTypeName());
			System.assertEquals('Invalid response.', e.getMessage());
		}
		Test.stopTest();
		// check debug logs
	}

	@IsTest
	public static void testSendWebhookNot200() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.CustAppHookNot200());
		Test.startTest();
		try { CustAppAPI.sendWebhook('{ "test": "abc" }'); }
		catch (Exception e) {
			System.assertEquals(CustAppAPI.CustAppException.class.getName(), e.getTypeName());
			System.assert(e.getMessage().contains('Error from sending webhook'));
		}
		Test.stopTest();
		// check debug logs
	}


	@IsTest
	public static void testCurrency() {
		Test.startTest();
		CustAppAPI.CurrencyCls money = new CustAppAPI.CurrencyCls(200);
		Test.stopTest();
		System.assertEquals(money.currencyType, CustAppAPI.CURRENCY_TYPE);
	}

	@IsTest
	public static void testCurrency2() {
		Test.startTest();
		CustAppAPI.CurrencyCls money = new CustAppAPI.CurrencyCls(CustAppAPI.CURRENCY_TYPE, 200);
		Test.stopTest();
		System.assertEquals(CustAppAPI.CURRENCY_TYPE, money.currencyType);
	}
}