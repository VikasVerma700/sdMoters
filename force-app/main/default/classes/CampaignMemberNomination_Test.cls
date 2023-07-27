@isTest
public class CampaignMemberNomination_Test {

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
        update cmpg;
    }

    @isTest
    static void testCtor() {
        CampaignMember cm = [SELECT Id, Name, CampaignId FROM CampaignMember LIMIT 1];
        
        PageReference pr = Page.CampaignMemberNomination;
        pr.getParameters().put('Id', cm.CampaignId);
        Test.setCurrentPage(pr);

        CampaignMemberNomination_Ctrl cn = new CampaignMemberNomination_Ctrl();

        Test.startTest();
                
        Test.stopTest();
    }

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

    @isTest
    static void testImportMember() {
        CampaignMember cm = [SELECT Id, CustomerEmail__c, CustomerName__c, CustomerContact__c, SalesAdvisorName__c, CampaignId FROM CampaignMember LIMIT 1];  
        PageReference pr = Page.CampaignMemberNomination;
        pr.getParameters().put('Id', cm.CampaignId);
        pr.getHeaders().put('Referer', pr.getURL());
        Test.setCurrentPage(pr);
        CampaignMemberNomination_Ctrl cn = new CampaignMemberNomination_Ctrl();

        cm.CustomerEmail__c = 'abc@email.com';
        cm.CustomerName__c = 'Test Customer';
        cm.CustomerContact__c = '+60123456789';
        cm.SalesAdvisorName__c = 'Test Advisor Name';
        update cm;

        cn.email = cm.CustomerEmail__c;
        cn.name = cm.CustomerName__c;
        cn.phone = cm.CustomerContact__c;
        cn.empName = 'Test Advisor Name';
        cn.sapId = '123456';

        Test.startTest();
        cn.importMembers();
        cn.importMembers();
        //errMsg = errorMessage + NOMINATED_BY_MSG + existingCmpMember.SalesAdvisorName__c;
        string expected = CampaignMemberNomination_Ctrl.DUP_CMP_MEMBER_MSG + '.'+ CampaignMemberNomination_Ctrl.NOMINATED_BY_MSG + cm.SalesAdvisorName__c;
        string actual  = cn.errMsg;

        System.assertEquals(expected, actual);
        Test.stopTest();
		//System.debug(url);		 
    }

    @isTest
    static void testWithoutRedirect(){
        CampaignMember cm = [SELECT Id, CustomerEmail__c, CustomerName__c, CustomerContact__c, SalesAdvisorName__c, CampaignId FROM CampaignMember LIMIT 1];  
        PageReference pr = Page.CampaignMemberNomination;
        pr.getParameters().put('Id', cm.CampaignId);
        pr.getHeaders().put('Referer', pr.getURL());
        Test.setCurrentPage(pr);
        CampaignMemberNomination_Ctrl cn = new CampaignMemberNomination_Ctrl();

        cm.CustomerEmail__c = 'abc@email.com';
        cm.CustomerName__c = 'Test Customer';
        cm.CustomerContact__c = '+60123456789';
        update cm;

        cn.email = cm.CustomerEmail__c;
        cn.name = cm.CustomerName__c;
        cn.phone = cm.CustomerContact__c;
        cn.sapId = '123456';

        Test.startTest();
        cn.importMembers();
        //errMsg = errorMessage + NOMINATED_BY_MSG + existingCmpMember.SalesAdvisorName__c;
        string expected = CampaignMemberNomination_Ctrl.NOMINATED_MSG;
        string actual  = cn.errMsg;

        System.assertEquals(expected, actual);
        Test.stopTest();
    }
}