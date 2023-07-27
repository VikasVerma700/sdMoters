@RestResource(urlMapping='/care/service/types')
global without sharing class CareServiceTypes {
	private final static String VIP = 'VIP';
	@HttpGet
	global static void getTypes() {
		RestResponse res = RestContext.response;
		try {
			RestRequest req = RestContext.request;
			String cmp = req.params.get('cmp');
			if (String.isBlank(cmp)) { throw new ServiceApptBooking.ApptException('No Company defined.'); }
			List<String> filterList;
			Boolean checkVIP = req.params.get('acctStatus') == VIP;
			List<Service_Type__c> services = ServiceApptBooking.getServices(cmp, filterList, checkVIP, false);

			List<ServiceType> rv = new List<ServiceType>();
			ServiceType cur;
			for (Service_Type__c sT : services) {
				if (!sT.Allow_External__c) { continue; }
				cur = new ServiceType();
				// cur.name = sT.Name;
				cur.name = sT.DisplayName__c;
				cur.description = (sT.Description__c != null) ? sT.Description__c : '';
				cur.allowCustCom = sT.Allow_Customer_Comments__c;
				cur.includedTypes = (sT.Included_Types__c != null) ? sT.Included_Types__c.split(',') : new List<String>();
				for (Integer i = 0; i < cur.includedTypes.size(); i++) {
					cur.includedTypes[i] = cur.includedTypes[i].trim();
				}
				rv.add(cur);
			}
			res.statusCode = 200;
			res.responseBody = Blob.valueOf(JSON.serialize(rv));
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new TypeResp(e)));
			res.statusCode = 400;
		}
	}

	global class TypeResp extends ServiceApptBooking.ApiResp { public TypeResp(Exception e) { super(e); } }

	global class ServiceType {
		global String name;
		global String description;
		global List<String> includedTypes;
		global Boolean allowCustCom;
	}
}