public class CaseStage
{
	/** Provide shorthand for CaseCommon.pref. */
	public static object pref(Case c, string key) { return CaseCommon.pref(c, key); }

	/** Check if case is valid for escalation. */
	public static boolean valid(Case c) {
		if(!c.Draft_Mode__c){
			if(c.Type == CaseCommon.TYPE_COMPLAINT || c.Type == CaseCommon.TYPE_GENERAL_ENQUIRY || c.Type == CaseCommon.TYPE_GENERAL_FEEDBACK){
				return true;
			}
		}
		return false;
	}

	/** Clamp BusinessHours.add to [open, close). */
	public static datetime add(object bh, datetime dt, long plus) { return add((Id) bh, dt, plus); }
	public static datetime add(Id bh, datetime dt, long plus) {
		datetime done = BusinessHours.add(bh, dt, plus);
		if (!u.hrs(bh, done)) {
			// do this to push it to the next opening time
			// (WARNING: will turn seconds to zero regardless of original value)
			done = BusinessHours.add(bh, BusinessHours.add(bh, done, 1), -1);
		}
		return done;
	}

	/** Clamp stage numbers within valid numbers. */
	public static integer clamp(Case c, integer st) {
		List<string> stages = (List<string>) CaseCommon.pref(c, 'stages');
		if (st < 0) { return 0; }
		if (st >= stages.size()) { return stages.size() - 1; }
		return st;
	}

	/** Calculate the initial escalation stage. */
	public static integer initial(Case c) {
		/*
        if(!Util.newEscalationRulesActive()){
		
            if      (c.Priority == 'critical')     { return 2; }
            else if (c.Priority == 'high')         { return 2; }
            else if (c.Priority == 'medium')       { return 1; }
            else if (c.Priority == 'low')          { return 0; }
            else if (c.Priority == 'keep in view') { return 0; }
            else if (c.Priority == 'n/a')          { return 0; }
            throw new CaseCommon.CaseException('CaseStage.initial: Cannot find initial stage for ' + c.CaseNumber + '.');
        }
        else{
			
		Map<String,Integer> priority2CaseStage = CaseStageMdt.getInitialStageMap();
		Integer initialStage = priority2CaseStage.get(c.Priority);
		if(initialStage == null){
			String message = 'CaseStage.initial: Cannot find initial stage for ';
			message += c.CaseNumber;
			message += ' with Priority: ';
			message += c.Priority;
			throw new CaseCommon.CaseException(message);
		}
		return initialStage;
		*/
		return 1;
	}

	/** Calculate the current escalation stage. */
	public static integer current(Case c, datetime now) {
		Integer maxCaseStage;
		Integer minCaseStage;
		Map<Integer,Integer> stage2Time = CaseStageMdt.getStageTimeMap(c.Priority);
		Map<Integer,Integer> stage2CumulativeTime = new Map<Integer, Integer>();
		Long caseAgeMs = CaseCommon.getCaseAge(c, now);

		for(Integer stage:stage2Time.keySet()){
			if(maxCaseStage == null || maxCaseStage<stage){
				maxCaseStage = stage;
			}

			if(minCaseStage == null || minCaseStage>stage){
				minCaseStage = stage;
			}
		}

		Integer currentStage = maxCaseStage;
		for(Integer stage =minCaseStage; stage<= maxCaseStage; stage++){
			if(stage == minCaseStage){
				stage2CumulativeTime.put(stage,stage2Time.get(stage));
			}
			else {
				stage2CumulativeTime.put(stage,stage2Time.get(stage)+stage2CumulativeTime.get(stage-1));
			}
		}
		for(Integer stage =maxCaseStage; stage>= minCaseStage; stage--){
			if(caseAgeMS<=stage2CumulativeTime.get(stage)){
				currentStage = stage;
			}
			else{
				break;
			}
		}
		return currentStage;
		/*
        integer p = initial(c);
		long age = BusinessHours.diff((Id) u.def(c.BusinessHoursId, pref(c, 'hours')), (datetime) u.def(c.CreatedDate, now), now);

		List<long> timing = (List<long>) pref(c, 'timing');
		while (p == clamp(c, p) && age >= timing[clamp(c, p)]) { age -= timing[clamp(c, p++)]; }
		return clamp(c, p);
		*/
	}

	/** Calculate the time to escalate the case next. */
	public static datetime next(Case c, datetime now) {
		Integer currentStage = Integer.valueOf(c.EscalationStage__c);
		Integer maxCaseStage;
		Integer minCaseStage;
		Map<Integer,Integer> stage2Time = CaseStageMdt.getStageTimeMap(c.Priority);
		Map<Integer,Integer> stage2CumulativeTime = new Map<Integer, Integer>();
		Map<Integer,DateTime> stage2NextEscalationDate = new Map<Integer, DateTime>();
		
		for(Integer stage:stage2Time.keySet()){
			if(maxCaseStage == null || maxCaseStage<stage){
				maxCaseStage = stage;
			}

			if(minCaseStage == null || minCaseStage>stage){
				minCaseStage = stage;
			}

		}
		if(currentStage== maxCaseStage){
			return null;
		}
		else{
			for(Integer stage =minCaseStage; stage<= maxCaseStage; stage++){
				if(stage == minCaseStage){
					stage2CumulativeTime.put(stage,stage2Time.get(stage));
				}
				else {
					stage2CumulativeTime.put(stage,stage2Time.get(stage)+stage2CumulativeTime.get(stage-1));
				}
			}

			Id businessHoursId = c.BusinessHoursId;
			if(businessHoursId == null){
				businessHoursId = CaseCommon.getDefaultBusinessHours();
			}
			for(Integer stage =minCaseStage; stage<= maxCaseStage; stage++){
				Datetime createdDate = c.CreatedDate;
				if(createdDate == null){
					createdDate = now;
				}

				stage2NextEscalationDate.put(stage,BusinessHours.addGmt(businessHoursId,createdDate,stage2CumulativeTime.get(stage)));
			}
			return stage2NextEscalationDate.get(currentStage);
		}
		/*
		integer p = initial(c);
		datetime fire = (datetime) u.def(c.CreatedDate, now);

		List<long> timing = (List<long>) pref(c, 'timing');
		while (fire <= now && p <= (decimal) u.def(c.EscalationStage__c, decimal.valueOf(p)))
		{ fire = add((Id) u.def(c.BusinessHoursId, pref(c, 'hours')), fire, timing[clamp(c, p++)]); }
		return fire;
		*/
	}

	public static String getCaseStageName(Case cs){
		Integer stage = Integer.valueOf(cs.EscalationStage__c);
		if(stage != 0){
			String stageName = '(Stage '+cs.EscalationStage__c+')';
			return stageName;
		}
		return '(Monitor)';

	}
}