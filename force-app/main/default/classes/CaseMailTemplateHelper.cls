public with sharing class CaseMailTemplateHelper {
	/*
    private static Map<String,Map<String,EmailTemplate>> company2CaseAction2EmailTemplate;

    public static EmailTemplate getCaseActionEmailTemplate(Case c, CaseActionHelper.CaseAction actionEnum){
		String action = actionEnum.name();
		if(company2CaseAction2EmailTemplate == null){
			company2CaseAction2EmailTemplate = new Map<String,Map<String,EmailTemplate>>();

			//company name => case action => null
			Set<String> templateApiNameSet = new Set<String>();
			Map<String,CaseAction__mdt> devName2CaseMailTemplate = CaseAction__mdt.getAll();
			for(String devName :devName2CaseMailTemplate.keySet()){
				CaseAction__mdt caseMailTemplate = devName2CaseMailTemplate.get(devName);
				templateApiNameSet.add(caseMailTemplate.TemplateApiName__c);
				Map<String,EmailTemplate> caseAction2EmailTemplate = company2CaseAction2EmailTemplate.get(caseMailTemplate.CompanyName__c);
				if(caseAction2EmailTemplate == null){
					caseAction2EmailTemplate = new Map<String,EmailTemplate>();
				}
				caseAction2EmailTemplate.put(caseMailTemplate.CaseAction__c,null);
				company2CaseAction2EmailTemplate.put(caseMailTemplate.CompanyName__c,caseAction2EmailTemplate);
			}

			List<EmailTemplate> caseActionEmailTemplateList = [
				SELECT Id, Name, Subject, TemplateType, Body, HtmlValue, DeveloperName
				FROM EmailTemplate
				WHERE DeveloperName IN :templateApiNameSet
			];
			Map<String,EmailTemplate> developerName2EmailTemplate;
			for(EmailTemplate caseEmailTemplate : caseActionEmailTemplateList){
				developerName2EmailTemplate.put(caseEmailTemplate.DeveloperName, caseEmailTemplate);
			}

			//company name => case action => email template
			for(String devName :devName2CaseMailTemplate.keySet()){
				CaseAction__mdt caseMailTemplate = devName2CaseMailTemplate.get(devName);
				Map<String,EmailTemplate> caseAction2EmailTemplate = company2CaseAction2EmailTemplate.get(caseMailTemplate.CompanyName__c);
				EmailTemplate caseEmailTemplate = developerName2EmailTemplate.get(caseMailTemplate.TemplateApiName__c);
				caseAction2EmailTemplate.put(caseMailTemplate.CaseAction__c,caseEmailTemplate);
				company2CaseAction2EmailTemplate.put(caseMailTemplate.CompanyName__c,caseAction2EmailTemplate);
			}
		}
		String companyName = c.Company__r.Name != null ? c.Company__r.Name :'028';
		EmailTemplate caseEmailTemplate = company2CaseAction2EmailTemplate.get(companyName).get(action);
		if(caseEmailTemplate == null){
			throw new CaseCommon.CaseException('No E-mail template assigned for this action and Company.');
		}
		else{
			return caseEmailTemplate;
		}
	}*/
}