@isTest
public with sharing class CaseStageTest {
    /*
    @isTest
    static void testInitial(){
        Util.newEscalationRulesActiveTest = true;
        System.assertEquals(CaseStage.initial(new Case(Priority=CaseCommon.PRIORITY_CRITICAL)), 0);
		System.assertEquals(CaseStage.initial(new Case(Priority=CaseCommon.PRIORITY_HIGH)), 0);
		System.assertEquals(CaseStage.initial(new Case(Priority=CaseCommon.PRIORITY_MEDIUM)), 0);
		System.assertEquals(CaseStage.initial(new Case(Priority=CaseCommon.PRIORITY_LOW)), 0);
		System.assertEquals(CaseStage.initial(new Case(Priority=CaseCommon.PRIORITY_KEEP_IN_VIEW)), 0);
		System.assertEquals(CaseStage.initial(new Case(Priority=CaseCommon.PRIORITY_NA)), 0);
        try{
            System.assertEquals(CaseStage.initial(new Case(Priority='Invalid')), 0);
            System.assert(false);
        }
        catch(CaseCommon.CaseException initialStageException){
            	String message = 'CaseStage.initial: Cannot find initial stage for ';
				message += null;
				message += ' with Priority: ';
				message += 'Invalid';
            System.assertEquals(message,initialStageException.getMessage());
        }
    }

    @isTest
    static void testCurrent(){
        Util.newEscalationRulesActiveTest = true;
        Case c = new Case(Priority=CaseCommon.PRIORITY_CRITICAL);
        insert c;
        Test.setCreatedDate(c.Id,DateTime.now().addDays(-1));
        c = [
            SELECT Id,CreatedDate,Priority,BusinessHoursId
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(0,CaseStage.initial(c));
        System.assertEquals(1,CaseStage.current(c,DateTime.now()));
    }


    @isTest
    static void testNext(){
        Util.newEscalationRulesActiveTest = true;
        Case c = new Case(Priority=CaseCommon.PRIORITY_CRITICAL);
        insert c;
        DateTime now = DateTime.now();
        Test.setCreatedDate(c.Id,now.addDays(-1));
        c = [
            SELECT Id,CreatedDate,Priority,BusinessHoursId
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(now.addDays(2).day(),CaseStage.next(c,now).day());
    }

/* test cases below will be verifying same procedures but
with label NewEscalationRulesEffective off */
/*
    @isTest
    static void testInitialOld(){
        Util.newEscalationRulesActiveTest = false;
        System.assertEquals(CaseStage.initial(new Case(Priority=CaseCommon.PRIORITY_CRITICAL)), 2);
		System.assertEquals(CaseStage.initial(new Case(Priority=CaseCommon.PRIORITY_HIGH)), 2);
		System.assertEquals(CaseStage.initial(new Case(Priority=CaseCommon.PRIORITY_MEDIUM)), 1);
		System.assertEquals(CaseStage.initial(new Case(Priority=CaseCommon.PRIORITY_LOW)), 0);
		System.assertEquals(CaseStage.initial(new Case(Priority=CaseCommon.PRIORITY_KEEP_IN_VIEW)), 0);
		System.assertEquals(CaseStage.initial(new Case(Priority=CaseCommon.PRIORITY_NA)), 0);

		boolean except;
		try {
            System.assertEquals(CaseStage.initial(new Case(Priority='foo')), 0);
            System.assert(false);
        }
        catch (Exception e) {
            System.assert(true);
        }
    }

    @isTest
    static void testCurrentOld() {
        Util.newEscalationRulesActiveTest = false;
		List<string> stages = (List<string>) CaseStage.pref(null, 'stages');
		List<long> timing = (List<long>) CaseStage.pref(null, 'timing');

		string js = '{"attributes":{"type":"Case","url":"/services/data/v25.0/sobjects/Case/500E0000002nH2fIAE"},"Id":"500E0000002nH2fIAE","CreatedDate": "2012-10-04T12:54:26.000+0000","Priority":"Keep in View"}';
		Case c = (Case) JSON.deserialize(js, Case.class);
		datetime now = c.CreatedDate, next = now;
		for (integer i=CaseStage.initial(c); i<=stages.size(); ++i) {
			System.assertEquals(CaseStage.current(c, next), CaseStage.clamp(c, i));
			next = CaseStage.add(CaseStage.pref(c, 'hours'), next, timing[CaseStage.clamp(c, i)]);
		}
	}

    @isTest
    static void testNextOld() {
        Util.newEscalationRulesActiveTest = false;
		List<string> stages = (List<string>) CaseStage.pref(null, 'stages');
		List<long> timing = (List<long>) CaseStage.pref(null, 'timing');

		string js = '{"attributes":{"type":"Case","url":"/services/data/v25.0/sobjects/Case/500E0000002nH2fIAE"},"Id":"500E0000002nH2fIAE","CreatedDate": "2012-10-04T12:54:26.000+0000","Priority":"Keep in View"}';
		Case c = (Case) JSON.deserialize(js, Case.class);
		datetime now = c.CreatedDate, next = now;
		for (integer i=CaseStage.initial(c); i<=stages.size(); ++i) {
			next = CaseStage.add((Id) CaseStage.pref(c, 'hours'), next, timing[CaseStage.clamp(c, i)]);
			System.assertEquals(CaseStage.next(c, now), next);
			now = next;
		}
	}

    @isTest static void clampTest() {
        Util.newEscalationRulesActiveTest = false;
		List<string> stages = (List<string>) CaseStage.pref(null, 'stages');
		System.assertEquals(CaseStage.clamp(null, -3000), 0);
		System.assertEquals(CaseStage.clamp(null, -1), 0);
		System.assertEquals(CaseStage.clamp(null, 0), 0);
		System.assertEquals(CaseStage.clamp(null, stages.size()-1), stages.size()-1);
		System.assertEquals(CaseStage.clamp(null, stages.size()), stages.size()-1);
		System.assertEquals(CaseStage.clamp(null, 3000), stages.size()-1);
	}
    */

}