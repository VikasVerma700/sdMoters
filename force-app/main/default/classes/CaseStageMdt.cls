public with sharing class CaseStageMdt {
    public static final String TYPE_INITIAL = 'Initial';
    public static final String TYPE_TIME = 'Time';

    @TestVisible
    private static final Integer DAY_TO_MS = 95*60*60*100; // 9.5* 60*60*1000

    private static Map<String,Map<Integer,List<String>>> priority2StageTitleList;
    public static Map<Integer,List<String>> getStageTitles(String priority){
        if(priority2StageTitleList == null){
            new CaseStageMdt();
        }
        return priority2StageTitleList.get(priority);
    }

    private static Map<String,Integer> priority2InitialStage;
    private static Map<String,Map<Integer,Integer>> priority2StageTimeMap;

    public static Map<String,Integer> getInitialStageMap(){
        if(priority2InitialStage == null){ //lazy loading
            new CaseStageMdt();
        }
        return priority2InitialStage;
    }

    public static Map<Integer,Integer> getStageTimeMap(String priority){
        Map<String, CaseStage__mdt> name2CaseStage = CaseStage__mdt.getAll();
        if(priority2StageTimeMap == null){//lazy loading
            new CaseStageMdt();
        }
        return priority2StageTimeMap.get(priority);
    }

    //class must be interacted with using static methods only
    private CaseStageMdt(){
        priority2StageTimeMap = new Map<String,Map<Integer,Integer>>();
        priority2InitialStage = new Map<String,Integer>();
        priority2StageTitleList = new Map<String,Map<Integer,List<String>>>();
        Map<String, CaseStage__mdt> name2CaseStage = CaseStage__mdt.getAll();

        for(String devName: name2CaseStage.keySet()){
            CaseStage__mdt caseStage = name2CaseStage.get(devName);
            Integer stage = Integer.valueOf(caseStage.EscalationStage__c);

            if(caseStage.Type__c == TYPE_TIME){
                Map<Integer,Integer> stage2Time = priority2StageTimeMap.get(caseStage.Priority__c);
                if(stage2Time == null){
                    stage2Time = new Map<Integer,Integer>();
                }

                Map<Integer,List<String>> stage2TitleList = priority2StageTitleList.get(caseStage.Priority__c);
                if(stage2TitleList == null){
                    stage2TitleList = new Map<Integer,List<String>>();
                }
                
                stage2Time.put(stage,(Integer) caseStage.Days__c * DAY_TO_MS);
                priority2StageTimeMap.put(caseStage.Priority__c,stage2Time);

                if(String.isNotBlank(caseStage.Titles__c)){
                    stage2TitleList.put(stage,caseStage.Titles__c.split(' '));
                }
                priority2StageTitleList.put(caseStage.Priority__c,stage2TitleList);
            }

            if(caseStage.Type__c == TYPE_INITIAL){
                priority2InitialStage.put(caseStage.Priority__c,stage);
            }
        }
    }
}