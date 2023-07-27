public with sharing class CaseComment_Ctrl {
    public Case theCase					{ get; set; }
	public Boolean lastOnly				{ get; set; }
	public Boolean includeUnpublished	{ get; set; }
	
	public List<CaseComment> getCaseComment() { return sortComments(); }

	private List<CaseComment> sortComments() {
		CaseComment[] ccs = [SELECT Id, CommentBody, IsPublished, CreatedDate, CreatedBy.Name FROM CaseComment WHERE ParentId = :theCase.Id ORDER BY CreatedDate];

		if (ccs == null || ccs.size() <= 1) { return ccs; }

		if (lastOnly)	{ return new CaseComment[] { ccs[ccs.size()-1] }; }
		else			{ return ccs;}
	}
}