/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 07-29-2023
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public class Util {
  ///// Email handler ////////////////////////////////////////////////////////
  private static final string EMAIL_REG = '^[a-z0-9!#$%&\'*+/=?^_`{|}~-]+(?:\\.[a-z0-9!#$%&\'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$';
  public static Boolean checkEmail(String email) {
    if (String.isBlank(email)) {
      return false;
    }
    return Pattern.compile(EMAIL_REG)
      .matcher(email.trim().toLowerCase())
      .matches();
  }
  public static Boolean newEscalationRulesActiveTest = null;

  public static void sendEmail(string body) {
    sendEmail(Envir.Subject, body);
  }
  public static void sendEmail(string subject, string body) {
    sendEmail(Envir.USER_CUR, subject, body);
  }
  public static void sendEmail(User recipient, string subject, string body) {
    sendEmail(Envir.USER_ADMIN, recipient, subject, body);
  }
  public static void sendEmail(User[] recipients, string subject, string body) {
    sendEmail(Envir.USER_ADMIN, recipients, subject, body);
  }
  public static void sendEmail(
    User sender,
    User recipient,
    string subject,
    string body
  ) {
    sendEmail(sender, new List<User>{ recipient }, subject, body);
  }
  public static void sendEmail(
    User sender,
    User[] recipients,
    string subject,
    string body
  ) {
    List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
    Messaging.SingleEmailMessage cur;
    for (User recipient : recipients) {
      cur = new Messaging.SingleEmailMessage();
      cur.setTargetObjectId(recipient.Id);
      cur.setReplyTo(sender.Email);
      cur.setSenderDisplayName(sender.Name);
      cur.setSubject(subject);
      cur.setBccSender(false);
      cur.setUseSignature(false);
      cur.setHtmlBody(body);
      cur.setSaveAsActivity(false); // prevent error when sending to user
      mails.add(cur);
    }
    if (Test.isRunningTest()) {
      System.debug('Test Unit (email not sent): ' + JSON.serialize(mails));
    } else {
      Messaging.sendEmail(mails, false);
    }
  }

  ///// Name handler /////////////////////////////////////////////////////////
  public static string purifyName(string name) {
    if (name == null)
      return '';
    string[] tokens = new List<string>{
      '(?i) b ',
      '(?i) b\\. ',
      '(?i) bin ',
      '(?i) bt ',
      '(?i) bt\\. ',
      '(?i) binti ',
      '(?i) a/l ',
      '(?i) a/p ',
      '(?i) al ',
      '(?i) ap '
    };
    string ret = name;
    for (string token : tokens) {
      ret = ret.replaceAll(token, ' ');
    }
    return ret;
  }
  ///// NRIC handler /////////////////////////////////////////////////////////
  public static Date getBirthdate(String nric) {
    if (String.isBlank(nric)) {
      return null;
    }

    nric = nric.replaceAll('\\D', '');
    /** Return null if doesn't meet initial criteria of Malaysian NRIC. */
    if (!nric.isNumeric() || nric.trim().length() != 12) {
      return null;
    }
    string y2d = String.valueOf(Date.today().year()).substring(2, 4);
    string by2d = nric.left(2);
    string bmn = nric.substring(2, 4);
    string bdy = nric.substring(4, 6);
    /** Determine year prefix. */
    string byr = (by2d >= y2d) ? '19' + by2d : '20' + by2d;

    return Date.newInstance(
      Integer.valueOf(byr),
      Integer.valueOf(bmn),
      Integer.valueOf(bdy)
    );
  }

  public class Identification {
    public string DocType;
    public string DocNumber;
    public string Original;
    public Identification(string type, string nmbr, string ori) {
      this.DocType = type;
      this.DocNumber = nmbr;
      this.Original = ori;
    }
  }
  public static Identification getIdent(string value) {
    Identification id;

    /** Derive identification from value -- best effort basis */
    if (String.isBlank(value)) {
      id = new Identification('Invalid', null, value);
      return id;
    }

    string clean = value.replace('-', '');
    if (clean.length() == 12) {
      /** 12-digit: NRIC or New CoID */
      if (!clean.isNumeric()) {
        id = new Identification('Unidentified', clean, value);
        return id;
      }
      /** 3-4 digit: >12 */
      if (Integer.valueOf(clean.mid(2, 2)) > 12) {
        id = new Identification('Company Reg No.', clean, value);
      } else {
        id = new Identification('Malaysian NRIC', clean, value);
      }
      return id;
    } else if (clean.left(1).isAlpha()) {
      /** Priority 1: leftmost character is alphabet */
      id = new Identification('Passport No.', clean, value);
    } else if (clean.right(1).isAlpha()) {
      /** Priority 2: rightmost character is alphabet */
      id = new Identification('Company Reg No.', clean, value);
    } else {
      /** Unable to identify */
      id = new Identification('Unidentified', clean, value);
    }
    return id;
  }
  ///// HTTP header //////////////////////////////////////////////////////////
  public static string genBasicAuthHeader(string username, string password) {
    return 'Basic ' +
      EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password));
  }

  ///// SAP Id ///////////////////////////////////////////////////////////////
  public static string padSapId(Integer sapId) {
    return padSapId(String.valueOf(sapId));
  }
  public static string padSapId(string sapId) {
    return padSapId(sapId, 8);
  }
  public static string padSapId(string sapId, integer length) {
    return sapId?.leftPad(length, '0');
  }

  public static Integer getSapId(string sapId) {
    Integer sid;
    try {
      sid = Integer.valueOf(sapId);
    } catch (Exception e) {
    }
    return sid;
  }

  ///// SObject valid date values ////////////////////////////////////////////
  /**
   * Returns only valid date range for SObject DML saving
   * Between: 1700-01-01 and 4000-12-31
   */
  public static Date validDate(Date inDate) {
    if (inDate == null) {
      return null;
    }
    if (inDate.year() < 1700 || inDate.year() > 4000) {
      return null;
    }
    return inDate;
  }
  public static Date validDate(string inDate) {
    // if (String.isBlank(inDate)) { return null; }
    Date outDate;
    try {
      outDate = Date.valueOf(inDate);
    } catch (Exception e) {
      return null;
    }
    return validDate(outDate);
  }

  public static String joinKeys(List<String> keyList, String delimiter) {
    String key = String.join(keyList, delimiter);
    return key;
  }

  public static Boolean newEscalationRulesActive() {
    if (Test.isRunningTest() && newEscalationRulesActiveTest != null) {
      return newEscalationRulesActiveTest;
    } else if (
      System.Label.newEscalationRulesEffective.toLowerCase() == 'yes'
    ) {
      return true;
    } else {
      return false;
    }
  }

  /** Stringify with default. */
  public static string str(DateTime o) {
    return o != null ? o.format() : '';
  }
  public static string str(DateTime o, string d) {
    return o != null ? o.format() : d;
  }
  public static string str(DateTime o, string fmt, string d) {
    return o != null ? o.format(fmt) : d;
  }
  public static string str(Schema.SObjectField field) {
    return String.valueOf(field);
  }
  public static string val(Schema.SObjectField picklist, string value) {
    Schema.PicklistEntry[] picklistEntries = picklist.getDescribe()
      .getPicklistValues();
    Map<string, string> mapPicklist = new Map<string, string>();

    for (Schema.PicklistEntry picklistEntry : picklistEntries) {
      mapPicklist.put(picklistEntry.getValue(), picklistEntry.getLabel());
    }

    return mapPicklist.get(value);
  }

  public static String getClassname(Object classInstance) {
    String className = String.valueOf(classInstance);
    return className.substringBefore(':');
  }
  /*
	public static boolean isPersonEntity(String customerType, String custNum, String custName){
        Boolean isPerson = logEntityType(customerType, custNum, custName);
        String message = 'Entity type is: ';
        message += isPerson ? 'Person' : 'Business';
        String stackTrace = 'isPersonEntity';
        if(customerType != null){
            stackTrace += '\nType: '+customerType;
        }
        if(custNum != null){
            stackTrace += '\nCustNum: '+custNum;
        }
        if(custName != null){
            stackTrace += '\nCustomer Name: '+custName;
        }
        ApplicationLogUtility.insertApexCompletionLog('Util',message,stackTrace,ApplicationLogUtility.PRIORITY_LOW,false);
        return isPerson;
    }

    public static boolean logEntityType(String customerType, String custNum, String custName){
        Pattern nonAlphanumeric = Pattern.compile('[^a-zA-Z0-9]');
        if(customerType == 'I'){
            return true;
        }
        else if(customerType == 'C'){
            return false;
        }
        else if(custNum != null){
            Matcher nonAlphaMatcher = nonAlphanumeric.matcher(custNum);
            String docNum = nonAlphaMatcher.replaceAll('').toUpperCase();
            
            if(docNum.length() == 12){
                String year = docNum.substring(0, 2);
                String month = docNum.substring(2,4);
                String day = docNum.substring(4,6);
                String stateCode = docNum.substring(6,8);
                String genderCode = docNum.substring(8,12);
                Set<String> stateCodes = new Set<String>{
                    '01','02','03','04','05','06','07','08','09','10','11','12','13','14','15','16'
                };
                Boolean validDate = false;
                if((year+month+day).isNumeric()){
                    try{
                        Date.valueOf('19'+year +'-'+month+'-'+day);
                        validDate = true;
                    }
                    catch(TypeException typeExcep){
                        try{
                            ApplicationLogUtility.insertApexErrorLog(new Util(),typeExcep,ApplicationLogUtility.PRIORITY_LOW,false);
                            Date.valueOf('20'+year +'-'+month+'-'+day);
                            validDate = true;
                        }
                        catch(Exception e){
                            ApplicationLogUtility.insertApexErrorLog(new Util(),typeExcep,ApplicationLogUtility.PRIORITY_LOW,false);
                        }
                    }
                }
                //person account: yyMMdd-ss(statecode)-####
                if(validDate && stateCodes.contains(stateCode)){
                    return true;
                }
                
                year = docNum.substring(0,4);
                String businessEntity = docNum.substring(4,6);
                Set<String> businessEntitySet = new Set<String>{
                    '01','02','03','04','05','06'
                };
                Boolean validYear = false;
                //check for yyyy-##-###### (business)
                try{
                    Integer yearInteger = Integer.valueOf(year);
                    if(yearInteger >= 2019){
                        validYear = true;
                        Integer sequenceNumber = Integer.valueOf(docNum.substring(6,12));
                        if(businessEntitySet.contains(businessEntity)){
                            return false;
                        }
                    }
                }
                catch(Exception e){
                    System.debug(e);
                }
                //company name hints in customer name -> business
                if(String.isNotBlank(custName)){
                    if(custName.indexOf('SDN BHD') != -1){
                        return false;
                    }
                }
                
                //return default false
                return false;
            }
            else{
                //passport thus a person account
				try{
					if('ABCDEFGHIJKLMNOPQRSTUVWXYZ'.indexOf(docNum.substring(0,1)) != -1){
						return true;
					}
				}
				catch(Exception e){
					ApplicationLogUtility.insertApexErrorLog(new Util(),e,ApplicationLogUtility.PRIORITY_LOW,false);
				}
                //less than 12 digits -> company
                return false;
            }
        }
        else{
            return true;
        }
    }
*/

  public static boolean isPersonEntity(
    Id id,
    String custType,
    String custDocNum,
    String custName
  ) {
    // assume Person by default
    boolean isPerson = true;

    Pattern nonAlphanumeric = Pattern.compile('[^a-zA-Z0-9]');
    Matcher nonAlphaMatcher = nonAlphanumeric.matcher(
      custDocNum == null ? '' : custDocNum
    );
    String docNum = nonAlphaMatcher.replaceAll('').toUpperCase();

    if (String.isBlank(docNum)) {
      /** P2: when docNum is blank, assume Person */
      if (custType == 'C') {
        isPerson = false;
      } else if (custType == 'I') {
        isPerson = true;
      }
      // System.debug('isPerson set: ' + isPerson);
      Util.logEntityType(
        custType,
        custDocNum,
        custName,
        isPerson,
        id + '|' + 'Document Number (' + custDocNum + ') is not valid.'
      );
      return isPerson;
    }

    Integer curYear = Date.today().year();
    string centPre = String.valueOf(curYear - 100).substring(0, 2);
    string centCur = String.valueOf(curYear).substring(0, 2);
    String year, month, day, pb;
    Integer docuYear;

    if (docNum.length() >= 8 && docNum.isNumeric()) {
      /** P3: proceed when docNum has at least 6-digit long and numeric only */
      year = docNum.substring(0, 2);

      Integer lastCent = Integer.valueOf(centPre + year);
      Integer currCent = Integer.valueOf(centCur + year);
      docuYear = Integer.valueOf(centPre + year);

      if (
        !((curYear - currCent) > 16 &&
        (curYear - currCent) <= 100 ||
        (curYear - lastCent) > 16 &&
        (curYear - lastCent) <= 100)
      ) {
        /**
         * Business:
         * yyyy	: 4-digit year (cannot be later than current year)
         * ee	: entity code (01 - 06)
         * */
        docuYear = Integer.valueOf(docNum.substring(0, 4));
        String businessEntity = docNum.substring(4, 6);
        Set<String> businessEntitySet = new Set<String>{
          '01',
          '02',
          '03',
          '04',
          '05',
          '06'
        };
        if (
          docuYear >= 1957 &&
          docuYear <= curYear &&
          businessEntitySet.contains(businessEntity)
        ) {
          isPerson = false;
          // System.debug('isPerson set: ' + isPerson);
        } else {
          /** Fallback to Person type (uncertain). */
          isPerson = true;
          // System.debug('isPerson set: ' + isPerson);
          Util.logEntityType(
            custType,
            custDocNum,
            custName,
            isPerson,
            id +
              '|' +
              'Note: Document Number (' +
              custDocNum +
              ') format may not be for a Person (CI).'
          );
          // return isPerson;
        }
      } else {
        if ((curYear - currCent) > 16 && (curYear - currCent) <= 100) {
          year = String.valueOf(currCent);
        } else if ((curYear - lastCent) > 16 && (curYear - lastCent) <= 100) {
          year = String.valueOf(lastCent);
        }
        /**
         * Person:
         * yy	: 2-digit year
         * MM	: 2-digit month
         * dd	: 2-digit day
         * pb	: 2-digit place of birth (https://en.wikipedia.org/wiki/Malaysian_identity_card#Place_of_birth)
         * Determine probable valid yy based on assumption
         * 1) buyer would not live up to 100-year old
         * 2) buyer would be at least 16-year old to have a valid driving license
         */
        /** Converting yyyyMMdd into date would determine if the date is valid */
        month = docNum.substring(2, 4);
        day = docNum.substring(4, 6);
        pb = docNum.substring(6, 8);
        string[] invalidPb = new List<string>{
          '00',
          '17',
          '18',
          '19',
          '20',
          '69',
          '70',
          '73',
          '80',
          '81',
          '94',
          '95',
          '96',
          '97'
        };
        try {
          Date.valueOf(String.join(new List<string>{ year, month, day }, '-'));
          if (invalidPb.contains(pb)) {
            throw new TypeException('Place of birth is invalid.');
          }
          isPerson = true;
          // System.debug('isPerson set: ' + isPerson + ' ' + year);
        } catch (TypeException e) {
          /** First 6-digit not a proper date format */
          String businessEntity = docNum.substring(4, 6);
          Set<String> businessEntitySet = new Set<String>{
            '01',
            '02',
            '03',
            '04',
            '05',
            '06'
          };
          if (businessEntitySet.contains(businessEntity)) {
            isPerson = false;
            // System.debug('isPerson set: ' + isPerson);
          } else {
            /** Fallback to Person type (uncertain). */
            isPerson = true;
            // System.debug('isPerson set: ' + isPerson);
            Util.logEntityType(
              custType,
              custDocNum,
              custName,
              isPerson,
              id +
                '|' +
                'Note: Document Number (' +
                custDocNum +
                ') format may not be for a Person (ICI).'
            );
            // return isPerson;
          }
        }
      }
      // else {
      // 	// System.debug('Identified year for (' + docNum + ') is ' + year);
      // 	// Util.logEntityType(custType,custDocNum,custName,isPerson, 'Note: Unable to identify type based on Document Number (' + custDocNum + ').');
      // }

      /** custDocNum is within abnormal length */
      if (docNum.length() < 12) {
        /** Assume missing digit on docNum */
        Util.logEntityType(
          custType,
          custDocNum,
          custName,
          isPerson,
          id +
            '|' +
            'Document Number (' +
            custDocNum +
            ') is incomplete or invalid.'
        );
      } else if (docNum.length() > 12) {
        /** Assume extra digit on docNum */
        Util.logEntityType(
          custType,
          custDocNum,
          custName,
          isPerson,
          id +
            '|' +
            'Note: Document Number (' +
            custDocNum +
            ') is abnormally long.'
        );
      }
    } else if (docNum.length() >= 17 && !docNum.isNumeric()) {
      /** Could be co. reg. new + old */
      isPerson = false;
      // System.debug('isPerson set: ' + isPerson);
      Util.logEntityType(
        custType,
        custDocNum,
        custName,
        isPerson,
        id +
          '|' +
          'Note: Document Number (' +
          custDocNum +
          ') is abnormally long.'
      );
    } else {
      /** Look for Passport or co. reg. old */
      string charNo1 = docNum.substring(0, 1);
      string charLast = docNum.substring(docNum.length() - 1, docNum.length());

      /**
       * Assume passport <= 9 char (Person)
       * A######
       */
      if (!charNo1.isNumeric()) {
        // System.debug('charNo1 ! numeric');
        isPerson = true;
        // System.debug('isPerson set: ' + isPerson);
      } else if (!charLast.isNumeric()) {
        /**
         * Assume old co. reg (Business)
         * ####A
         */
        // System.debug('charLast ! numeric');
        isPerson = false;
        // System.debug('isPerson set: ' + isPerson);
      } else {
        Util.logEntityType(
          custType,
          custDocNum,
          custName,
          isPerson,
          id +
            '|' +
            'Unable to determine Document Number (' +
            custDocNum +
            ') format.'
        );
        // System.debug('charNo1 & charLast ! numeric ' + new string[] { custType, custDocNum, custName });
      }
    }

    /** Log when custType != isPerson */
    if (String.isNotBlank(custType)) {
      string retType = (isPerson ? 'I' : 'C');
      if (String.isNotBlank(custType) && custType != retType) {
        Util.logEntityType(
          custType,
          custDocNum,
          custName,
          isPerson,
          id +
            '|' +
            'Customer Type (' +
            custType +
            ') does not match with Document Number (' +
            custDocNum +
            ') format.'
        );
      }

      /** P1: Customer Type determines record type
       * C = company (Business)
       * I = individual (Person)
       */
      if (custType == 'C') {
        isPerson = false;
      } else if (custType == 'I') {
        isPerson = true;
      }
      // System.debug('isPerson set ' + isPerson + ' 143');
    } else {
      // AppLog: Customer Type not specified
      Util.logEntityType(
        custType,
        custDocNum,
        custName,
        isPerson,
        id +
          '|' +
          'Customer Type not specified for (' +
          docNum +
          ') [' +
          isPerson +
          '].'
      );
    }

    return isPerson;
  }

  public static ApplicationLog__c logEntityType(
    String custType,
    String custDocNum,
    String custName,
    Boolean isPerson,
    String logMessage
  ) {
    if (custType == null) {
      custType = '';
    }
    String message = logMessage;
    String stackTrace = 'isPersonEntity';
    if (custType != null) {
      stackTrace += '\nType: ' + custType;
    }
    if (custDocNum != null) {
      stackTrace += '\nCustNum: ' + custDocNum;
    }
    if (custName != null) {
      stackTrace += '\nCustomer Name: ' + custName;
    }
    stackTrace += '\nIdentified: ' + (isPerson ? 'Person' : 'Business');

    if (String.isNotBlank(logMessage)) {
      stackTrace += '\n' + logMessage;
    }
    system.debug(message);
    return ApplicationLogUtility.insertApexCompletionLog(
      'Util',
      message,
      stackTrace,
      ApplicationLogUtility.PRIORITY_LOW,
      false
    );
  }

  public static Object getInstance(String className) {
    Type t = Type.forName(className);
    /*
		if (t != null) {
			return ((Callable) t.newInstance()).call(methodName, args);
		}
		return null;
		*/
    return t.newInstance();
  }
}
