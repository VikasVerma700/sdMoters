@IsTest
public class CustAppCallback_Test {
	@IsTest
	public static void testCallback() {
		List<String> events = new List<String> { 'UPDATE_ACCOUNT', 'UPSERT_LTA_VEHICLE', 'UPSERT_VEHICLE_ALTERNATE_DRIVER', 'REMOVE_VEHICLE_ALTERNATE_DRIVER',
												'SEND_TEST_DRIVE_REQUEST', 'SEND_ENQUIRY', 'SEND_TRADE_IN', 'UPSERT_MARKETING_RSVP',
												'UPSERT_VEHICLE_INSURANCE', 'REMOVE_VEHICLE_INSURANCE', 'SEND_NOTIFICATION_READ_RECEIPT',
												'UPDATE_RO' };
		RestContext.request = new RestRequest();
		RestContext.response = new RestResponse();
		Test.startTest();
		CustAppCallback.CallbackReq req = new CustAppCallback.CallbackReq();
		for (String s : events) {
			req.event = s;
			RestContext.request.requestBody = Blob.valueOf(JSON.serialize(req));
			CustAppCallback.callback();
		}
		Test.stopTest();
		// check debug logs, there shld be errors since the rest of the body isnt included
	}
}