//Generated by wsdl2apex

public class M3TechApi {
/** Synchronous API. */
    public class deliverMessage_element {
        public String Userkey;
        public String Password;
        public String MsgID;
        public String TimeStamp;
        public String ServiceID;
        public String aMsg;
        public String Mobile;
        public String MCN;
        public String ChargeCode;
        public String MsgType;
        private String[] Userkey_type_info = new String[]{'Userkey','http://tempuri.org/PlatformIMP/Service1',null,'0','1','false'};
        private String[] Password_type_info = new String[]{'Password','http://tempuri.org/PlatformIMP/Service1',null,'0','1','false'};
        private String[] MsgID_type_info = new String[]{'MsgID','http://tempuri.org/PlatformIMP/Service1',null,'0','1','false'};
        private String[] TimeStamp_type_info = new String[]{'TimeStamp','http://tempuri.org/PlatformIMP/Service1',null,'0','1','false'};
        private String[] ServiceID_type_info = new String[]{'ServiceID','http://tempuri.org/PlatformIMP/Service1',null,'0','1','false'};
        private String[] aMsg_type_info = new String[]{'aMsg','http://tempuri.org/PlatformIMP/Service1',null,'0','1','false'};
        private String[] Mobile_type_info = new String[]{'Mobile','http://tempuri.org/PlatformIMP/Service1',null,'0','1','false'};
        private String[] MCN_type_info = new String[]{'MCN','http://tempuri.org/PlatformIMP/Service1',null,'0','1','false'};
        private String[] ChargeCode_type_info = new String[]{'ChargeCode','http://tempuri.org/PlatformIMP/Service1',null,'0','1','false'};
        private String[] MsgType_type_info = new String[]{'MsgType','http://tempuri.org/PlatformIMP/Service1',null,'0','1','false'};
        private String[] apex_schema_type_info = new String[]{'http://tempuri.org/PlatformIMP/Service1','true','false'};
        private String[] field_order_type_info = new String[]{'Userkey','Password','MsgID','TimeStamp','ServiceID','aMsg','Mobile','MCN','ChargeCode','MsgType'};
    }
    public class deliverMessageResponse_element {
        public String deliverMessageResult;
        private String[] deliverMessageResult_type_info = new String[]{'deliverMessageResult','http://tempuri.org/PlatformIMP/Service1',null,'0','1','false'};
        private String[] apex_schema_type_info = new String[]{'http://tempuri.org/PlatformIMP/Service1','true','false'};
        private String[] field_order_type_info = new String[]{'deliverMessageResult'};
    }
    public class IMPServiceSoap {
        public String endpoint_x = 'https://www.m3tech.my:2500/imp/simedarby/submitsm.asmx';
        public Map<String,String> inputHttpHeaders_x;
        public Map<String,String> outputHttpHeaders_x;
        public String clientCertName_x;
        public String clientCert_x;
        public String clientCertPasswd_x;
        public Integer timeout_x;
        private String[] ns_map_type_info = new String[]{'http://tempuri.org/PlatformIMP/Service1', 'M3TechApi'};
        public String deliverMessage(String Userkey, String Password, String MsgID, String TimeStamp, String ServiceID, String aMsg, String Mobile,
                                     String MCN, String ChargeCode, String MsgType) {
            M3TechApi.deliverMessage_element request_x = new M3TechApi.deliverMessage_element();
            request_x.Userkey = Userkey;
            request_x.Password = Password;
            request_x.MsgID = MsgID;
            request_x.TimeStamp = TimeStamp;
            request_x.ServiceID = ServiceID;
            request_x.aMsg = aMsg;
            request_x.Mobile = Mobile;
            request_x.MCN = MCN;
            request_x.ChargeCode = ChargeCode;
            request_x.MsgType = MsgType;
            M3TechApi.deliverMessageResponse_element response_x;
            Map<String, M3TechApi.deliverMessageResponse_element> response_map_x = new Map<String, M3TechApi.deliverMessageResponse_element>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
              this,
              request_x,
              response_map_x,
              new String[]{endpoint_x,
              'http://tempuri.org/PlatformIMP/Service1/deliverMessage',
              'http://tempuri.org/PlatformIMP/Service1',
              'deliverMessage',
              'http://tempuri.org/PlatformIMP/Service1',
              'deliverMessageResponse',
              'M3TechApi.deliverMessageResponse_element'}
            );
            response_x = response_map_x.get('response_x');
            return response_x.deliverMessageResult;
        }
    }
}