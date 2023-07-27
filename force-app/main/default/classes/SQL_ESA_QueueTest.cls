@isTest
public with sharing class SQL_ESA_QueueTest {

    public static final String PERSON_ACCOUNT = 'personTest';
    public static final String BUSINESS_ACCOUNT = 'businessTest';

	@TestSetup
	public static void makeData() {
		SQL_API_Base_Test.makeData();
        Account accnt = TestFactory.genAccount(1, false)[0];
        accnt.LastName = PERSON_ACCOUNT;
        accnt.NRIC_Number__c = null;
        accnt.DocumentNumberAlphaN__c = null;
        accnt.Mobile_Country_Code_1__pc = null;
        accnt.Mobile_Preferred__pc = null;
        accnt.PersonMobilePhone = null;
        insert accnt;

        accnt = TestFactory.genBusinessAccount(1, false)[0];
        accnt.Name = BUSINESS_ACCOUNT;
        accnt.NRIC_Number__c = null;
        accnt.DocumentNumberAlphaN__c = null;
        insert accnt;

        TestFactory.genTriggerSettings(ESATriggerHandler.TRIG_SETTING,true);
        TestFactory.genTriggerSettings(ApplicationLogTriggerHandler.TRIG_SETTING,true);
	}

    static SQL_ESA_Queue.CareContactRes response1;
    static SQL_ESA_Queue.CareContactRes response2;
    static SQL_ESA_Queue.CareContactRes response3;

    static{
        response1 = new SQL_ESA_Queue.CareContactRes();
        response1.contactIds = new long[] { 14812 };
        response1.companyCode = '028';
        response1.source = 'Autoline';
        response1.custNo = 61627;
        response1.dmsNo = '55928';
        response1.isBusiness = false;
        response1.salutation = 'Mr';
        response1.fullName = 'Shahrul Nizam bin Abd Rahim';
        response1.preferredName = 'Shahrul Nizam bin Abd Rahim';
        response1.dateOfBirth = Datetime.valueOf('1979-12-19 00:00:00');
        response1.docNum = '791219025071';
        response1.docNumRaw = '791219025071';
        response1.gender = 'M';
        response1.prefix = '60';
        response1.mobile = '129264594';
        response1.phone1raw = '0129264594';
        response1.prefix2 = null;
        response1.mobile2 = null;
        response1.phone2raw = null;
        response1.prefix3 = null;
        response1.mobile3 = null;
        response1.phone3raw = null;
        response1.email = 'shahrul_pb@yahoo.com.my';
        response1.address1 = 'No 9, Long Branch Residence';
        response1.address2 = 'Jalan Anggerik Disa 31/183B,';
        response1.address3 = 'Alam Kemuning, Seksyen 31';
        response1.postalCode = '40460';
        response1.city = 'Alam Kemuning, Seksyen 31';
        response1.state = 'Shah Alam';
        response1.emailOptOut = false;
        response1.letterOptOut = false;
        response1.smsOptOut = false;

		response2 = new SQL_ESA_Queue.CareContactRes();
		response2.contactIds = new long[] { 26996 };
		response2.companyCode = '028';
		response2.source = 'GDMS';
		response2.custNo = 73811;
		response2.dmsNo = '19455';
		response2.isBusiness = false;
		response2.salutation = 'Dato\'';
		response2.fullName = 'Low Boon Hing a/l Low Bon Bon';
		response2.preferredName = 'Low Boon Hing LBB';
		response2.dateOfBirth = Datetime.valueOf('1959-04-30 00:00:00');
		response2.docNum = '590430016065';
		response2.docNumRaw = '590430016065';
		response2.gender = 'M';
		response2.prefix = null;
		response2.mobile = null;
		response2.phone1raw = null;
		response2.prefix2 = '60';
		response2.mobile2 = '122233088';
		response2.phone2raw = '0122233088';
		response2.prefix3 = null;
		response2.mobile3 = null;
		response2.phone3raw = null;
		response2.email = 'jeffry@federalpoint.com.my';
		response2.address1 = '4 Jln 5/2A';
		response2.address2 = 'Taman TAR';
		response2.address3 = 'Ampang Jaya';
		response2.postalCode = '68000';
		response2.city = 'Ampang Jaya';
		response2.state = 'Ampang';
		response2.emailOptOut = false;
		response2.letterOptOut = false;
		response2.smsOptOut = false;

        response3 = new SQL_ESA_Queue.CareContactRes();
		response3.contactIds = new long[]{};
		response3.companyCode = '028';
		response3.source = 'Autoline';
		response3.custNo = 130849;
		//response3.dmsNo = '16150|16151|16152|16153|16154|16155|16156|16157|16158|16159|16160|16161|16162|16163|16164|16165|16166|16167|16168|16169|16170|16171|16172|16173|16174|16175|16176|16177|16178|16179|16180|16181|16182|16183|16184|16185|16186|16187|16188|16189|16190|16191|16192|16193|16194|16195';
		response3.dmsNo = '16150';
        response3.isBusiness = true;
		response3.salutation = null;
		response3.fullName = 'Apple Galaxy Business Solutions';
		response3.preferredName = null;
		response3.dateOfBirth = null;
		response3.docNum = 'SA0219503X';
		response3.docNumRaw = 'SA0219503-X';
		response3.gender = null;
		response3.prefix = null;
		response3.mobile = null;
		response3.phone1raw = null;
		response3.prefix2 = null;
		response3.mobile2 = null;
		response3.phone2raw = null;
		response3.prefix3 = '60';
		response3.mobile3 = '129264594';
		response3.phone3raw = '012-9264594';
		response3.email = 'apple@no.email.com';
		response3.address1 = 'S-7-04 The Gamuda Biz Suites';
		response3.address2 = 'Persiaran Anggerik';
		response3.address3 = 'Villa Kota Kemuning';
		response3.postalCode = '40460';
		response3.city = 'Villa Kota Kemuning';
		response3.state = 'Shah Alam';
		response3.emailOptOut = false;
		response3.letterOptOut = false;
		response3.smsOptOut = false;
    }
    /*
    provided an account Id asserts following measures against ESA records
    two ESA records have been created
    one ESA has source__c as 'CareDb'
    one ESA has source__c as source parameter
    both ESA records have sourceby__c as 'CareDb'
    both ESA records have Account__c as accountId
    */
    static void assertESA(String source,Id accountId){
        List<ExternalSystemAccount__c> exSysAccountList = [
            SELECT Id,Account__c,Source__c
            FROM ExternalSystemAccount__c
            WHERE SourceBy__c = :SQL_ESA_Queue.SOURCE_CARE
        ];

        System.assertEquals(2, exSysAccountList.size(),'Failed to create all the ESA records');
        Integer careRecords = 0;
        Integer sourceRecords = 0;
        for(ExternalSystemAccount__c exSysAccount: exSysAccountList){
            if(exSysAccount.Source__c == source){
                sourceRecords +=1;
            }
            else if(exSysAccount.Source__c == SQL_ESA_Queue.SOURCE_CARE){
                careRecords += 1;
            }
            System.assertEquals(accountId,exSysAccount.Account__c,'Invalid Lookup Account');
        }
        System.assertEquals(1,careRecords,'One record for careDb must be created.');
        System.assertEquals(1,sourceRecords,'One record is missing the payoad source');
    }

    /*
    tests for case1 where ESA's !isBusiness+_+DocumentNumber__c matches with
    PersonAccount's  isPersonAccoutn+'_'+NRIC_Number__c
    ESA is business when DocumentNumber__c is populated
    */
    @isTest
    static void docKeyPersonAccountLookup(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response1);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE LastName = :PERSON_ACCOUNT];
        accnt.NRIC_Number__c = response1.docNum;
        update accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		//System.assertEquals(accnt.Id,exSysAccount.Account__c)
        assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);

    }

    /*
    tests for case1 where ESA's !isBusiness+_+DocumentNumber__c matches with
    Business Account's  isPersonAccoutn+'_'+NRIC_Number__c
    ESA is business when DocumentNumber__c is populated
    */
    @isTest
    static void docKeyBusinessAccountLookup(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response3);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE Name = :BUSINESS_ACCOUNT];
        accnt.NRIC_Number__c = response3.docNum;
        update accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);
    }

    /*
    tests for case2 where ESA's !isBusiness+_+DocumentNumber__c does not matches with
    PersonAccount's  isPersonAccoutn+'_'+NRIC_Number__c but
    ESA's DocumentNumber__c.toUpperCase matches with 
    Account.NRIC_Number__c
    */
    @isTest
    static void docNumBusinessAccountLookup(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response1);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE Name = :BUSINESS_ACCOUNT];
        accnt.NRIC_Number__c = response1.docNum;
        update accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);
    }

    /*
    tests for case2 where ESA's !isBusiness+_+DocumentNumber__c does not matches with
    PersonAccount's  isPersonAccoutn+'_'+NRIC_Number__c but
    ESA's DocumentNumber__c.toUpperCase matches with 
    Account.NRIC_Number__c
    */
    @isTest
    static void docNumPersonAccountLookup(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response3);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE LastName = :PERSON_ACCOUNT];
        accnt.NRIC_Number__c = response3.docNum;
        update accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);
    }

    /*
    tests for case1 where ESA's !isBusiness+_+DocumentNumber__c matches with
    PersonAccount's  isPersonAccoutn+'_'+DocumentNumberAlphaN__c
    ESA is business when DocumentNumber__c is populated
    */
    @isTest
    static void docKeyPersonAccountLookup2(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response1);
        Account accnt = [SELECT Id,DocumentNumberAlphaN__c FROM Account WHERE LastName = :PERSON_ACCOUNT];
        accnt.DocumentNumberAlphaN__c = response1.docNum;
        update accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);
    }

    /*
    tests for case1 where ESA's !isBusiness+_+DocumentNumber__c matches with
    Business Account's  isPersonAccoutn+'_'+DocumentNumberAlphaN__c
    ESA is business when DocumentNumber__c is populated
    */
    @isTest
    static void docKeyBusinessAccountLookup2(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response3);
        Account accnt = [SELECT Id,DocumentNumberAlphaN__c FROM Account WHERE Name = :BUSINESS_ACCOUNT];
        accnt.DocumentNumberAlphaN__c = response3.docNum;
        update accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);
    }

    /*
    tests for case2 where ESA's !isBusiness+_+DocumentNumber__c does not matches with
    PersonAccount's  isPersonAccoutn+'_'+DocumentNumberAlphaN__c but
    ESA's DocumentNumber__c.toUpperCase matches with 
    Account.DocumentNumberAlphaN__c
    */
    @isTest
    static void docNumBusinessAccountLookup2(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response1);
        Account accnt = [SELECT Id,DocumentNumberAlphaN__c FROM Account WHERE Name = :BUSINESS_ACCOUNT];
        accnt.DocumentNumberAlphaN__c = response1.docNum;
        update accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);
    }

    /*
    tests for case2 where ESA's !isBusiness+_+DocumentNumber__c does not matches with
    PersonAccount's  isPersonAccoutn+'_'+DocumentNumberAlphaN__c but
    ESA's DocumentNumber__c.toUpperCase matches with 
    Account.DocumentNumberAlphaN__c
    */
    @isTest
    static void docNumPersonAccountLookup2(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response3);
        Account accnt = [SELECT Id,DocumentNumberAlphaN__c FROM Account WHERE LastName = :PERSON_ACCOUNT];
        accnt.DocumentNumberAlphaN__c = response3.docNum;
        update accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);
    }

    /*
    tests for case3 where ESA's name+_+phone+'_'+EmailHome__c matches with
    phone: PhoneMobile__c
    name: Util.purifyName(exSysAccount.FullName__c)
    PersonAccount's  Name+'_'+phone+'_'+email
    phone: UtilPhone.toE164(String.valueOf(Mobile_Country_Code_1__pc) + Mobile_Preferred__pc);
    email:Office_Email__c
    */
    @isTest
    static void npeMobilePreferredAccountLookup(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response1);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE LastName = :PERSON_ACCOUNT];
        accnt.Office_Email__c = response1.email;
        accnt.Mobile_Country_Code_1__pc = Decimal.valueOf(response1.phone1raw.substring(0,1));
        accnt.Mobile_Preferred__pc = response1.phone1raw.substring(1);
        //accnt.FirstName = response1.fullName.substringBefore(' ');
        accnt.LastName = response1.fullName;
        update accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);
    }

    /*
    tests for case3 where ESA's name+_+phone+'_'+EmailHome__c matches with
    phone: PhoneMobile__c
    name: Util.purifyName(exSysAccount.FullName__c)
    PersonAccount's  Name+'_'+phone+'_'+email
    phone: UtilPhone.toE164(PersonMobilePhone);
    email:Office_Email__c
    */
    @isTest
    static void npePersonMobilePhoneAccountLookup(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response1);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE LastName = :PERSON_ACCOUNT];
        accnt.Office_Email__c = response1.email;
        accnt.PersonMobilePhone = response1.phone1raw;
        accnt.LastName = response1.fullName;
        update accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);
    }

    /*
    tests for case3 where ESA's name+_+phone+'_'+EmailHome__c matches with
    phone: PhoneMobile__c
    name: Util.purifyName(exSysAccount.FullName__c)
    Business Account's  Name+'_'+phone+'_'+email
    phone: UtilPhone.toE164(Phone);
    email:Office_Email__c
    */
    @isTest
    static void npePhoneAccountLookup(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response1);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE Name = :BUSINESS_ACCOUNT];
        accnt.Office_Email__c = response1.email;
        accnt.Phone = response1.phone1raw;
        accnt.Name = response1.fullName;
        update accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);
    }

    /*
    tests for account creation when no existing account matches ESA
    number of accounts created must be minimum for each to have a matching account
    based on response, account created must be PersonAccount
    */
    @isTest
    static void newLookupPersonAccount(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response1);
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
        System.debug([SELECT Id,Name,LastName,RecordTypeId FROM Account]);
		Test.startTest();
        System.debug(ESATriggerHandler.createAccounts);
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		
		Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        List<Account> createdAccountList = [
            SELECT Id
            FROM Account
            WHERE Name != :BUSINESS_ACCOUNT
                AND LastName != :PERSON_ACCOUNT
                AND RecordTypeId = :personAccountRecordTypeId
        ];
        System.debug(personAccountRecordTypeId);
        for(Account createdAccount: createdAccountList){
            System.debug(createdAccount.Id);
        }
        List<ExternalSystemAccount__c> exSysAccountList = [
            SELECT Id,Account__c,Source__c
            FROM ExternalSystemAccount__c
            WHERE SourceBy__c = :SQL_ESA_Queue.SOURCE_CARE
        ];
        Test.stopTest();
        for(ExternalSystemAccount__c exSysAccount: exSysAccountList){
            System.assertEquals(createdAccountList[0].Id,exSysAccount.Account__c);
        }
    }

    /*
    tests for account creation when no existing account matches ESA
    number of accounts created must be minimum for each to have a matching account
    based on response, account created must be Business Account
    */
    @isTest
    static void newLookupBusinessAccount(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response3);
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
		Test.stopTest();
		Id businessAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Business_Account').getRecordTypeId();
        List<Account> createdAccountList = [
            SELECT Id
            FROM Account
            WHERE Name != :BUSINESS_ACCOUNT
                AND LastName != :PERSON_ACCOUNT
                AND RecordTypeId = :businessAccountRecordTypeId
        ];
        System.debug('Test method debug');
        for(Account acc: [SELECT Id, Name, LastName,RecordTypeId FROM Account]){
            System.debug(acc.Name);
            System.debug(acc.LastName);
            System.debug(acc.RecordTypeId);
        }
        System.assertEquals(1,createdAccountList.size());
        List<ExternalSystemAccount__c> exSysAccountList = [
            SELECT Id,Account__c,Source__c
            FROM ExternalSystemAccount__c
            WHERE SourceBy__c = :SQL_ESA_Queue.SOURCE_CARE
        ];
        for(ExternalSystemAccount__c exSysAccount: exSysAccountList){
            System.assertEquals(createdAccountList[0].Id,exSysAccount.Account__c);
        }
        List<Subscription__c> subList= [
            SELECT Id
            FROM Subscription__c
            WHERE Account__c = :createdAccountList[0].Id
        ];
        System.assertEquals(subList.size(),3);
    }

    /*
    exception
    */
    @isTest 
	static void testException() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
        Test.stopTest();
	}
    /* callout exception*/
    @isTest
	static void testCalloutCallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
        Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
        Test.stopTest();
	}

    /*
    tests for case1 where ESA's !isBusiness+_+DocumentNumber__c matches with
    PersonAccount's  isPersonAccoutn+'_'+NRIC_Number__c
    ESA is business when DocumentNumber__c is populated
    */
    @isTest
    static void multipleESA(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response1);
        careResponseList.add(response2);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE LastName = :PERSON_ACCOUNT];
        accnt.NRIC_Number__c = response1.docNum;
        update accnt;
        accnt = TestFactory.genAccount(1, false)[0];
        accnt.LastName = PERSON_ACCOUNT;
        accnt.NRIC_Number__c = response2.docNum;
        accnt.DocumentNumberAlphaN__c = null;
        accnt.Mobile_Country_Code_1__pc = null;
        accnt.Mobile_Preferred__pc = null;
        accnt.PersonMobilePhone = null;
        insert accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);

        List<ExternalSystemAccount__c> exSysAccountList = [
            SELECT Id,Account__c,Source__c
            FROM ExternalSystemAccount__c
            WHERE SourceBy__c = :SQL_ESA_Queue.SOURCE_CARE
        ];

        System.assertEquals(4, exSysAccountList.size());
        Integer careRecords = 0;
        Integer gdmsRecords = 0;
        Integer autolineRecords = 0;
        for(ExternalSystemAccount__c exSysAccount: exSysAccountList){
            if(exSysAccount.Source__c == 'GdmsInternal'){
                gdmsRecords +=1;
            }
            else if(exSysAccount.Source__c == SQL_ESA_Queue.SOURCE_CARE){
                careRecords += 1;
            }
            else if(exSysAccount.Source__c == SQL_ESA_Queue.SOURCE_AUTOLINE){
                autolineRecords += 1;
            }
            //System.assertEquals(accountId,exSysAccount.Account__c);
        }
        System.assertEquals(2,careRecords);
        System.assertEquals(1,gdmsRecords);
        System.assertEquals(1,autolineRecords);
		Test.stopTest();
    }

    /*
    updates ESA on second call
    tests for case1 where ESA's !isBusiness+_+DocumentNumber__c matches with
    PersonAccount's  isPersonAccoutn+'_'+NRIC_Number__c
    ESA is business when DocumentNumber__c is populated
    */
    @isTest
    static void docKeyPersonAccountLookupUpdate(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response1);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE LastName = :PERSON_ACCOUNT];
        accnt.NRIC_Number__c = response1.docNum;
        update accnt;
		
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.careResponseList = careResponseList;
        job.initMaps();
        job.upsertEsa();
        careResponseList[0].state = 'Shah Alam2';
        accnt.NRIC_Number__c = response1.docNum;
        update accnt;
        Test.startTest();
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
        job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
        System.debug(careResponseList);
        System.debug(job.careResponseList);
		Test.stopTest();
        //assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);

    }

    /* callout exception with Error Log*/
    @isTest
    static void testCalloutCalloutLog() {
        Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
        Test.startTest();
        SQL_ESA_Queue job = new SQL_ESA_Queue();
        job.followOnToVeh = true;
        job.rowCount = job.minRowCount;
        job.execute(null);
        List<ApplicationLog__c> calloutErrorLogList = [
            SELECT Id,Name
            FROM ApplicationLog__c
            WHERE Type__c = 'Callout'
                AND ApexClassName__c = 'SQL_ESA_Queue'
        ];
        System.assertEquals(1,calloutErrorLogList.size());
        Test.stopTest();
    }
    /*
    test using case1 account Lookup
    response email is invalid and appropriate application Log must be created
    */
    @isTest
    static void testInvalidEmailLog(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response1);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE LastName = :PERSON_ACCOUNT];
        accnt.NRIC_Number__c = response1.docNum;
        response1.email = 'invalidEmail.com';
        update accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
        List<ApplicationLog__c> appLogList = new List<ApplicationLog__c>();
        appLogList = [
            SELECT Id,priority__c, Type__c,CalloutRequest__c,CalloutResponse__c,
                ErrorMessage__c,StackTrace__c,TransactionId__c,Status__c,ApexClassName__c
            FROM ApplicationLog__c
            WHERE Type__c = :ApplicationLogUtility.TYPE_APEX
                AND ApexClassName__c = 'ESATriggerHandler'
                AND Status__c = 'Record Updated'
        ];
        /*
        ApplicationLogAlerts batchInstance = new ApplicationLogAlerts(0);
        System.scheduleBatch(batchInstance, batchInstance.JOB_NAME, 0);
        */
		Test.stopTest();
		//System.assertEquals(accnt.Id,exSysAccount.Account__c)
        assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);
        System.assertEquals(2,appLogList.size());
    }

        /*
    test using case1 account Lookup
    response email is invalid and appropriate application Log must be created
    */
    @isTest
    static void testInvalidDOBLog(){
        List<SQL_ESA_Queue.CareContactRes> careResponseList = new List<SQL_ESA_Queue.CareContactRes>();
        careResponseList.add(response1);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE LastName = :PERSON_ACCOUNT];
        accnt.NRIC_Number__c = response1.docNum;
        response1.dateOfBirth = Date.newInstance(1600, 1, 1);
        update accnt;
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SQL_ESA_Queue job = new SQL_ESA_Queue();
		job.followOnToVeh = true;
		job.execute(null);
        List<ApplicationLog__c> appLogList = new List<ApplicationLog__c>();
        appLogList = [
            SELECT Id,priority__c, Type__c,CalloutRequest__c,CalloutResponse__c,
                ErrorMessage__c,StackTrace__c,TransactionId__c,Status__c,ApexClassName__c
            FROM ApplicationLog__c
            WHERE Type__c = :ApplicationLogUtility.TYPE_APEX
                AND ApexClassName__c = 'ESATriggerHandler'
                AND Status__c = 'Record Updated'
        ];
        /*
        ApplicationLogAlerts batchInstance = new ApplicationLogAlerts(0);
        System.scheduleBatch(batchInstance, batchInstance.JOB_NAME, 0);
        */
		Test.stopTest();
		//System.assertEquals(accnt.Id,exSysAccount.Account__c)
        assertESA(SQL_ESA_Queue.SOURCE_AUTOLINE,accnt.Id);
        System.assertEquals(2,appLogList.size());
    }
}