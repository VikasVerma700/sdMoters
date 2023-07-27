public with sharing class StaticSample {
    public static String info;
    public static void runTrans(){
        while(true){
            System.debug(info);
        }
    }
    public static void setInfo(String a){
        info = a;
        runTrans();
    }
}