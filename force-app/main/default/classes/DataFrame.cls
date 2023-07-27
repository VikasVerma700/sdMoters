public with sharing class DataFrame{
        public List<Map<String,String>> data{get;private set;}
        public List<String> headerList{get;private set;}
		public string html { 
			get { return toHtml(); }
			private set;
		}
        private String rowDelimiter;
        private List<ApplicationLog__c> appLogList;

        private DataFrame(String rowDelimiter){
            this.data = new List<Map<String,String>>();
            this.rowDelimiter = rowDelimiter;
            this.appLogList= new List<ApplicationLog__c>();
        }

        public DataFrame(String rowDelimiter,List<String> rowList){
            this(rowDelimiter);
            this.initializeHeaders(rowList.get(0));
            for(Integer i=1;i<rowList.size();i++){
                this.addRow(rowList.get(i));
            }
            this.insertAppLogs();
        }

        public DataFrame(String rowDelimiter, Blob b){
            this(rowDelimiter);
            List<String> rowList = b.toString().split('\n');
            this.initializeHeaders(rowList.get(0));
            for(Integer i=1;i<rowList.size();i++){
                this.addRow(rowList.get(i));
            }
            this.insertAppLogs();
        }

        private void insertAppLogs(){
            if(!this.appLogList.isEmpty()){
                insert(this.appLogList);
            }
            this.appLogList = new List<ApplicationLog__c>();
        }

        private void initializeHeaders(String headerRow){
            headerRow = headerRow.replace('\r', '');//ignore CR in CRLF
            this.initializeHeaders(headerRow.split(rowDelimiter));
        }

        private void initializeHeaders(List<String> headerList){
            this.headerList = new List<String>();
            for(String header: headerList){
                header = alphabeticTrim(header);
                this.headerList.add(header);
            }
        }

        private void addRow(String row){
            row = row.replace('\r', '');//ignore CR in CRLF
            this.addRow(row.split(this.rowDelimiter));
        }

        private void addRow(List<String> cellList){
            while(cellList.size()<this.headerList.size()){
                cellList.add(null);
            }
            if(cellList.size()==this.headerList.size()){
                Map<String,String> header2Value = new Map<String,String>();
                for(Integer i=0;i<headerList.size();i++){
                    header2Value.put(headerList.get(i),cellList.get(i));
                }
                this.data.add(header2Value);
            }
            else{
                String message = 'row NOT added to dataframe because of incompatible size with headers!\n';
                message += 'Row Content :\n';
                message += String.join(cellList,'|');
                message += '\nHeaders :\n';
                message += String.join(this.headerList,'|');
                this.appLogList.add(ApplicationLogUtility.insertApexErrorLog('DataFrame',message,
                'line 41, addRow(List<String>, DataFrame',Request.getCurrent().getRequestId(),
                ApplicationLogUtility.PRIORITY_LOW,false));
            }
        }

        public Map<String,String> get(Integer index){
            try{
                return this.data.get(index);
            }
            catch(Exception getException){
                return null;
            }
        }

        public Integer getLength(){
            return this.data.size();
        }

        public void debug(){
            for(Map<String,String> row: this.data){
                for(String header:row.keySet()){
                    System.debug(header+' -> '+row.get(header));
                }
                System.debug('------------------------------------');
            }
            System.debug('========================================');
        }

		public string toHtml() {
			string html = '';
			// table
			html += '<table style="border-collapse: collapse; border: 2px grey solid;">';
			// header column
			html += '<tr>';
			for (string header :headerList) {
				html += '<th style="border-bottom: 1px grey solid; border-right: 1px lightgrey dotted; padding: 5px;">' + header;
			}
			html += '</tr>';
			// rows
			for (Map<string, string> row :data) {
				html += '<tr>';
				for (string header :headerList) {
					html += '<td style="border-right: 1px lightgrey dotted; padding: 5px;">' + row.get(header);
				}
				html += '</tr>';
			}
			html += '</table>';

			return html;
		}

        private static String alphabeticTrim(String header){
            Pattern nonAlphaPattern = Pattern.compile('[^a-zA-Z ]');
            Matcher nonAlphaHeader = nonAlphaPattern.matcher(header);
            system.debug(nonAlphaHeader.replaceAll(''));
            return nonAlphaHeader.replaceAll('');
        }
    }