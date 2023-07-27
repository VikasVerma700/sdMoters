public class AB {
    //Org Checking to determine sandboc/production
    public static Organization org = [select id, name, InstanceName, IsSandbox from Organization limit 1];
    public static Boolean isSandbox{get{return org.isSandbox;}}
    public static string sbSuffix {get{
        if(isSandbox) return userInfo.getUserName().substringAfterLast('.');
        else return 'prod';
    }}
}