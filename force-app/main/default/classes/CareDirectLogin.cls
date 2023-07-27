@RestResource(urlMapping='/care/user/directLogin')
global without sharing class CareDirectLogin {
	@HttpPost
	global static void login(String mobOrCmpRegNum, String regNum, String code) {
		RestResponse res = RestContext.response;
		try {
			if (String.isBlank(code)) { throw new ServiceApptBooking.ApptException('No code provided.'); }
			CareToken.AdditionalClaims claims = CareToken.parseToken(code, false, true);
			CareLogin.HAS_2FA = claims.needs2FA;
			CareLogin.login(mobOrCmpRegNum, regNum, claims.company, claims.division);
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new CareLogin.LoginResp(e)));
			res.statusCode = 400;
		}
	}
}