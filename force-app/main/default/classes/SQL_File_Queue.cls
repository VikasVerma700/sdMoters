public class SQL_File_Queue implements Queueable, Database.AllowsCallouts, Database.Batchable<SObject> {
    private static final string USERNAME = SQL_API_Base.USERNAME;
    private static final string PASSWORD = SQL_API_Base.PASSWORD;
    private static final string ENDPOINT_LIST = SQL_API_Base.ENDPOINT + 'v1/ro/doclist';
    private static final string ENDPOINT_FILE = SQL_API_Base.ENDPOINT + 'v1/ro/doc';
    private static final string AUTH_HEADER = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(USERNAME + ':' + PASSWORD));
    private static final string JOB_NAME = SQL_API_Base.QUEUE_FILE;

	/** Mapping object */
	private static Map<string, ServiceInvoice__c> mapSvcInv;
	private static Map<string, Attachment> mapAttachments;

	private static string[] guidKeys;
	private static FileListObj[] respFile;

	/** Email Diagnostic */
	private static SQL_API_Base.API_DEBUG api;
	private static string[] errEmail = new List<string>();

    /** Apex Job: PULL file list */
	public string company = '028';
	public string wipKey;
	public string branchCode;
	public string docType;
	public string regNo;
	public string chassisNo;
    public DateTime dateFrom;
	public DateTime dateTo;
	public Boolean sendCompletionEmail = false;
	public string lastKey = null;
	public long rowCount = 25;
	public final Integer minRowCount = 10;
	public Boolean followOnToBatch = false;
	public boolean followOnToPayment = false;
	public SQL_API_Base.RowTracking rt = new SQL_API_Base.RowTracking();

    /** Apex Job: PULL file list */
    public SQL_File_Queue() { this.dateFrom = SQL_API_Base.getRunTime(JOB_NAME); }

    public void execute(QueueableContext context) {
        try {
			System.debug('Job: ' + JOB_NAME + ' (PULL list): ' + JSON.serialize(this));

            AsyncApexJob[] jobs = [
				SELECT Id FROM AsyncApexJob
				WHERE Status IN ('Queued', 'Processing')
					AND JobType = 'Queueable'
					// AND CreatedDate > :SQL_API_Base.RETRY_LIMIT
					AND ApexClass.Name = :JOB_NAME
			];
			if (lastKey != null && jobs.size() > 1) {
				System.debug('Skipping ' + JOB_NAME + ' queue.');
				if (this.followOnToPayment) {
					SQL_Payment_Queue p = new SQL_Payment_Queue();
					p.dateFrom = (this.dateFrom == null ? null : p.dateFrom); // indicative if full pull is requested.
					p.dateTo = this.dateTo;
					p.followOnToBatch = true;
					p.followOnToNext = true;
                    if (!Test.isRunningTest()) { System.enqueueJob(p); }
				}
				if (this.followOnToBatch) {
					/** Skip batch job when it still processing. */
					System.debug(JOB_NAME + ': Preparing SQL_File_Queue to pick-up 0-length file.');
					jobs = [
						SELECT Id, ApexClass.Name, JobType, Status, CreatedDate
						FROM AsyncApexJob
						WHERE Status IN ('Queued', 'Processing')
							AND JobType IN ('BatchApex', 'BatchApexWorker')
							AND ApexClass.Name = :JOB_NAME
					];
					if (jobs != null && jobs.size() > 0) {
						System.debug('Skipping ' + JOB_NAME + ' batch.');
						return;
					}
					/**
					 * SQL_File_Queue batch job to pull Payments for Service Invoice where:
					 * - BodyLength = 0
					 * - Name LIKE 'Service Invoice%'
					 * - Parent.Type = 'ServiceInvoice__c'
					 */
					/** Execute Batch Job to pull all Service Invoice with 0 byte (MAX scope = 10). */
					SQL_File_Queue q = new SQL_File_Queue(/*setAttId*/);
					q.sendCompletionEmail = this.sendCompletionEmail;
					if (!Test.isRunningTest()) { Database.executeBatch(q, 10); }
				}
				return;
			}

            respFile = callFileListApi();
            if (respFile.size() > 0) {
				setAttId = upsertFileList(respFile);
				if (setAttId != null && setAttId.size() > 0) {
					/** Execute Batch Job to pull each Invoice file individually (MAX scope = 10). */
					SQL_File_Queue q = new SQL_File_Queue(setAttId);
					q.sendCompletionEmail = false;
					if (!Test.isRunningTest()) { Database.executeBatch(q, 10); }
				}
				if (!Test.isRunningTest()) { System.enqueueJob(this); }
			}
			else {
				/** 0 (zero) record, send completion message */
				if (this.dateFrom == null && this.dateTo == null && sendCompletionEmail) {
					string body = (JOB_NAME + '\n\n' + JSON.serialize(this) + '\n\nJob completed!').replace('\n', '<br />');
					Util.sendEmail(Envir.subject + ': Job complete!', body);
				}
				if (this.dateTo != null) { SQL_API_Base.updateRun(JOB_NAME, this.dateTo); }
				if (this.followOnToPayment) {
					SQL_Payment_Queue p = new SQL_Payment_Queue();
					p.dateTo = this.dateTo;
					p.followOnToBatch = true;
					p.followOnToNext = true;
                    if (!Test.isRunningTest()) { System.enqueueJob(p); }
				}
				if (this.followOnToBatch) {
					/** Skip batch job when it still processing. */
					System.debug(JOB_NAME + ': Preparing SQL_File_Queue to pick-up 0-length file.');
					jobs = [
						SELECT Id, ApexClass.Name, JobType, Status, CreatedDate
						FROM AsyncApexJob
						WHERE Status IN ('Queued', 'Processing')
							AND JobType IN ('BatchApex', 'BatchApexWorker')
							AND ApexClass.Name = :JOB_NAME
					];
					if (jobs != null && jobs.size() > 0) { return; }
					/**
					 * SQL_File_Queue batch job to pull Payments for Service Invoice where:
					 * - BodyLength = 0
					 * - Name LIKE 'Service Invoice%'
					 * - Parent.Type = 'ServiceInvoice__c'
					 */
					/** Execute Batch Job to pull all Service Invoice with 0 byte (MAX scope = 10). */
					SQL_File_Queue q = new SQL_File_Queue(/*setAttId*/);
					q.sendCompletionEmail = this.sendCompletionEmail;
					if (!Test.isRunningTest()) { Database.executeBatch(q, 10); }
				}
			}
        }
        catch (CalloutException e) {
			/** Offline or timed out. */
			if (minRowCount < rowCount) {
				/** Half rowCount and re-queue job. */
				this.rowCount = Math.max(this.rowCount / 2, this.minRowCount);
				if (!Test.isRunningTest()) { System.enqueueJob(this); }
			}
			else if (minRowCount >= rowCount) {
				/** Probably server offline / error. */
				string header = JOB_NAME + '_LIST';
				string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
				string error = String.format(
					'Query row count: {0} is less than default minimum: {1}.\n\n{2}'
					, new string[] { 
						String.valueOf(rowCount)
						, String.valueOf(minRowCount) 
						, JSON.Serialize(this)
					}
				) + '\n\nAPI:\n' + api.toString();
				String emailBody = CommonMethodsLibrary.constructErrEmail(JOB_NAME, e.getMessage() + '\n\n' + e.getStackTraceString(), error);
				errEmail.add(emailBody);
			}
        }
        catch (Exception e) {
			string header = JOB_NAME + '_LIST';
			string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
			string error = JSON.serialize(this) + '\n\nAPI:\n' + api.toString();
			String emailBody = CommonMethodsLibrary.constructErrEmail(JOB_NAME, e.getMessage() + '\n\n' + e.getStackTraceString(), error);
			errEmail.add(emailBody);
        }
		finally {
			if (errEmail != null && errEmail.size() > 0) {
				CommonMethodsLibrary.sendErrorEmail(new User[] { SQL_API_Base.USER_CUR }, String.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
			}
		}
    }

    public FileListObj[] callFileListApi() {
        Http http = new Http();
		HttpRequest hreq = new HttpRequest();
		hreq.setEndpoint(ENDPOINT_LIST);
		hreq.setMethod('POST');
		hreq.setHeader('Content-Type', 'application/json');
        hreq.setHeader('Authorization', AUTH_HEADER);
		// FileListReq req = new FileListReq();
		FileListReq req = new FileListReq();
		req.Company = this.company;
		req.WipKey = this.wipKey;
		req.BranchCode = this.branchCode;
		req.DocType = (String.isBlank(this.docType) ? req.DocType : this.docType);
		req.RegNo = this.regNo;
		req.ChassisNo = this.chassisNo;
		/** Pull document aged 10 mins ago because of Service Invoice record delay */
		// req.DateFrom = (fromDT == null ? fromDT : fromDT.addHours(SQL_API_Base.TIME_ZONE).addMinutes(-10));
		// req.DateTo = (toDT == null ? toDT : toDT.addHours(SQL_API_Base.TIME_ZONE));
		req.DateFrom = this.dateFrom?.addMinutes(-10).format('yyyy-MM-dd HH:mm:ss.SSS ZZ'); // Timezone adjusted based on calling user profile
		req.DateTo = this.dateTo?.format('yyyy-MM-dd HH:mm:ss.SSS ZZ');	// Timezone adjusted based on calling user profile
		req.LastKey = this.lastKey;
		req.RowCount = this.rowCount;
		hreq.setBody(JSON.serialize(req, false));
		hreq.setTimeout(120000);
		
		/** Prep API request for exception email */
		api = new SQL_API_Base.API_DEBUG();
		api.parse(hreq, new string[] { 'Content-Type', 'Authorization' });

		FileListObj[] res = new List<FileListObj>();
		HttpResponse hres;
		try {
			hres = http.send(hreq);
			api.parse(hres);
			if (hres.getStatusCode() == 200) {
				res = (FileListObj[]) JSON.deserialize(hres.getBody(), FileListObj[].class);
				api.parse(res);
			}
			else { throw new ExternalObjectException(api?.Response); }
		}
		catch (Exception e) { throw e; }
		finally { System.debug(api?.toString()); }

		return res;
    }

	private void initMaps(FileListObj[] files) {
		Set<string> ro = new Set<string>(); // Repair Order		: WipKey + BranchCode
		Set<string> iv = new Set<string>(); // Service Invoice	: DocNo + BranchCode
		Set<string> fn = new Set<string>(); // Filename			: DocName + RegNo + #DocNo + BranchCode
		guidKeys = new List<string>();
		for (FileListObj file :files) {
			if (String.isNotBlank(file.keyRo)) { ro.add(file.keyRo); }
			if (String.isNotBlank(file.keyInv)) { iv.add(file.keyInv); }
			if (String.isNotBlank(file.filename)) { fn.add(file.filename); }
			if (String.isNotBlank(file.UID)) { guidKeys.add(file.UID); }
		}
		Set<Id> setInvoices = new Set<Id>();
		mapSvcInv = new Map<string, ServiceInvoice__c>();
		ServiceInvoice__c[] sis = [SELECT Id, ExternalId__c, RoKey__c, InvoiceKey__c FROM ServiceInvoice__c WHERE RoKey__c IN :ro AND InvoiceKey__c IN :iv];
		for (ServiceInvoice__c si :sis) {
			setInvoices.add(si.Id);
			mapSvcInv.put(si.InvoiceKey__c, si);
		}
		mapAttachments = new Map<string, Attachment>();
		Attachment[] atts = [SELECT Id, Name, Body, BodyLength, ContentType, Description, ParentId FROM Attachment WHERE ParentId IN :setInvoices AND Name IN :fn];
		for (Attachment att :atts) { mapAttachments.put(att.Name, att); }
	}

    public Set<Id> upsertFileList(FileListObj[] files) {
		/** Initialises mapping */
		initMaps(files);

		for (FileListObj file :files) {
			Attachment att = new Attachment();
			if (mapAttachments.containsKey(file.filename)) {
				/** update existing file. */
				att = mapAttachments.get(file.filename);
				rt.UpdateOne(); // Updated++;
			}
			else {
				if (!mapSvcInv.containsKey(file.keyInv)) {
					/** skip if no matching Service Invoice record. */
					System.debug('Can\'t find papa: ' + JSON.serialize(att));
					continue;
				}
				/** add new file. */
				att.Name = file.filename;
				att.Body = Blob.valueOf('');
				// att.ContentType = contentType; // 'image/png'
				att.ParentId = mapSvcInv.get(file.keyInv).Id;
				mapAttachments.put(file.filename, att);
				rt.AddOne(); // Added++;
			}
			/** Map fields to FileListBase class struct */
			FileListBase fileDesc = (FileListBase)JSON.deserialize(JSON.serialize(file), FileListBase.class);
			att.Description = JSON.serialize(fileDesc);
			// rt.Total++;
		}
		Set<Id> attIdset = new Set<Id>();
		if (mapAttachments.size() > 0) {
			Database.UpsertResult[] urs = Database.upsert(mapAttachments.values(), Attachment.Id, true);
			String err = CommonMethodsLibrary.emailResultFailure(
							urs, mapAttachments.values(), 'upsertFileList(FileListObj[])'
							, JOB_NAME, new User[] { SQL_API_Base.USER_CUR }, false);
			if (!String.isBlank(err) && err != 'No Error') { errEmail.add(err); }
			// System.debug('UpsertResult: ' + JSON.serialize(urs));
			/** Prepare Attachment.Id list for Batchable call to pull binary from Care API */
			for (Database.UpsertResult ur :urs) {
				if (ur.success) { attIdset.add(ur.id); }
			}
		}
		/** Record lastKey */
		if (guidKeys.size() > 0) {
			guidKeys.sort();
			this.lastKey = guidKeys[guidKeys.size() - 1];
		}
		return attIdset;
    }


    public class FileListReq {
        public string Company;
        public string WipKey;
        public string BranchCode;
        public string DocType = 'SERVICEINVOICE';
		public string RegNo;
		public string ChassisNo;
        public string DateFrom;
        public string DateTo;
        public string LastKey;
        public long RowCount;
    }

    public class FileListObj extends FileListBase {
        public string WIP;
		public string POS;
        public string DocCode;
		public string DocMapName;
        public string DocDescription;
        public Boolean IsRequiredSign;
        public Integer Status;
        public string StatusName;
        public Datetime dtSigned;
        public string InvoiceNumber;
        public string PrintedBy;
        public string AssignedTo;
        public Datetime dtCreated;
    }

	public virtual class FileListBase {
		public string UID;
		public string WipKey;
        public string RegNo;
        public string BranchCode;
		public string DocNo;
        public string DocName;
        public string ChassisNumber;
		public DateTime dtUpdated;
		public string filename { get { 
			// if (String.isBlank(this.DocName)) { throw new System.StringException('(filename) Required string DocName is empty.'); }
			// if (String.isBlank(this.RegNo)) { throw new System.StringException('(filename) Required string RegNo is empty.'); }
			// if (String.isBlank(this.DocNo)) { throw new System.StringException('(filename) Required string DocNo is empty.'); }
			// if (String.isBlank(this.BranchCode)) { throw new System.StringException('(filename) Required string BranchCode is empty.'); }
			return DocName + ' ' + RegNo + ' #' + DocNo + BranchCode; 
		}}
		// public string filename2 { get { return filename + ' ' + UID; }}
		public string keyRo { get {
			// if (String.isBlank(this.WipKey)) { throw new System.StringException('(keyRo) Required string WipKey is empty.'); }
			// if (String.isBlank(this.BranchCode)) { throw new System.StringException('(keyRo) Required string BranchCode is empty.'); }
			return WipKey + BranchCode;
		}}
		public string keyInv { get { 
			// if (String.isBlank(this.DocNo)) { throw new System.StringException('(keyInv) Required string DocNo is empty.'); }
			// if (String.isBlank(this.BranchCode)) { throw new System.StringException('(keyInv) Required string BranchCode is empty.'); }
			return DocNo.leftPad(8, '0') + BranchCode; 
		}}
	}

	/** Batchable: PULL - scope: 10 (callout limitation per batch) */
	public Set<string> setFilenames;
	public Set<Id> setAttId;
	// private EmailFileData[] emailFds = new EmailFileData[]{};

    public SQL_File_Queue(Set<Id> attachmentIds) {
		this.setAttId = attachmentIds;
    }
	public Database.QueryLocator start(Database.BatchableContext BC) {
		System.debug('Batch: SQL_File_Queue.start()');
		String query = Database.getQueryLocator([
			SELECT Id, Name, Body, BodyLength, ContentType, Description, ParentId
			FROM Attachment
			WHERE (Name LIKE 'Service Invoice%' AND BodyLength = 0)
			LIMIT 1
		]).getQuery().replace('LIMIT 1', ' ');
		if (setFilenames != null && !setFilenames.isEmpty()) {
			query += 'OR (Name IN :setFilenames) ';
		}
		if (setAttId != null && !setAttId.isEmpty()) {
			query += 'OR (Id IN :setAttId) ';
		}

		System.debug(query);
		return Database.getQueryLocator(query);
	}
	public void execute(Database.BatchableContext BC, List<SObject> scope) {
		System.debug('Job: ' + JOB_NAME + ' (PULL file): ' + JSON.serialize(this));

		try {
			if (scope.size() > 0) {
				api = new SQL_API_Base.API_DEBUG();
				for (SObject s :scope) {
					Attachment att = (Attachment)s;
					if (String.isNotBlank(att.Description)) {
						try {
							FileListBase fileDesc = (FileListBase)JSON.deserialize(att.Description, FileListBase.class);
							System.debug('Desc: ' + JSON.serialize(fileDesc));
							FileData fileInv = callFileByGuidApi(fileDesc.UID);
							// System.debug('fileInv: ' + JSON.serialize(fileInv));
							if (fileInv != null && (fileInv.Base64Content != null || fileInv.data.Base64Content != null)) {
								string b64 = (fileInv.Base64Content != null ? fileInv.Base64Content : fileInv.data.Base64Content);
								att.Body = EncodingUtil.base64Decode(b64);
								att.ContentType = 'application/pdf'; // assume it's PDF file.
								rt.UpdateOne();
							}
							else { rt.SkipOne(); }
						}
						catch (CalloutException e) {
							// TODO: manage binary pull failure. Where to keep the list?
							string header = JOB_NAME + '_FILE';
							string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
							string error = JSON.serialize(this) + '\n\nAPI:\n' + api.toString();
							String emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
							errEmail.add(emailBody);
						}
						catch (Exception e) {
							string header = JOB_NAME + '_FILE';
							string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
							string error = JSON.serialize(this) + '\n\nAPI:\n' + api.toString();
							String emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
							errEmail.add(emailBody);
						}
					}
				}
				/** Update attachment list. */
				Database.SaveResult[] srs = Database.update(scope, false);
			}
		}
		catch (Exception e) {
			// TODO: manage binary pull failure. Where to keep the list?
			string header = JOB_NAME + '_FILE';
			string footer = 'Exception - ' +  e.getTypeName() + ':\n' + e.getMessage() + '\n\nStack Trace:\n' + e.getStackTraceString();
			string error = JSON.serialize(this) + '\n\nAPI:\n' + api.toString();
			String emailBody = CommonMethodsLibrary.constructErrEmail(header, footer, error);
			errEmail.add(emailBody);
		}
	}
	public void finish(Database.BatchableContext BC) {
		if (errEmail != null && errEmail.size() > 0) {
			CommonMethodsLibrary.sendErrorEmail(new User[] { SQL_API_Base.USER_CUR }, String.join(errEmail, '<br/>'), true, Envir.subject + ': Job error!');
		}
		if (sendCompletionEmail) {
			string subject = Envir.subject + ': Job complete!';
			string body = (JOB_NAME + '_FILE' + '\n\n' + JSON.serialize(this) + '\n\nJob completed!').replace('\n', '<br />');
			Util.sendEmail(subject, body);
		}
		if (followOnToPayment) {
			/** Skip batch job when it still processing. */
			System.debug(JOB_NAME + ': Preparing SQL_File_Queue to pick-up 0-length file.');
			AsyncApexJob[] jobs = [
				SELECT Id, ApexClass.Name, JobType, Status, CreatedDate
				FROM AsyncApexJob
				WHERE Status IN ('Queued', 'Processing')
					AND JobType IN ('BatchApex', 'BatchApexWorker')
					AND ApexClass.Name = :JOB_NAME
			];
			if (jobs != null && jobs.size() > 0) { return; }
			
			SQL_Payment_Queue q = new SQL_Payment_Queue();
			q.sendCompletionEmail = this.sendCompletionEmail;
			Database.executeBatch(q, 200);
		}
	}

	public FileData callFileByGuidApi(string guid) {
		Http http = new Http();
		HttpRequest hreq = new HttpRequest();
		hreq.setEndpoint(ENDPOINT_FILE);
		hreq.setMethod('POST');
		hreq.setHeader('Content-Type', 'application/json');
        hreq.setHeader('Authorization', AUTH_HEADER);
		FileReq req = new FileReq();
		req.Guid = guid;
		hreq.setBody(JSON.serialize(req, false));
		hreq.setTimeout(120000);
		
		/** Prep API_REQUEST for exception email */
		api = new SQL_API_Base.API_DEBUG();
		api.parse(hreq, new string[] { 'Content-Type', 'Authorization' });

		FileData res;
		HttpResponse hres;
		try {
			hres = http.send(hreq);
			//api.parse(hres);
			if (hres.getStatusCode() == 200) {
				res = (FileData) JSON.deserialize(hres.getBody(), FileData.class);
			}
			else { throw new ExternalObjectException(api?.Response); }
		}
		catch (Exception e) { throw e; }
		finally { System.debug(api?.toString()); }
		
		return res;
	}
	public class FileReq {
        public string Guid;
    }
	public virtual class FileData extends FileBase {
		public FileBase data;
	}
	public virtual class FileBase {
		public Long WipKey;
		public Integer Wip;
		public string RegNo;
		public string ChassisNo;
		public Document Document;
		public string Base64Content;
	}
	public class Document extends DocumentBase {
		public Integer DocTypeUid;
		public Integer DocStatusUid;
		public Integer DocStatusValue;
		public string DocStatusName;
		public WriteAreaBase[] WriteAreas;
	}
	public virtual class DocumentBase {
		public string Guid;
		public string DocType;
		public DateTime DocDate;
      	public Time DocTime;
      	public string FTPPath;
      	public string Filename;
	}
	public virtual class WriteAreaBase {
		public string Guid;
		public Integer PageId;
		public Integer AreaUid;
		public string AreaType;
		public Boolean IsSigned;
		public string SignedBy;
		public DateTime SignedDate;
		public string Label;
		public Boolean Show;
	}

	/** temp */
	// public virtual class EmailFileData {
	// 	public Long WipKey;
	// 	public Integer Wip;
	// 	public string RegNo;
	// 	public string ChassisNo;
	// 	public Document Document;
	// }
}