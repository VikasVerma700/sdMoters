public class AbServiceApptEmail_Ctrl {

    public Service_Appointment__c sa { get; set; }

    private string m_headerId;
    public string headerId {
        get { return this.m_headerId; }
        set {
            try {
                Document doc = [SELECT Id FROM Document WHERE DeveloperName = :value];
                this.m_headerId = doc.Id;
            }
            catch (Exception e) { this.m_headerId = null; }
        }
    }

    private string m_detailsId;
    public string detailsId {
        get { return this.m_detailsId; }
        set {
            try {
                Document doc = [SELECT Id FROM Document WHERE DeveloperName = :value];
                this.m_detailsId = doc.Id;
            }
            catch (Exception e) { this.m_detailsId = null; }
        }
    }

    private string m_lineId;
    public string lineId {
        get { return this.m_lineId; }
        set {
            try {
                Document doc = [SELECT Id FROM Document WHERE DeveloperName = :value];
                this.m_lineId = doc.Id;
            }
            catch (Exception e) { this.m_lineId = null; }
        }
    }

    private string m_spacerId;
    public string spacerId {
        get { return this.m_spacerId; }
        set {
            try {
                Document doc = [SELECT Id FROM Document WHERE DeveloperName = :value];
                this.m_spacerId = doc.Id;
            }
            catch (Exception e) { this.m_spacerId = null; }
        }
    }

    public AbServiceApptEmail_Ctrl() {}
    public AbServiceApptEmail_Ctrl(ApexPages.StandardController controller) {
        this.sa = (Service_Appointment__c)controller.getRecord();
    }
}