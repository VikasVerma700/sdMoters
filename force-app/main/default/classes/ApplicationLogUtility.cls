public class ApplicationLogUtility {

    public static final String TYPE_APEX = 'Apex';
    public static final String TYPE_CALLOUT = 'Callout';

    public static final String PRIORITY_LOW = 'Low';
    public static final String PRIORITY_MEDIUM = 'Medium';
    public static final String PRIORITY_HIGH = 'High';

    @TestVisible
    private static List<ApplicationLog__c> appLogList;
    public static void addLog(ApplicationLog__c appLog){
        if(appLogList == null){
            appLogList = new List<ApplicationLog__c>{appLog};
        }
        else{
            appLogList.add(appLog);
        }
    }

    public static void addLog(List<ApplicationLog__c> appLogs){
        if(appLogList == null){
            appLogList = new List<ApplicationLog__c>(appLogs);
        }
        else{
            appLogList.addAll(appLogs);
        }
    }

    public static void insertLogs(){
        insertLogs(true);
    }
    public static void insertLogs(Boolean clearLogCache){
        if(appLogList != null){
            Database.insert(appLogList,false);
            if(Test.isRunningTest()){
                for(ApplicationLog__c appLog: appLogList){
                    System.debug(appLog.ErrorMessage__c);
                    System.debug(appLog.StackTrace__c);
                }
            }
            if(clearLogCache){
                appLogList = new List<ApplicationLog__c>();
            }
        }
    }

    public static final List<String> IMMEDIATE_PRIORITY_LIST = new List<String>{
        PRIORITY_HIGH,PRIORITY_MEDIUM
    };

    public static final List<String> REGULAR_PRIORITY_LIST = new List<String>{
        PRIORITY_LOW,PRIORITY_MEDIUM
    };
    
    public static void insertApexErrorLog(string className,string message,string stackTrace){
        insertApexErrorLog(className,message,stackTrace,Request.getCurrent().getRequestId());
    }

    public static void insertApexErrorLog(string className,string message,string stackTrace,string transactionId){
        INSERT new ApplicationLog__c(
            Type__c=TYPE_APEX,
            ErrorMessage__c = message,
            StackTrace__c = stackTrace,
            Status__c = 'ERROR',
            ApexClassName__c = className,
            TransactionId__c = transactionId,
            Priority__c = PRIORITY_MEDIUM
        );
    }

    public static ApplicationLog__c insertApexCompletionLog(String className, String message, String stackTrace, String priority,Boolean doInsert){
        ApplicationLog__c appLog = new ApplicationLog__c(
            Type__c=TYPE_APEX,
            ErrorMessage__c = message,
            StackTrace__c = stackTrace,
            Status__c = 'Completed',
            ApexClassName__c = className,
            TransactionId__c = null,
            Priority__c = priority
        );
        if(doInsert){
            insert appLog;
        }
        else{
            addLog(appLog);
        }
        return appLog;
    }

    public static ApplicationLog__c insertApexErrorLog(string className,string message,string stackTrace,string transactionId, String priority, Boolean doInsert){
        ApplicationLog__c appLog = new ApplicationLog__c(
            Type__c=TYPE_APEX,
            ErrorMessage__c = message,
            StackTrace__c = stackTrace,
            Status__c = 'ERROR',
            ApexClassName__c = className,
            TransactionId__c = transactionId,
            Priority__c = priority
        );
        if(doInsert){
            insert appLog;
        }
        else{
            addLog(appLog);
        }
        return appLog;
    }

    public static ApplicationLog__c insertApexErrorLog(Object classInstance, Exception exceptionInstance, String priority, Boolean doInsert){
        String className = Util.getClassname(classInstance);
        return insertApexErrorLog(className, exceptionInstance, priority, doInsert);
    }

    public static ApplicationLog__c insertApexErrorLog(String className, Exception exceptionInstance, String priority, Boolean doInsert){
        String message = exceptionInstance.getMessage();
        if(message.length()> 255){
            message = message.substring(255);
        }
        ApplicationLog__c appLog = new ApplicationLog__c(
            Type__c = TYPE_APEX,
            ErrorMessage__c = exceptionInstance.getMessage(),
            StackTrace__c = exceptionInstance.getStackTraceString(),
            ApexClassName__c = className,
            Priority__c = priority
        );
        if(doInsert){
            insert appLog;
        }
        else{
            addLog(appLog);
        }
        return appLog;
    }

    public static ApplicationLog__c insertApexErrorLog(Object classInstance, Database.Error dbError, String priority, Boolean doInsert){
        ApplicationLog__c appLog = new ApplicationLog__c(
            Type__c = TYPE_APEX,
            ErrorMessage__c = dbError.getMessage()+'\n'+dbError.getFields(),
            StackTrace__c = String.valueOf(dbError.getStatusCode()),
            ApexClassName__c = Util.getClassname(classInstance),
            Priority__c = priority
        );
        if(doInsert){
            insert appLog;
        }
        else{
            addLog(appLog);
        }
        return appLog;
    }

    public static List<ApplicationLog__c> logUpsertFailure(String className, List<Database.UpsertResult> upsertResultList, String priority, Boolean doInsert){
        List<ApplicationLog__c> upsertAppLogList = new List<ApplicationLog__c>();
        for(Database.UpsertResult upsertResult: upsertResultList){
            if(!upsertResult.isSuccess()){
                String operation = upsertResult.isCreated() ? 'create' : 'update';
                for(Database.Error dbError: upsertResult.getErrors()){
                    ApplicationLog__c appLog = new ApplicationLog__c(
                        Type__c = TYPE_APEX,
                        ErrorMessage__c = 'Operation Failed: ' + operation+ '\n'+dbError.getMessage()+'\n'+dbError.getFields()+'\n'+upsertResult.getId(),
                        StackTrace__c = String.valueOf(dbError.getStatusCode()),
                        ApexClassName__c = className,
                        Priority__c = priority
                    );
                    upsertAppLogList.add(appLog);
                }
            }
        }
        if(doInsert){
            insert upsertAppLogList;
        }
        else{
            addLog(upsertAppLogList);
        }
        return upsertAppLogList;

    }

    public static ApplicationLog__c insertCalloutErrorLog(Object classInstance, CalloutException exceptionInstance, String priority, Boolean doInsert){
        String className = Util.getClassname(classInstance);
        return insertCalloutErrorLog(className,exceptionInstance,priority,doInsert);
    }

    public static ApplicationLog__c insertCalloutErrorLog(String className, CalloutException exceptionInstance, String priority, Boolean doInsert){
        ApplicationLog__c appLog = new ApplicationLog__c(
            Type__c = TYPE_CALLOUT,
            ErrorMessage__c = exceptionInstance.getMessage(),
            StackTrace__c = exceptionInstance.getStackTraceString(),
            ApexClassName__c = className,
            Priority__c = priority,
            CalloutResponse__c = exceptionInstance.getMessage(),
            CalloutRequest__c = String.valueOf(exceptionInstance.getCause())
        );
        if(doInsert){
            insert appLog;
        }
        else{
            addLog(appLog);
        }
        return appLog;
    }

    public static void insertCalloutErrorLog(string className,string message,string stackTrace){
        insertCalloutErrorLog(className,message,stackTrace,Request.getCurrent().getRequestId());
    }

    public static void insertCalloutErrorLog(string className,string message,string stackTrace,string transactionId){
        INSERT new ApplicationLog__c(
            Type__c=TYPE_CALLOUT,
            ErrorMessage__c = message,
            StackTrace__c = stackTrace,
            Status__c = 'ERROR',
            ApexClassName__c = className,
            TransactionId__c = transactionId,
            Priority__c = PRIORITY_MEDIUM
        );
    }
    
    public static void insertCalloutFailLog(string className,string request,string response,string transactionId){
        INSERT new ApplicationLog__c(
            Type__c=TYPE_CALLOUT,
            Status__c = 'REQUEST FAILED',
            ApexClassName__c = className,
            CalloutRequest__c = request,
            CalloutResponse__c = response,
            TransactionId__c = transactionId,
            Priority__c = PRIORITY_MEDIUM
        );
    }
    
    public static void insertCalloutSuccessLog(string className,string request,string response,string transactionId){
        INSERT new ApplicationLog__c(
            Type__c=TYPE_CALLOUT,
            Status__c = 'COMPLETED',
            ApexClassName__c = className,
            CalloutRequest__c = request,
            CalloutResponse__c = response,
            TransactionId__c = transactionId,
            Priority__c = PRIORITY_MEDIUM
        );
    }

    public static void insertCalloutSuccessLog(String className, String request , string response, string transactionId, boolean doInsert){
        ApplicationLog__c appLog = new ApplicationLog__c(
            Type__c=TYPE_CALLOUT,
            Status__c = 'COMPLETED',
            ApexClassName__c = className,
            CalloutRequest__c = request,
            CalloutResponse__c = response,
            TransactionId__c = transactionId,
            Priority__c = PRIORITY_LOW
        );
        if(doInsert){
            insert appLog;
        }
        else{
            addLog(appLog);
        }
    }

    public static ApplicationLog__c insertCalloutSuccessLog(String className, String request , string response, string transactionId, String message, boolean doInsert){
        ApplicationLog__c appLog = new ApplicationLog__c(
            Type__c=TYPE_CALLOUT,
            Status__c = 'COMPLETED',
            ApexClassName__c = className,
            CalloutRequest__c = request,
            CalloutResponse__c = response,
            TransactionId__c = transactionId,
            Priority__c = PRIORITY_LOW,
            ErrorMessage__c = message
        );
        if(doInsert){
            insert appLog;
        }
        else{
            addLog(appLog);
        }
        return appLog;
    }


    public static String getLogHtml(ApplicationLog__c appLog){
        String header = '<strong>'+appLog.priority__c+'</strong>'+' priority ';
        header += '<strong>'+appLog.Type__c +'</strong>'+' type error ';
        header +=  'encountered in '+'<strong>'+appLog.ApexClassName__c +'</strong>'+'\n';
        String error = '';
        if(appLog.Type__c == TYPE_CALLOUT){
            if(String.isNotBlank(appLog.CalloutRequest__c)){
                error += 'Request : '+appLog.CalloutRequest__c + '\n';
            }

            if(String.isNotBlank(appLog.CalloutResponse__c)){
                error += 'Response : '+appLog.CalloutResponse__c + '\n';
            }
        }
        if(String.isNotBlank(appLog.ErrorMessage__c)){
            error += 'Error : '+appLog.ErrorMessage__c+ '\n';
        }

        if(String.isNotBlank(appLog.StackTrace__c)){
            error += 'Stack Trace : '+appLog.StackTrace__c+ '\n';
        }

        String footer = '';
        if(appLog.TransactionId__c!=null){
            footer += 'Transaction : '+appLog.TransactionId__c+ '\n';
        }

        if(String.isNotBlank(appLog.Status__c)){
            footer += 'Status : '+appLog.Status__c+ '\n';
            footer += 'Log Added On: '+String.valueOf(appLog.CreatedDate)+'\n';
        }
        footer += 'Link : '+URL.getSalesforceBaseUrl().toExternalForm()+'/'+appLog.Id;
        return CommonMethodsLibrary.constructErrEmail(header, footer, error,'');
    }

    public static void sendLogAlert(List<Id> appLogIdList){
        List<ApplicationLog__c> appLogList = new List<ApplicationLog__c>();
        appLogList = [
            SELECT Id,priority__c, Type__c,CalloutRequest__c,CalloutResponse__c,CreatedDate,
                ErrorMessage__c,StackTrace__c,TransactionId__c,Status__c,ApexClassName__c
            FROM ApplicationLog__c
            WHERE Id IN :appLogIdList
        ];
        if(appLogList.size()>0){
            List<String> appLogHtmlList = new List<String>();
            for(ApplicationLog__c appLog: appLogList){
                appLogHtmlList.add(ApplicationLogUtility.getLogHtml(appLog));
            }
            CommonMethodsLibrary.sendErrorEmail(Envir.USER_ADMINS, String.join(appLogHtmlList, '<br/>'), true, 'Log Alert');
        }
    }

}