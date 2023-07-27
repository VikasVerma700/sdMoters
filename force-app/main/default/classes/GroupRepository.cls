public with sharing class GroupRepository {
    public enum GroupType{
        Queue,
        Regular,
        Role
    }

    public static final String PREFIX_USER = '005';
    public static final String PREFIX_GROUP = '00G';
    public static final String PREFIX_ROLE = '00E';

    public static Map<String,Id> roleGroupDevName2Id{
        get{
            if(roleGroupDevName2Id == null){
                new GroupRepository();
            }
            return roleGroupDevName2Id;
        }
        private set;
    }

    public static Map<Id,String> roleGroupId2DevName{
        get{
            if(roleGroupId2DevName == null){
                new GroupRepository();
            }
            return roleGroupId2DevName;
        }
        private set;
    }

    private GroupRepository(){
        roleGroupDevName2Id = new Map<String,Id>();
        roleGroupId2DevName = new Map<Id,String>();

        for(Group roleGroup: [SELECT Id,DeveloperName FROM Group WHERE Type = :GroupType.Role.name()]){
            roleGroupId2DevName.put(roleGroup.Id,roleGroup.DeveloperName);
            roleGroupDevName2Id.put(roleGroup.DeveloperName, roleGroup.Id);
        }
    }
    
    public static Set<Id> getUsers(List<Id> groupIdList){
        Set<Id> userIdSet = new Set<Id>();
        Set<Id> groupIdSet = new Set<Id>();
        Set<String> roleDevNameSet = new Set<String>();
        //group members for groups which are not of role type
        List<GroupMember> groupMemberList = [
            SELECT Id,UserOrGroupId
            FROM GroupMember
            WHERE GroupId IN :groupIdList
                AND GroupId NOT IN :roleGroupId2DevName.keySet()
        ];

        System.debug(groupMemberList);
        if(groupMemberList.size() > 0){
            for(GroupMember member: groupMemberList){
                String memberId = String.valueOf(member.UserOrGroupId);
                //member is a user
                if(memberId.startsWith(PREFIX_USER)){
                    userIdSet.add(member.UserOrGroupId);
                }
                //member is a group record of role type
                else if(roleGroupId2DevName.containsKey(member.UserOrGroupId)){
                    roleDevNameSet.add(roleGroupId2DevName.get(member.UserOrGroupId));
                }
                //member is a group but not of role type
                else if(memberId.startsWith(PREFIX_GROUP)){
                    groupIdSet.add(member.UserOrGroupId);
                }
            }
        }
        System.debug(userIdSet);
        System.debug(roleDevNameSet);
        System.debug(groupIdSet);
        //role api names for groups of role type
        for(Id groupId: groupIdList){
            if(roleGroupId2DevName.containsKey(groupId)){
                roleDevNameSet.add(roleGroupId2DevName.get(groupId));
            }
        }

        if(roleDevNameSet.size() > 0){
            List<User> roleUserList = [
                SELECT Id
                FROM User 
                WHERE UserRole.DeveloperName IN :roleDevNameSet
            ];

            for(User roleUser: roleUserList){
                userIdSet.add(roleUser.Id);
            }
        }

        if(groupIdSet.size()>0){
            userIdSet.addAll(getUsers( new List<Id>(groupIdSet)));
        }
        return userIdSet;
    }
}