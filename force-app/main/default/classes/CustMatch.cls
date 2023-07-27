public class CustMatch {
	public final static Map<String, Integer> CMP_MIN_MATCH = new Map<String, Integer> { '02' => 2, '03' => 1, '05' => 2, '888' => 2, '028' => 1 };
	public final static Integer DEF_MIN_MATCH = 2;

	// public static Account checkAcc(Set<String> cmp, String partialNric, String docType, String prefix, String mobile, String email, String lastName, String name) {
	// 	string phoneNum = prefix + mobile;
	// 	return checkAcc(cmp, partialNric, docType, phoneNum, email, lastName, name);
	// }

	public static Account checkAcc(Set<String> cmp, String partialNric, String docType, String mobile, String email, String lastName, String name) {
		UtilPhone up = new UtilPhone(mobile);
		string woutTrunk = (up.toNational() != null) ? '%' + String.valueOf(Integer.valueOf(up.toNational().replace(' ', '').replace('-', ''))) : '';
		// string woutTrunk = u.onlyNumber(mobile);
		// string withTrunk = '0' + woutTrunk;
		String likePartialNric = (!String.isBlank(partialNric) ? '%' : ' ') + partialNric;
		List<Account> accnList = [
			SELECT
				Id, Name, LastName, Account_Name__c, Partial_NRIC__c, Doc_Type__c, NRIC_Number__c
				, PersonMobilePhone, Mobile_Country_Code_1__pc, Mobile_Preferred__pc
				, Home_Email__c, Office_Email__c, Other_Email__c
				, Marketing_Opt_Out__pc, Default_Email__c, PersonContactId, Customer_Number__c
				, (
					SELECT Id, Registration_No__c, Vehicle__c
					FROM Vehicle_Ownerships__r
					WHERE Status__c = 'Active' /* AND Company__c IN :cmp */
				)
				, (
					SELECT CreatedDate, ContactPhone__c
					FROM ServiceOrders__r
					WHERE ContactPhone__c != null
					AND ContactPhone__c LIKE :woutTrunk
					ORDER BY CreatedDate DESC
					LIMIT 1
				)
				FROM Account
				WHERE IsPersonAccount = true AND Deactivate__pc = FALSE
				AND ((Account_Name__c != null AND Account_Name__c = :lastName)
				OR (NRIC_Number__c != null AND (NRIC_Number__c = :partialNric OR NRIC_Number__c LIKE :likePartialNric))
				OR (Mobile_Preferred__pc != null AND (Mobile_Preferred__pc LIKE :woutTrunk))
				OR (PersonMobilePhone != null AND PersonMobilePhone LIKE :mobile)
				OR (Home_Email__c != null AND Home_Email__c = :email) OR (Other_Email__c != null AND Other_Email__c = :email)
				OR (Office_Email__c != null AND Office_Email__c = :email))
				ORDER BY NRIC_Number__c DESC, CreatedDate DESC
		];
		Account matched = CustMatch.checkMatching(cmp, accnList, partialNric, docType, mobile, email, lastName, name);
		if (matched != null) {
			System.debug('Matched record:');
			System.debug('Id\tName\tNRIC\tMobile\tEmail(o)\tEmail(h)\tEmail(o)\tDef. Email');
			System.debug(String.format('{0}\t{1}\t{2} ({3})\t{4}:{5} {6}\t{7}\t{8}\t{9}\t{10}'
					, new string[] {
						matched.Id
						, matched.Name
						, String.isBlank(matched.NRIC_Number__c) ? '' : matched.NRIC_Number__c
						, String.isBlank(matched.Doc_Type__c) ? '' : matched.Doc_Type__c
						, String.valueOf(Integer.valueOf(matched.Mobile_Country_Code_1__pc))
						, matched.Mobile_Preferred__pc
						, matched.PersonMobilePhone
						, String.isBlank(matched.Office_Email__c) ? '' : matched.Office_Email__c
						, String.isBlank(matched.Home_Email__c) ? '' : matched.Home_Email__c
						, String.isBlank(matched.Other_Email__c) ? '' : matched.Other_Email__c
						, String.isBlank(matched.Default_Email__c) ? '' : matched.Default_Email__c
			}));
		}
		else { System.debug('Matched record: ' + matched); }
		return matched;
	}
	// public static Account checkBusinessAcc(String partialNric, String name) {
	// 	String likePartialNric = (!String.isBlank(partialNric) ? '%' : ' ') + partialNric;
	// 	List<Account> bisAccList = [SELECT Id FROM Account WHERE IsPersonAccount = false AND Deactivate__pc = false AND
	// 								((Account_Name_Proper__c != null AND Account_Name_Proper__c = :name) OR
	// 								 (NRIC_Number__c != null AND (NRIC_Number__c = :partialNric OR NRIC_Number__c LIKE :likePartialNric)))
	// 								ORDER BY CreatedDate DESC LIMIT 1];
	// 	if (bisAccList.isEmpty()) {
	// 		return null;
	// 	}
	// 	return bisAccList[0];
	// }

	// public static Lead checkLead(Set<String> cmp, String partialNric, String docType, String mobile, String email, String lastName, String name) {
	// 	String likePartialNric = (!String.isBlank(partialNric) ? '%' : ' ') + partialNric;
	// 	List<Lead> leadList = [SELECT Id, OwnerId
	// 							// , Marketing_Opt_Out__c
	// 							// , Mobile_Preferred__c
	// 							, MobilePhone
	// 							, Surname__c, NRIC_Number__c, Email, LastName, Doc_Type__c,
	// 							Partial_Document_Number__c FROM Lead WHERE IsConverted = false AND (((Surname__c != null AND Surname__c = :lastName) OR
	// 							(NRIC_Number__c != null AND (NRIC_Number__c = :partialNric OR NRIC_Number__c LIKE :likePartialNric)) OR
	// 							(Partial_Document_Number__c != null AND Partial_Document_Number__c = :partialNric) OR
	// 							(Mobile_Preferred__c != null AND Mobile_Preferred__c = :mobile) OR
	// 							(Email != null AND Email = :email)))];
	// 	return CustMatch.checkMatching(cmp, leadList, partialNric, docType, mobile, email, lastName, name);
	// }

	public static Account checkMatching(Set<String> cmp, List<Account> accList, String partialNric, String docType, String mobile, String email,
										String lastName, String name) {
		return (Account) checkMatchingSObj(cmp, accList, partialNric, docType, mobile, email, lastName, name);
	}

	public static Lead checkMatching(Set<String> cmp, List<Lead> leadList,  String partialNric, String docType, String mobile, String email, String lastName,
									String name) {
		return (Lead) checkMatchingSObj(cmp, 1, leadList, partialNric, docType, mobile, email, lastName, name); // DEFAULT TO MATCH 1
	}

	public static SObject checkMatchingSObj(Set<String> cmp, List<SObject> objList, String partialNric, String docType, String mobile, String email,
											String lastName, String name) {
		Integer minMatch = getMinMatch(cmp);
		return checkMatchingSObj(cmp, minMatch, objList, partialNric, docType, mobile, email, lastName, name);
	}

	public static SObject checkMatchingSObj(Set<String> cmp, Integer minMatch, List<SObject> objList, String partialNric, String docType, String mobile,
											String email, String lastName, String name) {
		UtilPhone up = new UtilPhone(mobile);
		// string woutTrunk = mobile;
		string woutTrunk = (up.toNational() != null) ? String.valueOf(Integer.valueOf(up.toNational().replace(' ', '').replace('-', ''))) : '';
		string withTrunk = '0' + woutTrunk;
		Set<FieldType> notExclusiveMatch = new Set<FieldType>{ FieldType.DOC, FieldType.LAST_NAME, FieldType.NAME };
		// Set<FieldType> notExclusiveMatch = new Set<FieldType>{ FieldType.PARTIAL_NRIC, FieldType.LAST_NAME, FieldType.Name };

		Map<Integer, SObject> highestMatch = new Map<Integer, SObject>();
		Schema.SObjectType accType = Schema.Account.getSObjectType();
		Set<String> nameCheck = splitName(name);
		System.debug('Id\tName\tNRIC\tMobile\tEmail(o)\tEmail(h)\tEmail(o)\tDef. Email');
		for (SObject obj : objList) {
			Account acc = (Account)obj;
			System.debug(String.format('{0}\t{1}\t{2} ({3})\t{4}:{5} {6}\t{7}\t{8}\t{9}\t{10}'
					, new string[] {
						acc.Id
						, acc.Name
						, String.isBlank(acc.NRIC_Number__c) ? '' : acc.NRIC_Number__c
						, String.isBlank(acc.Doc_Type__c) ? '' : acc.Doc_Type__c
						, String.valueOf(Integer.valueOf(acc.Mobile_Country_Code_1__pc))
						, acc.Mobile_Preferred__pc
						, acc.PersonMobilePhone
						, String.isBlank(acc.Office_Email__c) ? '' : acc.Office_Email__c
						, String.isBlank(acc.Home_Email__c) ? '' : acc.Home_Email__c
						, String.isBlank(acc.Other_Email__c) ? '' : acc.Other_Email__c
						, String.isBlank(acc.Default_Email__c) ? '' : acc.Default_Email__c
			}));
			List<Field> matchers = new List<Field>();
			if (String.isNotBlank(partialNric) && minMatch >= 1) {
				matchers.add(new Field(FieldType.PARTIAL_NRIC, 'NRIC_Number__c', partialNric));
				matchers.add(new Field(FieldType.DOC_TYPE, 'Doc_Type__c', docType));
			}
			if (obj.getSObjectType() == accType) {
				// matchers.add(new Field(FieldType.MOBILE, 'Mobile_Country_Code_1__pc', prefix));
				matchers.add(new Field(FieldType.MOBILE, 'Mobile_Preferred__pc', withTrunk));
				matchers.add(new Field(FieldType.MOBILE, 'Mobile_Preferred__pc', woutTrunk));
				matchers.add(new Field(FieldType.MOBILE, 'PersonMobilePhone', mobile));
				// matchers.add(new Field(FieldType.MOBILE, 'ServiceOrder__r.ContactPhone__c', withTrunk));
				// matchers.add(new Field(FieldType.MOBILE, 'ServiceOrder__r.ContactPhone__c', woutTrunk));
				matchers.add(new Field(FieldType.EMAIL, 'Home_Email__c', email));
				matchers.add(new Field(FieldType.EMAIL, 'Office_Email__c', email));
				matchers.add(new Field(FieldType.EMAIL, 'Other_Email__c', email));
				// matchers.add(new Field(FieldType.EMAIL, 'Default_Email__c', email));
				// if (minMatch > 1) {
					matchers.add(new Field(FieldType.NAME, 'LastName', name));
					matchers.add(new Field(FieldType.LAST_NAME, 'Account_Name__c', lastName));
				// }
			} else {
				// matchers.add(new Field(FieldType.MOBILE, 'Mobile_Preferred__c', mobile));
				// matchers.add(new Field(FieldType.MOBILE, 'Mobile_Country_Code_1__pc', prefix));
				matchers.add(new Field(FieldType.MOBILE, 'Mobile_Preferred__c', withTrunk));
				matchers.add(new Field(FieldType.MOBILE, 'Mobile_Preferred__c', woutTrunk));
				matchers.add(new Field(FieldType.MOBILE, 'PersonMobilePhone', mobile));
				// matchers.add(new Field(FieldType.MOBILE, 'ServiceOrder__r.ContactPhone__c', withTrunk));
				// matchers.add(new Field(FieldType.MOBILE, 'ServiceOrder__r.ContactPhone__c', woutTrunk));
				matchers.add(new Field(FieldType.EMAIL, 'Email', email));
				// if (minMatch > 1) {
					matchers.add(new Field(FieldType.NAME, 'LastName', name));
					matchers.add(new Field(FieldType.LAST_NAME, 'Surname__c', lastName));
				// }
			}

			Set<FieldType> matchedFieldSet = new Set<FieldType>();
			Integer fieldMatched = 0;

			for (Field f : matchers) {
				String valueToCheck;
				if (u.getType(obj.get(f.fieldName)) == 'Decimal' || u.getType(obj.get(f.fieldName)) == 'Double') {
					valueToCheck = String.valueOf(Integer.valueOf(obj.get(f.fieldName)));
				}
				else { valueToCheck = (String) obj.get(f.fieldName); }
				if (String.isBlank(valueToCheck)) { continue; }
				System.debug(String.format('Start match: {0} / {1} / {2} ', new string[] { valueToCheck, String.valueOf(f.type), String.valueOf(f.fieldValue) }));

				if (f.type == FieldType.PARTIAL_NRIC && !String.isBlank(f.fieldValue)) {
					valueToCheck = valueToCheck.right(f.fieldValue.length());
				}
				if (f.type == FieldType.NAME) {
					if (!String.isBlank(f.fieldValue)) {
						Set<String> nameToCheck = splitName(valueToCheck);
						if (nameToCheck.containsAll(nameCheck)) {
							matchedFieldSet.add(f.type);
							fieldMatched++;
							System.debug(String.format('{0}: {1}', new string[] { String.valueOf(f.type), String.valueOf(fieldMatched) }));
							continue;
						}
					}
				} if (f.type == FieldType.MOBILE) {
					if (valueToCheck.equalsIgnoreCase(f.fieldValue)) {
						matchedFieldSet.add(f.type);
						fieldMatched += 7; /* 7 points score for phone match, so with 3 email match, phone still is higher priority. */
						System.debug(String.format('{0}: {1}', new string[] { String.valueOf(f.type), String.valueOf(fieldMatched) }));
						continue;
					}
				} if (f.type == FieldType.EMAIL) {
					if (valueToCheck.equalsIgnoreCase(f.fieldValue)) {
						matchedFieldSet.add(f.type);
						fieldMatched += 2; /* 2 points score for email match. */
						System.debug(String.format('{0}: {1}', new string[] { String.valueOf(f.type), String.valueOf(fieldMatched) }));
						continue;
					}
				} else {
					if (valueToCheck.equalsIgnoreCase(f.fieldValue)) {
						matchedFieldSet.add(f.type);
						fieldMatched++; /* 1 point score for other match. */
						System.debug(String.format('{0}: {1}', new string[] { String.valueOf(f.type), String.valueOf(fieldMatched) }));
						continue;
					}
				}
			}
			// if hv doc type, must have both to be considered a match
			if (String.isNotBlank(docType) && matchedFieldSet.contains(FieldType.DOC_TYPE) != matchedFieldSet.contains(FieldType.PARTIAL_NRIC)) {
				if (matchedFieldSet.contains(FieldType.DOC_TYPE)) {
					fieldMatched--;
					matchedFieldSet.remove(FieldType.DOC_TYPE);
				}
				if (matchedFieldSet.contains(FieldType.PARTIAL_NRIC)) {
					fieldMatched--;
					matchedFieldSet.remove(FieldType.PARTIAL_NRIC);
				}
			}
			Set<FieldType> checkMatch = new Set<FieldType>(matchedFieldSet);
			checkMatch.removeAll(notExclusiveMatch);
			if (checkMatch.isEmpty()) { continue; }
			highestMatch.put(fieldMatched, obj);
		}

		Integer highestMatchNum = 0;
		for (Integer numMatched : highestMatch.keySet()) {
			System.debug(String.format('{0}: {1}', new string[] { String.valueOf(numMatched), JSON.serialize(highestMatch.get(numMatched)) }));
			highestMatchNum = highestMatchNum < numMatched ? numMatched : highestMatchNum;
		}
		return highestMatchNum >= minMatch ? highestMatch.get(highestMatchNum) : null;
	}

	private static String setDocKey(String docType, String docNum) { return 'DT:' + docType + 'DN:' + docNum; }

	private static Set<String> splitName(String name) {
		Set<String> splitName = (String.isBlank(name)) ? new Set<String>() : new Set<String>(name.split('\\s'));
		Set<String> rv = new Set<String>();
		for (String s : splitName) {
			String checker = s.toLowerCase().trim();
			if (!String.isBlank(checker)) { rv.add(checker); }
		}
		return rv;
	}

	private static Integer getMinMatch(Set<String> cmp) {
		Integer curMatch;
		Integer minMatch = -1;
		for (String c : cmp) {
			curMatch = CMP_MIN_MATCH.get(c);
			curMatch = (curMatch == null) ? DEF_MIN_MATCH : curMatch;
			minMatch = (minMatch < curMatch) ? curMatch : minMatch;
		}
		return minMatch;
	}

	public class Field {
		FieldType type;
		String fieldName;
		String fieldValue;
		public Field(FieldType type, String fieldName, String fieldValue) {
			this.type = type;
			this.fieldName = fieldName;
			this.fieldValue = fieldValue;
		}
	}

	public enum FieldType {
		PARTIAL_NRIC,
		DOC,
		DOC_TYPE,
		LAST_NAME,
		PREFIX,
		MOBILE,
		EMAIL,
		NAME
	}
}