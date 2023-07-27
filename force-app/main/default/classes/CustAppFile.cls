global without sharing class CustAppFile {
	public static List<String> ATT_FIELDS = new List<String> { 'Id', 'Name', 'Description', 'ContentType', 'BodyLength', 'ParentId' };
	global class FileCls {
		public String id;
		public String url;
		public String name;
		public Integer size;
		public String mime;

		global FileCls(Attachment att) {
			this.id = att.Id;
			this.name = att.Name;
			this.url = CustAppAPI.INSTANCE_URL + '/services/data/v48.0/sobjects/Attachment/' + att.Id + '/body';
			this.size = att.BodyLength;
			this.mime = att.ContentType;
		}
		global FileCls() {}
	}
		
	@Future(callout=true)
	public static void saveFile(String url, String name, Id parentId, String appCallbackName, String appCallbackId) {
		Attachment att = new Attachment();
		att.ParentId = parentId;
		att.Name = name;
		Http http = new Http();
		HttpRequest req = new HttpRequest();
		req.setEndpoint(url);
		req.setMethod('GET');
		req.setTimeout(60000);
		HttpResponse resp = http.send(req);
		att.Body = resp.getBodyAsBlob();
		att.ContentType = resp.getHeader('Content-Type');
		insert att;
		EventBus.publish(new List<Customer_App_Callback__e>{ new Customer_App_Callback__e(Id__c = appCallbackId, Event__c = appCallbackName) });
	}
}