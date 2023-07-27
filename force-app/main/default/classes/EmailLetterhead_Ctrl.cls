public with sharing class EmailLetterhead_Ctrl {
	public case cs { get; set; }
	
	private string m_headerId;
	public string headerId {
		get { return this.m_headerId; }
		set { this.m_headerId = getDocument(value); }
	}
	
	public EmailLetterhead_Ctrl() {}
	public EmailLetterhead_Ctrl(ApexPages.StandardController controller) {
		this.cs = (Case)controller.getRecord();
	}
	private String getDocument(string developerName) {
		try {
			Document doc = [SELECT Id FROM Document WHERE DeveloperName = :developerName];
			return doc.Id;
		}
		catch (Exception e) { return null; }
	}
}