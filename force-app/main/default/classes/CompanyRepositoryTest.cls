@isTest
public with sharing class CompanyRepositoryTest {

    @TestSetup
    public static void makeData(){
        Company__c c028 = new Company__c(DmsCompanyCode__c = '028', MobyCompanyCode__c = 'SDAB', Name = '028');
        Company__c c099 = new Company__c(DmsCompanyCode__c = '099', MobyCompanyCode__c = 'SDBA', Name = '099');
        Company__c c168 = new Company__c(DmsCompanyCode__c = '168', MobyCompanyCode__c = 'SDAS', Name = '168');
        List<Company__c> companyList = new List<Company__c>{c028,c099,c168};
        insert companyList;
    }

    @isTest
    private static void testCache(){
        System.assertEquals(3,CompanyRepository.name2Company.keySet().size());
        System.assertEquals(3,CompanyRepository.id2Company.keySet().size());
    }

    @isTest
    private static void testRelatedEmail(){
        //test gdms external to internal
        String relatedCode = CompanyRepository.getRelatedCompanyCode(CompanyRepository.C138);
        System.assert(relatedCode == CompanyRepository.C038);

        //test gdms internal to external
        relatedCode = CompanyRepository.getRelatedCompanyCode(CompanyRepository.C099);
        System.assert(relatedCode == CompanyRepository.C199);

        try{
            relatedCode = CompanyRepository.getRelatedCompanyCode('111');
            System.assert(false);
        }
        catch(TypeException typeError){
            System.assert(typeError.getMessage()==('Invalid Company Code: 111'));
        }

        try{
            relatedCode = CompanyRepository.getRelatedCompanyCode(CompanyRepository.C089);
            System.assert(false);
        }
        catch(TypeException typeError){
            System.assert(typeError.getMessage()==('No related company defined for: '+ CompanyRepository.C089));
        }
    }
}