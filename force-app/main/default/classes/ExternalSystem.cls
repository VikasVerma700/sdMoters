public with sharing class ExternalSystem {
    public enum Type{
        GDMS,
        Autoline,
        CareDb,
        Units,
        GdmsInternal,
        GdmsExternal
    }
    public Type systemType;
    public String companyName;
    public boolean transactionComplete;

    public ExternalSystem(String companyName){
        this.transactionComplete = false;
        this.systemType = CompanyRepository.NAME_TO_EXTERNAL_SYSTEM.get(companyName);
        if(this.systemType == null){
            throw new TypeException('Invalid company name');
        }
        else{
            this.companyName = companyName;
        }
    }
}