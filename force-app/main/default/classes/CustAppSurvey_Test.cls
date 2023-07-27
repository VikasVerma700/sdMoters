@IsTest
public class CustAppSurvey_Test {
	@IsTest
	static void testSurvey() {
		Survey_List__c survey = new Survey_List__c();
		survey.Survey_Status__c = 'Completed';
		insert survey;
		Survey_List__c checkSurvey = [SELECT Id, URL_Link__c, Survey_Status__c FROM Survey_List__c LIMIT 1];
		Test.startTest();
		CustAppSurvey.SurveyCls res = new CustAppSurvey.SurveyCls(checkSurvey);
		Test.stopTest();
		System.assertEquals(res.url, checkSurvey.URL_Link__c);
	}
}