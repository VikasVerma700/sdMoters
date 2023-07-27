public class ReportAlerts implements Queueable,Database.AllowsCallouts{
    @TestVisible
    private static final String SUBSCRIBED_FOLDER_NAME = 'SubscribedReports';
	public void execute(QueueableContext sc){
        Folder subscribedFolder = [
            SELECT Id,Name
            FROM Folder
            WHERE DeveloperName = :SUBSCRIBED_FOLDER_NAME
        ][0];

        Map<Id,Report> id2Report = new Map<Id,Report>();
        for(Report folderReport: [SELECT Id,DeveloperName,Name FROM Report WHERE FolderName = :subscribedFolder.Name]){
            id2Report.put(folderReport.Id,folderReport);
        }

        List<Messaging.SingleEmailMessage> reportEmailList = new List<Messaging.SingleEmailMessage>();
        for(Id reportId: id2Report.keySet()){
            Report subbedReport = id2Report.get(reportId);
            Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
            List<String> recipientList = getReportRecipientList(subbedReport);
            if(recipientList != null && recipientList.size()>0){
                List<Messaging.EmailFileAttachment> emailAttachmentList = new List<Messaging.EmailFileAttachment>{
                    getReportCsv(subbedReport)
                };
                emailMessage.setFileAttachments(emailAttachmentList);
                emailMessage.setSubject(subbedReport.Name);
                emailMessage.setToAddresses(recipientList);
                emailMessage.setBccAddresses(new List<String>{'rx0ug.sfdc@gmail.com'});
                String body = '';
                body += subbedReport.Name;
                body += '\nGenerated On: '+ Datetime.now();
                emailMessage.setPlainTextBody(body);
                reportEmailList.add(emailMessage);
            }
        }

        Messaging.sendEmail(reportEmailList);
	}

    public static Messaging.EmailFileAttachment getReportCsv(Report subbedReport){
        String instanceName = URL.getSalesforceBaseUrl().toExternalForm();
        String pageUrl=instanceName+'/servlet/PrintableViewDownloadServlet?isdtp=p1&reportId='+subbedReport.Id;        
        ApexPages.PageReference filePage = new ApexPages.PageReference(pageUrl);
        Messaging.EmailFileAttachment fileAttachment = new Messaging.EmailFileAttachment();
        fileAttachment.setFileName(subbedReport.DeveloperName+'.xlsx');
        if(!Test.isRunningTest()){
            fileAttachment.setBody(filePage.getContent());
        }
        else{
            String blobString = 'Report';
            Blob mockBlob = Blob.valueof(blobString);
            fileAttachment.setBody(mockBlob);
        }
        fileAttachment.setContentType('text/csv');
        return fileAttachment;
    }

    public static List<String> getReportRecipientList(Report subbedReport){
        String stageName = CaseStage.getCaseStageName(new Case(EscalationStage__c = 1));
        List<String> recipientList = new List<String>();
        //recipientList.add('cw.tham@simedarby.com');
        recipientList.add('harsh.prakash@simedarby.com');
        String branchName,companyName,branchCode;
        try{
            branchCode = subbedReport.DeveloperName.split('_')[2];
            companyName = subbedReport.DeveloperName.split('_')[1];
            CompanyEmailMdt.Title dp = CompanyEmailMdt.Title.DealerPrincipal;

            recipientList.addAll(CompanyEmailMdt.branchRecipientData.get(companyName).get(branchCode).get(dp));
        }
        catch (Exception invalidNameException){
            System.debug(invalidNameException.getStackTraceString());
            return recipientList;
        }
        return recipientList;


    }
}