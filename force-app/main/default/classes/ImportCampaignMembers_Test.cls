@isTest
public with sharing class ImportCampaignMembers_Test {
    static final String TEST_CAMPAIGN_NAME = 'Member Test Campaign';

    static String joinColumns (List<String> keyList){
        return Util.joinKeys(keyList,',');
    }

    static String joinRows(List<String> keyList){
        return Util.joinKeys(keyList,'\n');
    }

    static List<String> headerList = new List<String>{
        ImportCampaignMembers_Ctrl.H_ID,
        ImportCampaignMembers_Ctrl.H_NAME,
        ImportCampaignMembers_Ctrl.H_PHONE,
        ImportCampaignMembers_Ctrl.H_EMAIL,
        ImportCampaignMembers_Ctrl.H_P_S_B,
        ImportCampaignMembers_Ctrl.H_S_ADVISOR,
        ImportCampaignMembers_Ctrl.H_S_ADVISOR_EMAIL,
        ImportCampaignMembers_Ctrl.H_GUESTS,
        ImportCampaignMembers_Ctrl.H_SAP_ID,
        ImportCampaignMembers_Ctrl.H_AD_USERNAME
    };

    static String getBlobString(){
        String blobString = '';
        blobString = joinColumns(headerList);
        List<String> rowValueList = new List<String>{
            '1','Alex Chin','60199646542','email1@domain1.com','ADKL','Jane Eyre','janeEyre@domain2.com','2','66666','jane.rochester'
        };
        blobString = joinRows(new List<String>{blobString,joinColumns(rowValueList)});
        return blobString;
    }

    static String get(Map<String,String> stringMap,String key){
        String value = stringMap.get(key);
        if(value == null){
            return '';
        }
        return value;
    }

    static String getRowString(Map<String,String> column2ValueMap){
        List<String> rowList = new List<String>();
        for(String header: headerList){
            rowList.add(get(column2ValueMap,header));
        }

        return joinColumns(rowList);
    }

    static ImportCampaignMembers_Ctrl getImportCampaignMemberController(){
        Id testCampaignId = [
            SELECT Id 
            FROM Campaign 
            WHERE Name = :TEST_CAMPAIGN_NAME
        ][0].Id;

        ImportCampaignMembers_Ctrl importCmpMember = new ImportCampaignMembers_Ctrl(testCampaignId);
        return importCmpMember;
    }

    static void assertAccount(Account accnt,String name,String email, String phone){
        System.assert(accnt.isPersonAccount);
        if(String.isNotBlank(name)){
            name = Util.purifyName(name);
            System.assertEquals(name,accnt.LastName);
            System.assertEquals(name,accnt.Account_Name__c);
            System.assertEquals(name,accnt.OfficialName__c);
            System.assertEquals(name,accnt.DisplayName__c);
            System.assertEquals(name,accnt.Prefer_Name__pc);
        }

        if(phone!= null){
            UtilPhone phoneUtil = new UtilPhone(phone);
            System.assertEquals(accnt.PersonMobilePhone,phoneUtil.toE164());
            System.assertEquals(accnt.Mobile_Country_Code_1__pc,phoneUtil.getCountryCode());
            System.assertEquals(accnt.Mobile_Preferred__pc,phoneUtil.toNoPrefixNumber());
        }

        if(Util.checkEmail(email)){
            System.assertEquals(email,accnt.PersonEmail);
            System.assertEquals(email,accnt.Home_Email__c);
            System.assertEquals(true,accnt.Active_Home__c);
        }
    }

    @TestSetup
    static void makeData(){
        Campaign cmp = TestFactory.genCampaign(1,false)[0];
        cmp.Name = TEST_CAMPAIGN_NAME;
        insert cmp;
    }

    @isTest
    static void testPersonAccountCreation(){
        ImportCampaignMembers_Ctrl importCmpMember = getImportCampaignMemberController();

        Blob contentBlob = Blob.valueOf(getBlobString());
        importCmpMember.blobInput = contentBlob;
        TestFactory.genTriggerSettings(AccountHandler.TRIG_SETTING, true);
        Test.startTest();
        importCmpMember.verifyCsvInput();
        importCmpMember.importMembers();
        Test.stopTest();
        List<CampaignMember> campaignMemberList = [
            SELECT Id,ContactId,CampaignId
            FROM CampaignMember
            WHERE CampaignId = :importCmpMember.campaignId
        ];

        System.assertEquals(1, campaignMemberList.size());
        List<Account> personAccountList = [
            SELECT Id, LastName, isPersonAccount, Phone,Mobile_Country_Code_1__pc,
                PersonMobilePhone,Mobile_Preferred__pc,Office_Email__c,Account_Name__c,
                Home_Email__c,Other_Email__c,PersonEmail,PersonContactId,
                OfficialName__c,DisplayName__c,Prefer_Name__pc,Active_Home__c
            FROM Account
            WHERE PersonContactId = :campaignMemberList[0].ContactId
        ];
        System.assertEquals(1,personAccountList.size());

        Account personAccount = personAccountList[0];
        String name = 'Alex Chin';
        String phone = '60199646542';
        String email = 'email1@domain1.com';
        assertAccount(personAccount,name,email,phone);

        List<Subscription__c> subList = [
            SELECT  Id,Company__c, Account__c,Channel__c,OptOut__c
            FROM Subscription__C
            WHERE Account__c = :personAccount.Id
        ];
        System.assertEquals(subList.size(),3);
    }

    @isTest
    static void testdefaultConstructor(){
        PageReference currentPage = Page.ImportCampaignMembers;
		Test.setCurrentPage(currentPage);

        Id testCampaignId = [
            SELECT Id 
            FROM Campaign 
            WHERE Name = :TEST_CAMPAIGN_NAME
        ][0].Id;
        ApexPages.currentPage().getParameters().put('campaignId', testCampaignId);
        ImportCampaignMembers_Ctrl importCmpMemberController = new ImportCampaignMembers_Ctrl();

        Id testCompanyId = [
            SELECT Company__c
            FROM Campaign
            WHERE Id = :testCampaignId
        ][0].Company__c;

        System.assertEquals(testCompanyId,importCmpMemberController.campaignCompanyId);
        System.assertEquals(false, importCmpMemberController.disableFileInput);
        System.assertEquals(true, importCmpMemberController.disableImport);
    }

    @isTest
    static void testVerifyCsvInput(){
        ImportCampaignMembers_Ctrl importCmpMemberController = getImportCampaignMemberController();
        importCmpMemberController.blobInput=Blob.valueOf('');
        importCmpMemberController.verifyCsvInput();
        System.assertEquals(true, importCmpMemberController.disableImport);

        Blob contentBlob = Blob.valueOf(getBlobString());
        importCmpMemberController.blobInput = contentBlob;
        importCmpMemberController.verifyCsvInput();
        System.assertEquals(false, importCmpMemberController.disableImport);
    }

    @isTest
    static void testContactLookup(){
        ImportCampaignMembers_Ctrl importCmpMemberController = getImportCampaignMemberController();

        Blob contentBlob = Blob.valueOf(getBlobString());
        importCmpMemberController.blobInput = contentBlob;

        Contact lookupContact = new Contact();
        lookupContact.MobilePhone = '601 996 46 542';
        lookupContact.FirstName = 'Alex';
        lookupContact.LastName = 'Chin';
        lookupContact.Email = 'email1@domain1.com';
        insert lookupContact;

        importCmpMemberController.verifyCsvInput();
        importCmpMemberController.importMembers();
        List<CampaignMember> campaignMemberList = [
            SELECT Id,ContactId,CampaignId
            FROM CampaignMember
            WHERE CampaignId = :importCmpMemberController.campaignId
                AND ContactId = :lookupContact.Id
        ];
        System.assertEquals(1, campaignMemberList.size());
    }

    @isTest
    static void testEmployeeMasterLookup(){
        ImportCampaignMembers_Ctrl importCmpMemberController = getImportCampaignMemberController();

        Blob contentBlob = Blob.valueOf(getBlobString());
        importCmpMemberController.blobInput = contentBlob;

        Employee_Master__c empMaster = new Employee_Master__c();
        empMaster.Name = 'Jane Eyre';
        empMaster.Email__c = 'janeEyre@domain2.com';
        empMaster.Company__c = importCmpMemberController.campaignCompanyId;
        insert empMaster;

        importCmpMemberController.verifyCsvInput();
        importCmpMemberController.importMembers();
        List<CampaignMember> campaignMemberList = [
            SELECT Id,ContactId,CampaignId
            FROM CampaignMember
            WHERE CampaignId = :importCmpMemberController.campaignId
                AND SalesAdvisor__c = :empMaster.Id
        ];
        System.assertEquals(1, campaignMemberList.size());
    }

    @isTest
    static void testMemberUpdate(){
        ImportCampaignMembers_Ctrl importCmpMemberController = getImportCampaignMemberController();

        Blob contentBlob = Blob.valueOf(getBlobString());
        importCmpMemberController.blobInput = contentBlob;

        Contact lookupContact = new Contact();
        lookupContact.MobilePhone = '601 996 46 542';
        lookupContact.FirstName = 'Alex';
        lookupContact.LastName = 'Chin';
        lookupContact.Email = 'email1@domain1.com';
        insert lookupContact;

        importCmpMemberController.verifyCsvInput();
        importCmpMemberController.importMembers();
        List<CampaignMember> campaignMemberList = [
            SELECT Id,ContactId,CampaignId
            FROM CampaignMember
            WHERE CampaignId = :importCmpMemberController.campaignId
                AND ContactId = :lookupContact.Id
                AND SapId__c = '66666'
        ];
        System.assertEquals(1, campaignMemberList.size());
        String blobString = '';
        blobString = joinColumns(headerList);
        List<String> rowValueList = new List<String>{
            '2','Alex Chin','60199646542','email1@domain1.com','ADKL','Jane Eyre','janeEyre@domain2.com','2','11111','jane.rochester'
        };
        blobString = joinRows(new List<String>{blobString,joinColumns(rowValueList)});
        contentBlob = Blob.valueOf(blobString);
        ImportCampaignMembers_Ctrl importCmpMemberController2 = getImportCampaignMemberController();
        importCmpMemberController2.blobInput = contentBlob;
        importCmpMemberController2.verifyCsvInput();
        importCmpMemberController2.importMembers();
        campaignMemberList = [
            SELECT Id,ContactId,CampaignId,SapId__c
            FROM CampaignMember
            WHERE CampaignId = :importCmpMemberController2.campaignId
                AND ContactId = :lookupContact.Id
        ];
        System.assertEquals(1, campaignMemberList.size());
        System.assertEquals('11111', campaignMemberList[0].sapId__c);
    }

    @isTest
    static void testMemberSelectivity(){
        String blobString = '';
        blobString = joinColumns(headerList);
        List<String> rowValueList = new List<String>{
            '2','Alex Chin','60199646542','email1@domain1.com','ADKL','Jane Eyre','janeEyre@domain2.com','2','11111','jane.rochester'
        };
        blobString = joinRows(new List<String>{blobString,joinColumns(rowValueList)});
        rowValueList = new List<String>{
            '40','Alex Chin','60199646542','email1@domain1.com','ADKL','Jane Eyre','janeEyre@domain2.com','2','22222','jane.rochester'
        };
        blobString = joinRows(new List<String>{blobString,joinColumns(rowValueList)});
        Blob contentBlob = Blob.valueOf(blobString);

        Contact lookupContact = new Contact();
        lookupContact.MobilePhone = '601 996 46 542';
        lookupContact.FirstName = 'Alex';
        lookupContact.LastName = 'Chin';
        lookupContact.Email = 'email1@domain1.com';
        insert lookupContact;

        ImportCampaignMembers_Ctrl importCmpMemberController = getImportCampaignMemberController();
        importCmpMemberController.blobInput = contentBlob;
        importCmpMemberController.verifyCsvInput();
        importCmpMemberController.importMembers();
        List<CampaignMember> campaignMemberList = [
            SELECT Id,ContactId,CampaignId,SapId__c,SourceId__c
            FROM CampaignMember
            WHERE CampaignId = :importCmpMemberController.campaignId
                AND ContactId = :lookupContact.Id
        ];
        System.assertEquals(1, campaignMemberList.size());
        System.assertEquals('22222', campaignMemberList[0].sapId__c);
        System.assertEquals('40', campaignMemberList[0].SourceId__c);
    }

    @isTest
    static void invalidIDTest(){
        String blobString = '';
        blobString = joinColumns(headerList);
        List<String> rowValueList = new List<String>{
            'AD','Alex Chin','60199646542','email1@domain1.com','ADKL','Jane Eyre','janeEyre@domain2.com','2','11111','jane.rochester'
        };
        blobString = joinRows(new List<String>{blobString,joinColumns(rowValueList)});
        rowValueList = new List<String>{
            '40','Alex Chin','60199646542','email1@domain1.com','ADKL','Jane Eyre','janeEyre@domain2.com','2','22222','jane.rochester'
        };
        blobString = joinRows(new List<String>{blobString,joinColumns(rowValueList)});
        Blob contentBlob = Blob.valueOf(blobString);

        Contact lookupContact = new Contact();
        lookupContact.MobilePhone = '601 996 46 542';
        lookupContact.FirstName = 'Alex';
        lookupContact.LastName = 'Chin';
        lookupContact.Email = 'email1@domain1.com';
        insert lookupContact;

        ImportCampaignMembers_Ctrl importCmpMemberController = getImportCampaignMemberController();
        importCmpMemberController.blobInput = contentBlob;
        importCmpMemberController.verifyCsvInput();
        importCmpMemberController.importMembers();
        List<ApplicationLog__c> appLogList = [
            SELECT Id,ErrorMessage__c
            FROM ApplicationLog__c
        ];
        System.assertEquals(1, appLogList.size());
        System.assert(appLogList[0].ErrorMessage__c.contains('ID value invalid for comparision'));
    }
}