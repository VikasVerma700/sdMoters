public with sharing class CompanyEmailMdt {
    private static List<String> debugEmailList = new List<String>{
        'harsh@astreait.com'
    };
    // Map for Company -> Branch -> Title -> List of Emails
    //title is different for each branch of each OU/Company
    public static Map<String,Map<String,Map<Title,List<String>>>> branchRecipientData{
        get{
            if(branchRecipientData == null){
                new CompanyEmailMdt();
            }
            return branchRecipientData;
        }
        private set;
    }

    //title is different for each company but same across branches
    public static Map<String,Map<Title,List<String>>> companyRecipientData{
        get{
            if(companyRecipientData == null){
                new CompanyEmailMdt();
            }
            return companyRecipientData;
        }
        private set;
    }

    //title is same across all OU(s)/Companies
    public static Map<Title,List<String>> recipientData{
        get{
            if(recipientData == null){
                new CompanyEmailMdt();
            }
            return recipientData;
        }
        private set;
    }

    private static Map<String,List<String>> roleDevName2EmailList;

    private static List<String> getEmails(CompanyEmail__mdt companyEmail){
        List<String> emailList = new List<String>();

        if(String.isNotBlank(companyEmail.RoleDevName__c)){
            List<String> roleDevNameList = companyEmail.RoleDevName__c.split(' ');
            for(String roleDevName: roleDevNameList){
                if(roleDevName2EmailList.get(roleDevName) != null){
                    //emailList.addAll(roleDevName2EmailList.get(roleDevName));
                }
            }
        }

        String emails = companyEmail.Emails__c;
        if(String.isNotBlank(emails)){
            for(String email:emails.split(' ')){
                if(debugEmailList.contains(email)){
                    emailList.add(email);
                }
                else{
                    emailList.add(u.sandboxEmail(email));
                }
                
            }
        }

        return emailList;
    }

    private CompanyEmailMdt(){
        recipientData = new Map<Title,List<String>>();
        branchRecipientData = new Map<String,Map<String,Map<Title,List<String>>>>();
        companyRecipientData = new Map<String,Map<Title,List<String>>>();
        Map<String,Map<String,String>> company2branch2code = CaseBranchCodeMdt.getBranchCodeMap();
        Map<Title,List<String>> titleMap;

        //initialize all email list for each of recipient data propertes
        for(Title recipientTitle: Title.values()){

            for(String companyName : company2branch2code.keySet()){
                titleMap = new Map<Title,List<String>>();
                titleMap.put(recipientTitle, new List<String>());
                companyRecipientData.put(companyName, titleMap);
                
                List<String> branchCodeList = company2branch2code.get(companyName).values();
                Map<String,Map<Title,List<String>>> branchMap = branchRecipientData.get(companyName);
                if(branchMap == null){
                    branchMap = new Map<String,Map<Title,List<String>>>();
                }
                for(String branchCode: branchCodeList){
                    titleMap = new Map<Title,List<String>>();
                    titleMap.put(recipientTitle, new List<String>());
                    branchMap.put(branchCode, titleMap);
                }
                branchRecipientData.put(companyName,branchMap);
            }
            titleMap = new Map<Title,List<String>>();
            titleMap.put(recipientTitle, new List<String>());
            recipientData.put(recipientTitle, new List<String>());
        }

        Set<String> roleDevNameSet = new Set<String>();
        Map<String,CompanyEmail__mdt> devName2CompanyEmail = CompanyEmail__mdt.getAll();
        for(String devName: devName2CompanyEmail.keySet()){
            CompanyEmail__mdt companyEmail = devName2CompanyEmail.get(devName);

            String roleDevName = companyEmail.RoleDevName__c;
            if(roleDevName != null){
                roleDevNameSet.addAll(roleDevName.split(' '));
            }
        }
        
        
        if(roleDevNameSet != null){
            //prepare map for roleDev -> roleId
            Map<String,Id> roleDevName2RoleId = new Map<String,Id>();
            for(UserRole role: [SELECT Id,DeveloperName FROM UserRole WHERE DeveloperName IN :roleDevNameSet]){
                roleDevName2RoleId.put(role.DeveloperName, role.Id);
            }

            //map for roleId -> emails of users with that role
            Map<Id,List<String>> roleId2EmailList = new Map<Id,List<String>>();
            List<User> userList = [
                SELECT Id,Email,UserRoleId
                FROM User
                WHERE User.UserRoleId IN :roleDevName2RoleId.values()
                    AND IsActive = true
            ];

            for(User recipientUser: userList){
                List<String> emailList = roleId2EmailList.get(recipientUser.UserRoleId);
                if(emailList == null){
                    emailList = new List<String>();
                }
                emailList.add(recipientUser.Email);
                roleId2EmailList.put(recipientUser.UserRoleId,emailList);
            }

            roleDevName2EmailList = new Map<String,List<String>>();
            for(String roleDevName: roleDevName2RoleId.keySet()){
                Id roleId = roleDevName2RoleId.get(roleDevName);
                roleDevName2EmailList.put(roleDevName,roleId2EmailList.get(roleId));
            }
        }

        for(String devName: devName2CompanyEmail.keySet()){
            CompanyEmail__mdt companyEmail = devName2CompanyEmail.get(devName);
            CompanyEmailMdt.Title recipientTitle = Title.valueOf(companyEmail.Title__c);

            String companyName = companyEmail.Company__c;
            if(String.isNotBlank(companyName)){

                String branchName = companyEmail.BranchCode__c;
                if(String.isNotBlank(branchName)){//title is different for each branch of each OU/Company
                    try{
                        branchRecipientData.get(companyName).get(branchName).get(recipientTitle).addAll(getEmails(companyEmail));
                    }
                    catch(NullPointerException npException){
                        branchRecipientData.get(companyName).get(branchName).put(recipientTitle,getEmails(companyEmail));
                    }
                }
                else{//title is different for each company but same across branches
                    try{
                        companyRecipientData.get(companyname).get(recipientTitle).addAll(getEmails(companyEmail));
                    }
                    catch(NullPointerException npException){
                        companyRecipientData.get(companyname).put(recipientTitle,getEmails(companyEmail));
                    }
                }
            }
            else{
                //title is same across all OU(s)/Companies
                recipientData.get(recipientTitle).addAll(getEmails(companyEmail));
            }
        }
    }

    public enum Title{
        SalesHead,
        AfterSalesHead,
        Md,
        MdRetailDistribution,
        MdMotorDivision,
        CustomerServiceHead,
        DealerPrincipal,
        ServiceManager
    }
}