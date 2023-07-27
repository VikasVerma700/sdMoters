public with sharing class CustAppHandler extends TriggerBase {
	public class CustAppException extends Exception {}

	public static final string TRIG_SETTING = 'Customer App Callback';
    public CustAppHandler() {
		super(TRIG_SETTING, 2);
	}
	
	public override void afterInsert(Map<Id, SObject> triggerNew) {
		System.enqueueJob(new CustAppCallbackQueue(trigger.new));
	}
}