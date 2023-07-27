@isTest
public class SyncMoby08SalesOrder_Test {

	@TestSetup
	static void makeData(){
		SyncMobyApiBase_Test.makeData();

		// SyncMoby01User_Test.testPull();
		SyncMoby01User.MobyUserRes resUser = SyncMoby01User_Test.createObj();
		SyncMoby01User jobUser = new SyncMoby01User();
		jobUser.upsertUser(resUser);

		SyncMoby02Contact.MobyContactRes resCont = SyncMoby02Contact_Test.createObj();
		SyncMoby02Contact jobCont = new SyncMoby02Contact();
		jobCont.upsertContact(resCont);

		SyncMoby04Opportunity.MobyOpportunityRes resOppo = SyncMoby04Opportunity_Test.createObj();
		SyncMoby04Opportunity jobOppo = new SyncMoby04Opportunity();
		jobOppo.upsertOppo(resOppo);

		SyncMoby06Booking.MobyBookingRes resBook = SyncMoby06Booking_Test.createObj();
		SyncMoby06Booking jobBook = new SyncMoby06Booking();
		jobBook.upsertBooking(resBook);

		TestFactory.genVehicle(3, true);
		
		// remove Showroom__c records
		delete [SELECT Id FROM Showroom__c];
	}
	
	@isTest
	public static SyncMoby08SalesOrder.MobySalesOrderRes createObj() {
		Vehicle__c[] vehs = [SELECT Id, Name FROM Vehicle__c];
		
		SyncMoby08SalesOrder.MobySalesOrderRes response = new SyncMoby08SalesOrder.MobySalesOrderRes();
		response.salesOrders = new SyncMoby08SalesOrder.MobySalesOrder[]{};

		SyncMoby08SalesOrder.MobySalesOrder sord;

		/** Booking 1 */
		sord = new SyncMoby08SalesOrder.MobySalesOrder();
		sord.deliveryId = 255;
		sord.bookingId = 189;
		sord.opportunityId = 725;
		sord.insertDate = Datetime.valueOf('2019-03-08 18:12:49.12+08:00');
		sord.updateDate = Datetime.valueOf('2019-07-23 11:55:34.023+08:00');
		sord.stockbookNumber = 2441;
		sord.franchise = 'B';
		sord.modelCode = 'F20';
		sord.acsStatus = 'X';
		sord.variantCode = '1U78B7';
		sord.vehicleDescriptio001 = 'BMW 120i M Sport F20 - CKD';
		sord.colourWheelbaseDesc = 'Alpine White';
		sord.trimCabtypeDesc = 'Alcantara/Cloth Hexagon';
		sord.physicalBranch = 'A31';
		sord.progressCode = 'X';
		sord.engineNumber = 'A108K208';
		sord.supplierName = 'Vehicle ICT Within Branches';
		sord.supplierAddress001 = 'Please Complete';
		sord.supplierAddress002 = ' ';
		sord.supplierAddress003 = ' ';
		sord.supplierAddress004 = ' ';
		sord.supplierAddress005 = ' ';
		sord.registrationNumber = 'VH5055';
		sord.regDate = Datetime.valueOf('2016-12-30 00:00:00');
		sord.inputVAT = 0.00;
		sord.customerName = 'Sime Darby Auto Bavaria Sdn Bhd';
		sord.customerAddress001 = '1st Floor Lot 33 Jalan Pelukis U1/4';
		sord.customerAddress002 = 'Temasya Industrial Park';
		sord.customerAddress003 = 'Seksyen U1, 40150 Shah Alam';
		sord.customerAddress004 = 'Selangor Darul Ehsan';
		sord.customerAddress005 = '40150';
		sord.cusAddressPostcode = ' ';
		sord.telephoneNumber = ' ';
		sord.invoiceName = 'Sime Darby Auto Bavaria Sdn Bhd';
		sord.invoiceAddress001 = '1st Floor Lot 33 Jalan Pelukis U1/4';
		sord.invoiceAddress002 = 'Temasya Industrial Park';
		sord.invoiceAddress003 = 'Seksyen U1, 40150 Shah Alam';
		sord.invoiceAddress004 = 'Selangor Darul Ehsan';
		sord.invoiceAddress005 = '40150';
		sord.invAddressPostcode = ' ';
		sord.customerOrderNo = ' ';
		sord.orderDate = null;
		sord.sOrderType = 'D';
		sord.salesExecutive001 = '84023-20';
		sord.salesExecutive002 = ' ';
		sord.salesExecutive003 = ' ';
		sord.salesExecutive004 = ' ';
		sord.deliveryDate = Datetime.valueOf('2017-03-07 00:00:00');
		sord.salesInvoiceNumber = 3602927.0;
		sord.dateTaxPoint = Datetime.valueOf('2017-03-07 00:00:00');
		sord.nettTotal = 0.00;
		sord.salesDiscount = 0.00;
		sord.vatTotal = 0.00;
		sord.cost = 149586.47;
		sord.grossTotal = 0.00;
		sord.whereAddressFrom001 = 'T';
		sord.whereAddressFrom002 = 'T';
		sord.fullChassis = vehs[0].Name; // 'PM11U780105A17897';
		sord.nonRecoverableCos001 = 0.00;
		sord.nonRecoverableCos002 = 0.00;
		sord.nonRecoverableCos003 = 0.00;
		sord.financeDue = 0.00;
		sord.customerDue = 0.00;
		sord.otherCosts001 = 234.00;
		sord.otherCosts002 = 0.00;
		sord.otherCosts003 = 0.00;
		sord.otherCosts004 = 0.00;
		sord.otherCosts005 = 0.00;
		sord.otherCosts006 = 0.00;
		sord.otherCosts007 = 0.00;
		sord.otherCosts008 = 0.00;
		sord.otherCosts009 = 0.00;
		sord.otherCosts010 = 0.00;
		sord.otherCosts011 = 0.00;
		sord.otherCosts012 = 0.00;
		sord.otherCosts013 = 0.00;
		sord.otherCosts014 = 34433.82;
		sord.otherCosts015 = 0.00;
		sord.totalNRCosts = 34667.82;
		sord.overAllowance001 = 0.00;
		sord.overAllowance002 = 0.00;
		sord.overAllowance003 = 0.00;
		sord.latestProfitValue = 0.00;
		sord.invoicedProfitValu = 0.00;
		sord.invoicedProfitDate = Datetime.valueOf('2017-03-07 00:00:00');
		sord.profitLastVSBPend = 0.00;
		sord.dateLastVSBPEnd = Datetime.valueOf('2017-03-07 00:00:00');
		sord.profitLastNLPEnd = 0.00;
		sord.dateLastNLPEnd = Datetime.valueOf('2017-03-31 00:00:00');
		sord.estimatedCosts = 184254.29;
		sord.lateCosts = 0.00;
		sord.locator = 'F20';
		sord.defaultPictureCode = ' ';
		sord.preReserveProgress = 'A';
		sord.dateReserved = null;
		sord.timeReserved = 0.0000;
		sord.reservedBy = ' ';
		sord.supplierAccount = 'v2000001';
		sord.invoiceAccount = 'v1000001';
		sord.customerAccount = 'v1000001';
		sord.invoiceTotal = 184254.29;
		sord.customerACAmount = 0.00;
		sord.depositTotal = 0.00;
		sord.invoiceACAmount = 0.00;
		sord.netAllowanceTotal = 184254.29;
		sord.netAllowances001 = 184254.29;
		sord.netAllowances002 = 0.00;
		sord.netAllowances003 = 0.00;
		sord.overallowanceTotal = 0.00;
		sord.supplYValueTotal = 0.00;
		sord.mainInvoiceTotal = 184254.29;
		sord.invoiceVATCodes001 = '5';
		sord.invoiceVATCodes002 = ' ';
		sord.invoiceVATCodes003 = ' ';
		sord.invoiceVATCodes004 = ' ';
		sord.invoiceVATCodes005 = ' ';
		sord.invoiceVATCodes006 = ' ';
		sord.invoiceVATCodes007 = ' ';
		sord.invoiceVATCodes008 = ' ';
		sord.invoiceVATCodes009 = ' ';
		sord.invoiceVATCodes010 = ' ';
		sord.toAtThisCode001 = 0.00;
		sord.toAtThisCode002 = 0.00;
		sord.toAtThisCode003 = 0.00;
		sord.toAtThisCode004 = 0.00;
		sord.toAtThisCode005 = 0.00;
		sord.toAtThisCode006 = 0.00;
		sord.toAtThisCode007 = 0.00;
		sord.toAtThisCode008 = 0.00;
		sord.toAtThisCode009 = 0.00;
		sord.toAtThisCode010 = 0.00;
		sord.vatAtThisCode001 = 0.00;
		sord.vatAtThisCode002 = 0.00;
		sord.vatAtThisCode003 = 0.00;
		sord.vatAtThisCode004 = 0.00;
		sord.vatAtThisCode005 = 0.00;
		sord.vatAtThisCode006 = 0.00;
		sord.vatAtThisCode007 = 0.00;
		sord.vatAtThisCode008 = 0.00;
		sord.vatAtThisCode009 = 0.00;
		sord.vatAtThisCode010 = 0.00;
		sord.lastPLMagicNo = 0;
		sord.lastSLMagicNo = 818664;
		sord.invoiceProduced = 1;
		sord.carTaxCost = 0.00;
		sord.warrantyReference = ' ';
		sord.carTaxSale = 0.00;
		sord.overallSaleNet = 184254.29;
		sord.overallSaleDisc = 0.00;
		sord.overallSaleVat = 0.00;
		sord.overallSaleGross = 184254.29;
		sord.cdSecurityCode = ' ';
		sord.fleetnetCode = ' ';
		sord.fleetnetID = 0;
		sord.autosellLotNumber = 0;
		sord.stockCheckDate = null;
		sord.interCoTransRef = 'DA3U001043';
		sord.stockCheckPerson = ' ';
		sord.stockCheckRef = ' ';
		sord.buyingBranch = 'A31';
		sord.usTaxCodes001 = ' ';
		sord.usTaxCodes002 = ' ';
		sord.sellingBranch = 'A31';
		sord.crmCustomerMagic = 57973;
		sord.crmVehicleMagic = 75208;
		sord.vsPostingCode = 'A';
		sord.stockSuspenseAC = 23020380002.0;
		sord.recalculateVehicle = ' ';
		sord.taxOnVehicleList = 0.00;
		sord.carTaxAdjustment = 0.00;
		sord.taxAllInvoices = 0.00;
		sord.currentPrevPrice = ' ';
		sord.datePriceEffective = Datetime.valueOf('2016-09-27 00:00:00');
		sord.estimatedSalesVal = 184254.29;
		sord.estActCosts = 0.00;
		sord.unit10 = 1.0;
		sord.lifetimeCare = null;
		sord.shortChassis = '79871A501087U11MP';
		sord.heavyLightCommercl = 'L';
		sord.discountValues001 = 0.00;
		sord.discountValues002 = 0.00;
		sord.discountValues003 = 0.00;
		sord.discountValues004 = 0.00;
		sord.discountValues005 = 0.00;
		sord.discountValues006 = 0.00;
		sord.discountValues007 = 0.00;
		sord.discountValues008 = 0.00;
		sord.discountValues009 = 0.00;
		sord.discountValues010 = 0.00;
		sord.discountValues011 = 0.00;
		sord.discountValues012 = 0.00;
		sord.discountValues013 = 0.00;
		sord.discountValues014 = 0.00;
		sord.discountValues015 = 0.00;
		sord.currencyCode = 'MYR';
		sord.exchangeRate = 1.00000;
		sord.bulkInvoice = 0;
		sord.modelYear = '2016';
		sord.modelAnalysisCode = 'CKD';
		sord.genericColourCode = ' ';
		sord.genericTrimCode = ' ';
		sord.creditNoteDate = null;
		sord.capKey = ' ';
		sord.capYear = ' ';
		sord.fuelType = 'U';
		sord.pxhpSettlements001 = 0.00;
		sord.pxhpSettlements002 = 0.00;
		sord.pxhpSettlements003 = 0.00;
		sord.totalPXSettlements = 0.00;
		sord.deliveryTime = ' ';
		sord.transmissionType = 'A';
		sord.saleCarTaxVAT = 0.00;
		sord.totalCarTaxVAT = 0.00;
		sord.glassCode = ' ';
		sord.supplierVATNo = '001168113664';
		sord.reservedUntil = null;
		sord.co2Emissions = 0.00;
		sord.localDescription = ' ';
		sord.trimDescription = ' ';
		sord.complianceDate = null;
		sord.brakeHorsePower = 0;
		sord.showroomCompany = ' ';
		sord.srQuoteMagic = 0;
		sord.accidentDamage = ' ';
		sord.governmentNumber = ' ';
		sord.mileageOnSale = 5.00;
		sord.finallyPriced = 1;
		sord.immobiliserCode = 'SDP-D';
		sord.driverSide = '2';
		sord.totalAllowedWeight = 0;
		sord.previousICTRef = 'AZN004047';
		sord.subModelGroup = ' ';
		sord.vehicleHasVideo = ' ';
		sord.keyNumber = ' ';
		sord.altKeyNumber = ' ';
		sord.slDepositMagic001 = 0;
		sord.slDepositMagic002 = 0;
		sord.slDepositMagic003 = 0;
		sord.slDepositMagic004 = 0;
		sord.slDepositMagic005 = 0;
		sord.slDepositMagic006 = 0;
		sord.slDepositMagic007 = 0;
		sord.slDepositMagic008 = 0;
		sord.slDepositMagic009 = 0;
		sord.slDepositMagic010 = 0;
		sord.slDepositMagic011 = 0;
		sord.slDepositMagic012 = 0;
		sord.slDepositMagic013 = 0;
		sord.slDepositMagic014 = 0;
		sord.slDepositMagic015 = 0;
		sord.slDepositMagic016 = 0;
		sord.slDepositMagic017 = 0;
		sord.slDepositMagic018 = 0;
		sord.slDepositMagic019 = 0;
		sord.slDepositMagic020 = 0;
		sord.depositVAT001 = 0.00;
		sord.depositVAT002 = 0.00;
		sord.depositVAT003 = 0.00;
		sord.depositVAT004 = 0.00;
		sord.depositVAT005 = 0.00;
		sord.depositVAT006 = 0.00;
		sord.depositVAT007 = 0.00;
		sord.depositVAT008 = 0.00;
		sord.depositVAT009 = 0.00;
		sord.depositVAT010 = 0.00;
		sord.depositVAT011 = 0.00;
		sord.depositVAT012 = 0.00;
		sord.depositVAT013 = 0.00;
		sord.depositVAT014 = 0.00;
		sord.depositVAT015 = 0.00;
		sord.depositVAT016 = 0.00;
		sord.depositVAT017 = 0.00;
		sord.depositVAT018 = 0.00;
		sord.depositVAT019 = 0.00;
		sord.depositVAT020 = 0.00;
		sord.colourWheelbase = '300';
		sord.trimCabtype = 'HAAT';
		response.salesOrders.add(sord);

		/** Booking 2 */
		sord = new SyncMoby08SalesOrder.MobySalesOrder();
		sord.deliveryId = 256;
		sord.bookingId = 184;
		sord.opportunityId = 737;
		sord.insertDate = Datetime.valueOf('2019-03-08 18:31:08.507+08:00');
		sord.updateDate = Datetime.valueOf('2019-11-13 12:54:11.337+08:00');
		sord.stockbookNumber = 2441;
		sord.franchise = 'B';
		sord.modelCode = 'F20';
		sord.acsStatus = 'X';
		sord.variantCode = '1U78B7';
		sord.vehicleDescriptio001 = 'BMW 120i M Sport F20 - CKD';
		sord.colourWheelbaseDesc = 'Alpine White';
		sord.trimCabtypeDesc = 'Alcantara/Cloth Hexagon';
		sord.physicalBranch = 'A31';
		sord.progressCode = 'X';
		sord.engineNumber = 'A108K208';
		sord.supplierName = 'Vehicle ICT Within Branches';
		sord.supplierAddress001 = 'Please Complete';
		sord.supplierAddress002 = ' ';
		sord.supplierAddress003 = ' ';
		sord.supplierAddress004 = ' ';
		sord.supplierAddress005 = ' ';
		sord.registrationNumber = 'VH5055';
		sord.regDate = Datetime.valueOf('2016-12-30 00:00:00');
		sord.inputVAT = 0.00;
		sord.customerName = 'Sime Darby Auto Bavaria Sdn Bhd';
		sord.customerAddress001 = '1st Floor Lot 33 Jalan Pelukis U1/4';
		sord.customerAddress002 = 'Temasya Industrial Park';
		sord.customerAddress003 = 'Seksyen U1, 40150 Shah Alam';
		sord.customerAddress004 = 'Selangor Darul Ehsan';
		sord.customerAddress005 = '40150';
		sord.cusAddressPostcode = ' ';
		sord.telephoneNumber = ' ';
		sord.invoiceName = 'Sime Darby Auto Bavaria Sdn Bhd';
		sord.invoiceAddress001 = '1st Floor Lot 33 Jalan Pelukis U1/4';
		sord.invoiceAddress002 = 'Temasya Industrial Park';
		sord.invoiceAddress003 = 'Seksyen U1, 40150 Shah Alam';
		sord.invoiceAddress004 = 'Selangor Darul Ehsan';
		sord.invoiceAddress005 = '40150';
		sord.invAddressPostcode = ' ';
		sord.customerOrderNo = ' ';
		sord.orderDate = null;
		sord.sOrderType = 'D';
		sord.salesExecutive001 = '84023-20';
		sord.salesExecutive002 = ' ';
		sord.salesExecutive003 = ' ';
		sord.salesExecutive004 = ' ';
		sord.deliveryDate = Datetime.valueOf('2017-03-07 00:00:00');
		sord.salesInvoiceNumber = 3602927.0;
		sord.dateTaxPoint = Datetime.valueOf('2017-03-07 00:00:00');
		sord.nettTotal = 0.00;
		sord.salesDiscount = 0.00;
		sord.vatTotal = 0.00;
		sord.cost = 149586.47;
		sord.grossTotal = 0.00;
		sord.whereAddressFrom001 = 'T';
		sord.whereAddressFrom002 = 'T';
		sord.fullChassis = vehs[1].Name; // 'PM11U780105A17897';
		sord.nonRecoverableCos001 = 0.00;
		sord.nonRecoverableCos002 = 0.00;
		sord.nonRecoverableCos003 = 0.00;
		sord.financeDue = 0.00;
		sord.customerDue = 0.00;
		sord.otherCosts001 = 234.00;
		sord.otherCosts002 = 0.00;
		sord.otherCosts003 = 0.00;
		sord.otherCosts004 = 0.00;
		sord.otherCosts005 = 0.00;
		sord.otherCosts006 = 0.00;
		sord.otherCosts007 = 0.00;
		sord.otherCosts008 = 0.00;
		sord.otherCosts009 = 0.00;
		sord.otherCosts010 = 0.00;
		sord.otherCosts011 = 0.00;
		sord.otherCosts012 = 0.00;
		sord.otherCosts013 = 0.00;
		sord.otherCosts014 = 34433.82;
		sord.otherCosts015 = 0.00;
		sord.totalNRCosts = 34667.82;
		sord.overAllowance001 = 0.00;
		sord.overAllowance002 = 0.00;
		sord.overAllowance003 = 0.00;
		sord.latestProfitValue = 0.00;
		sord.invoicedProfitValu = 0.00;
		sord.invoicedProfitDate = Datetime.valueOf('2017-03-07 00:00:00');
		sord.profitLastVSBPend = 0.00;
		sord.dateLastVSBPEnd = Datetime.valueOf('2017-03-07 00:00:00');
		sord.profitLastNLPEnd = 0.00;
		sord.dateLastNLPEnd = Datetime.valueOf('2017-03-31 00:00:00');
		sord.estimatedCosts = 184254.29;
		sord.lateCosts = 0.00;
		sord.locator = 'F20';
		sord.defaultPictureCode = ' ';
		sord.preReserveProgress = 'A';
		sord.dateReserved = null;
		sord.timeReserved = 0.0000;
		sord.reservedBy = ' ';
		sord.supplierAccount = 'v2000001';
		sord.invoiceAccount = 'v1000001';
		sord.customerAccount = 'v1000001';
		sord.invoiceTotal = 184254.29;
		sord.customerACAmount = 0.00;
		sord.depositTotal = 0.00;
		sord.invoiceACAmount = 0.00;
		sord.netAllowanceTotal = 184254.29;
		sord.netAllowances001 = 184254.29;
		sord.netAllowances002 = 0.00;
		sord.netAllowances003 = 0.00;
		sord.overallowanceTotal = 0.00;
		sord.supplYValueTotal = 0.00;
		sord.mainInvoiceTotal = 184254.29;
		sord.invoiceVATCodes001 = '5';
		sord.invoiceVATCodes002 = ' ';
		sord.invoiceVATCodes003 = ' ';
		sord.invoiceVATCodes004 = ' ';
		sord.invoiceVATCodes005 = ' ';
		sord.invoiceVATCodes006 = ' ';
		sord.invoiceVATCodes007 = ' ';
		sord.invoiceVATCodes008 = ' ';
		sord.invoiceVATCodes009 = ' ';
		sord.invoiceVATCodes010 = ' ';
		sord.toAtThisCode001 = 0.00;
		sord.toAtThisCode002 = 0.00;
		sord.toAtThisCode003 = 0.00;
		sord.toAtThisCode004 = 0.00;
		sord.toAtThisCode005 = 0.00;
		sord.toAtThisCode006 = 0.00;
		sord.toAtThisCode007 = 0.00;
		sord.toAtThisCode008 = 0.00;
		sord.toAtThisCode009 = 0.00;
		sord.toAtThisCode010 = 0.00;
		sord.vatAtThisCode001 = 0.00;
		sord.vatAtThisCode002 = 0.00;
		sord.vatAtThisCode003 = 0.00;
		sord.vatAtThisCode004 = 0.00;
		sord.vatAtThisCode005 = 0.00;
		sord.vatAtThisCode006 = 0.00;
		sord.vatAtThisCode007 = 0.00;
		sord.vatAtThisCode008 = 0.00;
		sord.vatAtThisCode009 = 0.00;
		sord.vatAtThisCode010 = 0.00;
		sord.lastPLMagicNo = 0;
		sord.lastSLMagicNo = 818664;
		sord.invoiceProduced = 1;
		sord.carTaxCost = 0.00;
		sord.warrantyReference = ' ';
		sord.carTaxSale = 0.00;
		sord.overallSaleNet = 184254.29;
		sord.overallSaleDisc = 0.00;
		sord.overallSaleVat = 0.00;
		sord.overallSaleGross = 184254.29;
		sord.cdSecurityCode = ' ';
		sord.fleetnetCode = ' ';
		sord.fleetnetID = 0;
		sord.autosellLotNumber = 0;
		sord.stockCheckDate = null;
		sord.interCoTransRef = 'DA3U001043';
		sord.stockCheckPerson = ' ';
		sord.stockCheckRef = ' ';
		sord.buyingBranch = 'A31';
		sord.usTaxCodes001 = ' ';
		sord.usTaxCodes002 = ' ';
		sord.sellingBranch = 'A31';
		sord.crmCustomerMagic = 57973;
		sord.crmVehicleMagic = 75208;
		sord.vsPostingCode = 'A';
		sord.stockSuspenseAC = 23020380002.0;
		sord.recalculateVehicle = ' ';
		sord.taxOnVehicleList = 0.00;
		sord.carTaxAdjustment = 0.00;
		sord.taxAllInvoices = 0.00;
		sord.currentPrevPrice = ' ';
		sord.datePriceEffective = Datetime.valueOf('2016-09-27 00:00:00');
		sord.estimatedSalesVal = 184254.29;
		sord.estActCosts = 0.00;
		sord.unit10 = 1.0;
		sord.lifetimeCare = null;
		sord.shortChassis = '79871A501087U11MP';
		sord.heavyLightCommercl = 'L';
		sord.discountValues001 = 0.00;
		sord.discountValues002 = 0.00;
		sord.discountValues003 = 0.00;
		sord.discountValues004 = 0.00;
		sord.discountValues005 = 0.00;
		sord.discountValues006 = 0.00;
		sord.discountValues007 = 0.00;
		sord.discountValues008 = 0.00;
		sord.discountValues009 = 0.00;
		sord.discountValues010 = 0.00;
		sord.discountValues011 = 0.00;
		sord.discountValues012 = 0.00;
		sord.discountValues013 = 0.00;
		sord.discountValues014 = 0.00;
		sord.discountValues015 = 0.00;
		sord.currencyCode = 'MYR';
		sord.exchangeRate = 1.00000;
		sord.bulkInvoice = 0;
		sord.modelYear = '2016';
		sord.modelAnalysisCode = 'CKD';
		sord.genericColourCode = ' ';
		sord.genericTrimCode = ' ';
		sord.creditNoteDate = null;
		sord.capKey = ' ';
		sord.capYear = ' ';
		sord.fuelType = 'U';
		sord.pxhpSettlements001 = 0.00;
		sord.pxhpSettlements002 = 0.00;
		sord.pxhpSettlements003 = 0.00;
		sord.totalPXSettlements = 0.00;
		sord.deliveryTime = ' ';
		sord.transmissionType = 'A';
		sord.saleCarTaxVAT = 0.00;
		sord.totalCarTaxVAT = 0.00;
		sord.glassCode = ' ';
		sord.supplierVATNo = '001168113664';
		sord.reservedUntil = null;
		sord.co2Emissions = 0.00;
		sord.localDescription = ' ';
		sord.trimDescription = ' ';
		sord.complianceDate = null;
		sord.brakeHorsePower = 0;
		sord.showroomCompany = ' ';
		sord.srQuoteMagic = 0;
		sord.accidentDamage = ' ';
		sord.governmentNumber = ' ';
		sord.mileageOnSale = 5.00;
		sord.finallyPriced = 1;
		sord.immobiliserCode = 'SDP-D';
		sord.driverSide = '2';
		sord.totalAllowedWeight = 0;
		sord.previousICTRef = 'AZN004047';
		sord.subModelGroup = ' ';
		sord.vehicleHasVideo = ' ';
		sord.keyNumber = ' ';
		sord.altKeyNumber = ' ';
		sord.slDepositMagic001 = 0;
		sord.slDepositMagic002 = 0;
		sord.slDepositMagic003 = 0;
		sord.slDepositMagic004 = 0;
		sord.slDepositMagic005 = 0;
		sord.slDepositMagic006 = 0;
		sord.slDepositMagic007 = 0;
		sord.slDepositMagic008 = 0;
		sord.slDepositMagic009 = 0;
		sord.slDepositMagic010 = 0;
		sord.slDepositMagic011 = 0;
		sord.slDepositMagic012 = 0;
		sord.slDepositMagic013 = 0;
		sord.slDepositMagic014 = 0;
		sord.slDepositMagic015 = 0;
		sord.slDepositMagic016 = 0;
		sord.slDepositMagic017 = 0;
		sord.slDepositMagic018 = 0;
		sord.slDepositMagic019 = 0;
		sord.slDepositMagic020 = 0;
		sord.depositVAT001 = 0.00;
		sord.depositVAT002 = 0.00;
		sord.depositVAT003 = 0.00;
		sord.depositVAT004 = 0.00;
		sord.depositVAT005 = 0.00;
		sord.depositVAT006 = 0.00;
		sord.depositVAT007 = 0.00;
		sord.depositVAT008 = 0.00;
		sord.depositVAT009 = 0.00;
		sord.depositVAT010 = 0.00;
		sord.depositVAT011 = 0.00;
		sord.depositVAT012 = 0.00;
		sord.depositVAT013 = 0.00;
		sord.depositVAT014 = 0.00;
		sord.depositVAT015 = 0.00;
		sord.depositVAT016 = 0.00;
		sord.depositVAT017 = 0.00;
		sord.depositVAT018 = 0.00;
		sord.depositVAT019 = 0.00;
		sord.depositVAT020 = 0.00;
		sord.colourWheelbase = '300';
		sord.trimCabtype = 'HAAT';
		response.salesOrders.add(sord);

		/** Booking 3 */
		sord = new SyncMoby08SalesOrder.MobySalesOrder();
		sord.deliveryId = 257;
		sord.bookingId = 425;
		sord.opportunityId = 757;
		sord.insertDate = Datetime.valueOf('2019-03-08 18:50:30.287+08:00');
		sord.updateDate = Datetime.valueOf('2019-11-13 13:46:16.477+08:00');
		sord.stockbookNumber = 2441;
		sord.franchise = 'B';
		sord.modelCode = 'F20';
		sord.acsStatus = 'X';
		sord.variantCode = '1U78B7';
		sord.vehicleDescriptio001 = 'BMW 120i M Sport F20 - CKD';
		sord.colourWheelbaseDesc = 'Alpine White';
		sord.trimCabtypeDesc = 'Alcantara/Cloth Hexagon';
		sord.physicalBranch = 'A31';
		sord.progressCode = 'X';
		sord.engineNumber = 'A108K208';
		sord.supplierName = 'Vehicle ICT Within Branches';
		sord.supplierAddress001 = 'Please Complete';
		sord.supplierAddress002 = ' ';
		sord.supplierAddress003 = ' ';
		sord.supplierAddress004 = ' ';
		sord.supplierAddress005 = ' ';
		sord.registrationNumber = 'VH5055';
		sord.regDate = Datetime.valueOf('2016-12-30 00:00:00');
		sord.inputVAT = 0.00;
		sord.customerName = 'Sime Darby Auto Bavaria Sdn Bhd';
		sord.customerAddress001 = '1st Floor Lot 33 Jalan Pelukis U1/4';
		sord.customerAddress002 = 'Temasya Industrial Park';
		sord.customerAddress003 = 'Seksyen U1, 40150 Shah Alam';
		sord.customerAddress004 = 'Selangor Darul Ehsan';
		sord.customerAddress005 = '40150';
		sord.cusAddressPostcode = ' ';
		sord.telephoneNumber = ' ';
		sord.invoiceName = 'Sime Darby Auto Bavaria Sdn Bhd';
		sord.invoiceAddress001 = '1st Floor Lot 33 Jalan Pelukis U1/4';
		sord.invoiceAddress002 = 'Temasya Industrial Park';
		sord.invoiceAddress003 = 'Seksyen U1, 40150 Shah Alam';
		sord.invoiceAddress004 = 'Selangor Darul Ehsan';
		sord.invoiceAddress005 = '40150';
		sord.invAddressPostcode = ' ';
		sord.customerOrderNo = ' ';
		sord.orderDate = null;
		sord.sOrderType = 'D';
		sord.salesExecutive001 = '84023-20';
		sord.salesExecutive002 = ' ';
		sord.salesExecutive003 = ' ';
		sord.salesExecutive004 = ' ';
		sord.deliveryDate = Datetime.valueOf('2017-03-07 00:00:00');
		sord.salesInvoiceNumber = 3602927.0;
		sord.dateTaxPoint = Datetime.valueOf('2017-03-07 00:00:00');
		sord.nettTotal = 0.00;
		sord.salesDiscount = 0.00;
		sord.vatTotal = 0.00;
		sord.cost = 149586.47;
		sord.grossTotal = 0.00;
		sord.whereAddressFrom001 = 'T';
		sord.whereAddressFrom002 = 'T';
		sord.fullChassis = vehs[2].Name; // 'PM11U780105A17897';
		sord.nonRecoverableCos001 = 0.00;
		sord.nonRecoverableCos002 = 0.00;
		sord.nonRecoverableCos003 = 0.00;
		sord.financeDue = 0.00;
		sord.customerDue = 0.00;
		sord.otherCosts001 = 234.00;
		sord.otherCosts002 = 0.00;
		sord.otherCosts003 = 0.00;
		sord.otherCosts004 = 0.00;
		sord.otherCosts005 = 0.00;
		sord.otherCosts006 = 0.00;
		sord.otherCosts007 = 0.00;
		sord.otherCosts008 = 0.00;
		sord.otherCosts009 = 0.00;
		sord.otherCosts010 = 0.00;
		sord.otherCosts011 = 0.00;
		sord.otherCosts012 = 0.00;
		sord.otherCosts013 = 0.00;
		sord.otherCosts014 = 34433.82;
		sord.otherCosts015 = 0.00;
		sord.totalNRCosts = 34667.82;
		sord.overAllowance001 = 0.00;
		sord.overAllowance002 = 0.00;
		sord.overAllowance003 = 0.00;
		sord.latestProfitValue = 0.00;
		sord.invoicedProfitValu = 0.00;
		sord.invoicedProfitDate = Datetime.valueOf('2017-03-07 00:00:00');
		sord.profitLastVSBPend = 0.00;
		sord.dateLastVSBPEnd = Datetime.valueOf('2017-03-07 00:00:00');
		sord.profitLastNLPEnd = 0.00;
		sord.dateLastNLPEnd = Datetime.valueOf('2017-03-31 00:00:00');
		sord.estimatedCosts = 184254.29;
		sord.lateCosts = 0.00;
		sord.locator = 'F20';
		sord.defaultPictureCode = ' ';
		sord.preReserveProgress = 'A';
		sord.dateReserved = null;
		sord.timeReserved = 0.0000;
		sord.reservedBy = ' ';
		sord.supplierAccount = 'v2000001';
		sord.invoiceAccount = 'v1000001';
		sord.customerAccount = 'v1000001';
		sord.invoiceTotal = 184254.29;
		sord.customerACAmount = 0.00;
		sord.depositTotal = 0.00;
		sord.invoiceACAmount = 0.00;
		sord.netAllowanceTotal = 184254.29;
		sord.netAllowances001 = 184254.29;
		sord.netAllowances002 = 0.00;
		sord.netAllowances003 = 0.00;
		sord.overallowanceTotal = 0.00;
		sord.supplYValueTotal = 0.00;
		sord.mainInvoiceTotal = 184254.29;
		sord.invoiceVATCodes001 = '5';
		sord.invoiceVATCodes002 = ' ';
		sord.invoiceVATCodes003 = ' ';
		sord.invoiceVATCodes004 = ' ';
		sord.invoiceVATCodes005 = ' ';
		sord.invoiceVATCodes006 = ' ';
		sord.invoiceVATCodes007 = ' ';
		sord.invoiceVATCodes008 = ' ';
		sord.invoiceVATCodes009 = ' ';
		sord.invoiceVATCodes010 = ' ';
		sord.toAtThisCode001 = 0.00;
		sord.toAtThisCode002 = 0.00;
		sord.toAtThisCode003 = 0.00;
		sord.toAtThisCode004 = 0.00;
		sord.toAtThisCode005 = 0.00;
		sord.toAtThisCode006 = 0.00;
		sord.toAtThisCode007 = 0.00;
		sord.toAtThisCode008 = 0.00;
		sord.toAtThisCode009 = 0.00;
		sord.toAtThisCode010 = 0.00;
		sord.vatAtThisCode001 = 0.00;
		sord.vatAtThisCode002 = 0.00;
		sord.vatAtThisCode003 = 0.00;
		sord.vatAtThisCode004 = 0.00;
		sord.vatAtThisCode005 = 0.00;
		sord.vatAtThisCode006 = 0.00;
		sord.vatAtThisCode007 = 0.00;
		sord.vatAtThisCode008 = 0.00;
		sord.vatAtThisCode009 = 0.00;
		sord.vatAtThisCode010 = 0.00;
		sord.lastPLMagicNo = 0;
		sord.lastSLMagicNo = 818664;
		sord.invoiceProduced = 1;
		sord.carTaxCost = 0.00;
		sord.warrantyReference = ' ';
		sord.carTaxSale = 0.00;
		sord.overallSaleNet = 184254.29;
		sord.overallSaleDisc = 0.00;
		sord.overallSaleVat = 0.00;
		sord.overallSaleGross = 184254.29;
		sord.cdSecurityCode = ' ';
		sord.fleetnetCode = ' ';
		sord.fleetnetID = 0;
		sord.autosellLotNumber = 0;
		sord.stockCheckDate = null;
		sord.interCoTransRef = 'DA3U001043';
		sord.stockCheckPerson = ' ';
		sord.stockCheckRef = ' ';
		sord.buyingBranch = 'A31';
		sord.usTaxCodes001 = ' ';
		sord.usTaxCodes002 = ' ';
		sord.sellingBranch = 'A31';
		sord.crmCustomerMagic = 57973;
		sord.crmVehicleMagic = 75208;
		sord.vsPostingCode = 'A';
		sord.stockSuspenseAC = 23020380002.0;
		sord.recalculateVehicle = ' ';
		sord.taxOnVehicleList = 0.00;
		sord.carTaxAdjustment = 0.00;
		sord.taxAllInvoices = 0.00;
		sord.currentPrevPrice = ' ';
		sord.datePriceEffective = Datetime.valueOf('2016-09-27 00:00:00');
		sord.estimatedSalesVal = 184254.29;
		sord.estActCosts = 0.00;
		sord.unit10 = 1.0;
		sord.lifetimeCare = null;
		sord.shortChassis = '79871A501087U11MP';
		sord.heavyLightCommercl = 'L';
		sord.discountValues001 = 0.00;
		sord.discountValues002 = 0.00;
		sord.discountValues003 = 0.00;
		sord.discountValues004 = 0.00;
		sord.discountValues005 = 0.00;
		sord.discountValues006 = 0.00;
		sord.discountValues007 = 0.00;
		sord.discountValues008 = 0.00;
		sord.discountValues009 = 0.00;
		sord.discountValues010 = 0.00;
		sord.discountValues011 = 0.00;
		sord.discountValues012 = 0.00;
		sord.discountValues013 = 0.00;
		sord.discountValues014 = 0.00;
		sord.discountValues015 = 0.00;
		sord.currencyCode = 'MYR';
		sord.exchangeRate = 1.00000;
		sord.bulkInvoice = 0;
		sord.modelYear = '2016';
		sord.modelAnalysisCode = 'CKD';
		sord.genericColourCode = ' ';
		sord.genericTrimCode = ' ';
		sord.creditNoteDate = null;
		sord.capKey = ' ';
		sord.capYear = ' ';
		sord.fuelType = 'U';
		sord.pxhpSettlements001 = 0.00;
		sord.pxhpSettlements002 = 0.00;
		sord.pxhpSettlements003 = 0.00;
		sord.totalPXSettlements = 0.00;
		sord.deliveryTime = ' ';
		sord.transmissionType = 'A';
		sord.saleCarTaxVAT = 0.00;
		sord.totalCarTaxVAT = 0.00;
		sord.glassCode = ' ';
		sord.supplierVATNo = '001168113664';
		sord.reservedUntil = null;
		sord.co2Emissions = 0.00;
		sord.localDescription = ' ';
		sord.trimDescription = ' ';
		sord.complianceDate = null;
		sord.brakeHorsePower = 0;
		sord.showroomCompany = ' ';
		sord.srQuoteMagic = 0;
		sord.accidentDamage = ' ';
		sord.governmentNumber = ' ';
		sord.mileageOnSale = 5.00;
		sord.finallyPriced = 1;
		sord.immobiliserCode = 'SDP-D';
		sord.driverSide = '2';
		sord.totalAllowedWeight = 0;
		sord.previousICTRef = 'AZN004047';
		sord.subModelGroup = ' ';
		sord.vehicleHasVideo = ' ';
		sord.keyNumber = ' ';
		sord.altKeyNumber = ' ';
		sord.slDepositMagic001 = 0;
		sord.slDepositMagic002 = 0;
		sord.slDepositMagic003 = 0;
		sord.slDepositMagic004 = 0;
		sord.slDepositMagic005 = 0;
		sord.slDepositMagic006 = 0;
		sord.slDepositMagic007 = 0;
		sord.slDepositMagic008 = 0;
		sord.slDepositMagic009 = 0;
		sord.slDepositMagic010 = 0;
		sord.slDepositMagic011 = 0;
		sord.slDepositMagic012 = 0;
		sord.slDepositMagic013 = 0;
		sord.slDepositMagic014 = 0;
		sord.slDepositMagic015 = 0;
		sord.slDepositMagic016 = 0;
		sord.slDepositMagic017 = 0;
		sord.slDepositMagic018 = 0;
		sord.slDepositMagic019 = 0;
		sord.slDepositMagic020 = 0;
		sord.depositVAT001 = 0.00;
		sord.depositVAT002 = 0.00;
		sord.depositVAT003 = 0.00;
		sord.depositVAT004 = 0.00;
		sord.depositVAT005 = 0.00;
		sord.depositVAT006 = 0.00;
		sord.depositVAT007 = 0.00;
		sord.depositVAT008 = 0.00;
		sord.depositVAT009 = 0.00;
		sord.depositVAT010 = 0.00;
		sord.depositVAT011 = 0.00;
		sord.depositVAT012 = 0.00;
		sord.depositVAT013 = 0.00;
		sord.depositVAT014 = 0.00;
		sord.depositVAT015 = 0.00;
		sord.depositVAT016 = 0.00;
		sord.depositVAT017 = 0.00;
		sord.depositVAT018 = 0.00;
		sord.depositVAT019 = 0.00;
		sord.depositVAT020 = 0.00;
		sord.colourWheelbase = '300';
		sord.trimCabtype = 'HAAT';
		response.salesOrders.add(sord);

		response.lastKey = 25;

		return response;
	}

