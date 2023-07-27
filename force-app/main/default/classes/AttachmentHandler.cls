public without sharing class AttachmentHandler extends TriggerBase {
	public class AttachmentException extends Exception {}
	public static User ADMIN = TriggerBase.admin;

	public static final String TRIG_SETTING = 'Attachment';
	public AttachmentHandler() { super(TRIG_SETTING); }


	public override void afterInsert(Map<Id, SObject> triggerNew) {
		if (!System.isFuture() && !System.isQueueable() && !System.isBatch()) {
		}
		AttachmentHandler.recalculateInvoiceDocument((Attachment[])triggerNew.values());
	}

	public override void afterUpdate(Map<Id, SObject> triggerNew, Map<Id, SObject> triggerOld) {
		if (!System.isFuture() && !System.isBatch() && !System.isQueueable()) {
		}
		AttachmentHandler.recalculateInvoiceDocument((Attachment[])triggerNew.values());
	}

	public override void afterDelete(Map<Id, SObject> triggerOld) {
		AttachmentHandler.recalculateInvoiceDocument((Attachment[])triggerOld.values());
	}
	public static void recalculateInvoiceDocument(Attachment[] atts) {
		if (atts != null && atts.size() > 0) {
			Set<Id> setSvcInv = new Set<Id>();
			for (Attachment att :atts) {
				if (att.ParentId.getSObjectType() == ServiceInvoice__c.getSObjectType()) {
					setSvcInv.add(att.ParentId);
				}
			}
			if (setSvcInv.size() > 0) {
				/** Affected Service Invoice records */
				ServiceInvoice__c[] sis = [
					SELECT Id, Name, InvoiceReady__c
						, (SELECT Id FROM Attachments WHERE Name LIKE 'Service Invoice%' AND BodyLength > 0)
					FROM ServiceInvoice__c
					WHERE Id IN :setSvcInv
				];
				if (sis != null && sis.size() > 0) {
					for (ServiceInvoice__c si :sis) {
						Attachment[] lAtts = si.Attachments;
						si.InvoiceReady__c = (lAtts != null && lAtts.size() > 0);
					}
					Database.SaveResult[] srs = Database.update(sis, false);
				}
			}
		}
	}
}