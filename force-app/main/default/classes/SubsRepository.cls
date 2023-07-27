public with sharing class SubsRepository {
    public enum SubChannel{
        Email,
        Letter,
        SMS
    }

    public static Subscription__c create(Id accountId, Id companyId,String uniqueKey, SubChannel channel, boolean optOut, boolean doInsert){
        Subscription__c sub= new Subscription__c();
        sub.Account__c = accountId;
        sub.Company__c = companyId;
        sub.Channel__c = channel.name();
        sub.OptOut__c = optOut;
        if(uniqueKey == null){
            uniqueKey = String.join(new List<String> { companyId,accountId,channel.name().toUpperCase()}, '_');
        }
        sub.UniqueKey__c = uniqueKey;
        sub.EventOptOut__c = false;
        sub.NewsletterOptOut__c = false;
        sub.SalesPromoOfferOptOut__c = false;
        sub.ApsPromoOfferOptOut__c = false;
        if(doInsert){
            insert sub;
        }
        return sub;
    }

    public static List<Subscription__c> create(Id accountId, Id companyId,String uniqueKey, boolean doInsert){
        List<Subscription__c> subList = new List<Subscription__c>();
        for(SubChannel channel :SubChannel.values()){
            subList.add(create(accountId,companyId,uniqueKey,channel,false,false));
        }
        if(doInsert){
            insert subList;
        }
        return subList;
    }

    public static List<Subscription__c> create(Map<Id,Set<Id>> companyId2AccountIdSet, boolean doInsert){
        List<Subscription__c> subList = new List<Subscription__c>();
        for(Id companyId: companyId2AccountIdSet.keySet()){
            for(Id accountId: companyId2AccountIdSet.get(companyId)){
                subList.addAll(create(accountId, companyId, null, false));
            }
        }

        if(doInsert){
            insert subList;
        }
        return subList;
    }

    public static List<Subscription__c> create(Map<String,Set<Id>> companyName2AccountIdSet, boolean doInsert){
        Map<Id,Set<Id>> companyId2AccountIdSet = new Map<Id,Set<Id>>();
        for(String companyName: companyName2AccountIdSet.keySet()){
            System.debug(companyName);
            System.debug(CompanyRepository.name2Company);
            Id companyId = CompanyRepository.name2Company.get(companyName).Id;
            companyId2AccountIdSet.put(companyId, companyName2AccountIdSet.get(companyName));
        }
        return create(companyId2AccountIdSet, doInsert);
    }
}