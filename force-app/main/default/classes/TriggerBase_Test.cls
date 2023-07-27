@IsTest
public class TriggerBase_Test {

    private static testMethod void testUser() {
        Company__c pml = TestFactory.getCompany('028');
        Test.startTest();
        TriggerBase b = new TriggerBase('test');
        b.beforeInsert(new List<SObject>());
        b.beforeUpdate(new Map<Id, SObject>(), new Map<Id, SObject>());
        b.beforeDelete(new Map<Id, SObject>(), new Map<Id, SObject>());
        b.afterInsert(new Map<Id, SObject>());
        b.afterUpdate(new Map<Id, SObject>(), new Map<Id, SObject>());
        b.afterDelete(new Map<Id, SObject>());
        b.afterUndelete(new Map<Id, SObject>());
        System.assertEquals(b.getTriggerName(), 'test');
        System.assertEquals(TriggerBase.CMP_MAP.size(), 1);
        System.assertEquals(TriggerBase.CMP_MAP.get('028').Id, pml.Id);
        System.assertEquals(TriggerBase.CUR_USER.Id, UserInfo.getUserId());
        System.assertEquals(TriggerBase.ERR_USER.size(), 1);
    }
}