@isTest
public with sharing class ExternalSystem_Test {
    @isTest
    static void testInvalidCompany(){
        try{
            new ExternalSystem('666');
            System.assert(false,'type exception now thrown');
        }
        catch(TypeException invalidCompanyExcepiton ){
            System.assert(true);
        }
    }

    @isTest
    static void testValidCompany(){
        new ExternalSystem(CompanyRepository.C001);
    }
    
}