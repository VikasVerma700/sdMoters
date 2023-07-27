global without sharing class CustAppLocation {
	global class LocationCls {
		public String unitNumber;
		public String blockNumber;
		public String address;
		public Decimal latitude;
		public Decimal longitude;
		global LocationCls(String unitNumber, String blockNumber, String address, Decimal latitude, Decimal longitude) {
			this.unitNumber = unitNumber;
			this.blockNumber = blockNumber;
			this.address = address;
			this.latitude = latitude;
			this.longitude = longitude;
		}
	}

	global class BranchCls {
		public String name;
		public String uuid;
	}
}