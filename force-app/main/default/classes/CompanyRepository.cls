public without sharing class CompanyRepository {

    public static Map<Id,Company__c> id2Company{
        get{
            if(id2Company == null){
                new CompanyRepository();
            }
            return id2Company;
        }
        private set;
    }

    public static Map<String,Company__c> name2Company{
        get{
            if(name2Company == null){
                new CompanyRepository();
            }
            return name2Company;
        }
        private set;
    }

	/** Internal */
	public static final String C001 = '1';		//	SD Swedish Auto - UNITS (Volvo)
    public static final String C028 = '028';	//	SD Auto Bavaria - Autoline (BMW; MINI; Motorrad)
	public static final String C038 = '038';	//	SD Auto Hyundai - GDMS (Hyundai; Genesis)
	public static final String C088 = '088';	//	SD Auto Connextion - GDMS (Ford)
	public static final String C089 = '089';	//	Jaguar Land Rover - GDMS (Jaguar; Land Rover)
    public static final String C099 = '099';	//	SD Beyond Auto - GDMS (BYD)
    public static final String C168 = '168';	//	SD Auto Selection - GDMS (Multi brand)

	/** External */
	public static final String C138 = '138';	//	HSDM dealers - GDMS External
	public static final String C188 = '288';	//	SD Auto Connextion - GDMS External
	public static final String C199 = '199';	//	SD Beyond Auto - GDMS External

	private static String allFields;
	public static String getAllFields(){
		if(allFields == null){
			allFields = String.join(new List<String>(schema.SObjectType.Company__c.fields.getMap().keySet()),',');
		}
		return allFields;
	}

    private CompanyRepository(){
        String query = 'SELECT '+getAllFields();
        query += ' FROM Company__c';
        //id2Name = new Map<Id,String>();
        //companyData = new Map<String,Company__c>();
        id2Company = new Map<Id,Company__c>();
        name2Company = new Map<String,Company__c>();

        List<Company__c> companyList = Database.query(query);
        for(Company__c company: companyList){
            //companyData.put(company.DmsCompanyCode__c, company);
            //id2Name.put(company.Id,company.DmsCompanyCode__c);
            id2Company.put(company.Id,company);
            name2Company.put(company.DmsCompanyCode__c,company);
        }
    }

    public static final Map<String, ExternalSystem.Type> NAME_TO_EXTERNAL_SYSTEM = new Map<String, ExternalSystem.Type>{
        C001 => ExternalSystem.Type.CareDb,		// Future: Units
        C028 => ExternalSystem.Type.CareDb,		// Future: Autoline
		C038 => ExternalSystem.Type.GdmsInternal,
		C088 => ExternalSystem.Type.GdmsInternal,
		C089 => ExternalSystem.Type.GdmsInternal,
		C099 => ExternalSystem.Type.GdmsInternal,
		C168 => ExternalSystem.Type.GdmsInternal,
		C138 => ExternalSystem.Type.GdmsExternal,
		C188 => ExternalSystem.Type.GdmsExternal,
		C199 => ExternalSystem.Type.GdmsExternal
    };

    public static final Map<ExternalSystem.Type,Set<String>> EXTERNAL_SYSTEM_TO_COMPANY_CODE = new Map<ExternalSystem.Type,Set<String>>{
        ExternalSystem.Type.GDMS => new Set<String>{C199,C099},
        ExternalSystem.Type.CareDb => new Set<String>{C001,C028},
        ExternalSystem.Type.GdmsInternal => new Set<String>{C038,C088,C099},
        ExternalSystem.Type.GdmsExternal => new Set<String>{C138,C188,C199}
    };

    public static String getRelatedCompanyCode(String companyCode){
        ExternalSystem.Type sourceType = NAME_TO_EXTERNAL_SYSTEM.get(companyCode);
        if(sourceType == null){
            throw new  TypeException('Invalid Company Code: '+companyCode);
        }
        else{
            List<String> sourceCodeList = new List<String>(EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(sourceType));
            Integer codeIndex = sourceCodeList.indexOf(companyCode);
            if(codeIndex == -1){
                throw new  TypeException('No related company defined for: '+ companyCode);
            }
            else{
                ExternalSystem.Type targetType = sourceType == ExternalSystem.Type.GdmsExternal ? ExternalSystem.Type.GdmsInternal : ExternalSystem.Type.GdmsExternal;
                List<String> targetCodeList = new List<String>(EXTERNAL_SYSTEM_TO_COMPANY_CODE.get(targetType));
                return targetCodeList.get(codeIndex);
            }
        }
    }
}