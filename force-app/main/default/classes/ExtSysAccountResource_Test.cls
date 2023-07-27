@isTest
public with sharing class ExtSysAccountResource_Test {
    public static final String PERSON_ACCOUNT = 'personTest';
    public static final String BUSINESS_ACCOUNT = 'businessTest';

	@TestSetup
	public static void makeData() {
        CompanyRepositoryTest.makeData();
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

    static CareService.ContactResponse response1;
    static CareService.ContactResponse response2;
    static CareService.ContactResponse response3;
    static CustomerVehicleService.QueryCustomerAccount_CustomerRow custAccount;

    static{
        response1 = new CareService.ContactResponse();
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

		response2 = new CareService.ContactResponse();
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

        response3 = new CareService.ContactResponse();
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

        custAccount = new CustomerVehicleService.QueryCustomerAccount_CustomerRow();
        custAccount.Address = '1-9-7 Krystal Point Park';
        custAccount.Address2 = 'Lebuah Biscuit Pencil 6';
        custAccount.City = 'Bayan Lepas, Pulau Pinang';
        custAccount.PostCode = '11 900';
        custAccount.DOB = Date.newInstance(1990, 7, 13);
        custAccount.CompanyCode = CompanyRepository.C099;
        custAccount.CustomerNo = 011147;
        custAccount.DocNum = '750706846087';
        custAccount.CustomerType = 'I';
        custAccount.OtherEmail = 'email1@example.com';
        custAccount.PrefferedName = 'Firsty Lasty';
        custAccount.Salutation = 'Mr.';
        custAccount.FirstName = 'First';
        custAccount.LastName = 'Last';
        custAccount.MobilePhone = '8537036617';
        custAccount.HomePhone = '8587039617';
        custAccount.OfficePhone = '7887039617';
        custAccount.Cust_Driver = false;

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
        List<String> extSysNameList = new List<String>();
        extSysNameList.add(ExternalSystem.Type.CareDb.name());
        extSysNameList.add(ExternalSystem.Type.Autoline.name());

        List<ExternalSystemAccount__c> exSysAccountList = [
            SELECT Id,Account__c,Source__c,SourceBy__c
            FROM ExternalSystemAccount__c
            WHERE SourceBy__c IN :extSysNameList
        ];
        System.debug([SELECT Id,Account__c,Source__c,SourceBy__c FROM ExternalSystemAccount__c]);

        System.assertEquals(2, exSysAccountList.size(),'Failed to create all the ESA records');
        Integer careRecords = 0;
        Integer sourceRecords = 0;
        for(ExternalSystemAccount__c exSysAccount: exSysAccountList){
            if(exSysAccount.SourceBy__c == source){
                sourceRecords +=1;
            }
            else if(exSysAccount.SourceBy__c == ExternalSystem.Type.CareDb.name()){
                careRecords += 1;
            }
            System.assertEquals(accountId,exSysAccount.Account__c,'Invalid Lookup Account');
        }
        System.assertEquals(1,careRecords,'One record for careDb must be created.');
        System.assertEquals(1,sourceRecords,'One record is missing the payoad source');
    }

    static void assertEsaGdms(Id accountId){
        List<ExternalSystemAccount__c> exSysAccountList = [
            SELECT Id,Account__c,Source__c
            FROM ExternalSystemAccount__c
            WHERE Source__c = 'GdmsInternal'
        ];
        System.debug([SELECT Id,Account__c,Source__c,SourceBy__c FROM ExternalSystemAccount__c]);
        System.assertEquals(1, exSysAccountList.size());
    }

    /*
    tests for case1 where ESA's !isBusiness+_+DocumentNumber__c matches with
    PersonAccount's  isPersonAccoutn+'_'+NRIC_Number__c
    ESA is business when DocumentNumber__c is populated
    */
    @isTest
    static void docKeyPersonAccountLookup(){
        List<CareService.ContactResponse> careResponseList = new List<CareService.ContactResponse>();
        careResponseList.add(response1);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE LastName = :PERSON_ACCOUNT];
        accnt.NRIC_Number__c = response1.docNum;
        update accnt;
        Test.startTest();
        TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(careResponseList));
        //Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);
		//Test.startTest();
        ExternalSystem extSystem = new ExternalSystem(CompanyRepository.C028);
		ExtSysAccountResource job = new ExtSysAccountResource(extSystem);
        QueueableContext qcontext = null;
        job.careResponseList = careResponseList;
		job.execute(qcontext);
		Test.stopTest();
        assertESA(ExternalSystem.Type.Autoline.name(),accnt.Id);
    }
    @isTest
    static void queryCustomerTest(){
        List<CustomerVehicleService.QueryCustomerAccount_CustomerRow> custAccountList = new List<CustomerVehicleService.QueryCustomerAccount_CustomerRow>();
        custAccountList.add(custAccount);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE LastName = :PERSON_ACCOUNT];
        accnt.NRIC_Number__c = custAccount.docNum;
        update accnt;
        Test.startTest();
        ExternalSystem extSystem = new ExternalSystem(CompanyRepository.C099);
		ExtSysAccountResource job = new ExtSysAccountResource(extSystem);
        QueueableContext qcontext = null;
        job.CustomerAccountList = custAccountList;
		job.execute(qcontext);
		Test.stopTest();
        assertEsaGdms(accnt.Id);
    }

    //creates account
    @isTest
    static void queryCustomerTest2(){
        List<CustomerVehicleService.QueryCustomerAccount_CustomerRow> custAccountList = new List<CustomerVehicleService.QueryCustomerAccount_CustomerRow>();
        custAccountList.add(custAccount);
        Test.startTest();
        ExternalSystem extSystem = new ExternalSystem(CompanyRepository.C099);
		ExtSysAccountResource job = new ExtSysAccountResource(extSystem);
        QueueableContext qcontext = null;
        job.CustomerAccountList = custAccountList;
		job.execute(qcontext);
		Test.stopTest();
        ExternalSystemAccount__c extSysAccount = [SELECT Id,Account__c FROM ExternalSystemAccount__c][0];
        System.assert(extSysAccount.Account__c != null);
    }

    @isTest
    static void testAccountUpdate(){
        List<CustomerVehicleService.QueryCustomerAccount_CustomerRow> custAccountList = new List<CustomerVehicleService.QueryCustomerAccount_CustomerRow>();
        custAccountList.add(custAccount);
        Account accnt = [SELECT Id,NRIC_Number__c FROM Account WHERE LastName = :PERSON_ACCOUNT];
        accnt.NRIC_Number__c = custAccount.docNum;
        update accnt;
        Test.startTest();
        ExternalSystem extSystem = new ExternalSystem(CompanyRepository.C099);
		ExtSysAccountResource job = new ExtSysAccountResource(extSystem);
        QueueableContext qcontext = null;
        job.CustomerAccountList = custAccountList;
		job.execute(qcontext);
        assertEsaGdms(accnt.Id);
        custAccountList = new List<CustomerVehicleService.QueryCustomerAccount_CustomerRow>();
        custAccount.OtherEmail = 'updated@email.com';
        custAccountList.add(custAccount);
        job = new ExtSysAccountResource(extSystem);
        job.CustomerAccountList = custAccountList;
		job.execute(qcontext);
        Test.stopTest();
        accnt = [
            SELECT Id,Other_Email__c FROM Account WHERE LastName = :PERSON_ACCOUNT
        ];
        System.debug(accnt);
        System.assert(accnt.Other_Email__c == custAccount.OtherEmail);
    }
}