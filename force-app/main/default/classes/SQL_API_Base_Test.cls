@IsTest
public class SQL_API_Base_Test {
	@TestSetup
	public static void makeData() {
		TestFactory.getCompany('028');
		TestFactory.genApiSetup();
		List<String> services = getServices();
		List<Service_Run__c> runs = new List<Service_Run__c>();
		for (String s : services) {
			runs.add(new Service_Run__c(Name = s, Last_Run__c = DateTime.now().addDays(-1)));
		}
		insert runs;
	}
	@isTest
	static string[] getServices() {
		string[] services = new string[] { 
			// SQL_API_Base.QUEUE_EMPL
			SQL_API_Base.QUEUE_ACCO, SQL_API_Base.QUEUE_VEHI, SQL_API_Base.QUEUE_VOWN
			, SQL_API_Base.QUEUE_APPT, SQL_API_Base.QUEUE_RORD, SQL_API_Base.QUEUE_INVO
			, SQL_API_Base.QUEUE_FILE, SQL_API_Base.QUEUE_PAYM, SQL_API_Base.QUEUE_PKGE
			, SQL_API_Base.QUEUE_WRTY
		};
		return services;
	}

	@IsTest static void testGetRuns() {

		Test.startTest();
		for (string service :getServices()) {
			System.assert(SQL_API_Base.getRun(service) != null);
			System.assert(SQL_API_Base.getRunTime(service) != null);
		}
		Test.stopTest();
	}

	@IsTest static void testUpdateRun() {
		Test.startTest();
		SQL_API_Base.updateRun(getServices()[0], DateTime.now().addDays(1));
		Test.stopTest();
		System.assert(SQL_API_Base.getRunTime(getServices()[0]) <= DateTime.now());
	}

	@isTest static void testRowTracking() {
		SQL_API_Base.RowTracking rt = new SQL_API_Base.RowTracking();
		Test.startTest();
		rt.AddOne();
		rt.AddTo(2);
		rt.UpdateOne();
		rt.UpdateTo(3);
		rt.MatchOne();
		rt.MatchTo(4);
		rt.SkipOne();
		rt.SkipTo(5);
		Test.stopTest();
		System.assertEquals(1+2, rt.Added);
		System.assertEquals(1+3, rt.Updated);
		System.assertEquals(1+4, rt.Matched);
		System.assertEquals(1+5, rt.Skipped);
		System.assertEquals(1+2+1+3+1+4+1+5, rt.Total);
	}

	@isTest static void testApiDebug() {
		string[] resp = new string[]{};
		resp.add('This is line 1');
		resp.add('This is line 2');

		SQL_API_Base.API_DEBUG api;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(resp));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('/mock/endpoint');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(resp, false));
        req.setTimeout(120000);

		/** Prep API request for exception email */
		api = new SQL_API_Base.API_DEBUG();
		api.parse(req, new string[] { 'Content-Type' });

		string[] ret = new string[]{};
        HttpResponse res;
		try {
			res = http.send(req);
			api.parse(res);
			if (res.getStatusCode() == 200) {
				ret = (string[]) JSON.deserialize(res.getBody(), string[].class);
				api.parse(ret);
				api.setRows(ret.size());
			}
			else { throw new ExternalObjectException(api?.Response); }
		}
		catch (Exception e) {}
		finally { System.debug(api?.toString()); }

		Test.stopTest();
	}
}