	@isTest
	public static void testPull() {
		SyncMoby08SalesOrder.MobySalesOrderRes res = createObj();

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby08SalesOrder job = new SyncMoby08SalesOrder();
		job.followOnToNext = true;
		System.enqueueJob(job);
		job.execute(null); // kick out of queue
		Test.stopTest();

		System.debug(JSON.serialize([SELECT Id, Name FROM Sales_Order__c]));
		System.assertEquals(3,	[SELECT Id FROM Sales_Order__c].size());
	}

	@isTest
	static void testPullUpdateByMobyId() {
		SyncMoby08SalesOrder.MobySalesOrderRes res = createObj();

		SyncMoby08SalesOrder job = new SyncMoby08SalesOrder();
		job.upsertSalesOrder(res);

		/** Coverage:
		 * SyncMoby08SalesOrder: 290
		 * 	Remove MobyBranchNumber__c */
		// Showroom__c[] shows = [SELECT Id, Name, MobyBranchNumber__c, MobyBranchCode__c FROM Showroom__c];
		// shows[1].MobyBranchNumber__c = null;
		// update shows;

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby08SalesOrder kob = new SyncMoby08SalesOrder();
		kob.followOnToNext = true;
		kob.execute(null);
		Test.stopTest();
		System.assertEquals(3, [SELECT Id FROM Sales_Order__c].size());
	}

