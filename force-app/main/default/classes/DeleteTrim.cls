public with sharing class DeleteTrim implements Database.Batchable<SObject>{
    public Database.QueryLocator start(Database.BatchableContext bc){
		//String query  = 'SELECT Id FROM Vehicle_Model_Trim__c';
        String className = 'VehicleResource';
        String query = 'SELECT Id FROM ApplicationLog__c WHERE ApexClassName__c = :className';

		return Database.getQueryLocator(query);
    }
/*
    public void execute(Database.BatchableContext bc, List<Vehicle_Model_Trim__c> trimList){
        delete trimList;
    }
*/
    public void execute(Database.BatchableContext bc, List<ApplicationLog__c> trimList){
        delete trimList;
    }

    public void finish(Database.BatchableContext bc){
        system.debug('finished');
    }
}