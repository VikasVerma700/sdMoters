@RestResource(urlMapping='/care/user/verify')
global without sharing class CareVerify {
	@HttpPost
	global static void verify(String token, String code) {
		RestResponse res = RestContext.response;
		res.addHeader('Content-Type', 'application/json');
		try {
			CareToken.AdditionalClaims claims = CareToken.parseToken(token);
			String curCode = CareToken.generateVerificationCode(claims.accountId, DateTime.now());
			Boolean isVerified = (code == curCode);
			if (String.isBlank(claims.mobile)) {
				throw new ServiceApptBooking.ApptException('Invalid mobile');
			}
			if (String.isBlank(claims.accountId)) {
				throw new ServiceApptBooking.ApptException('Invalid account Id.');
			}
			if (!isVerified) {
				String backwardCode = CareToken.generateVerificationCode(claims.accountId, DateTime.now().addSeconds(CareToken.TIMESTEP * -1));
				String forwardCode = CareToken.generateVerificationCode(claims.accountId, DateTime.now().addSeconds(CareToken.TIMESTEP));
				if (backwardCode != code && forwardCode != code) {
					throw new ServiceApptBooking.ApptException('Invalid verification code');
				}
			}
			string mobWoPrefix = claims.mobile.replaceFirst('^0+', '');
			string mobWPrefix = string.format('0{0}', new string[] { claims.mobile.replaceFirst('^0+', '') });
			Map<Id, Account> accMap = new Map<Id, Account>([SELECT Id, Mobile_Preferred__pc, Profile_Update_Duplicated_Mobile__c, X2FA_Verified_List__c
															FROM Account WHERE (Mobile_Preferred__pc != null AND (Mobile_Preferred__pc = :mobWoPrefix OR Mobile_Preferred__pc = :mobWPrefix)) OR
															Id = :claims.accountId]);
			List<Account> updList = new List<Account>();
			Account updAcc = accMap.get(claims.accountId);
			// if (claims.mobile != updAcc.Mobile_Preferred__pc) {
			if (mobWoPrefix != updAcc.Mobile_Preferred__pc && mobWPrefix != updAcc.Mobile_Preferred__pc) {
				updAcc.Mobile_Preferred__pc = claims.mobile;
				updAcc.PersonMobilePhone = claims.mobile;
				updAcc.Profile_Mobile_Update__c = claims.mobile;
				updAcc.Profile_Update_Duplicated_Mobile__c = false;
				updAcc.X2FA_Verified_List__c = '';
			}
			updList.add(updAcc);
			for (Account a : accMap.values()) {
				if (a.Id == claims.accountId) { continue; }
				a.Mobile_Preferred__pc = 'CRM';
				a.PersonMobilePhone = 'CRM';
				a.Profile_Update_Duplicated_Mobile__c = true;
				updList.add(a);
			}
			update updList;
			// we separate it into two update calls due to the process builder call
			Set<String> curVerifications = (String.isBlank(updAcc.X2FA_Verified_List__c)) ? new Set<String>() :
											new Set<String>(updAcc.X2FA_Verified_List__c.split(';'));
			curVerifications.add(claims.company);
			updAcc.X2FA_Verified_List__c = String.join(new List<String>(curVerifications), ';');
			update updAcc;
			List<CareLogin.Veh> vehList = CareLogin.getVehList(claims.company, claims.division, updAcc.Id);
			CareLogin.UserResp user = CareLogin.getLoginInfo(claims.company, claims.division, updAcc.Id, vehList);
			CareLogin.LoginResp loginBody = new CareLogin.LoginResp();
			loginBody.token = CareToken.issueJWTToken(claims.company, claims.division, updAcc, DateTime.now());
			loginBody.user = user;
			res.responseBody = Blob.valueOf(JSON.serialize(loginBody));
			res.statusCode = 200;
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new CareLogin.LoginResp(e)));
			res.statusCode = 400;
		}
	 }
}