public with sharing class CaseBranchCodeMdt {
    private static Map<String,Map<String,String>> company2branch2code;

    public static Map<String,Map<String,String>>  getBranchCodeMap(){
		if(company2branch2code == null){
			company2branch2code = new Map<String,Map<String,String>>();

			//company name => case action => null
			Map<String,CaseBranchCode__mdt> devName2CaseBranchCode = CaseBranchCode__mdt.getAll();
			for(String devName :devName2CaseBranchCode.keySet()){
				CaseBranchCode__mdt caseBranchCode = devName2CaseBranchCode.get(devName);
				Map<String,String> branch2branchCode = company2branch2code.get(caseBranchCode.CompanyCode__c);
				if(branch2branchCode == null){
					branch2branchCode = new Map<String,String>();
				}
				branch2branchCode.put(caseBranchCode.Branch__c,caseBranchCode.BranchCode__c);
				company2branch2code.put(caseBranchCode.CompanyCode__c,branch2branchCode);
			}
        }
        return company2branch2code;
	}
}