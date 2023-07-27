public class pr {
    public class PrefException extends System.Exception { }

    /** Cache processed configuration keys. */
    public static Map<string, object> memo = new Map<string, object>();

    /**
     * Access instance-specific configuration.
     *
     * @return              configuration value
     * @param   domain      domain/namespace
     * @param   prefix      overriding key prefix
     * @param   key         configuration key to access
     */
    public static object ef(string domain, string key) { return ef(domain, null, key); }
    public static object ef(string domain, string prefix, string key) {
        string full = string.join(u.filter(new List<string>{ domain, prefix, key }), ':');
        string defo = string.join(u.filter(new List<string>{ domain, key }), ':');
        string part = string.join(u.filter(new List<string>{ prefix, key }), ':');

        if (memo.containsKey(full)) { return memo.get(full); }
        object val = z.pref.get(full);

////////// account /////////////////////////////////////////////////////////////

        if (domain == 'account') {
            if (key == 'type') {
                Map<string, string> arg = (Map<string, string>) val;
                Map<string, RecordType> ret = new Map<string, RecordType>();

                for (RecordType type :
                    [select Id, IsPersonType from RecordType
                        where SobjectType = 'Account' and (IsPersonType = true or Name = 'Business Account')])
                {
                    if (type.IsPersonType) { ret.put('person', type); }
                    else { ret.put('business', type); }
                }

                memo.put(full, ret);
                return ret;
            }
        }

////////// case ////////////////////////////////////////////////////////////////

        if (domain == 'case')
        {
            if (part == 'fields') {
                List<string> ret = new List<string>();

                Map<String, Schema.SObjectField> temp = schema.SObjectType.Case.fields.getMap();
                for(Schema.SObjectField s : temp.values()) { ret.add(s.getDescribe().getName()); }

                memo.put(full, ret);
                return ret;
            }
            else if (key == 'type') {
                Map<string, string> arg = (Map<string, string>) val;
                Map<string, RecordType> ret = new Map<string, RecordType>();

                Map<string, SObject> types = u.key('name', [select Id, Name from RecordType where SObjectType = 'Case' and Name in :arg.values()]);
                for (string fn : arg.keyset()) {
                    RecordType t = (RecordType) types.get(arg.get(fn));
                    if (t == null) { throw new PrefException(full + '.' + fn + ': Record Type does not exist.'); }
                    ret.put(fn, t);
                }

                memo.put(full, ret);
                return ret;
            }
            else if (key == 'owner') {
                List<string> arg = (List<string>) val;
                SObject ret;

                try {
                    if (arg[0] == 'queue') { ret = [select Id from Group where Type = 'Queue' and DeveloperName = :arg[1]]; }
                    else if (arg[0] == 'user') { ret = [select Id from User where Username = :arg[1]]; }
                } catch (Exception e) { throw new PrefException(full + ': ' + arg[0] + ' object could not be found.'); }

                memo.put(full, ret.Id);
                return ret.Id;
            }
            else if (key == 'managing_director') {
                string arg = (string) val;
                User ret = u.usrn(arg);
                if (ret == null) { throw new PrefException(full + ': Username does not exist.'); }

                memo.put(full, ret);
                return ret;
            }
            else if (key == 'creator_role') {
                string arg = (string) val;
                CaseTeamRole ret;

                try { ret = [select Id from CaseTeamRole where Name = :arg]; }
                catch (Exception e) { throw new PrefException(full + ': Case Team Role cannot be found.'); }

                memo.put(full, ret.Id);
                return ret.Id;
            }

            // assignment

            else if (part == 'teams') {
                Map<string, CaseTeamTemplate> ret = new Map<string, CaseTeamTemplate>();

                for (CaseTeamTemplate ct : [select Id, Name from CaseTeamTemplate]) { ret.put(ct.Name, ct); }

                memo.put(full, ret);
                return ret;
            }
            else if (part == 'members') {
                Map<Id, List<Id>> ret = new Map<Id, List<Id>>();

                for (CaseTeamTemplateMember m : [select MemberId, TeamTemplateId from CaseTeamTemplateMember]) {
                    if (!ret.containsKey(m.TeamTemplateId)) { ret.put(m.TeamTemplateId, new List<Id>()); }
                    ret.get(m.TeamTemplateId).add(m.MemberId);
                }

                memo.put(full, ret);
                return ret;
            }

            // staging

            else if (key == 'hours') {
                string arg = (string) val;
                BusinessHours ret;

                try {
                    if (arg != null) { ret = [select Id from BusinessHours where IsActive = true and Name = :arg]; }
                    else { ret = [select Id from BusinessHours where IsDefault = true]; }
                } catch (Exception e) { throw new PrefException(full + ': Business Hours does not exist.'); }

                memo.put(full, ret.Id);
                return ret.Id;
            }
            else if (key == 'template') {
                if (val == null) { throw new PrefException(full + ': Email Template mapping cannot be null.'); }
                Map<string, string> arg = (Map<string, string>) val;
                Map<string, EmailTemplate> ret = new Map<string, EmailTemplate>();

                Map<string, SObject> tpl = u.key('name', [select Id, Name, Subject, TemplateType, Body, HtmlValue from EmailTemplate where Name in :arg.values()]);
                for (string fn : arg.keyset()) {
                    EmailTemplate t = (EmailTemplate) tpl.get(arg.get(fn));
                    if (t == null) { throw new PrefException(full + '.' + fn + ': Email Template does not exist.'); }
                    ret.put(fn, t);
                }

                memo.put(full, ret);
                return ret;
            }
            else if (key == 'timing') {
                List<double> arg = (List<double>) val;
                List<long> ret = new List<long>();

                for (double i : arg) { ret.add((i * 60 * 60 * 1000).longValue() + 1); }

                memo.put(full, ret);
                return ret;
            }
        }

        if (!z.pref.containsKey(full)) {
            if (full != defo) { return ef(domain, null, key); }
            throw new PrefException(full + ': Key does not exist in z.pref.');
        }
        return val;
    }
    @isTest static void efTest() {
        boolean except;
        try { except = false; ef(null, null, 'foo'); } catch (Exception e) { except = true; }
        system.assert(except);
        z.pref.put('foo', 'bar');
        system.assertEquals(ef(null, null, 'foo'), 'bar');
    }
}