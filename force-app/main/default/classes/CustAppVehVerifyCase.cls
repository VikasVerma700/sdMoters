public class CustAppVehVerifyCase implements Queueable {
	Id vehOwnerId;
	CustAppVehicle.LtaVehCls veh;
	String cmp;
    public CustAppVehVerifyCase(Id vehOwnerId, CustAppVehicle.LtaVehCls veh, String cmp) {
		this.vehOwnerId = vehOwnerId;
		this.veh = veh;
		this.cmp = cmp;
	}

	public void execute(QueueableContext context) {
		try {
			List<Vehicle_Ownership__c> voList = [SELECT Id, Vehicle__c, Customer__c, Registration_No__c FROM Vehicle_Ownership__c WHERE Id = :this.vehOwnerId];
			if (voList.size() <= 0) { return; }
			Vehicle_Ownership__c vo = voList[0];
			Case newCase = new Case();
			newCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('General Enquiry').getRecordTypeId();
			newCase.Type = 'General Enquiry';
			newCase.Status = 'New';
			newCase.Priority = 'Low';
			newCase.Chassis__c = vo.Vehicle__c;
			newCase.AccountId = vo.Customer__c;
			newCase.Subject = 'Verification of Ownership ' + vo.Registration_No__c;
			newCase.Origin = 'APP';
			newCase.Description = 'Please verify ownership of this newly registered customer from the BMW Customer App.';
			newCase.Registration_No_Manual__c = veh.vehicleDetails.no;
			newCase.UniqueCaseIdentifier__c = newCase.Type + newCase.AccountId + newCase.Chassis__c + newCase.Subject +
												String.valueOf(Datetime.now().format('hh:mm dd-MM-yyyy'));
			if (cmp == '028') {
				newCase.Operating_Unit__c = '028';
				newCase.Incident_Location__c = 'AbAraDamansara';
				newCase.Department__c = 'Others';
			} else {
				throw new CustAppAPI.CustAppException('Unmapped case handler.');
			}
			insert newCase;
		} catch (Exception e) {
			String emailBody = CommonMethodsLibrary.constructErrEmail('Error from CustAppVehVerifyCase', e.getStackTraceString(), e.getMessage());
			System.debug('CustAppVehVerifyCase Error: ' + emailBody);
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
		}
	}
}