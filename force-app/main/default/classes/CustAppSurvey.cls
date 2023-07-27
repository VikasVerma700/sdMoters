global without sharing class CustAppSurvey {
	public final static List<String> SURVEY_FIELDS = new List<String> { 'Survey_Status__c', 'URL_Link__c', 'Repair_Order__c' };
	global class SurveyCls {
		public String status;
		public String url;
		global SurveyCls(Survey_List__c survey) {
			this.status = (survey.Survey_Status__c == 'Completed') ? 'COMPLETED' : 'PENDING';
			this.url = survey.URL_Link__c;
		}
	}
}