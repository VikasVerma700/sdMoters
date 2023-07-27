public class M3TechApiServiceWrapper {
    //Sandbox
    public static String AbEndpoint = API_Setup__c.getInstance('M3 Sandbox URL').Value__c;
    public static String AbUserName = API_Setup__c.getInstance('M3 Sandbox Username').Value__c;
    public static string AbPassword = API_Setup__c.getInstance('M3 Sandbox Password').Value__c;
    public static string AbServiceId = API_Setup__c.getInstance('M3 Sandbox ServiceId').value__c;

    //Production
    public static string ProdEndpoint = API_Setup__c.getInstance('M3 Production URL').value__c;
    public static string ProdUserName = API_Setup__c.getInstance('M3 Production Username').value__c;
    public static string ProdPassword = API_Setup__c.getInstance('M3 Production Password').value__c;
    public static string ProdServiceId = API_Setup__c.getInstance('M3 Production ServiceId').value__c;


    public static string Endpoint;
    public static string UserName;
    public static string Password;
    public static string ServiceId;

    public static final integer TIMED_OUT_SHORT = 5000;
    public static final integer TIMED_OUT_NORMAL = 90000;
    public static final integer TIMED_OUT_LONG = 120000;

    static{
        Endpoint = (AB.IsSandbox)? AbEndpoint:ProdEndpoint;
        UserName = (AB.isSandbox)? AbUserName:ProdUserName;
        Password = (AB.isSandbox)? AbPassword:ProdPassword;
        ServiceId = (AB.isSandbox)? AbServiceId:AbServiceId;
    }

    public static string deliverMessage(string MsgId, string MobileNo, string msgContent){
        M3TechApiService.IMPServiceSoap svc = new M3TechApiService.IMPServiceSoap();
        svc.endpoint_x = Endpoint;
        svc.timeout_x = TIMED_OUT_LONG;
        system.System.debug('1');
        string TimeStamp = Datetime.now().format('yyyyMMddHHmmss');
        string ret = svc.deliverMessage(UserName, Password, MsgId, TimeStamp, ServiceId, msgContent, MobileNo, 'push', '000', '03');
        return ret;
    }

    public static DeliverMsgReturnWrapper deliverMessage2(string msgId, string msgContent, string mobileNo, string workshopName, String wsSmsEndpoint, string wsServiceId, string wsUserkey, string wsSmsPassword){
        M3TechApiService.IMPServiceSoap svc= new M3TechApiService.IMPServiceSoap();
        DeliverMsgReturnWrapper deliverMsgRet = new DeliverMsgReturnWrapper();
        svc.endpoint_x = wsSmsEndpoint;
        svc.timeout_x = TIMED_OUT_LONG;
        string timeStamp = datetime.now().format('yyyyMMddHHmmss');
        string ret = svc.deliverMessage(wsUserkey, wsSmsPassword, msgId, timeStamp, wsServiceId, msgContent, mobileNo, '66600', '000', '03');
        string retCode = ret.split(',')[0];
        string retMsgId = ret.split(',')[1];
        string returnDesc;

        Map<String, SMSAPIResponseCode__mdt> smsAPIResponseCodes = SMSAPIResponseCode__mdt.getAll();
        if(smsAPIResponseCodes.containsKey(retCode)){
            returnDesc = smsAPIResponseCodes.get(retCode).Description__c;
        } else{
            returnDesc = 'Unknown code';
        }

        deliverMsgRet.returnCode = retCode;
		deliverMsgRet.returnDesc = returnDesc;
		deliverMsgRet.msg = msgContent;
		deliverMsgRet.mobileNumber = mobileNo;
		deliverMsgRet.workshopCode = workshopName;
		deliverMsgRet.msgId = retMsgId;
		deliverMsgRet.smsCount = SMSCounter(msgContent);

        return deliverMsgRet;
    }

    public class DeliverMsgReturnWrapper {
        public string returnCode;
        public string returnDesc;
        public string msg;
        public string mobileNumber;
        public string workshopCode;
        public string msgId;
        public integer smsCount;
    }

    public static Integer SMSCounter(String msgContent){
		if(msgContent.length() <= 152){
			return 1;
		}else if(msgContent.length() >= 153 && msgContent.length() <= 248){
			return 2;
		}else if(msgContent.length() >= 249 && msgContent.length() <= 456){
			return 3;
		}
		return 0;
	}
}