@IsTest
public class M3TechApiWrapper_Test {

	@TestSetup
	public static void setup() {
		List<String> apiSetups = new List<String> { 
			'CareDB Username', 'Live CareDB Username', 
			'CareDB Password', 'Live CareDB Password', 
			'CareDB Endpoint', 'Live CareDB Endpoint',
			'CareQR Dev', 'CareQR Prd',
			'M3 Tech Username', 'M3 Tech Password', 'M3 Tech URL',
			'M3 Tech 2 Username', 'M3 Tech 2 Password', 'M3 Tech 2 URL',
			'M3 Sandbox URL','M3 Sandbox Username','M3 Sandbox Password','M3 Sandbox ServiceId',
            'M3 Production URL','M3 Production Username','M3 Production Password','M3 Production ServiceId'
		};
		List<API_Setup__c> setupList = new List<API_Setup__c>();
		for (String s : apiSetups) {
			setupList.add(new API_Setup__c(Name = s, Value__c = 'Test'));
		}
		insert setupList;

		// API_Setup__c apiSetupU = new API_Setup__c();
		// apiSetupU.Name = 'M3 Tech Username';
		// API_Setup__c apiSetupP = new API_Setup__c();
		// apiSetupP.Name = 'M3 Tech Password';
		// API_Setup__c apiSetupE = new API_Setup__c();
		// apiSetupE.Name = 'M3 Tech URL';
		// insert apiSetupU;
		// insert apiSetupP;
		// insert apiSetupE;

		// apiSetupU = new API_Setup__c(Name = 'M3 Tech 2 Username');
		// apiSetupP = new API_Setup__c(Name = 'M3 Tech 2 Password');
		// apiSetupE = new API_Setup__c(Name = 'M3 Tech 2 URL');
		// insert apiSetupU;
		// insert apiSetupP;
		// insert apiSetupE;
	}

	@isTest static void testDeliverMsg() {
		String success = 'YES';
		TestWSMock.M3TechAPI_Mock mock = new TestWSMock.M3TechAPI_Mock(success);
		Test.setMock(WebServiceMock.class, mock);
		Test.startTest();
		String res = M3TechApiWrapper.deliverMessage('test', 'test', 'test', 'test');
		Test.stopTest();
		System.assertEquals(res, success);
	}

	@isTest static void testDeliverMsg2() {
		String success = 'YES';
		TestWSMock.M3TechAPI2_Mock mock = new TestWSMock.M3TechAPI2_Mock(success);
		Test.setMock(WebServiceMock.class, mock);
		Test.startTest();
		String res = M3TechApiWrapper.deliverMessage2('test', 'test', 'test', 'test');
		Test.stopTest();
		System.assertEquals(res, success);
	}

	@isTest static void testDeliverMsgM3TechApiServiceWrapper(){
		String success = null;
		TestWSMock.M3TechApiService_Mock mock = new TestWSMock.M3TechApiService_Mock(success);
		test.setMock(WebServiceMock.class, mock);
		test.startTest();
		String res = M3TechApiServiceWrapper.deliverMessage('test', 'test', 'test');
		test.stopTest();
		System.assertEquals(res,success);

	}

	@isTest static void testDeliverMsg2M3TechApiServiceWrapper(){
		string ret = '00';
		string msgID = '1234';
		TestWSMock.M3TechApiService_SUCC mock = new TestWSMock.M3TechApiService_SUCC(msgId, ret);
		test.setMock(WebServiceMock.class, mock);
		test.startTest();
		M3TechApiServiceWrapper.DeliverMsgReturnWrapper deliverMsgRet = new M3TechApiServiceWrapper.DeliverMsgReturnWrapper();
		deliverMsgRet = M3TechApiServiceWrapper.deliverMessage2(msgId, 'msgContent', 'mobileNo', 'workshopName', 'wsSmsEndpoint', 'wsServiceId', 'wsUserkey', 'wsSmsPassword');
		test.stopTest();
		System.assertEquals(deliverMsgRet.returnCode, ret);
		system.assertEquals(deliverMsgRet.msgId, msgId);

	}
}