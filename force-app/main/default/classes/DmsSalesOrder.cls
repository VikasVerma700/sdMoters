public with sharing class DmsSalesOrder {

    public static CallbackSalesOrderResp checkExistingSalesOrders(List<SalesReq> payloadList) {
        List<Database.UpsertResult> resultList;// = EmployeeMasterResource.upsertEmployees(payloadList);
        if(resultList.isEmpty()){ return null; }

        Map<Id, String>orderIdMap = new Map<Id, String>();
        for(Database.UpsertResult sr : resultList) {
            if(!sr.isSuccess()) {
                String error;
                for(Database.Error dbError : sr.getErrors()) {
                    error += dbError; 
                }
                orderIdMap.put(sr.getId(), error);
            }else{
                orderIdMap.put(sr.getId(), 'Success');
            }
        }

        List<Details> detailsList = new list<Details>();
        for(Sales_Order__c sales : [Select Id, CreatedDate, LastModifiedDate from Sales_Order__c Where Id IN :orderIdMap.keySet() WITH SECURITY_ENFORCED]){
            if(orderIdMap.containsKey(sales.Id)){
                if(orderIdMap.get(sales.Id) == 'Success'){
                    String message;
                    if(date.newInstance(sales.LastModifiedDate.year(), sales.LastModifiedDate.month(), sales.LastModifiedDate.day()) == date.newInstance(sales.CreatedDate.year(), sales.CreatedDate.month(), sales.CreatedDate.day()) && sales.CreatedDate.format('HH:mm') == sales.LastModifiedDate.format('HH:mm')){
                        message = 'Inserted';
                    }else{
                        message = 'Updated';
                    }
                    detailsList.add( new Details(sales.Id,'Sales Order Successfully '+message));
                }else{
                    detailsList.add( new Details(sales.Id, orderIdMap.get(sales.Id)));
                }
            }
        }

        ApplicationLogUtility.insertLogs();
        return new CallbackSalesOrderResp('UPDATE_SALES_ORDER', detailsList);
    }

    public class CallbackSalesOrderResp {
		public String event;
        public List<Details> details;
        public CallbackSalesOrderResp(String evt, List<Details> detList) {
            this.event = evt;
            this.details = detList;
        }
    }

    public class Details {
        public String salesOrderId;
        public String message;
        public Details(String salesOrderId,  String msg) {
            this.salesOrderId = salesOrderId;
            this.message = msg;
        }
    }

    public class SalesReq {
		public string companyCode;
		public long[] id;
		public dateTime dateFrom;
		public DateTime dateTo;
		public long lastKey;
		public long rowCount;
	}
}