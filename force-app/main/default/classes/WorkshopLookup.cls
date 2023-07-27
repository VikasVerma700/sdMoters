public with sharing class WorkshopLookup {
    Map<String, Workshop__c> name2Workshop;
    List<Workshop__c> missingWorkshopList;
    List<String> missingWorkshopKeyList;

    public static String joinKeys(List<String> keyList){
		String key = String.join(keyList,'_').toUpperCase();
		return key;
	}

    public WorkshopLookup(){
        this.refresh();
    }

    public WorkshopLookup(List<Workshop__c> workshopList){
        this.updateMaps(workshopList,true);
    }

    public void refresh(){
        this.name2Workshop = new Map<String, Workshop__c>();
        this.missingWorkshopList = new List<Workshop__c>();
        this.missingWorkshopKeyList = new List<String>();
    }

    public List<Workshop__c> insertMissingWorkshops(){
        Database.insert(missingWorkshopList,false);
        this.updateMaps(missingWorkshopList, false);
        return missingWorkshopList;
    }

    public void updateMaps(List<Workshop__c> workshopList, Boolean refresh){
        List<String> keyList;
        if(refresh){
            this.refresh();
        }

        for(Workshop__c workshop:workshopList){
            String companyName = CompanyRepository.id2Company.get(workshop.Company__c).DmsCompanyCode__c;
            keyList = new List<String>{companyName,workshop.Name};
            this.name2Workshop.put(joinKeys(keyList), workshop);
        }
    }

    public Workshop__c lookWorkshop(String companyName,String workshopName){
        Workshop__c workshop = null;
        List<String> keyList;
        keyList = new List<String>{companyName,workshopName};
        String key = joinKeys(keyList);
        workshop = this.name2Workshop.get(key);
        if(workshop == null && !this.missingWorkshopKeyList.contains(key)){
            Workshop__c missingWorkshop = new Workshop__c();
            missingWorkshop.Name = workshopName;
            missingWorkshop.Company__c = CompanyRepository.name2Company.get(companyName).Id;
            missingWorkshop.IsActive__c = true;
            this.missingWorkshopList.add(missingWorkshop);
            this.missingWorkshopKeyList.add(key);
        }
        return workshop;
    }

    public void lookAll(Set<String> workshopNameSet, String companyName){
        for(String workshopName: workshopNameSet){
            this.lookWorkshop(companyName,workshopName);
        }
    }
}