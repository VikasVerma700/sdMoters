@RestResource(urlMapping='/care/user/enquiry')
global without sharing class CareCase {

	@HttpPost
	global static void newCase(String vo, String enquiryType, String cmp) {
		RestResponse res = RestContext.response;
		SavePoint sp = Database.setSavePoint();
		try {
			RestRequest req = RestContext.request;
			List<Vehicle_Ownership__c> voList = [SELECT Id, Customer__c, Customer__r.PersonContactId, Vehicle__c FROM Vehicle_Ownership__c WHERE Id = :vo];
			if (voList.size() <= 0) { throw new ServiceApptBooking.ApptException('Invalid VO Id.'); }
			
			Case newCase = new Case();

			newCase.Priority = 'Low';
			newCase.Status = 'New';
			newCase.Type = 'General Enquiry';
			newCase.Origin = 'Care App';
			newCase.RecordTypeId = Envir.recordTypeByDevName.get('GeneralEnquiry').Id; // Schema.SObjectType.Case.getRecordTypeInfosByName().get('General Enquiry').getRecordTypeId();

			newCase.Operating_Unit__c = '028';
			newCase.Incident_Location__c = 'AbAraDamansara';
			newCase.Department__c = 'Others';

			newCase.Subject = enquiryType;
			// newCase.Enquiry_Type__c = enquiryType;
			newCase.Chassis__c = voList[0].Vehicle__c;
			newCase.AccountId = voList[0].Customer__c;
			newCase.ContactId = voList[0].Customer__r.PersonContactId;

			newCase.UniqueCaseIdentifier__c = newCase.Type + newCase.AccountId + newCase.Chassis__c + newCase.Subject + newCase.Enquiry_Type__c +
											  String.valueOf(Datetime.now().format('hh:mm dd-MM-yyyy'));
			QueueSobject qso = [
				SELECT Id, QueueId, Queue.Name, Queue.DeveloperName, SobjectType
				FROM QueueSobject
				WHERE SobjectType = 'Case'
				AND Queue.DeveloperName = 'CfmOwners'
			];
			newCase.OwnerId = qso.QueueId;
			System.debug(JSON.serialize(newCase));
			insert newCase;
			res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>()));
			res.statusCode = 200;
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new CaseResp(e)));
			res.statusCode = 400;
		}
	}

	global class CaseResp extends ServiceApptBooking.ApiResp {
		public CaseResp(Exception e) { super(e); }
	}
}