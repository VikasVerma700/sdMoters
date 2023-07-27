global without sharing class CareToken {
	public final static String SUBJECT = 'SFCareApp';
	public final static String ISSUER = 'SDMotors-SG';
	public final static String CERT_NAME = 'CareApp';
	public static Set<String> KNOWN_AUD = new Set<String>{};
	public final static Integer TIMESTEP = 60; // seconds
	private final static Integer CODE_LEN = 6;
	private final static Integer TOKEN_EXP = 60 * 60; // 1 hour
	private final static String HASH_FN = 'hmacSHA1';
	private final static Blob PRIVATE_KEY = Blob.valueOf('!z%C*F-JaNdRgUkXp2s5v8y/B?D(G+Kb');
	public final static Map<String, String> ALG_MAP = new Map<String, String> { 'RS256' => 'RSA-SHA256' };

	private final static Map<String, Integer> HEX_MAP = new Map<String, Integer> { '0' => 0, '1' => 1, '2' => 2, '3' => 3, '4' => 4, '5' => 5, '6' => 6,
																					'7' => 7, '8' => 8, '9' => 9, 'A' => 10, 'B' => 11, 'C' => 12, 'D' => 13,
																					'E' => 14, 'F' => 15 };

	public static String generateDirectLoginToken(String cmp, String div, Boolean needs2FA, String aud) {
		if (!KNOWN_AUD.contains(aud) && !Test.isRunningTest()) {
			throw new ServiceApptBooking.ApptException('Please add audience to known audience');
		}
		AdditionalClaims token = new AdditionalClaims();
		token.company = cmp;
		token.division = div;
		token.needs2FA = needs2FA;
		return issueJWTToken(token, 0, aud);
	}

	public static RegistrationResp issuePartialTokenForReg(String cmp, String div, Account acc, DateTime createdDate) {
		AdditionalClaims newToken = new AdditionalClaims();
		newToken.company = cmp;
		newToken.division = (String.isBlank(div)) ? '' : div;
		newToken.createdDate = createdDate;
		newToken.accountId = acc.Id;
		newToken.mobile = '';
		return issuePartialTokenForReg(newToken);
	}

	public static RegistrationResp issuePartialTokenForReg(AdditionalClaims claims) {
		RegistrationResp resp = new RegistrationResp();
		resp.token = issueJWTToken(claims, 30 * 60); // longer timestep for the registration flow token for retries
		return resp;
	}

	public static VerificationResp issuePartialToken(String cmp, String div, Account acc, DateTime createdDate) {
		AdditionalClaims newToken = new AdditionalClaims();
		newToken.company = cmp;
		newToken.division = (String.isBlank(div)) ? '' : div;
		newToken.createdDate = createdDate;
		newToken.accountId = acc.Id;
		newToken.mobile = acc.Mobile_Preferred__pc;
		return issuePartialToken(newToken);
	}

	public static VerificationResp issuePartialToken(AdditionalClaims claims) {
		VerificationResp resp = new VerificationResp();
		resp.allowRetrySeconds = TIMESTEP;
		resp.token = issueJWTToken(claims, TIMESTEP * 2); // 1 timestep leeway
		resp.validFrom = claims.createdDate;
		resp.validSeconds = TIMESTEP;
		return resp;
	}

	public static String issueJWTToken(String cmp, String div, Account acc, DateTime createdDate) {
		AdditionalClaims newToken = new AdditionalClaims();
		newToken.company = cmp;
		newToken.division = (String.isBlank(div)) ? '' : div;
		newToken.createdDate = createdDate;
		newToken.accountId = acc.Id;
		newToken.mobile = acc.Mobile_Preferred__pc;
		newToken.isVerified = true;
		return issueJWTToken(newToken);
	}

	public static String issueJWTToken(AdditionalClaims claims) {
		return issueJWTToken(claims, TOKEN_EXP);
	}

	public static String issueJWTToken(AdditionalClaims claims, Integer validity) {
		return issueJWTToken(claims, validity, '');
	}

	public static String issueJWTToken(AdditionalClaims claims, Integer validity, String aud) {
		Map<String, Object> addClaims = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(claims, true));
		Auth.JWT newJWT = new Auth.JWT();
		newJWT.setAud(aud); // only set for those special directLogin tokens
		newJWT.setSub(SUBJECT);
		newJWT.setIss(ISSUER);
		newJWT.setValidityLength(validity);
		newJWT.setAdditionalClaims(addClaims);
		Auth.JWS jws = new Auth.JWS(newJWT, CERT_NAME);
		return jws.getCompactSerialization();
	}

	public static AdditionalClaims parseToken(String token) {
		return parseToken(token, true, false);
	}

	public static AdditionalClaims parseToken(String token, Boolean checkExp, Boolean checkAud) {
		List<String> jwtParts = token.split('\\.');
		if (jwtParts.size() != 3) { throw new ServiceApptBooking.ApptException('Invalid JWT token'); }
		List<Blob> jwtBase64Decoded = base64DecodeJWT(jwtParts);
		System.debug(jwtParts);
		// get the algo from header
		Map<String, String> header = (Map<String, String>) JSON.deserialize(jwtBase64Decoded[0].toString(), Map<String, String>.class);
		// verify jwt first
		Blob encodedData = Blob.valueOf(String.join(new List<String> { jwtParts[0], jwtParts[1] }, '.'));
		String rawAlg = header.get('alg');
		if (String.isBlank(rawAlg)) { throw new ServiceApptBooking.ApptException('Invalid JWT Token'); }
		String alg = ALG_MAP.get(rawAlg);
		if (String.isBlank(alg)) { throw new ServiceApptBooking.ApptException('Unrecognized JWT Algorithm: ' + rawAlg); }
		if (!Crypto.verify(alg, encodedData, jwtBase64Decoded[2], CERT_NAME)) {
			throw new ServiceApptBooking.ApptException('Invalid JWT token');
		}
		String claimsData = jwtBase64Decoded[1].toString();
		Map<String, Object> claimsMap = (Map<String, Object>) JSON.deserializeUntyped(claimsData);
		String iss = (String) claimsMap.get('iss');
		if (iss == null || iss != ISSUER) { throw new ServiceApptBooking.ApptException('Invalid JWT Token'); }
		String subj = (String) claimsMap.get('sub');
		if (subj == null || subj != SUBJECT) { throw new ServiceApptBooking.ApptException('Invalid JWT Token'); }
		// only set for those special directLogin tokens
		if (checkAud) {
			String aud = (String) claimsMap.get('aud');
			if (String.isBlank(aud) || !KNOWN_AUD.contains(aud)) { throw new ServiceApptBooking.ApptException('Invalid JWT Token'); }
		}
		if (checkExp) {
			Long expTime = (Long) claimsMap.get('exp');
			Long now = DateTime.now().getTime() / 1000;
			if (expTime != null && now > expTime) { throw new ServiceApptBooking.ApptException('Expired JWT Token.'); }
		}
		// retrieve data
		AdditionalClaims claims = (AdditionalClaims) JSON.deserialize(claimsData, AdditionalClaims.class);
		return claims;
	}

	public static String generateVerificationCode(Id accId, DateTime tokenTime) {
		TOTP curCode = new TOTP();
		curCode.accountId = accId;
		curCode.step = (tokenTime.getTime() / 1000) / TIMESTEP;
		System.debug('tokenTime:' + tokenTime + 'mils:' + tokenTime.getTime() / 1000 + 'json:' + JSON.serialize(curCode));
		Blob data = Crypto.generateMac(HASH_FN, Blob.valueOf(JSON.serialize(curCode)), PRIVATE_KEY);
		String hexStr = EncodingUtil.convertToHex(data);
		Integer truncatedCode = truncateCode(hexStr);
		return String.valueOf(truncatedCode).leftPad(CODE_LEN, '0');
	}

	private static List<Blob> base64DecodeJWT(List<String> jwtParts) {
		List<Blob> rv = new List<Blob>();
		for (Integer i = 0; i < 2; i++) {
			rv.add(EncodingUtil.base64Decode(jwtParts[i]));
		}
		String signature = jwtParts[2];
		// taken from https://www.rfc-editor.org/rfc/rfc7515.html#appendix-C
		signature = signature.replace('-', '+');
		signature = signature.replace('_', '/');
		Integer sigLen = Math.mod(signature.length(), 4);
		switch on Math.mod(signature.length(), 4) {
			when 0 {}
			when 2 { signature += '=='; }
			when 3 { signature += '='; }
			when else { throw new ServiceApptBooking.ApptException('Invalid JWT Token'); }
		}
		Blob bSig = EncodingUtil.base64Decode(signature);
		rv.add(bSig);
		return rv;
	}

	// taken from https://tools.ietf.org/html/rfc4226
	private static Integer truncateCode(String hexStr) {
		List<String> characters = hexStr.toUppercase().split('');
		if (characters.size() != 40) { throw new ServiceApptBooking.ApptException('Unexpected length for SHA-1 Hash.'); }
		Integer val;
		List<Integer> byteArray = new List<Integer>();
		Integer first4Bit, next4Bit;
		for (Integer i = 0; i < characters.size(); i += 2) {
			first4Bit = HEX_MAP.get(characters[i]);
			next4Bit = HEX_MAP.get(characters[i + 1]);
			byteArray.add((first4Bit << 4) + next4Bit);
		}
		Integer offset = byteArray[19] & 15;
		Integer code = (byteArray[offset] & 127) << 24;
		code = code | ((byteArray[offset + 1] & 255) << 16);
		code = code | ((byteArray[offset + 2] & 255) << 8);
		code = code | (byteArray[offset + 3] & 255);
		System.debug(code);
		Integer maxVal = 1;
		for (Integer i = 0; i < CODE_LEN; i++) { maxVal *= 10; }
		return Math.mod(code, maxVal);

	}

	global class RegistrationResp extends ServiceApptBooking.ApiResp {
		public RegistrationResp() { super(); }
		public RegistrationResp(Exception e) { super(e); }
		public String token;
	}

	global class VerificationResp extends ServiceApptBooking.ApiResp {
		public VerificationResp() { super(); }
		public VerificationResp(Exception e) { super(e); }
		public String token;
		public DateTime validFrom;
		public Integer validSeconds;
		public Integer allowRetrySeconds;
	}

	global class AdditionalClaims {
		public String company;
		public String division;
		public String accountId;
		public String mobile;
		public DateTime createdDate;
		public Boolean isVerified = false;
		public Boolean needs2FA = true;
	}

	global class TOTP {
		public String accountId;
		public Long step;
	}
}