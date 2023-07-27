global without sharing class PDPA {
	public final static String PDPA_NAME = 'PDPA Consent T&C for Existing Customers';
	public final static String PDPA_VER = '2';
	public final static Map<String, String> CMP_EMBED_TNC = new Map<String, String>{'028' => 'Embedded-AB'};
	public final static Map<String, String> CMP_TNC = new Map<String, String>{'028' => '(AB)'};
	public class PDPAException extends Exception {}

	public static PDPA_Consent__mdt consentTerms(String cmp) { return consentTerms(new Set<String> { cmp }).get(cmp); }

	public static Map<String, PDPA_Consent__mdt> consentTerms(Set<String> cmp) {
		List<PDPA_Consent__mdt> consents = [SELECT Company__c, DeveloperName, PDPA_Consent__c, Marketing_Consent__c, Terms_and_Conditions__c
											FROM PDPA_Consent__mdt WHERE Company__c IN :cmp];
		Map<String, PDPA_Consent__mdt> consentMap = new Map<String, PDPA_Consent__mdt>();
		for (PDPA_Consent__mdt c : consents) {
			consentMap.put(c.Company__c, c);
		}
		return consentMap;
	}

	public static Attachment getTNC(String cmp) { return getTNC(new Set<String> { cmp }).get(cmp); }
	public static Map<String, Attachment> getTNC(Set<String> cmp) { return getTNCFromTitle(cmp, CMP_TNC); }

	public static String getTNCString(String cmp) { return getTNCString(new Set<String>{ cmp }).get(cmp); }
	public static Map<String, String> getTNCString(Set<String> cmp) {
		Map<String, Attachment> attRes = getTNC(cmp);
		Map<String, String> strRes = new Map<String, String>();
		String body;
		Blob b;
		for (String s : attRes.keySet()) {
			b = attRes.get(s).Body;
			if (b == null) { continue; }
			body = b.toString();
			strRes.put(s, body);
		}
		return strRes;
	}

	public static String getEmbeddedTNC(String cmp) { return getEmbeddedTNC(new Set<String>{ cmp }).get(cmp); }
	public static Map<String, String> getEmbeddedTNC(Set<String> cmp) {
		Map<String, Attachment> attRes = getTNCFromTitle(cmp, CMP_EMBED_TNC);
		Map<String, String> strRes = new Map<String, String>();
		String body;
		Blob b;
		Attachment att;
		for (String s : attRes.keySet()) {
			att = attRes.get(s);
			if (att == null) { continue; }
			b = attRes.get(s).Body;
			if (b == null) { continue; }
			body = b.toString();
			body = body.replace('{! TnCLastModified }', att.LastModifiedDate.format('dd-MMMM-yyyy'));
			strRes.put(s, body);
		}
		return strRes;
	}


	public static Map<String, Attachment> getTNCFromTitle(Set<String> cmp, Map<String, String> titleMap) {
		List<String> titles = new List<String>();
		String curAttName;
		for (String s : cmp) {
			curAttName = titleMap.get(s);
			if (curAttName == null) { continue; }
			titles.add('Name LIKE \'%' + curAttName + '%\'');
		}
		List<Legislation_Type__c> legType = [SELECT Id, Name FROM Legislation_Type__c WHERE Name = :PDPA_NAME AND Inactive__c = FALSE LIMIT 1];
		if (legType.size() <= 0) { throw new PDPAException('Unable to find legislation type:' + PDPA_NAME); }
		Id legTypeId = legType[0].Id;
		String queryStr = 'SELECT Name, Id, Body, LastModifiedDate FROM Attachment WHERE ContentType = \'text/html\' AND ParentId = :legTypeId ' +
							'AND (' + String.join(titles, ' OR ') + ') ORDER BY LastModifiedDate DESC LIMIT 1';
		List<Attachment> attList = Database.query(queryStr);
		Map<String, Attachment> rv = new Map<String, Attachment>();
		if (attList.size() <= 0) { return rv; }
		Set<String> remStr = new Set<String>(cmp);
		for (Attachment att : attList) {
			for (String s : remStr) {
				curAttName = titleMap.get(s);
				if (curAttName == null) { continue; }
				if (att.Name.contains(curAttName)) {
					rv.put(s, att);
					remStr.remove(s);
					break;
				}
			}
		}
		return rv;
	}

	public static Local_Legislation__C createPDPA(Account acc, String source) { return createPDPA(acc, source, true, true, true); }
	public static Local_Legislation__c createPDPA(Account acc, String source, Boolean mktgConsent, Boolean dataConsent, Boolean addToDB) {
		if (String.isBlank(source)) { throw new PDPA.PDPAException('No source provided.'); }
		List<Legislation_Type__c> legType = [SELECT Id, Name FROM Legislation_Type__c WHERE Name = :PDPA_NAME LIMIT 1];
		if (legType.size() <= 0) { throw new PDPA.PDPAException('Unable to find terms and conditions. Please contact administrator.'); }
		Local_Legislation__c newLeg = new Local_Legislation__c();
		newLeg.Account_Name__c = acc.Id;
		newLeg.Consent_Status__c = 'Consent';
		newLeg.Consent_Date_Time__c = DateTime.now();
		newLeg.Document_Number_Entered__c = acc.NRIC_Number__c;
		newLeg.Doc_Type__c = acc.Doc_Type__c;
		newLeg.Country__c = acc.Country__c;
		newLeg.I_have_read_the_consent_provisions__c = dataConsent;
		newLeg.Legislation_Type__c = legType[0].Id;
		newLeg.Source__c = source;
		newLeg.Email_To__c = acc.Default_Email__c;
		newLeg.Type_of_Legal_Legislation_Version__c = PDPA_VER;
		newLeg.Opt_In__c = mktgConsent;
		if (addToDB) { insert newLeg; }
		return newLeg;
	}
}