	@isTest static void testPullNoRow() {
		SyncMoby08SalesOrder.MobySalesOrderRes res = new SyncMoby08SalesOrder.MobySalesOrderRes();
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Test.startTest();
		SyncMoby08SalesOrder job = new SyncMoby08SalesOrder();
		job.dateFrom = null;
		job.dateTo = null;
		job.followOnToNext = true;
		job.execute(null);
		Test.stopTest();
	}

	@isTest static void testPullStatusNotOK() {
		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(400, 'Error retrieving data');
		Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        SyncMoby08SalesOrder job = new SyncMoby08SalesOrder();
        job.followOnToNext = true;
        System.enqueueJob(job);
        Test.stopTest();
	}

	@isTest static void testPull_E() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowE());
		Test.startTest();
		SyncMoby08SalesOrder job = new SyncMoby08SalesOrder();
		job.followOnToNext = true;
		System.enqueueJob(job);
		Test.stopTest();

	}
	@isTest static void testPull_ECallout() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SyncMoby08SalesOrder job = new SyncMoby08SalesOrder();
		job.followOnToNext = true;
		job.rowCount = job.minRowCount + 1;
		System.enqueueJob(job);
		Test.stopTest();
	}
	@isTest static void testPull_ECallout2() {
		Test.setMock(HttpCalloutMock.class, new TestWSMock.HttpThrowECallout());
		Test.startTest();
		SyncMoby08SalesOrder job = new SyncMoby08SalesOrder();
		job.followOnToNext = true;
		job.rowCount = job.minRowCount - 1;
		System.enqueueJob(job);
		Test.stopTest();
	}

	@isTest
	static void testRefresh() {
		SyncMoby08SalesOrder.MobySalesOrderRes res = createObj();
		
		SyncMoby08SalesOrder job = new SyncMoby08SalesOrder();
		job.upsertSalesOrder(res);

		TestWSMock.SQL_QUEUE_API mock = new TestWSMock.SQL_QUEUE_API(200, JSON.serialize(res));
		Test.setMock(HttpCalloutMock.class, mock);
		Sales_Order__c[] sos = [SELECT Id FROM Sales_Order__c];
		Test.startTest();
		String ret = SyncMoby08SalesOrder.refreshSOrd(sos[0].Id);
		Test.stopTest();
		System.assert(!ret.containsIgnoreCase('Error'));
	}
}