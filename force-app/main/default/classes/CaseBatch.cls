public with sharing class CaseBatch implements Database.Batchable<SObject> {

	DateTime now;
	String query;
	BatchType type;
	//Date + time when queued + interval after which the job is to be executed
	public String batchJobName;

    CaseMail mailHelper;
    Boolean scheduleNext;
	public static Boolean withinBusinessRange = false;
	public static String JOB_NAME{
		get{
			return 'CaseBatch';
		}
		private set;
	}
	

	public CaseBatch( BatchType type, DateTime now){
		this(type,now,false);
	}

    public CaseBatch(BatchType type, Datetime now, Boolean scheduleNext){
        this.type = type;
		this.now = now;
        this.scheduleNext = scheduleNext;

		this.batchJobName = JOB_NAME+' | '+this.type.name()+' | '+String.valueOf(this.now);
		if(type == BatchType.TYPE_A){
			this.query = 'SELECT '+ CaseCommon.getAllFields();
			this.query += ',(SELECT '+CaseTeamMemberHelper.getAllFields();
			this.query += ' FROM TeamMembers)';
			this.query += ' FROM Case';
			this.query += ' WHERE IsClosed = false AND';
			this.query += ' (Draft_Mode__c = true OR Hold_Notification_Email__c = true)';
		}

		if(type == BatchType.TYPE_B){
			this.query = 'SELECT '+ CaseCommon.getAllFields();
			this.query += ' FROM Case';
			this.query += ' WHERE IsClosed = false AND Stop_Escalation__c = true';
			this.query += ' AND Stop_Escalation_Till_Date__c <= :nowDate';
		}

		if(type == BatchType.TYPE_C){
			this.query = 'SELECT '+ CaseCommon.getAllFields();
			this.query += ',(SELECT '+CaseTeamMemberHelper.getAllFields();
			this.query += ' FROM TeamMembers)';
			this.query += ' FROM Case';
			this.query += ' WHERE IsClosed = false AND';
			this.query += ' To_Escalate__c = true AND NextEscalation__c <= :nowDateTime';
		}

        
    }

	public Database.QueryLocator start(Database.BatchableContext bc){
		Date nowDate = this.now.date();
		DateTime nowDateTime = this.now;

		return Database.getQueryLocator(this.query);
    }

    public void execute(Database.BatchableContext bc, List<Case> batchedCaseList){

		List<Case> caseList = new List<Case>();
		for(Case cs: batchedCaseList){
			if(BusinessHours.isWithin(cs.BusinessHoursId,now) || withinBusinessRange){
				caseList.add(cs);
				CaseTeamMemberHelper.add(cs.TeamMembers);
			}
		}

		this.mailHelper = new CaseMail();
		if(this.type == BatchType.TYPE_A){
			for (Case cs : caseList){
				// notify CFM of draft cases after 4 hours
				if(cs.Draft_Mode__c && (BusinessHours.isWithin(cs.BusinessHoursId, now.addHours(4)) || withinBusinessRange)){
					Messaging.SingleEmailMessage emailMessage = CaseMail.prepareCaseMail(cs,CaseActionMdt.CaseAction.draft,null);
					if(emailMessage != null){
						this.mailHelper.addEmailMessage(emailMessage);
					}
				}

				// notify CFM of high/critical case notification emails held after 4 hours
				else if (cs.Hold_Notification_Email__c && (this.now >= BusinessHours.add(cs.BusinessHoursId, cs.Draft_Mode_Unchecked_Date__c, 4L * 60 * 60 * 1000) || withinBusinessRange)){
					Messaging.SingleEmailMessage emailMessage = CaseMail.prepareCaseMail(cs,CaseActionMdt.CaseAction.hold,null);
					if(emailMessage != null){
						this.mailHelper.addEmailMessage(emailMessage);
					}
				}
			}

			this.mailHelper.sendEmail();
		}

		else if(this.type == BatchType.TYPE_B){
			
			List<Case> expiredCaseList = new List<Case>();
			for (Case cs : caseList){
				cs.Stop_Escalation__c = false;
				expiredCaseList.add(cs);
			}

			if(!expiredCaseList.isEmpty()){
				update expiredCaseList;
			}
		}

		else if(this.type == BatchType.TYPE_C){
			List<Case> dueCaseList = new List<Case>();
			List<Id> dueCaseIdList = new List<Id>();
			for (Case cs : caseList){
				Integer currentStage = CaseStage.current(cs, now);
				if (cs.EscalationStage__c < currentStage){
					System.debug(cs.CaseNumber);
					cs.IsEscalated = true;
					cs.EscalationStage__c = currentStage;
					cs.NextEscalation__c = CaseStage.next(cs, this.now);
					dueCaseList.add(cs);
					dueCaseIdList.add(cs.Id);
				}
			}
			update dueCaseList;
			/*
			Map<Id,Set<Id>> caseId2CommenterIdSet = new Map<Id,Set<Id>>();
			List<CaseComment> commentList = [
				SELECT Id,ParentId, CreatedById
				FROM CaseComment
				WHERE ParentId IN :dueCaseIdList
			];

			for (CaseComment comment : commentList) {
				Set<Id> commenterIdSet = caseId2CommenterIdSet.get(comment.ParentId);
				if(commenterIdSet == null){
					commenterIdSet = new Set<Id>();
				}
				commenterIdSet.add(comment.CreatedById);
				caseId2CommenterIdSet.put(comment.ParentId,commenterIdSet);
			}

			String query = 'SELECT '+ CaseCommon.getAllFields();
			query += ' FROM Case';
			query += ' WHERE Id IN :dueCaseIdList';
			dueCaseList= Database.query(query);

			for (Case cs : dueCaseList) {
				if (cs.EscalationStage__c >=4){
					User mdUser = CaseCommon.getManagingDirector();
					Set<Id> commenterIdSet = caseId2CommenterIdSet.get(cs.Id);
					if(commenterIdSet == null || !commenterIdSet.contains(mdUser.Id)){
						Messaging.SingleEmailMessage emailMessage = CaseMail.prepareCaseMail(cs,CaseActionMdt.CaseAction.no_md_comment,null);
						if(emailMessage != null){
							this.mailHelper.addEmailMessage(emailMessage);
						}
					}
				}
			}
			*/
			this.mailHelper.sendEmail();
		}
    }

    public void finish(Database.BatchableContext bc){
        if(this.scheduleNext){
			Integer scheduleInterval = nextDelay.get(this.type);
			DateTime nextScheduleTime = this.now;

			if(scheduleInterval != 0){
				Integer minuteLag = Math.mod(Datetime.now().minuteGmt(),scheduleInterval);
				scheduleInterval = scheduleInterval - minuteLag;
				nextScheduleTime = DateTime.now().addMinutes(scheduleInterval);
			}
    
            if(nextScheduleTime.day() == this.now.day()){
                CaseBatch nextJob = new CaseBatch(nextType.get(this.type), nextScheduleTime, true);
                String nextJobId = System.scheduleBatch(nextJob, nextJob.batchJobName, scheduleInterval,10);
                String message = 'JobId : '+nextJobId +' scheduled';
                message += '\n JobName : '+nextJob.batchJobName;
                ApplicationLogUtility.insertApexCompletionLog('CaseBatch',message,'CaseBatch -> finish', ApplicationLogUtility.PRIORITY_LOW, true);
            }
        }
    }

    Map<BatchType,BatchType> nextType = new Map<BatchType,BatchType>{
        BatchType.TYPE_A => BatchType.TYPE_B,
        BatchType.TYPE_B => BatchType.TYPE_C,
        BatchType.TYPE_C => BatchType.TYPE_A
    };

    Map<BatchType,Integer> nextDelay = new Map<BatchType,Integer>{
        BatchType.TYPE_A => 0,
        BatchType.TYPE_B => 0,
        BatchType.TYPE_C => 30
    };

	public enum BatchType{
		TYPE_A,
		TYPE_B,
		TYPE_C
	}
}