trigger ServiceAppointment on Service_Appointment__c (after insert, after update, before insert, before update) {
	TriggerRun.run(new ServiceAppointmentHandler());
}