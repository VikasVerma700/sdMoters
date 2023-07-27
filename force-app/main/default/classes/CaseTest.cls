@isTest public class CaseTest {

////// setup ///////////////////////////////////////////////////////////////////
	@TestSetup
	static void makeData() {
		TestFactory.genTriggerSettings('Case', true);
		Company__c C028 = new Company__c(Name = '028');
        insert C028;
	}

	public static Case createValid() {
		Case c = new Case();
		c.Customer_Name_Manual__c = 'John Smith';
		return c;
	}

////// workflow ////////////////////////////////////////////////////////////////

	static testMethod void TriggerBasic() {
		Case c;
		boolean except;

		// make sure required fields are filled in
		c = new Case();
		try { except = false; insert c; } catch (Exception e) { except = true; }
		system.assert(except);

		c = createValid();
		insert c;

		// update //////////////////////////////////////////////////////////////

		Id owner = [select OwnerId from Case where Id = :c.Id].OwnerId;
		c.Status = 'Escalated';
		c.OwnerId = u.usr().Id;
		try { except = false; update c; } catch (Exception e) { except = true; }
		system.assert(except);
		c.OwnerId = owner;

		CaseComment cc = new CaseComment();
		cc.ParentId = c.Id;
		cc.CommentBody = 'Comment';
		insert cc;

		c.Status = 'Closed';
		update c;
	}

	static testMethod void TriggerDraft() {
		Case c;
		boolean except;

		c = createValid();
		c.Draft_Mode__c = true;

		c.Priority = 'High';
		try { except = false; insert c; } catch (Exception e) { except = true; }
		system.assert(except);

		c.Priority = 'Low';
		insert c;

		c.Draft_Mode__c = false;
		update c;
	}

	static testMethod void TriggerStopEscalation() {
		User u = [SELECT Id,Is_CFM_Owner__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
		u.Is_CFM_Owner__c = true;
		update u;
		System.runAs(u){
			Case c;
			boolean except;
	
			c = createValid();
			insert c;
	
			c.Stop_Escalation__c = true;
			try { except = false; update c; } catch (Exception e) { except = true; }
			system.assert(except);
	
			c.Stop_Escalation_Remarks__c = 'stop';
			c.Stop_Escalation_Till_Date__c = Date.today() - 1;
			try { except = false; update c; } catch (Exception e) { except = true; }
			system.assert(except);
	
			c.Stop_Escalation_Till_Date__c += 2;
			update c;
			c = [select Stop_Escalation__c, Stop_Escalation_Count__c from Case where Id = :c.Id];
			system.assertEquals(c.Stop_Escalation_Count__c, 1);
		}

	}
}