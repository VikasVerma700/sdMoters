global class SQL_Veh_Queue implements Database.AllowsCallouts, Queueable {
	private static final string USERNAME = SQL_API_Base.USERNAME;
	private static final string PASSWORD = SQL_API_Base.PASSWORD;
	private static final string ENDPOINT = SQL_API_Base.ENDPOINT + 'v3/vehicle/list';
	private static final string JOB_NAME = SQL_API_Base.QUEUE_VEHI;
	private static final string CREATEDFROM = 'Autoline';

	/** Mapping objects */
	private static Map<string, Company__c>				mapCompany;		// companyCode => Company__c.Name
	private static Map<string, Vehicle_Make__c>			mapMake;		// vehMakeCode => Vehicle_Make__c.Name
	private static Map<string, Vehicle_Model__c>		mapModel;		// vehModelCode => Vehicle_Model__c.Vehicle_Make__c.Name + Vehicle_Model__c.Name
	private static Map<string, Vehicle_Model_Range__c>	mapModelRange;	// vehModelRange => Vehicle_Model_Range__c.Name
	private static Map<string, VehicleVariant__c>		mapVariant;		// vehMakeCode + vehModelCode + vehVariantCode => VehicleVariant__c.Make__c.Name + VehicleVariant__c.Model__c.Name + VehicleVariant__c.Name
	private static Map<string, Vehicle_Colour__c>		mapColour;		// vehColorCode => Vehicle_Colour__c.Name
	private static Map<string, Vehicle_Trim__c>			mapTrim;		// vehTrimCode => Vehicle_Trim__c.Name
	private static Map<string, Vehicle_Type__c>			mapType;		// vehType => Vehicle_Type__c.AutolineTypeCode__c
	private static Map<long, Vehicle__c>				mapVehByNo;		// vehNo => Vehicle__c.Vehicle_Number__c
	private static Map<string, Vehicle__c>				mapVehByVin;	// chassis => Vehicle__c.Name

	private static long[] vehNos;
	private static CareVehicleRes[] respVeh;

	/** Email Diagnostic */
	private static SQL_API_Base.API_DEBUG api;
	private static string[] errEmail = new List<string>();

	public string[] company = SQL_API_Base.COMPANY_CODE;
	public DateTime dateFrom;
	public DateTime dateTo;
	public long[] vehNo;
	public string[] chassisNo;
	public string[] regNo;
	public long lastId = 0;
	public long rowCount = 500;
	public final Integer minRowCount = 10;
	public Boolean followOnToVO = false;
	public SQL_API_Base.RowTracking rt = new SQL_API_Base.RowTracking();

	public SQL_Veh_Queue() { this.dateFrom = SQL_API_Base.getRunTime(JOB_NAME); }

	public void execute(QueueableContext context) {
		try {
			System.debug('Job: ' + JOB_NAME + ': ' + JSON.serialize(this));
			AsyncApexJob[] jobs = [
				SELECT Id FROM AsyncApexJob
				WHERE Status IN ('Queued', 'Processing')
					AND JobType = 'Queueable'
					// AND CreatedDate > :SQL_API_Base.RETRY_LIMIT
					AND ApexClass.Name = :JOB_NAME
			];
            if ((lastId == null || lastId == 0) && jobs.size() > 1) { return; }
			// if (lastId != null && jobs.size() > 1) {
			// 	System.debug('Skipping ' + JOB_NAME + ' queue.');
			// 	if (this.followOnToVO) {
			// 		SQL_VO_Queue q = new SQL_VO_Queue();
			// 		q.dateTo = this.dateTo;
			// 		q.followOnToAppt = true;
			// 		if (!Test.isRunningTest()) { System.enqueueJob(q); }
			// 	}
			// 	return; 
			// }

			respVeh = callCareApi();
			if (respVeh.size() > 0) {
				upsertVehicle(respVeh);
				if (!Test.isRunningTest()) { System.enqueueJob(this); }
			}
			else {
				/** 0 (zero) record, send completion message */
				if (this.dateFrom == null && this.dateTo == null) {
					string subject = Envir.subject + ': Job complete!';
					string body = (JOB_NAME + '\n\n' + JSON.serialize(this) + '\n\nJob completed!').replace('\n', '<br />');
					Util.sendEmail(subject, body);
				}
				if (this.dateTo != null) { SQL_API_Base.updateRun(SQL_API_Base.getRun(JOB_NAME), this.dateTo); }
				if (this.followOnToVO) {
					SQL_VO_Queue q = new SQL_VO_Queue();
					q.company = this.company;
					if (this.dateFrom == null) { q.dateFrom = null; }
					q.dateTo = this.dateTo;
					q.followOnToAppt = true;
					if (!Test.isRunningTest()) { System.enqueueJob(q); }
				}
			}
		}
		catch (CalloutException e) {
			if (minRowCount < rowCount) {
				/** Half rowCount and re-queue job. */
				this.rowCount = Math.max(this.rowCount / 2, this.minRowCount);
				if (!Test.isRunningTest()) { System.enqueueJob(this); }
			}
			else if (minRowCount >= rowCount) {
				/** Probably server offline / error. */
				string header = JOB_NAME;
				string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
				string error = String.format(
					'Query row count: {0} is less than default minimum: {1}.\n\n{2}'
					, new string[] { 
						String.valueOf(rowCount)
						, String.valueOf(minRowCount) 
						, JSON.Serialize(this)
					}
				) + '\n\nAPI:\n' + api?.toString();
				String emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
				errEmail.add(emailBody);
			}
		}
		catch (Exception e) {
			string header = JOB_NAME;
			string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
			string error = JSON.serialize(this) + '\n\nAPI:\n' + api?.toString();
			String emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
			errEmail.add(emailBody);
		}
		finally {
			if (errEmail != null && errEmail.size() > 0) {
				CommonMethodsLibrary.sendErrorEmail(new User[] { SQL_API_Base.USER_CUR }, string.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
			}
		}
	}

	public CareVehicleRes[] callCareApi() {
		Http http = new Http();
		HttpRequest hreq = new HttpRequest();
		hreq.setEndpoint(ENDPOINT);
		hreq.setMethod('POST');
		hreq.setHeader('Content-Type', 'application/json');
		CareVehicleReq req = new CareVehicleReq();
		req.Company = this.company;
		req.UserName = USERNAME;
		req.Password = PASSWORD;
		req.DateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ'); // Timezone adjusted based on calling user profile
		req.DateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');	// Timezone adjusted based on calling user profile
		req.vehNo = this.vehNo;
		req.ChassisNo = this.chassisNo;
		req.RegNo = this.regNo;
		req.LastId = this.lastId;
		req.RowCount = this.rowCount;
		hreq.setBody(JSON.serialize(req, false));
		hreq.setTimeout(120000);

		/** Prep API request for exception email */
		api = new SQL_API_Base.API_DEBUG();
		api.parse(hreq, new string[] { 'Content-Type' });

		CareVehicleRes[] res = new CareVehicleRes[]{};
		HttpResponse hres;
		try {
			hres = http.send(hreq);
			api.parse(hres);
			if (hres.getStatusCode() == 200) {
				res = (CareVehicleRes[]) JSON.deserialize(hres.getBody(), CareVehicleRes[].class);
				api.parse(res);
			}
			else { throw new ExternalObjectException(api?.Response); }
		}
		catch (Exception e) { throw e; }
		finally { System.debug(api?.toString()); }

		return res;
	}

	public void upsertVehicle(CareVehicleRes[] res) {
		/** Initialises mapping */
		initMaps(res);
		/** Initialise dependency objects */
		initVehParts(res);

		Map<Id, Vehicle__c> updateMap = new Map<Id, Vehicle__c>();
		Vehicle__c[] insertList = new List<Vehicle__c>();
		Vehicle__c veh;
		Boolean hasVehNo;
		for (CareVehicleRes obj : res) {
			veh = null;
			hasVehNo = false;
			if (mapVehByNo.containsKey(obj.vehNo)) {
				veh = mapVehByNo.get(obj.vehNo);
				hasVehNo = true;
			}
			else if (mapVehByVin.containsKey(obj.chassis)) {
				veh = mapVehByVin.get(obj.chassis);
			}
			else {
				veh = new Vehicle__c();
			}
			if (veh.Id == null || !updateMap.containsKey(veh.Id) || hasVehNo) {
				setValues(obj, veh);
				if (veh.Id != null) {
					updateMap.put(veh.Id, veh);
					rt.UpdateOne(); // Updated++;
				} else {
					insertList.add(veh);
					rt.AddOne(); // Added++;
				}
			}
		}
		Vehicle__c[] upsertList = updateMap.values();
		upsertList.addAll(insertList);
		if (upsertList.size() > 0) {
			Database.UpsertResult[] urs = Database.upsert(upsertList, false);
			String err = CommonMethodsLibrary.emailResultFailure(
							urs, upsertList, 'upsertVehicle (upsertList)'
							, JOB_NAME, new User[] { SQL_API_Base.USER_CUR }, false);
			if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
		}
		/** Record lastId */
		if (vehNos.size() > 0) {
			vehNos.sort();
			this.lastId = vehNos[vehNos.size() - 1];
		}
	}

	private void initMaps(CareVehicleRes[] res) {
		/** Gather all lookup list */
		Set<string>	setCompany		= new Set<string>();
		Set<string>	setMake			= new Set<string>();
		Set<string>	setRange		= new Set<string>();
		Set<string>	setModel		= new Set<string>();
		Set<string>	setVariant		= new Set<string>();
		Set<string>	setTrim			= new Set<string>();
		Set<string>	setType			= new Set<string>();
		Set<string>	setColour		= new Set<string>();
		Set<long>	setVehicleNo	= new Set<long>();
		Set<string>	setChassisNo	= new Set<string>();
		vehNos = new List<long>();
		for (CareVehicleRes veo : res) {
			// System.debug('vehColorCode: ' + String.isNotBlank(veo.vehColorCode));
			// System.debug('vehColor: ' + String.isNotBlank(veo.vehColor));
			/** Hardcode C => Motorrad (was Motrocycle) */
			if (veo.vehMakeCode.equalsIgnoreCase('C'))	{ veo.vehMake = 'Motorrad'; }
			if (String.isNotBlank(veo.companyCode))		{ setCompany.add(veo.companyCode); }
			if (String.isNotBlank(veo.vehMakeCode))		{ setMake.add(veo.vehMakeCode); }
			if (String.isNotBlank(veo.vehModelRange))	{ setRange.add(veo.vehModelRange); }
			if (String.isNotBlank(veo.vehModelCode))	{ setModel.add(veo.vehModelCode); }
			if (String.isNotBlank(veo.vehVariantCode))	{ setVariant.add(veo.vehVariantCode); }
			if (String.isNotBlank(veo.vehTrimCode))		{ setTrim.add(veo.vehTrimCode); }
			if (String.isNotBlank(veo.vehType))			{ setType.add(veo.vehType); }
			if (String.isNotBlank(veo.vehColorCode))	{ setColour.add(veo.vehColorCode); }
			else if (String.isNotBlank(veo.vehColor))	{ setColour.add(veo.vehColor.trim()); }
			if (veo.vehNo != null)						{ setVehicleNo.add(veo.vehNo); }
			if (String.isNotBlank(veo.chassis))			{ setChassisNo.add(veo.chassis); }
			vehNos.add(veo.vehNo);
		}
		/** companyCode => Company__r.Name */
		mapCompany = new Map<string, Company__c>();
		for (Company__c cmp :[SELECT Id, Name, Description__c FROM Company__c WHERE Name IN :setCompany]) {
			if (!mapCompany.containsKey(cmp.Name)) { mapCompany.put(cmp.Name, cmp); }
		}
		/** companyCode + vehMakeCode => Company__r.Name + Name */
		mapMake = new Map<string, Vehicle_Make__c>();
		for (Vehicle_Make__c vmk :[SELECT Id, Name, Description__c, Company__r.Name, Key__c FROM Vehicle_Make__c WHERE /*Company__r.Name IN :setCompany AND*/ Name IN :setMake]) {
			string key = String.join(new string[] { /*vmk.Company__r.Name,*/ vmk.Name }, '_').toUpperCase();
			if (!mapMake.containsKey(key)) { mapMake.put(key, vmk); }
		}
		/** companyCode + vehMakeCode + vehModelRange => Company__r.Name + Vehicle_Make__r.Name + Name */
		mapModelRange = new Map<string, Vehicle_Model_Range__c>();
		for (Vehicle_Model_Range__c vmr :[SELECT Id, Name, Description__c, Company__r.Name, Vehicle_Make__r.Name, Key__c FROM Vehicle_Model_Range__c WHERE /*Company__r.Name IN :setCompany AND*/ Vehicle_Make__r.Name IN :setMake AND Name IN :setRange]) {
			string key = String.join(new string[] { /*vmr.Company__r.Name,*/ vmr.Vehicle_Make__r.Name, vmr.Name }, '_').toUpperCase();
			if (!mapModelRange.containsKey(key)) { mapModelRange.put(key, vmr); }
		}
		/** companyCode + vehMakeCode + vehModelCode => Company__r.Name + Vehicle_Make__r.Name + Name */
		mapModel = new Map<string, Vehicle_Model__c>();
		for (Vehicle_Model__c vmo :[SELECT Id, Name, Description__c, Manufacturer_Year_From__c, Company__r.Name, Vehicle_Make__r.Name, Vehicle_Type__r.Name, Key__c FROM Vehicle_Model__c WHERE /*Company__r.Name IN :setCompany AND*/ Vehicle_Make__r.Name IN :setMake AND Name IN :setModel]) {
			string key = String.join(new string[] { /*vmo.Company__r.Name,*/ vmo.Vehicle_Make__r.Name, vmo.Name }, '_').toUpperCase();
			if (!mapModel.containsKey(key)) { mapModel.put(key, vmo); }
		}
		/** companyCode + vehMakeCode + vehModelCode + vehVariantCode => Company__r.Name + Make__r.Name + Model__r.Name + Name */
		mapVariant = new Map<string, VehicleVariant__c>();
		for (VehicleVariant__c var :[SELECT Id, Name, Company__r.Name, Make__r.Name, Model__r.Name, Key__c FROM VehicleVariant__c WHERE /*Company__r.Name IN :setCompany AND*/ Make__r.Name IN :setMake AND Model__r.Name IN :setModel AND Name IN :setVariant]) {
			string key = String.join(new string[] { /*var.Company__r.Name,*/ var.Make__r.Name, var.Model__r.Name, var.Name }, '_').toUpperCase();
			if (!mapVariant.containsKey(key)) { mapVariant.put(key, var); }
		}
		/** companyCode + vehType => Company__r.Name + Name */
		mapType = new Map<string, Vehicle_Type__c>();
		for (Vehicle_Type__c vty :[SELECT Id, Name, Company__r.Name, AutolineTypeCode__c, Key__c FROM Vehicle_Type__c WHERE /*Company__r.Name IN :setCompany AND Name */ AutolineTypeCode__c IN :setType]) {
			string key = String.join(new string[] { /*vty.Company__r.Name, vty.Name */ vty.AutolineTypeCode__c }, '_').toUpperCase();
			if (!mapType.containsKey(key)) { mapType.put(key, vty); }
		}
		/** companyCode + vehMakeCode + vehTrimCode => Company__r.Name + Vehicle_Make__r.Name + Name */
		mapTrim = new Map<string, Vehicle_Trim__c>();
		for (Vehicle_Trim__c vtr :[SELECT Id, Name, Company__r.Name, Vehicle_Make__r.Name, Key__c FROM Vehicle_Trim__c WHERE /*Company__r.Name IN :setCompany AND*/ Vehicle_Make__r.Name IN :setMake AND Name IN :setTrim]) {
			string key = String.join(new string[] { /*vtr.Company__r.Name,*/ vtr.Vehicle_Make__r.Name, vtr.Name }, '_').toUpperCase();
			if (!mapTrim.containsKey(key)) { mapTrim.put(key, vtr); }
		}
		/** companyCode + vehMakeCode + vehColourCode => Company__r.Name + Vehicle_Make__r.Name + Name */
		mapColour = new Map<string, Vehicle_Colour__c>();
		for (Vehicle_Colour__c vcl :[SELECT Id, Name, Company__r.Name, Vehicle_Make__r.Name, Key__c FROM Vehicle_Colour__c WHERE /*Company__r.Name IN :setCompany AND*/ Vehicle_Make__r.Name IN :setMake AND Name IN :setColour]) {
			string key = String.join(new string[] { /*vcl.Company__r.Name,*/ vcl.Vehicle_Make__r.Name, vcl.Name }, '_').toUpperCase();
			if (!mapColour.containsKey(key)) { mapColour.put(key, vcl); }
		}
		/** vehNo => Vehicle_Number__c */
		mapVehByNo = new Map<long, Vehicle__c>();
		mapVehByVin = new Map<string, Vehicle__c>();
		for (Vehicle__c veh :[SELECT Id, Name, Vehicle_Number__c FROM Vehicle__c WHERE Vehicle_Number__c IN :setVehicleNo OR Name IN :setChassisNo]) {
			if (!mapVehByNo.containsKey(veh.Vehicle_Number__c.longValue()))	{ mapVehByNo.put(veh.Vehicle_Number__c.longValue(), veh); }
			if (!mapVehByVin.containsKey(veh.Name))							{ mapVehByVin.put(veh.Name, veh); }
		}
		/** Print all maps */
		// System.debug('mapCompany: ' + JSON.serialize(mapCompany));
		// System.debug('mapMake: ' + JSON.serialize(mapMake));
		// System.debug('mapModelRange: ' + JSON.serialize(mapModelRange));
		// System.debug('mapModel: ' + JSON.serialize(mapModel));
		// System.debug('mapVariant: ' + JSON.serialize(mapVariant));
		// System.debug('mapType: ' + JSON.serialize(mapType));
		// System.debug('mapTrim: ' + JSON.serialize(mapTrim));
		// System.debug('mapColour: ' + JSON.serialize(mapColour));
		// System.debug('mapVehByNo: ' + JSON.serialize(mapVehByNo));
		// System.debug('mapVehByVin: ' + JSON.serialize(mapVehByVin));
	}

	public void initVehParts(CareVehicleRes[] res) {
		// Need to insert in order so to reference to each other correctly
		SObject[] tmpso;
		tmpso = genVehParts('Company', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
		tmpso = genVehParts('Make', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
		tmpso = genVehParts('Range', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
		tmpso = genVehParts('Type', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
		tmpso = genVehParts('Model', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
		tmpso = genVehParts('Trim', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
		tmpso = genVehParts('Colour', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
		tmpso = genVehParts('Variant', res);
		if (tmpso != null) { Database.UpsertResult[] ur = Database.upsert(tmpso); }
	}

	public SObject[] genVehParts(String objType, CareVehicleRes[] res) {
		Set<SObject> sObjSet = new Set<SObject>();
		SObject sObj;
		Map<string, SObject> mapRet = new Map<string, SObject>();
		for (CareVehicleRes veo : res) {
			/** Key forming */
			string keyCompany, keyMake, keyModelRange, keyModel, keyType, keyTrim, keyColour, keyVariant;
			if (String.isNotBlank(veo.companyCode)) { keyCompany	= String.join(new string[] { veo.companyCode.toUpperCase() }, '_'); }
			if (String.isNotBlank(veo.vehType))		{ keyType		= String.join(new string[] { veo.vehType }, '_').toUpperCase(); }
			if (String.isNotBlank(veo.vehMakeCode)) {
				keyMake = String.join(new string[] { veo.vehMakeCode }, '_').toUpperCase();
				if (String.isNotBlank(veo.vehModelRange))	{ keyModelRange	= String.join(new string[] { veo.vehMakeCode, veo.vehModelRange }, '_').toUpperCase(); }
				if (String.isNotBlank(veo.vehModelCode))	{
					keyModel = String.join(new string[] { veo.vehMakeCode, veo.vehModelCode }, '_').toUpperCase();
					if (String.isNotBlank(veo.vehVariantCode))
															{ keyVariant	= String.join(new string[] { veo.vehMakeCode, veo.vehModelCode, veo.vehVariantCode }, '_').toUpperCase(); }
				}
				if (String.isNotBlank(veo.vehTrimCode))		{ keyTrim		= String.join(new string[] { veo.vehMakeCode, veo.vehTrimCode }, '_').toUpperCase(); }
				if (String.isNotBlank(veo.vehColorCode))	{ keyColour 	= String.join(new string[] { veo.vehMakeCode, veo.vehColorCode }, '_').toUpperCase(); }
			}

			// System.debug('objType: ' + objType);
			// System.debug('keyCompany: ' + keyCompany);
			// System.debug('keyType: ' + keyType);
			// System.debug('keyMake: ' + keyMake);
			// System.debug('keyModelRange: ' + keyModelRange);
			// System.debug('keyModel: ' + keyModel);
			// System.debug('keyTrim: ' + keyTrim);
			// System.debug('keyColour: ' + keyColour);
			// System.debug('keyVariant: ' + keyVariant);

			if (objType == 'Company') {
				if (String.isNotBlank(keyCompany)) {
					if (mapCompany.containsKey(keyCompany)) { sObj = mapCompany.get(keyCompany); }
					else {
						sObj = new Company__c();
						/** Prevent Description__c (company full name) from being updated. */
						sObj.put('Name', veo.companyCode);
						sObj.put('Description__c', company);
						mapCompany.put(keyCompany, (Company__c) sObj);
					}
					if (!mapRet.containsKey(keyCompany)) { mapRet.put(keyCompany, (Company__c) sObj); }
				}
			}
			else if (objType == 'Make') {
				if (String.isNotBlank(keyMake)) {
					if (mapMake.containsKey(keyMake)) { sObj = mapMake.get(keyMake); }
					else { sObj = new Vehicle_Make__c(); }
					sObj.put('Name', veo.vehMakeCode);
					sObj.put('Description__c', veo.vehMake);
					mapMake.put(keyMake, (Vehicle_Make__c) sObj);
					if (!mapRet.containsKey(keyMake)) { mapRet.put(keyMake, (Vehicle_Make__c) sObj); }
				}
			}
			else if (objType == 'Range') {
				if (String.isNotBlank(keyModelRange)) {
					if (mapModelRange.containsKey(keyModelRange)) { sObj = mapModelRange.get(keyModelRange); }
					else { sObj = new Vehicle_Model_Range__c(); }
					sObj.put('Name', veo.vehModelRange);
					sObj.put('Description__c', veo.vehModelRange);
					sObj.put('Vehicle_Make__c', mapMake.containsKey(keyMake) ? mapMake.get(keyMake).Id : null);
					mapModelRange.put(keyModelRange, (Vehicle_Model_Range__c) sObj);
					if (!mapRet.containsKey(keyModelRange)) { mapRet.put(keyModelRange, (Vehicle_Model_Range__c) sObj); }
				}
			}
			else if (objType == 'Model') {
				if (String.isNotBlank(keyModel)) {
					if (mapModel.containsKey(keyModel)) { sObj = mapModel.get(keyModel); }
					else { sObj = new Vehicle_Model__c(); }
					sObj.put('Name', veo.vehModelCode);
					sObj.put('Description__c', veo.vehModelDesc);
					sObj.put('Manufacturer_Year_From__c', veo.vehModelYear);
					sObj.put('Vehicle_Make__c', mapMake.containsKey(keyMake) ? mapMake.get(keyMake).Id : null);
					sObj.put('Vehicle_Model_Range__c', mapModelRange.containsKey(keyModelRange) ? mapModelRange.get(keyModelRange).Id : null);
					sObj.put('Vehicle_Type__c', mapType.containsKey(keyType) ? mapType.get(keyType).Id : null);
					mapModel.put(keyModel, (Vehicle_Model__c) sObj);
					if (!mapRet.containsKey(keyModel)) { mapRet.put(keyModel, (Vehicle_Model__c) sObj); }
				}
			}
			else if (objType == 'Type') {
				if (String.isNotBlank(keyType)) {
					if (mapType.containsKey(keyType)) { sObj = mapType.get(keyType); }
					else {
						sObj = new Vehicle_Type__c();
						sObj.put('Name', veo.vehType);
						sObj.put('Description__c', veo.vehType);
						sObj.put('AutolineTypeCode__c', veo.vehType);
					}
					mapType.put(keyType, (Vehicle_Type__c) sObj);
					if (!mapRet.containsKey(keyType)) { mapRet.put(keyType, (Vehicle_Type__c) sObj); }
				}
			}
			else if (objType == 'Trim') {
				if (String.isNotBlank(keyTrim)) {
					if (mapTrim.containsKey(keyTrim)) { sObj = mapTrim.get(keyTrim); }
					else { sObj = new Vehicle_Trim__c(); }
					sObj.put('Name', veo.vehTrimCode);
					sObj.put('Description__c', veo.vehTrim);
					sObj.put('Vehicle_Make__c', mapMake.containsKey(keyMake) ? mapMake.get(keyMake).Id : null);
					mapTrim.put(keyTrim, (Vehicle_Trim__c) sObj);
					if (!mapRet.containsKey(keyTrim)) { mapRet.put(keyTrim, (Vehicle_Trim__c) sObj); }
				}
			}
			else if (objType == 'Colour') {
				if (String.isNotBlank(keyColour)) {
					if (mapColour.containsKey(keyColour)) { sObj = mapColour.get(keyColour); }
					else { sObj = new Vehicle_Colour__c(); }
					sObj.put('Name', String.isNotBlank(veo.vehColorCode) ? veo.vehColorCode : veo.vehColor);
					sObj.put('Description__c', veo.vehColor);
					sObj.put('Vehicle_Make__c', mapMake.containsKey(keyMake) ? mapMake.get(keyMake).Id : null);
					mapColour.put(keyColour, (Vehicle_Colour__c) sObj);
					if (!mapRet.containsKey(keyColour)) { mapRet.put(keyColour, (Vehicle_Colour__c) sObj); }
				}
			}
			else if (objType == 'Variant') {
				if (String.isNotBlank(keyVariant)) {
					if (mapVariant.containsKey(keyVariant)) { sObj = mapVariant.get(keyVariant); }
					else { sObj = new VehicleVariant__c(); }
					sObj.put('Name', veo.vehVariantCode);
					sObj.put('Description__c', veo.vehVariantDesc);
					sObj.put('Make__c', mapMake.containsKey(keyMake) ? mapMake.get(keyMake).Id : null);
					sObj.put('Model__c', mapModel.containsKey(keyModel) ? mapModel.get(keyModel).Id : null);
					mapVariant.put(keyVariant, (VehicleVariant__c) sObj);
					if (!mapRet.containsKey(keyVariant)) { mapRet.put(keyVariant, (VehicleVariant__c) sObj); }
				}
			}
			if (objType != 'Company' && sObj != null) {
				sObj.put('Company__c', mapCompany.get(keyCompany).Id);
				sObjSet.add(sObj);
			}
		}
		return new List<SObject>(mapRet.values());
	}

	private void setValues(CareVehicleRes objFr, Vehicle__c objTo) {
		objTo.Name = objFr.chassis;
		objTo.UniqueVehicle__c = objFr.chassis;
		// if (objTo.Id == null) { objTo.CreatedFrom__c = objFr.source; }

		/** Key forming */
		string keyCompany		= objFr.companyCode.toUpperCase();
		string keyMake			= String.join(new string[] { /* objFr.companyCode, */ objFr.vehMakeCode }, '_').toUpperCase();
		string keyModelRange	= String.join(new string[] { /* objFr.companyCode, */ objFr.vehMakeCode, objFr.vehModelRange }, '_').toUpperCase();
		string keyModel			= String.join(new string[] { /* objFr.companyCode, */ objFr.vehMakeCode, objFr.vehModelCode }, '_').toUpperCase();
		string keyType			= String.join(new string[] { /* objFr.companyCode, */ objFr.vehType }, '_').toUpperCase();
		string keyTrim			= String.join(new string[] { /* objFr.companyCode, */ objFr.vehMakeCode, objFr.vehTrimCode }, '_').toUpperCase();
		string keyColour		= String.join(new string[] { /* objFr.companyCode, */ objFr.vehMakeCode, objFr.vehColorCode }, '_').toUpperCase();
		string keyVariant		= String.join(new string[] { /* objFr.companyCode, */ objFr.vehMakeCode, objFr.vehModelCode, objFr.vehVariantCode }, '_').toUpperCase();
		
		/** Populate lookups */
		if (mapCompany.containsKey(keyCompany))	{ objTo.Company__c = mapCompany.get(keyCompany).Id; }
		if (mapMake.containsKey(keyMake))		{ objTo.Vehicle_Make__c = mapMake.get(keyMake).Id; }
		if (mapModel.containsKey(keyModel))		{ objTo.Vehicle_Model__c = mapModel.get(keyModel).Id; }
		// if (mapModelRange.containsKey(keyModelRange))
		// 												{ objTo.Vehicle_Model_Range__c = mapModelRange.get(keyModelRange).Id; }
		if (mapVariant.containsKey(keyVariant))	{ objTo.VehicleVariant__c = mapVariant.get(keyVariant).Id; }
		if (mapColour.containsKey(keyColour))	{ objTo.Vehicle_Colour__c = mapColour.get(keyColour).Id; }
		if (mapTrim.containsKey(keyTrim))		{ objTo.Vehicle_Trim__c = mapTrim.get(keyTrim).Id; }
		if (mapType.containsKey(keyType))		{ objTo.Vehicle_Type__c = mapType.get(keyType).Id; }

		objTo.Engine_Number__c = objFr.engineNum;
		objTo.Vehicle_Number__c = objFr.vehNo;
		objTo.DMS_Number__c = objFr.dmsNo;

		objTo.Production_Date__c = objFr.productionDate?.date();
		objTo.Production_Month__c = objFr.productionMonth;
		objTo.Production_Year__c = objFr.productionYear;

		objTo.Description__c = objFr.description;

		objTo.Registration_Date__c = objFr.regDate?.date();
		objTo.Registration_Number__c = objFr.regNum;
		objTo.Running_Mileage__c = objFr.mileage;
		// objTo.Next_Service_Date__c = objFr.nextServiceDate;
		
		objTo.VSB_Reference__c = objFr.vsbRef;
		objTo.VSB_Reference_Company__c = objFr.vsbRefCmp;
		objTo.SellingDealer__c = objFr.sellingDealer;
		objTo.Warranty_Expiry_Date__c = Util.validDate(objFr.warrantyExDate?.date());
		objTo.Extended_Warranty_Date__c = Util.validDate(objFr.extendedWarrantyDate?.date());
	}

	/** Button: Pull from Care API (Vehicle__c) */
	Webservice static string refreshVeh(Id vehId) {
		try {
			Vehicle__c veh = [SELECT Id, Vehicle_Number__c FROM Vehicle__c WHERE Id = :vehId];
			if (veh?.Vehicle_Number__c == null) { return 'Error: Unable to refresh Vehicle (w/o Vehicle Number).'; }
			SQL_Veh_Queue q = new SQL_Veh_Queue();
			q.dateFrom = q.dateTo = null;
			q.vehNo = new long[] { veh.Vehicle_Number__c?.longValue() };
			q.rowCount = 1;
			CareVehicleRes[] hres = q.callCareApi();
			if (hres == null || hres.size() <= 0) { return 'Error: Unable to find vehicle for refresh.'; }
			q.upsertVehicle(hres);
			return 'Refreshed successfully!';
		}
		catch (QueryException e) { return 'Error: No record found with id: \'' + vehId + '\''; }
		catch (Exception e) { return 'Error: ' + e.getMessage() + (SQL_API_Base.ISSANDBOX ? '\n\n' + e.getStackTraceString() : ''); }
	}

	public class CareVehicleReq extends SQL_API_Base.CareReq {
		public long[] vehNo;
		public string[] ChassisNo;
		public string[] RegNo;
		public long LastId;
	}

	public virtual class CareVehicleRes {
		public string companyCode;
		public string company;
		public string chassis;
		public string engineNum;
		public Decimal engineCap;
		public string source;
		public Long vehNo;
		public string dmsNo;

		public string vehMakeCode;
		public string vehMake;

		public string vehModelCode;
		public string vehModelDesc;
		public Integer vehModelYear;
		public string vehModelRange;

		public string vehVariantCode;
		public string vehVariantDesc;

		public string vehType;

		public string vehColorCode;
		public string vehColor;
		public string vehTrimCode;
		public string vehTrim;

		public Datetime productionDate;
		public string productionMonth;
		public string productionYear;
		public string bodyStyle;
		public string description;
		public Datetime regDate;
		public string regNum;
		public Decimal mileage;
		public Datetime nextServiceDate;
		public string vsbRef;
		public string vsbRefCmp;
		public string sellingDealer;
		public Datetime warrantyExDate;
		public Datetime extendedWarrantyDate;

		// public string keyCompany { get {
		// 	if (String.isNotBlank(companyCode)) { return companyCode; }
		// 	else { return null; }
		// }}
		// public string keyMake { get {
		// 	if (String.isNotBlank(companyCode) && string.isNotBlank(vehMakeCode)) {
		// 		return string.format('{0}_{1}', new string[] { companyCode, vehMakeCode });
		// 	}
		// 	else { return null; }
		// }}
		// public string keyModel { get {
		// 	if (String.isNotBlank(companyCode) && string.isNotBlank(vehMakeCode) && string.isNotBlank(vehModelCode)) {
		// 		return string.format('{0}_{1}_{2}', new string[] { companyCode, vehMakeCode, vehModelCode });
		// 	}
		// 	else { return null; }
		// }}
		// public string keyModelRange { get {
		// 	if (String.isNotBlank(companyCode) && string.isNotBlank(vehMakeCode) && string.isNotBlank(vehModelRange)) {
		// 		return string.format('{0}_{1}_{2}', new string[] { companyCode, vehMakeCode, vehModelRange });
		// 	}
		// 	else { return null; }
		// }}
		// public string keyVariant { get { 
		// 	if (String.isNotBlank(companyCode) && string.isNotBlank(vehMakeCode) && string.isNotBlank(vehModelCode) && string.isNotBlank(vehVariantCode)) {
		// 		return string.format('{0}_{1}_{2}_{3}', new string[] { companyCode, vehMakeCode, vehModelCode, vehVariantCode });
		// 	}
		// 	else { return null; }
		// }}
		// public string keyTrim { get {
		// 	if (String.isNotBlank(companyCode) && string.isNotBlank(vehMakeCode) && string.isNotBlank(vehTrimCode)) {
		// 		return string.format('{0}_{1}_{2}', new string[] { companyCode, vehMakeCode, vehTrimCode });
		// 	}
		// 	else { return null; }
		// }}
		// public string keyType { get {
		// 	if (String.isNotBlank(companyCode) && string.isNotBlank(vehType)) {
		// 		return string.format('{0}_{1}', new string[] { companyCode, vehType });
		// 	}
		// 	else { return null; }
		// }}
		// public string keyColour { get {
		// 	if (String.isNotBlank(companyCode) && string.isNotBlank(vehMakeCode) && string.isNotBlank(vehColorCode)) {
		// 		return string.format('{0}_{1}_{2}', new string[] { companyCode, vehMakeCode, vehColorCode });
		// 	}
		// 	else { return null; }
		// }}
	}
	
}