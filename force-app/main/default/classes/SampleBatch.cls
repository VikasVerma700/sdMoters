public with sharing class SampleBatch implements Database.Batchable<Integer>{

    public SampleBatch() {
    }

    public Iterable<Integer> start(Database.BatchableContext bc){
        String query;
        List<Integer> emptyList = new List<Integer>();
        System.debug('Records in start: '+ emptyList);
        return emptyList;
    }

    public void execute(Database.BatchableContext bc, List<Integer> numberList){
        System.debug('Control in Execute');
    }

    public void finish(Database.BatchableContext bc){
        system.debug('Control in FINISH');
    }

}