@RestResource(urlMapping='/care/user/update')
global without sharing class CareUpdateProfile {
	@HttpPost
	global static void updateProfile(String mobile, String email, String accId) {
		RestResponse res = RestContext.response;
		try {
			if (String.isBlank(accId)) { throw new ServiceApptBooking.ApptException('No Account Id specified'); }
			if (String.isBlank(mobile)) { throw new ServiceApptBooking.ApptException('Mobile Number is empty.'); }
			if (String.isBlank(email)) { throw new ServiceApptBooking.ApptException('Email is empty.'); }
			List<Account> accList = [SELECT Id, PersonMobilePhone, Mobile_Preferred__pc, Home_Email__c, Other_Email__c, Office_Email__c, Active_Work__c,
									 Active_Other__c, Active_Home__c FROM Account WHERE Id = :accId AND IsPersonAccount = TRUE];
			if (accList.size() <= 0) { throw new ServiceApptBooking.ApptException('Invalid Account Id'); }
			List<Account> updList = new List<Account>();
			Account updAcc = new Account(Id = accList[0].Id);
			// if (mobile != accList[0].Mobile_Preferred__pc) {
			UtilPhone upMobile = new UtilPhone(mobile);
			string e164 = upMobile.toE164();
			if (e164 != accList[0].PersonMobilePhone) {
				updAcc.PersonMobilePhone = e164;
				updAcc.Mobile_Preferred__pc = upMobile.toNoPrefixNumber(); // mobile;
				updAcc.Profile_Mobile_Update__c = e164; // mobile;
				updAcc.Profile_Update_Duplicated_Mobile__c = false;
				List<Account> dupList = [
					SELECT Id, Mobile_Preferred__pc, Profile_Update_Duplicated_Mobile__c
					FROM Account
					WHERE PersonMobilePhone = :e164
					// WHERE Mobile_Preferred__pc = :mobile
					AND Id != :accList[0].Id
				];
				System.debug('=====' + JSON.serialize(dupList));
				for (Account a : dupList) {
					a.Mobile_Preferred__pc = 'CRM';
					a.PersonMobilePhone = 'CRM';
					a.Profile_Update_Duplicated_Mobile__c = true;
					updList.add(a);
				}
			}
			updAcc.Profile_Email_Update__c = email;
			if (email == accList[0].Home_Email__c || email == accList[0].Other_Email__c || email == accList[0].Office_Email__c) {
				updAcc.Active_Home__c = (email == accList[0].Home_Email__c);
				updAcc.Active_Other__c = (email == accList[0].Other_Email__c);
				updAcc.Active_Work__c = (email == accList[0].Office_Email__c);
			} else {
				if (accList[0].Active_Work__c) {
					updAcc.Office_Email__c = email;
				} else if (accList[0].Active_Other__c) {
					updAcc.Other_Email__c = email;
				} else {
					updAcc.Home_Email__c = email;
					updAcc.Active_Home__c = true;
				}
			}
			updList.add(updAcc);
			update updList;
			res.responseBody = Blob.valueOf(JSOn.serialize(new UpdateProfile()));
			res.statusCode = 200;
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new UpdateProfile(e)));
			res.statusCode = 400;
		}
	}

	global class UpdateProfile extends ServiceApptBooking.ApiResp {
		public UpdateProfile() { super(); }
		public UpdateProfile(Exception e) { super(e); }
	}
}