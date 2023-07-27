trigger AttachmentTrigger on Attachment (before insert, after insert, before update, after update, before delete, after delete) {
	TriggerRun.run(new AttachmentHandler());
}