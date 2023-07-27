trigger DmsCallbackTrigger on DmsCallBack__e (after insert) {
    if(trigger.isAfter && trigger.isInsert){
        DmsCallbackTriggerHandler.afterInsert(trigger.new); 
    }
}