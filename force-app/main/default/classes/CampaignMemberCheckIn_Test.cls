@isTest
class CampaignMemberCheckIn_Test{

    @TestSetup
    static void makeData(){
        TestFactory.genCampaignMember(1, true);
        Campaign cmpg = [SELECT Id, Name, LogoImage__c, BackgroundImage__c, Header__c, SubHeader__c, CheckInLimit__c FROM Campaign LIMIT 1];

        Document headerD = new Document();
        headerD.Name ='Test Header Document';
        headerD.DeveloperName = 'TestHeaderDocApi';
        // d.AuthorId = UserInfo.getUserId();
        headerD.FolderId = UserInfo.getUserId();
        headerD.IsPublic = true;
        insert headerD;

        Document backgroundD = new Document();
        backgroundD.Name ='Test Bg Document';
        backgroundD.DeveloperName = 'TestBgDocApi';
        // d.AuthorId = UserInfo.getUserId();
        backgroundD.FolderId = UserInfo.getUserId();
        backgroundD.IsPublic = true;
        insert backgroundD;

        cmpg.LogoImage__c = headerD.DeveloperName;
        cmpg.BackgroundImage__c = backgroundD.DeveloperName;
        cmpg.CheckInLimit__c = null;
        update cmpg;
    }

    @isTest
    static void testCtor() {
        CampaignMember cm = [SELECT Id, Name, CampaignId FROM CampaignMember LIMIT 1];
        
        PageReference pr = Page.CampaignMemberCheckIn;
        pr.getParameters().put('Id', cm.CampaignId);
        Test.setCurrentPage(pr);

        CampaignMemberCheckIn_Ctrl ct = new CampaignMemberCheckIn_Ctrl();

        Test.startTest();
                
        Test.stopTest();
    }

    // @isTest
    // static void testCmpgIdValid()
    // {
    //     CampaignMember cm = [SELECT Id, Name, CampaignId FROM CampaignMember LIMIT 1];
    //     CampaignMemberCheckIn_Ctrl ct = new CampaignMemberCheckIn_Ctrl();
    //     PageReference pr = Page.CampaignMemberCheckIn;
    //     pr.getParameters().put('Id', cm.CampaignId);

    //     Boolean expected = true;
    //     Test.startTest();
    //     Boolean actual = ct.fncCheckIsCampaignExist((Id)cm.CampaignId);
    //     System.assertEquals(expected, actual);
    //     Test.stopTest();
    // }

    @isTest
    static void testCampaignIdInvalIdNull() {
        CampaignMemberCheckIn_Ctrl ct = new CampaignMemberCheckIn_Ctrl();
        Boolean expected = false;
        Test.startTest();
        Boolean actual = ct.fncCheckIsCampaignExist(null);
        System.assertEquals(expected, actual, 'Invalid Campaign Id');
        Test.stopTest();  
    }

    @isTest
    static void testCampaignIdInvalIdNotNull() {
        CampaignMemberCheckIn_Ctrl ct = new CampaignMemberCheckIn_Ctrl();
        Boolean expected = false;
        Test.startTest();
        Boolean actual = ct.fncCheckIsCampaignExist((Id)'7010p000000CzEl');
        System.assertEquals(expected, actual, 'Invalid Campaign Id');
        Test.stopTest();  
    }

    @isTest
    static void testCampaignIdValid() {
        CampaignMember cm = [SELECT Id, Name, CampaignId FROM CampaignMember LIMIT 1];
        CampaignMemberCheckIn_Ctrl ct = new CampaignMemberCheckIn_Ctrl();

        PageReference pr = Page.CampaignMemberCheckIn;
        pr.getParameters().put('id', cm.CampaignId);
        Test.setCurrentPage(pr);
        Boolean expected = true;
        Test.startTest();
        Boolean actual = ct.fncCheckIsCampaignExist((Id)cm.CampaignId);
        System.assertEquals(expected, actual, 'Valid Campaign Id');
        Test.stopTest();     
    }

    @IsTest
    static void testValidCmpMemberDtl()
    {
        CampaignMember cm = [SELECT Id, Name, CheckInCount__c, CampaignId FROM CampaignMember LIMIT 1];
        cm.CheckInCount__c = 0;
        update cm;

        PageReference pr = Page.CampaignMemberCheckIn;
        pr.getParameters().put('Id', cm.CampaignId);
        Test.setCurrentPage(pr);
        CampaignMemberCheckIn_Ctrl ct = new CampaignMemberCheckIn_Ctrl();
        //ct.cmpgMemberId = cm.Id;

        Blob cmpMemIdBlob = Blob.valueOf(cm.Id);
        ct.cmpgMemberId = 'https://www.bmw-autobavaria.com/?' + EncodingUtil.base64Encode(cmpMemIdBlob);

        Test.startTest();
        ct.fncGetCmpgMemberDtl();
        string expected = CampaignMemberCheckIn_Ctrl.SHOW_HIDE_WELCOME_ALERT_SCRIPT;
        string actual = ct.callfunc;
        System.assertEquals(expected, actual);
        Test.stopTest();
    }

