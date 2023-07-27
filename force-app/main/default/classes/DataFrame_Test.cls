@isTest
public with sharing class DataFrame_Test {
    @isTest
    static void shortHeaders(){
        List<String> rowList = new List<String>();
        rowList.add('H1,H2,H3\n');
        rowList.add('v1,v2,v3,v4');
        DataFrame invalidDF = new DataFrame(',',rowList);
        List<ApplicationLog__c> appLogs = [
            SELECT Id
            FROM ApplicationLog__c
            WHERE Priority__c = :ApplicationLogUtility.PRIORITY_LOW
                AND ErrorMessage__c LIKE '%row NOT added to dataframe%'
        ];
        System.assertEquals(1,appLogs.size());
    }

    @isTest
    static void longHeaders(){
        List<String> rowList = new List<String>();
        rowList.add('H1,H2,H3\n');
        rowList.add('v1,v2');
        DataFrame invalidDF = new DataFrame(',',rowList);
        System.assertEquals(null,invalidDF.get(0).get('H3'));
        System.assertEquals(null,invalidDF.get(13));
    }

	@isTest
	static void coverage() {
		List<String> rowList = new List<String>();
        rowList.add('H1,H2,H3\n');
        rowList.add('v1,v2');
        DataFrame invalidDF = new DataFrame(',',rowList);
        invalidDF.getLength();
		invalidDF.debug();
		string html = invalidDF.html;
	}
}