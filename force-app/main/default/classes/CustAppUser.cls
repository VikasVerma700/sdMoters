global without sharing class CustAppUser {
	public final static List<String> USER_FIELDS = new List<String> { 'MobilePhone', 'Name', 'Email' };
	public final static List<String> EMPMASTER_FIELDS = new List<String> { 'Name', 'Mobile_Number__c', 'Email__c' };
	global class UserCls {
		public String name;
		public String email;
		public CustAppAccount.PhoneCls phone;
		global UserCls() {}
		global UserCls(Employee_Master__c emp) {
			this.name = emp.Name;
			this.phone = new CustAppAccount.PhoneCls(emp.Mobile_Number__c);
			this.email = emp.Email__c;
		}

		global UserCls(User usr) {
			this.name = usr.Name;
			String userPhone = usr.MobilePhone;
			userPhone = (String.isBlank(userPhone)) ? '' : userPhone.removeStart('+60').trim();
			this.phone = new CustAppAccount.PhoneCls(userPhone);
			this.email = usr.Email;
		}
	}
}