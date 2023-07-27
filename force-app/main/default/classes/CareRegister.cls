@RestResource(urlMapping='/care/user/register')
global without sharing class CareRegister {

	@HttpPost
	global static void register(String token, String mobile) {
		RestResponse res = RestContext.response;
		res.addHeader('Content-Type', 'application/json');
		try {
			if (String.isBlank(token) || String.isBlank(mobile)) {
				throw new ServiceApptBooking.ApptException('Token and Mobile required for registration call.');
			}
			DateTime curTime = DateTime.now();
			CareToken.AdditionalClaims claims = CareToken.parseToken(token);
			claims.mobile = mobile;
			claims.createdDate = curTime;
			String code = CareToken.generateVerificationCode(claims.accountId, curTime);
			CareToken.VerificationResp resp = CareToken.issuePartialToken(claims);
			CareLogin.sendVerificationSMS(code, claims.company, claims.division, mobile);
			res.responseBody = Blob.valueOf(JSON.serialize(resp));
			res.statusCode = 200;
		} catch (Exception e) {
			System.debug('ERROR: ' + e.getMessage() + '|' + e.getStackTraceString());
			res.responseBody = Blob.valueOf(JSON.serialize(new CareToken.VerificationResp(e)));
			res.statusCode = 400;
		}
	}
}