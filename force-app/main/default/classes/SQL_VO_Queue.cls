global class SQL_VO_Queue implements Database.AllowsCallouts, Queueable {
	private static final String USERNAME = SQL_API_Base.USERNAME;
	private static final String PASSWORD = SQL_API_Base.PASSWORD;
	private static final String ENDPOINT = SQL_API_Base.ENDPOINT + 'v3/vo/list';
	private static final string JOB_NAME = SQL_API_Base.QUEUE_VOWN;
	private static final string CREATEDFROM = 'Autoline';

	/** Mapping objects */
	/** Key 1: Care DB AccountVehicles.Id / vehOwnId => vo.VehicleOwnershipNumber__c */
	private static Map<Long, Vehicle_Ownership__c>		mapVoByNo;
	/** Key 2: Care DB Vehicles.Id + AccountVehicles.RegNum + AccountDetail.Id => vo.Vehicle__r.Vehicle_Number__c + vo.Registration_No__c + vo.Customer__r.Customer_Number__c */
	private static Map<string, Vehicle_Ownership__c>	mapVoByKey2;
	/** Key 3: Care DB AccountVehicles.chassisNo + AccountVehicles.RegNum + AccountDetail.DocumentNo => vo.Chassis_No__c +  + vo.Customer__r.NRIC_Number__c  */
	private static Map<string, Vehicle_Ownership__c>	mapVoByKey3;
	private static Map<Long, Vehicle__c>				mapVehByVno;
	private static Map<string, Vehicle__c> mapVehByVin;
	private static Map<Long, Account> mapAccByCustNo;
	private static Map<string, Account> mapAccByDocNo;
	private static Map<Id, Map<string, Alternative_Driver__c[]>> mapVoAltDrv;

	private static Long[] vehOwnIds;
	private static CareVehOwnRes[] respVehOwn;

	/** Email Diagnostic */
	private static SQL_API_Base.API_DEBUG api;
	private static string[] errEmail = new List<string>();

	public long[] vehOwnId;
	public long[] custNo;
	public string[] docNo;
	public long[] vehNo;
	public string[] chassisNo;
	public string[] regNo;
	public long lastId = 0;
	public string[] company = SQL_API_Base.COMPANY_CODE;
	public DateTime dateFrom;
	public DateTime dateTo;
	public long rowCount = 100;
	public final Integer minRowCount = 10;
	public Boolean followOnToAppt = false;
	public SQL_API_Base.RowTracking rt = new SQL_API_Base.RowTracking();

	public SQL_VO_Queue() { this.dateFrom = SQL_API_Base.getRunTime(JOB_NAME); }

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
			// if (lastId != null && jobs.size() > 1) { return; }

			respVehOwn = callCareApi();

			if (respVehOwn.size() > 0) {
				upsertVO(respVehOwn);
				upsertAltDrv(respVehOwn);
				System.debug('Upsert Total: ' + JSON.serialize(rt));
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
				if (this.followOnToAppt) { 
					SQL_Appt_Queue q = new SQL_Appt_Queue();
					q.company = this.company;
					q.dateFrom = (this.dateFrom == null ? null : q.dateFrom); // indicative if full pull is requested.
					q.dateTo = this.dateTo;
					q.followOnToPull = true;
					/** Use executeBatch for PUSH to Care */
					if (!Test.isRunningTest()) { Database.executeBatch(q, 100); }
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
			System.debug('SQL_VO_Queue why except?: ' + e.getTypeName() + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
			string header = JOB_NAME;
			string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
			string error = JSON.serialize(this) + '\n\nAPI:\n' + api?.toString();
			String emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
			errEmail.add(emailBody);
		}
		finally {
			if (errEmail != null && errEmail.size() > 0) {
				CommonMethodsLibrary.sendErrorEmail(new User[] { SQL_API_Base.USER_CUR }, String.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
			}
		}
	}

	public CareVehOwnRes[] callCareApi() {
		Http http = new Http();
		HttpRequest hreq = new HttpRequest();
		hreq.setEndpoint(ENDPOINT);
		hreq.setMethod('POST');
		hreq.setHeader('Content-Type', 'application/json');
		CareVehOwnReq req = new CareVehOwnReq();
		req.Company = this.company;
		req.UserName = USERNAME;
		req.Password = PASSWORD;
		req.DateFrom = this.dateFrom?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
		req.DateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');
		req.VehOwnId = this.vehOwnId;
		req.CustomerNo = this.custNo;
		req.VehNo = this.vehNo;
		req.ChassisNo = this.chassisNo;
		req.LastId = this.lastId;
		req.RowCount = this.rowCount;
		hreq.setBody(JSON.serialize(req, false));
		hreq.setTimeout(120000);

		/** Prep API request for exception email */
		api = new SQL_API_Base.API_DEBUG();
		api.parse(hreq, new string[] { 'Content-Type' });

		CareVehOwnRes[] ret = new CareVehOwnRes[]{};
		HttpResponse hres;
		try {
			hres = http.send(hreq);
			api.parse(hres);
			if (hres.getStatusCode() == 200) {
				ret = (CareVehOwnRes[]) JSON.deserialize(hres.getBody(), CareVehOwnRes[].class);
				api.parse(ret);
			}
			else { throw new ExternalObjectException(api?.Response); }
		}
		catch (Exception e) { throw e; }
		finally { System.debug(api?.toString()); }

		return ret;
	}

	public void upsertVO(CareVehOwnRes[] voos) {
		SQL_API_Base.RowTracking lt = new SQL_API_Base.RowTracking();
		/** Initialises mapping */
		initMaps(voos);


		Vehicle_Ownership__c[] insertVown = new Vehicle_Ownership__c[]{};
		Map<Id, Vehicle_Ownership__c> updateVown = new Map<Id, Vehicle_Ownership__c>();
		// Match with order priortised
		Vehicle_Ownership__c vo;
		Boolean hasVownNo;

		for (CareVehOwnRes voo : voos) {
			vo = null;
			hasVownNo = false;

			/** Key 1: Care DB AccountVehicles.Id / vehOwnId => vo.VehicleOwnershipNumber__c */
			if (vo == null && voo.vehOwnId != null) {
				Long key1 = voo.vehOwnId;
				if (mapVoByNo.containsKey(key1)) {
					vo = mapVoByNo.get(key1);
					hasVownNo = true;
				}
			}

			/** Key 2: Care DB Vehicles.Id + AccountVehicles.RegNum + AccountDetail.Id => vo.Vehicle__r.Vehicle_Number__c + vo.Registration_No__c + vo.Customer__r.Customer_Number__c */
			if (vo == null && voo.vehNo != null && String.isNotBlank(voo.vehRegNo) && voo.custNo != null) {
				string key2 = String.join(new string[] { String.valueOf(voo.vehNo), voo.vehRegNo, String.valueOf(voo.custNo) }, '_').toUpperCase();
				if (mapVoByKey2.containsKey(key2)) {
					vo = mapVoByKey2.get(key2);
				}
			}

			/** Key 3: Care DB AccountVehicles.chassisNo + AccountVehicles.RegNum + AccountDetail.DocumentNo => vo.Chassis_No__c +  + vo.Customer__r.NRIC_Number__c  */
			if (vo == null && String.isNotBlank(voo.vehChassisNo) && String.isNotBlank(voo.vehRegNo) && String.isNotBlank(voo.custDocNo)) {
				string key3 = String.join(new string[] { voo.vehChassisNo, voo.vehRegNo, String.valueOf(!voo.isBusiness), voo.custDocNo }, '_').toUpperCase();
				if (mapVoByKey3.containsKey(key3)) {
					vo = mapVoByKey3.get(key3);
				}
			}
			
			/** still no match */
			if (vo == null) { vo = new Vehicle_Ownership__c(); }
			setValues(voo, vo);
			if (vo.Id == null) {
				insertVown.add(vo);
				lt.AddOne(); rt.AddOne();
			}
			else {
				if (updateVown.containsKey(vo.Id)) {
					// updateVown.remove(vo.Id);
					updateVown.put(vo.Id, vo);
					lt.MatchOne(); rt.MatchOne();
				}
				else {
					updateVown.put(vo.Id, vo);
					lt.UpdateOne(); rt.UpdateOne();
				}
			}
		}
		Vehicle_Ownership__c[] upsertList = updateVown.values();
		upsertList.addAll(insertVown);
		if (upsertList.size() > 0) {
			if (Test.isRunningTest() || Envir.isSandbox) { System.debug('upsertList: ' + JSON.serialize(upsertList)); }
			Database.UpsertResult[] urs = Database.upsert(upsertList, false);
			if (Test.isRunningTest() || Envir.isSandbox) { System.debug('urs: ' + JSON.serialize(urs)); }
			String err = CommonMethodsLibrary.emailResultFailure(
							urs, upsertList, 'upsertVO (upsertList)'
							, JOB_NAME, SQL_API_Base.USER_ADMINS, false);
			if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
		}
		/** Record lastId */
		if (vehOwnIds.size() > 0) {
			vehOwnIds.sort();
			this.lastId = vehOwnIds[vehOwnIds.size() - 1];
		}
		
		System.debug('Upsert Current: ' + JSON.serialize(lt));
	}

	public void upsertAltDrv(CareVehOwnRes[] voos) {
		/** Re-initialises mapping */
		initMaps(voos);

		Alternative_Driver__c[] altDrvAdd = new List<Alternative_Driver__c>();
		Map<Id, Alternative_Driver__c> altDrvDel = new Map<Id, Alternative_Driver__c>();
		
		// Match with order priortised
		Vehicle_Ownership__c vo;
		Account acc;
		Account drv;
		Map<string, Alternative_Driver__c[]> mapAltDrv;

		for (CareVehOwnRes voo :voos) {
			vo = null;
			acc = null;
			drv = null;
			mapAltDrv = null;

			/** Key 1: Care DB AccountVehicles.Id / vehOwnId => vo.VehicleOwnershipNumber__c */
			if (vo == null && voo.vehOwnId != null) {
				Long key1 = voo.vehOwnId;
				if (mapVoByNo.containsKey(key1)) {
					vo = mapVoByNo.get(key1);
				}
			}

			/** Key 2: Care DB Vehicles.Id + AccountVehicles.RegNum + AccountDetail.Id => vo.Vehicle__r.Vehicle_Number__c + vo.Registration_No__c + vo.Customer__r.Customer_Number__c */
			if (vo == null && voo.vehNo != null && String.isNotBlank(voo.vehRegNo) && voo.custNo != null) {
				string key2 = String.join(new string[] { String.valueOf(voo.vehNo), voo.vehRegNo, String.valueOf(voo.custNo) }, '_').toUpperCase();
				if (mapVoByKey2.containsKey(key2)) {
					vo = mapVoByKey2.get(key2);
				}
			}

			/** Key 3: Care DB AccountVehicles.chassisNo + AccountVehicles.RegNum + AccountDetail.DocumentNo => vo.Chassis_No__c +  + vo.Customer__r.NRIC_Number__c  */
			if (vo == null && String.isNotBlank(voo.vehChassisNo) && String.isNotBlank(voo.vehRegNo) && String.isNotBlank(voo.custDocNo)) {
				string key3 = String.join(new string[] { voo.vehChassisNo, voo.vehRegNo, String.valueOf(!voo.isBusiness), voo.custDocNo }, '_').toUpperCase();
				if (mapVoByKey3.containsKey(key3)) {
					vo = mapVoByKey3.get(key3);
				}
			}

			/** Skip Alt D process if Vehicle_Ownership__c record not found. */
			if (vo == null) { continue; }

			/** Get Account */
			if (acc == null) { acc = mapAccByCustNo.get(voo.custNo); }
			System.debug('mapAccByCustNo: ' + JSON.serialize(mapAccByCustNo));
			System.debug('mapAccByDocNo: ' + JSON.serialize(mapAccByDocNo));
			System.debug('acc by cust no: ' + voo.custNo + ': ' + JSON.serialize(acc));
			if (acc == null) {
				string key = String.join(new string[] { String.valueOf(!voo.isBusiness), voo.custDocNo }, '_').toUpperCase();
				acc = mapAccByDocNo.get(key);
				System.debug('acc by doc no: ' + key + ': ' + JSON.serialize(acc));
			}

			/** Get Driver */
			if (drv == null) { drv = mapAccByCustNo.get(voo.drvNo); }
			System.debug('drv by cust no: ' + voo.drvNo + ': ' + JSON.serialize(drv));
			if (drv == null) {
				string key = String.join(new string[] { String.valueOf(true), voo.drvDocNo }, '_').toUpperCase();
				drv = mapAccByDocNo.get(key);
				System.debug('drv by doc no: ' + key + ': ' + JSON.serialize(drv));
			}
			/** Get Alternate Drivers */
			mapAltDrv = mapVoAltDrv.get(vo.Id);
			/** Alt Drivers from DMS: flag for removal before reactivate, no DML until completed. */
			for (Alternative_Driver__c[] ads :mapAltDrv.values()) {
				for (Alternative_Driver__c ad :ads) {
					if (ad.Created_From__c == voo.source) { ad.Status__c = 'Removed'; }
				}
			}
			/** Only do work if there's Driver assigned */
			if (drv != null) {
				string keyAltD = String.join(new string[] { String.valueOf(vo.Id), String.valueOf(drv.Id) }, '_');
				if (mapAltDrv.containsKey(keyAltD)) {
					Alternative_Driver__c[] altDrvs = mapAltDrv.get(keyAltD);
					for (Alternative_Driver__c ad :altDrvs) {
						ad.Created_From__c = voo.source;
						ad.Status__c = 'Active';
						/** Set to Inactive if VO is Inactive */
						if (vo.Status__c?.equalsIgnoreCase('Inactive')) { ad.Status__c = vo.Status__c; }
					}
					/** Remove duplicate */
					if (altDrvs.size() > 1) {
						for (Integer i = 1; i < altDrvs.size(); i++) {
							Alternative_Driver__c ad = altDrvs[i];
							ad.Status__c = 'Removed';
							/** Remove this when Mobile App comes in */
							altDrvDel.put(ad.Id, ad);
						}
					}
				}
				else {
					if (voo.custNo != voo.drvNo) {
						/** Create new Alt D from Autoline. */
						Alternative_Driver__c ad = new Alternative_Driver__c();
						ad.Vehicle_Ownership__c = vo.Id;
						ad.Account__c = drv.Id;
						ad.Alternative_Driver_Name__c = drv.Name; // drv.DisplayName__c;
						ad.Alternative_Driver_Contact_Number__c = drv.PersonMobilePhone;
						if (ad.Alternative_Driver_Contact_Number__c == null) { ad.Alternative_Driver_Contact_Number__c = UtilPhone.toE164(drv.Mobile_Country_Code_1__pc + drv.Mobile_Preferred__pc); }
						ad.Email_Address__c = drv.Default_Email__c;
						ad.Created_From__c = voo.source;
						if (acc != null && acc.IsPersonAccount) { ad.Relationship_to_Owner__c = 'Relative'; }
						else 									{ ad.Relationship_to_Owner__c = 'Employed'; }
						ad.Status__c = 'Active';
						/** Set to Inactive if VO is Inactive */
						if (vo.Status__c?.equalsIgnoreCase('Inactive')) { ad.Status__c = vo.Status__c; }
						altDrvAdd.add(ad);
					}
				}
			}
		}

		/** Add updated Alt D into list for update */
		for (Alternative_Driver__c[] ads :mapAltDrv.values()) { altDrvAdd.addAll(ads); }

		/** Start DML operations - Delete first */
		if (altDrvDel.size() > 0) {
			if (Test.isRunningTest() || Envir.isSandbox) { System.debug('altDrvDel: ' + JSON.serialize(altDrvDel)); }
			Database.DeleteResult[] drs = Database.delete(altDrvDel.values(), false);
			if (Test.isRunningTest() || Envir.isSandbox) { System.debug('drs: ' + JSON.serialize(drs)); }
			String err = CommonMethodsLibrary.emailResultFailure(
							drs, altDrvDel.values(), 'updateAltDriver (altDrvDel)'
							, JOB_NAME, new User[] { SQL_API_Base.USER_CUR }, false);
			if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
		}
		if (altDrvAdd.size() > 0) {
			if (Test.isRunningTest() || Envir.isSandbox) {
				System.debug('mapAltDrv: ' + JSON.serialize(mapAltDrv));
				System.debug('altDrvAdd: ' + JSON.serialize(altDrvAdd));
			}
			Database.UpsertResult[] urs = Database.upsert(altDrvAdd, false);
			if (Test.isRunningTest() || Envir.isSandbox) { System.debug('urs: ' + JSON.serialize(urs)); }
			String err = CommonMethodsLibrary.emailResultFailure(
							urs, altDrvAdd, 'updateAltDriver (altDrvAdd)'
							, JOB_NAME, new User[] { SQL_API_Base.USER_CUR }, false);
			if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
		}
	}

	private void initMaps(CareVehOwnRes[] voos) {
		/** Gather all lookup list */
		Set<Long>   vono = new Set<Long>();		// AccountVehicles.Id
		Set<Long>   vehn = new Set<Long>();		// Vehicles.Id
		Set<string> vin  = new Set<string>();	// AccountVehicles.ChassisNo
		Set<string> vreg = new Set<string>();	// AccountVehicles.RegNum
		Set<Long>   cusn = new Set<Long>();		// AccountDetails.Id
		Set<string>	cdoc = new Set<string>();	// AccountDetails.DocumentNo
		Set<Long>   drvn = new Set<Long>();		// AccountDetails.Id
		Set<string> ddoc = new Set<string>();	// AccountDetails.DocumentNo
		vehOwnIds = new List<Long>();
		for (CareVehOwnRes voo :voos) {
			if (voo.vehOwnId != null)					{ vono.add(voo.vehOwnId); }
			if (voo.vehNo != null)						{ vehn.add(voo.vehNo); }
			if (String.isNotBlank(voo.vehChassisNo))	{ vin.add(voo.vehChassisNo); }
			if (String.isNotBlank(voo.vehRegNo))		{ vreg.add(voo.vehRegNo); }
			if (voo.custNo != null)						{ cusn.add(voo.custNo); }
			if (String.isNotBlank(voo.custDocNo))		{ cdoc.add(voo.custDocNo); }
			if (voo.drvNo != null)						{ drvn.add(voo.drvNo); }
			if (String.isNotBlank(voo.drvDocNo))		{ ddoc.add(voo.drvDocNo); }
			vehOwnIds.add(voo.vehOwnId);
		}

		Vehicle_Ownership__c[] vos = [
			SELECT
				Id, Name, VehicleOwnershipNumber__c, Status__c
				, Registration_No__c, Chassis_No__c
				, Vehicle__r.Vehicle_Number__c
				, Customer__r.Customer_Number__c, Customer__r.IsPersonAccount
				, Customer__r.NRIC_Number__c, Customer__r.DocumentNumberAlphaN__c
				, CreatedFrom__c, UniqueKey__c
				, (
					SELECT
						Id, Name, Vehicle_Ownership__c, Vehicle_Ownership__r.Name
						, Vehicle_Ownership__r.VehicleOwnershipNumber__c, Account__c
						, Account__r.Name, Account__r.Customer_Number__c, Created_From__c
						// , Type__c
						, Relationship_to_Owner__c, Status__c, UniqueKey__c
					FROM Drivers__r
					ORDER BY CreatedDate
				)
			FROM Vehicle_Ownership__c
			WHERE (VehicleOwnershipNumber__c IN :vono)
			OR (
				Vehicle__r.Vehicle_Number__c IN :vehn
				AND Registration_No__c IN :vreg
				AND Customer__r.Customer_Number__c IN :cusn
			)
			OR (
				Chassis_No__c IN :vin
				AND Registration_No__c IN :vreg
				AND Customer__r.NRIC_Number__c IN :cdoc
			)
		];

		/** Key 1: Care DB AccountVehicles.Id / vehOwnId => vo.VehicleOwnershipNumber__c */
		mapVoByNo = new Map<Long, Vehicle_Ownership__c>();
		/** Key 2: Care DB Vehicles.Id + AccountVehicles.RegNum + AccountDetail.Id => vo.Vehicle__r.Vehicle_Number__c + vo.Registration_No__c + vo.Customer__r.Customer_Number__c */
		mapVoByKey2 = new map<string, Vehicle_Ownership__c>();
		/** Key 3: Care DB AccountVehicles.chassisNo + AccountVehicles.RegNum + AccountDetail.DocumentNo => vo.Chassis_No__c +  + vo.Customer__r.NRIC_Number__c  */
		mapVoByKey3 = new map<string, Vehicle_Ownership__c>();
		/** vehOwnId => Vehicle_Ownership__c.VehicleOwnershipNumber__c + Alternative_Driver__c */
		mapVoAltDrv = new Map<Id, Map<string, Alternative_Driver__c[]>>();
		
		for (Vehicle_Ownership__c vo :vos) {
			/** Key 1: Care DB AccountVehicles.Id / vehOwnId => vo.VehicleOwnershipNumber__c */
			if (vo.VehicleOwnershipNumber__c != null) {
				Long key1 = vo.VehicleOwnershipNumber__c?.longValue();
				mapVoByNo.put(key1, vo);
				/** Get alternate drivers from VO list */
				mapVoAltDrv.put(vo.Id, getAltDriverMap(vo.Drivers__r));
			}
			/** Key 2: Care DB Vehicles.Id + AccountVehicles.RegNum + AccountDetail.Id => vo.Vehicle__r.Vehicle_Number__c + vo.Registration_No__c + vo.Customer__r.Customer_Number__c */
			if (vo.Vehicle__r?.Vehicle_Number__c != null && String.isNotBlank(vo.Registration_No__c) && vo.Customer__r?.Customer_Number__c != null) {
				string key2 = String.join(new string[] { String.valueOf(vo.Vehicle__r.Vehicle_Number__c), vo.Registration_No__c, String.valueOf(vo.Customer__r.Customer_Number__c) }, '_').toUpperCase();
				mapVoByKey2.put(key2, vo);
				/** Get alternate drivers from VO list */
				mapVoAltDrv.put(vo.Id, getAltDriverMap(vo.Drivers__r));
			}
			/** Key 3: Care DB AccountVehicles.chassisNo + AccountVehicles.RegNum + AccountDetail.DocumentNo => vo.Chassis_No__c +  + vo.Customer__r.NRIC_Number__c  */
			if (String.isNotBlank(vo.Chassis_No__c) && String.isNotBlank(vo.Registration_No__c) && String.isNotBlank(vo.Customer__r?.NRIC_Number__c)) {
				string key3 = String.join(new string[] { vo.Chassis_No__c, vo.Registration_No__c, String.valueOf(vo.Customer__r.IsPersonAccount), vo.Customer__r.NRIC_Number__c }, '_').toUpperCase();
				mapVoByKey3.put(key3, vo);
				/** Get alternate drivers from VO list */
				mapVoAltDrv.put(vo.Id, getAltDriverMap(vo.Drivers__r));
			}
		}

		/** vehNo => Vehicle__r.Vehicle_Number__c  */
		mapVehByVno = new Map<Long, Vehicle__c>();
		/** chassisNo => Vehicle__r.Name */
		mapVehByVin = new Map<string, Vehicle__c>();
		Vehicle__c[] vs = [SELECT Id, Name, Vehicle_Number__c, Registration_Number__c FROM Vehicle__c WHERE Name IN :vin OR Vehicle_Number__c IN :vehn];
		for (Vehicle__c v :vs) {
			if (v.Vehicle_Number__c != null)	{ mapVehByVno.put(v.Vehicle_Number__c.longValue(), v); }
			if (String.isNotBlank(v.Name))		{ mapVehByVin.put(v.Name, v); }
		}

		/** custNo / drvNo => Customer__r.Customer_Number__c  */
		mapAccByCustNo = new Map<Long, Account>();
		/** !isBusiness + '_' + custDocNo / drvDocNo => Customer__r.IsPersonAccount + '_' + Customer__r.NRIC_Number__c */
		mapAccByDocNo = new Map<string, Account>();
		Account[] accs = [
			SELECT
				Id, Name, Customer_Number__c, IsPersonAccount , OfficialName__c
				, DisplayName__c , NRIC_Number__c, DocumentNumberAlphaN__c
				, PersonMobilePhone, Default_Email__c
				, Mobile_Country_Code_1__pc, Mobile_Preferred__pc
			FROM Account
			WHERE Customer_Number__c != null
			AND (
				Customer_Number__c IN :cusn
				OR Customer_Number__c IN :drvn
				OR NRIC_Number__c IN :cdoc
				OR NRIC_Number__c IN :ddoc
				OR DocumentNumberAlphaN__c IN :cdoc
				OR DocumentNumberAlphaN__c IN :ddoc
			)
		];
		for (Account acc :accs) {
			if (acc.Customer_Number__c != null)	{ mapAccByCustNo.put(acc.Customer_Number__c.longValue(), acc); }
			if (String.isNotBlank(acc.NRIC_Number__c)) {
				string key = String.join(new string[] { String.valueOf(acc.IsPersonAccount), acc.NRIC_Number__c }, '_').toUpperCase();
				mapAccByDocNo.put(key, acc);
			}
			if (String.isNotBlank(acc.DocumentNumberAlphaN__c)) {
				string key = String.join(new string[] { String.valueOf(acc.IsPersonAccount), acc.DocumentNumberAlphaN__c }, '_').toUpperCase();
				mapAccByDocNo.put(key, acc);
			}
		}
	}

	private Map<string, Alternative_Driver__c[]> getAltDriverMap(Alternative_Driver__c[] altDrivers) {
		Map<string, Alternative_Driver__c[]> mapAltDrv = new Map<string, Alternative_Driver__c[]>();
		for (Alternative_Driver__c ad: altDrivers) {
			string keyAltD = String.join(new string[] { String.valueOf(ad.Vehicle_Ownership__c), String.valueOf(ad.Account__c) }, '_');
			
			if (!mapAltDrv.containsKey(keyAltD)) { mapAltDrv.put(keyAltD, new List<Alternative_Driver__c>{ ad }); }
			else {
				Alternative_Driver__c[] altDrvs = mapAltDrv.get(keyAltD);
				altDrvs.add(ad);
			}
		}
		return mapAltDrv;
	}

	public void setValues(CareVehOwnRes objFr, Vehicle_Ownership__c objTo) {
		// if (objTo.Id == null) { objTo.CreatedFrom__c = DMS_NAME; }
		if (String.isBlank(objTo.CreatedFrom__c)) { objTo.CreatedFrom__c = objFr.source; }
		/** Key 1: AccountVehicles.vehOwnId => Vehicle_Ownership__c.VehicleOwnershipNumber__c */
		objTo.VehicleOwnershipNumber__c = objFr.vehOwnId;
		/** Key 2: AccountVehicles.vehNo + AccountVehicles.vehRegNo + AccountVehicles.custNo => Vehicle_Ownership__c.Vehicle__r.Vehicle_Number__c + Vehicle_Ownership__c.RegistrationNumber__c + Vehicle_Ownership__c.Customer__r.Customer_Number__c */
		objTo.Vehicle__c = mapVehByVno.get(objFr.vehNo)?.Id;
		if (objTo.Vehicle__c == null) { objTo.Vehicle__c = mapVehByVin.get(objFr.vehChassisNo)?.Id; }
		objTo.Customer__c = mapAccByCustNo.get(objFr.custNo)?.Id;
		if (objTo.Customer__c == null) {
			System.debug(objFr.isBusiness);
			System.debug(objFr.custDocNo);
			string key = String.join(new string[] { String.valueOf(!objFr?.isBusiness), objFr?.custDocNo }, '_').toUpperCase();
			objTo.Customer__c = mapAccByDocNo.get(key)?.Id;
		}
		objTo.Registration_No__c = objFr.vehRegNo;
		if (String.isBlank(objTo.Registration_No__c)) {
			objTo.Registration_No__c = mapVehByVno.get(objFr.vehNo)?.Registration_Number__c;
		}
		if (String.isBlank(objTo.Registration_No__c)) {
			objTo.Registration_No__c = mapVehByVin.get(objFr.vehChassisNo)?.Registration_Number__c;
		}
		objTo.Start_Date__c = Util.validDate(objFr?.voStartDate?.date());
		objTo.End_Date__c = Util.validDate(objFr?.voEndDate?.date());
	}

	/** Button: Pull from Care API (Vehicle_Ownership__c) */
	Webservice static String refreshVO(Id vehOwnId) {
		try {
			Vehicle_Ownership__c vo = [SELECT Id, VehicleOwnershipNumber__c, Vehicle__r.Name FROM Vehicle_Ownership__c WHERE Id = :vehOwnId];
			if (vo?.VehicleOwnershipNumber__c == null) { return 'Error: Unable to refresh VO (w/o Vehicle Ownership Number).'; }
			SQL_VO_Queue q = new SQL_VO_Queue();
			q.dateFrom = q.dateTo = null;
			q.vehOwnId = new long[] { vo.VehicleOwnershipNumber__c.longValue() };
			CareVehOwnRes[] hres = q.callCareApi();
			if (hres == null || hres.size() <= 0) { return 'Error: Unable to find VO for refresh.'; }
			q.upsertVO(hres);
			q.upsertAltDrv(hres);
			return 'Refreshed successfully!';
		}
		catch (QueryException e) { return 'Error: No record found with id: \'' + vehOwnId + '\''; }
		catch (Exception e) { return 'Error: ' + e.getMessage() + (SQL_API_Base.isSandbox ? '\n\n' + e.getStackTraceString() : ''); }
	}

	/** Button: Pull from Care API (Vehicle__c) */
	Webservice static String refreshVoByVin(String vin) {
		try {
			if (String.isBlank(vin)) { return 'Error: Unable to refresh VO with blank VIN.'; }
			SQL_VO_Queue q = new SQL_VO_Queue();
			q.dateFrom = q.dateTo = null;
			q.chassisNo = new string[] { vin };
			SQL_VO_Queue.CareVehOwnRes[] hres = q.callCareApi();
			if (hres == null || hres.size() <= 0) { return 'Error: Unable to find VO for VIN: \'' + vin + '\'.'; }
			q.upsertVO(hres);
			q.upsertAltDrv(hres);
			return 'Refreshed successfully!';
		}
		catch (Exception e) { return 'Error: ' + e.getMessage() + (SQL_API_Base.isSandbox ? '\n\n' + e.getStackTraceString() : ''); }
	}

	public class CareVehOwnReq extends SQL_API_Base.CareReq {
		public long[] VehOwnId;
		public long[] CustomerNo;
		public long[] DocumentNo;
		public long[] VehNo;
		public string[] ChassisNo;
		public string[] RegistrationNo;
		public long LastId;
		public long RowCount;
	}

	public virtual class CareVehOwnRes {
		public string companyCode;
		public string source;
		public Long vehOwnId;
		public Long vehNo;
		public string vehChassisNo;
		public string vehRegNo;
		public Boolean isBusiness;
		public Long custNo;
		public string custDocNo;
		public Long drvNo;
		public string drvDocNo;
		public DateTime voStartDate;
		public DateTime voEndDate;
	}

}