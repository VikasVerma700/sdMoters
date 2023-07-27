public with sharing class CaseTeamMemberHelper {

    private static String allFields;
	public static String getAllFields(){
		if(allFields == null){
			allFields = String.join(new List<String>(schema.SObjectType.CaseTeamMember.fields.getMap().keySet()),',');
		}
		return allFields;
	}

    //caches team members based on id and caseid 
    public static void add(List<CaseTeamMember> memberList){
        for(CaseTeamMember member: memberList){
            if(member.ParentId != null){
                List<CaseTeamMember> caseMemberList = caseId2TeamMemberMap.get(member.ParentId);
                if(caseMemberList == null){
                    caseMemberList = new List<CaseTeamMember>();
                }
                caseMemberList.add(member);
            }

            if(member.Id == null){
                id2TeamMemberMap.put(member.Id,member);
            }
        }
    }

    public static void add(CaseTeamMember member){
        add(new List<CaseTeamMember>{member});
    }

    public static Map<Id,List<CaseTeamMember>> caseId2TeamMemberMap{
        get{
            if(caseId2TeamMemberMap == null){
                caseId2TeamMemberMap = new  Map<Id,List<CaseTeamMember>>();
            }
            return caseId2TeamMemberMap;
        }
        private set;
    }

    public static Map<Id,CaseTeamMember> id2TeamMemberMap{
        get{
            if(id2TeamMemberMap == null){
                id2TeamMemberMap=  new Map<Id,CaseTeamMember>();
            }
            return id2TeamMemberMap;
        }
        private set;
    }

    //provide list of members based on caseid or id (two can never be same)
    public static List<CaseTeamMember> get(Id keyId){
        List<CaseTeamMember> memberList = caseId2TeamMemberMap.get(keyId);
        if(memberList == null){
            CaseTeamMember member = id2TeamMemberMap.get(keyId);
            if(member == null){
                return null;
            }
            memberList = new List<CaseTeamMember>();
            
            if(member != null){
                memberList.add(member);
            }
        }
        return memberList;
    }

}