    @IsTest
    static void testInvalidCmpMemberDtl()
    {
        CampaignMember cm = [SELECT Id, Name, CampaignId FROM CampaignMember LIMIT 1];
        cm.Id = (Id)'00v0K00000cPmxXQAA';

        PageReference pr = Page.CampaignMemberCheckIn;
        pr.getParameters().put('Id', cm.CampaignId);
        Test.setCurrentPage(pr);
        CampaignMemberCheckIn_Ctrl ct = new CampaignMemberCheckIn_Ctrl();

        Blob cmpMemIdBlob = Blob.valueOf(cm.Id);
        ct.cmpgMemberId = 'https://www.bmw-autobavaria.com/?' + EncodingUtil.base64Encode(cmpMemIdBlob);

        Test.startTest();
        ct.fncGetCmpgMemberDtl();
        string expected = CampaignMemberCheckIn_Ctrl.NOTIFY_NOT_IN_CAMPAIGN_SCRIPT;
        string actual = ct.callfunc;
        System.assertEquals(expected, actual, 'Campaign Member Invalid in Invalid Test');
        Test.stopTest();
    }

    @isTest
    static void testManualInputNewCmpgMember()
    {
        Campaign cmpg = [SELECT Id, Name, LogoImage__c, BackgroundImage__c, Header__c, SubHeader__c, CheckInLimit__c FROM Campaign LIMIT 1];
        PageReference pr = Page.CampaignMemberCheckIn;
        pr.getParameters().put('Id', cmpg.Id);
        Test.setCurrentPage(pr);
        CampaignMemberCheckIn_Ctrl ct = new CampaignMemberCheckIn_Ctrl();
        ct.name = 'KL';
        ct.phone = '0182980611';
        ct.email = 'hoh.kai.loon@simedarby.com';

        Test.startTest();
        ct.fncManualInputSubmit();
        string expected = CampaignMemberCheckIn_Ctrl.SUCCESS_CHECK_IN_ALERT_SCRIPT;
        string actual = ct.callfunc;
        System.assertEquals(expected, actual);
        Test.stopTest();
    }

    @isTest
    static void testManualInputExistingCmpMember()
    {
        CampaignMember cm = [SELECT Id, ContactId, Name, Phone, Email, CheckInCount__c, CampaignId FROM CampaignMember LIMIT 1];
        system.debug(cm);
        PageReference pr = Page.CampaignMemberCheckIn;
        pr.getParameters().put('Id', cm.CampaignId);
        Test.setCurrentPage(pr);
        CampaignMemberCheckIn_Ctrl ct = new CampaignMemberCheckIn_Ctrl();
        cm.CheckInCount__c = 0;
        cm.CustomerName__c = 'KL';
        cm.CustomerContact__c = '60182980611';
        cm.CustomerEmail__c = 'hoh.kai.loon@simedarby.com';
        update cm;

        ct.name = cm.CustomerName__c;
        ct.phone = cm.CustomerContact__c;
        ct.email = cm.CustomerEmail__c;

        Test.startTest();
        ct.fncManualInputSubmit();
        string expected = CampaignMemberCheckIn_Ctrl.SHOW_HIDE_WELCOME_ALERT_SCRIPT;
        string actual = ct.callfunc;
        System.assertEquals(expected, actual);
        Test.stopTest();
    }

    @isTest
    static void testCmpgMaxCheckInExceed(){
        CampaignMember cm = [SELECT Id, Name, CheckInCount__c, CampaignId FROM CampaignMember LIMIT 1];
        cm.CheckInCount__c = 3;
        update cm;

        Campaign cmpg = [SELECT Id, Name, LogoImage__c, BackgroundImage__c, Header__c, SubHeader__c, CheckInLimit__c FROM Campaign WHERE Id = :cm.CampaignId];
        cmpg.CheckInLimit__c = 3;
        update cmpg;

        PageReference pr = Page.CampaignMemberCheckIn;
        pr.getParameters().put('Id', cm.CampaignId);
        Test.setCurrentPage(pr);
        CampaignMemberCheckIn_Ctrl ct = new CampaignMemberCheckIn_Ctrl();

        //ct.cmpgMemberId = cm.Id;
        Blob cmpMemIdBlob = Blob.valueOf(cm.Id);
        ct.cmpgMemberId = 'https://www.bmw-autobavaria.com/?' + EncodingUtil.base64Encode(cmpMemIdBlob);

        Test.startTest();
        ct.fncGetCmpgMemberDtl();
        string expected = CampaignMemberCheckIn_Ctrl.MAX_CHECK_IN_ALERT_SCRIPT;
        string actual = ct.callfunc;
        System.assertEquals(expected, actual);
        Test.stopTest();
    }

    @isTest
    static void testCmpgMaxCheckInNotExceed()
    {
        CampaignMember cm = [SELECT Id, Name, CheckInCount__c, CampaignId FROM CampaignMember LIMIT 1];
        cm.CheckInCount__c = 0;
        update cm;

        Campaign cmpg = [SELECT Id, Name, LogoImage__c, BackgroundImage__c, Header__c, SubHeader__c, CheckInLimit__c FROM Campaign WHERE Id = :cm.CampaignId];
        cmpg.CheckInLimit__c = 3;
        update cmpg;

        PageReference pr = Page.CampaignMemberCheckIn;
        pr.getParameters().put('Id', cm.CampaignId);
        Test.setCurrentPage(pr);
        CampaignMemberCheckIn_Ctrl ct = new CampaignMemberCheckIn_Ctrl();

        //ct.cmpgMemberId = cm.Id;
        Blob cmpMemIdBlob = Blob.valueOf(cm.Id);
        ct.cmpgMemberId = 'https://www.bmw-autobavaria.com/?' + EncodingUtil.base64Encode(cmpMemIdBlob);

        Test.startTest();
        ct.fncGetCmpgMemberDtl();
        string expected = CampaignMemberCheckIn_Ctrl.SHOW_HIDE_WELCOME_ALERT_SCRIPT;
        string actual = ct.callfunc;
        System.assertEquals(expected, actual);
        Test.stopTest();
    }
}