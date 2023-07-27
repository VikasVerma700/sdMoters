public class MitiApproval_Ctrl {

	public Service_Appointment__c sa { get; set; }

	// public string bannerApi;
	// public string logoApi;

	private string m_bannerId;
	public string bannerId {
		get { return this.m_bannerId; }
		set {
			try {
				Document doc = [SELECT Id FROM Document WHERE DeveloperName = :value];
				this.m_bannerId = doc.Id;
			}
			catch (Exception e) { this.m_bannerId = null; }
		}
	}

	private string m_logoId;
	public string logoId {
		get { return this.m_logoId; }
		set {
			try { 
				Document doc = [SELECT Id FROM Document WHERE DeveloperName = :value];
				this.m_logoId = doc.Id;
			}
			catch (Exception e) { this.m_logoId = null; }
		}
	}

	private string m_qrLink;
	public string qrLink {
		get {
			system.debug('qrLink getter: ' + m_qrLink);
			return m_qrLink;
		}
		set {
			system.debug('qrLink setter: ' + value);
			// string[] qr = ServiceApptBooking.getApptQR(new string[] { value });
			// if (qr == null || qr.size() == 0) { this.m_qrLink = null; } 
			// else { this.m_qrLink = qr[0]; }
			Attachment[] atts = [SELECT Id FROM Attachment WHERE Name = 'SelfCheckInQr.png' AND ParentId = :value];
			if (atts == null || atts.size() == 0) { this.m_qrLink = null; }
			else { this.m_qrLink = atts[0].Id; }
		}
	}

	public MitiApproval_Ctrl() {}

	public MitiApproval_Ctrl(ApexPages.StandardController controller) {
		this.sa = (Service_Appointment__c)controller.getRecord();
	}

}