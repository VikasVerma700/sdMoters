global class GetOrgSiteUrl {
	@AuraEnabled
	global static Result[] getSiteUrl2(){
		Map<string, SiteDetail> masterLabel2Detail = new Map<string, SiteDetail>();

		Site[] sites = [SELECT Id, Name, MasterLabel, Subdomain, UrlPathPrefix FROM Site];
		Map<Id, Site> id2Site = new Map<Id, Site>();
		for (Site site :sites) {
			if (site?.Id == null) { continue; }
			id2Site.put(site.Id, site);
		}
		
		SiteDetail[] details = [SELECT Id, DurableId, SecureUrl FROM SiteDetail WHERE DurableId IN :id2Site.keySet()];
		for (SiteDetail detail :details) {
			if (detail?.Id == null || id2Site.get(detail.DurableId) == null) { continue; }
			masterLabel2Detail.put(id2Site.get(detail.DurableId).MasterLabel, detail);
		}

		Result[] ret = new Result[]{};
		for (string name :masterLabel2Detail.keySet()) {
			Result res = new Result();
			res.siteName = name;
			res.siteUrl = masterLabel2Detail.get(name).SecureUrl;
			ret.add(res);
		}
		return ret;
	}
	
	@InvocableMethod(Label='Get Salesforce Site url')
	global static Result[] getSiteUrl() {
		Map<string, SiteDetail> masterLabel2Detail = new Map<string, SiteDetail>();

		Site[] sites = [SELECT Id, Name, MasterLabel, Subdomain, UrlPathPrefix FROM Site];
		Map<Id, Site> id2Site = new Map<Id, Site>();
		for (Site site :sites) {
			if (site?.Id == null) { continue; }
			id2Site.put(site.Id, site);
		}
		
		SiteDetail[] details = [SELECT Id, DurableId, SecureUrl FROM SiteDetail WHERE DurableId IN :id2Site.keySet()];
		for (SiteDetail detail :details) {
			if (detail?.Id == null || id2Site.get(detail.DurableId) == null) { continue; }
			masterLabel2Detail.put(id2Site.get(detail.DurableId).MasterLabel, detail);
		}

		Result[] ret = new Result[]{};
		for (string name :masterLabel2Detail.keySet()) {
			Result res = new Result();
			res.siteName = name;
			res.siteUrl = masterLabel2Detail.get(name).SecureUrl;
			ret.add(res);
		}
		return ret;
	}

	global class Result {
		@InvocableVariable
		global string siteName;

		@InvocableVariable
		global string siteUrl;
	}
}