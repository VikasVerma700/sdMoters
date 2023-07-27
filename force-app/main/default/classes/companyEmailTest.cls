@isTest
public with sharing class companyEmailTest {
    @isTest static void testAccess(){
        User u = [select id from user where id = '0050K00000CXYRf'];
        System.runAs(u){
            Map<String,CompanyEmail__mdt> devName2CompanyEmail = CompanyEmail__mdt.getAll();
            for(String devName: devName2CompanyEmail.keySet()){
                CompanyEmail__mdt companyEmail = devName2CompanyEmail.get(devName);
                System.debug(companyEmail);
            }
        }

    }
}