@RestResource(urlMapping='/cust/*/webhook')
global class CustAppCallback {
	@HttpPost
	global static void callback() {
		RestRequest req = RestContext.request;
		RestResponse res = RestContext.response;
		Savepoint sp;
		try {
			System.debug(req.requestBody.toString());
			CallbackReq reqBody = (CallbackReq) JSON.deserialize(req.requestBody.toString(), CallbackReq.class);
			switch on reqBody.event {
				when 'SEND_TEST_DRIVE_REQUEST' {
					/** From: AB Customer App (Nerv)
					 *    To: Moby
					 * */
					// MOBY_API_TestDrive.processCallback();
					MobyApiTestDrive.processWhipCallback();
				}
				when 'UPSERT_TEST_DRIVE' {
					/** From: Moby
					 * 	  To: AB Customer App (Nerv)
					 */
					MobyApiTestDrive.processMobyCallback();
				}
				when 'RETURN_TEST_DRIVE_REQUEST' {
					/** Callback from Moby (request to AB Customer App) */
					CustAppTD.TDWebhook td = MOBY_API_TestDrive.sendWebhook();
					res.responseBody = Blob.valueOf(JSON.serialize(td));
					res.statusCode = 200;
				}
				when else {
					sp = Database.setSavepoint();
					switch on reqBody.event {
						when 'UPDATE_ACCOUNT' {
							if (req.requestURI.containsIgnoreCase('v1.0')) {
								CustAppAccount.processV1Callback();
							} else {
								CustAppAccount.processCallback();
							}
						// } when 'UPSERT_LTA_VEHICLE' {
							// CustAppVehicle.processCallback();
						} when 'UPSERT_VEHICLE_ALTERNATE_DRIVER' {
							CustAppAltDriver.processAddCallback();
						} when 'REMOVE_VEHICLE_ALTERNATE_DRIVER' {
							CustAppAltDriver.processRemoveCallback();
						} when 'SEND_TEST_DRIVE_REQUEST' {
							CustAppTD.processCallback();
						} when 'SEND_ENQUIRY' {
							if (req.requestURI.containsIgnoreCase('v1.0')) {
								CustAppEnquiry.processCallback();
							} else if (req.requestURI.containsIgnoreCase('v1.1')) {
								CustAppEnquiry.processCallback();
							}
						} when 'SEND_TRADE_IN' {
							CustAppTradeInEnquiry.processCallback();
						} when 'UPSERT_MARKETING_RSVP' {
							CustAppCampaignMember.processCallback();
						} when 'REMOVE_VEHICLE_INSURANCE' {
							CustAppInsurance.processRemoveCallback();
						} when 'UPSERT_VEHICLE_INSURANCE' {
							CustAppInsurance.processAddCallback();
						} when 'SEND_NOTIFICATION_READ_RECEIPT' {
							try { CustAppNotification.processCallback(); }
							catch (Exception e) {
								/** catching this to prevent Invalid inbox message id. email being sent */
							}
						} when 'UPDATE_RO' {
							CustAppRO.processUpdateCallback();
						} when 'SEND_PAYMENT_RECEIPT' {

						} when else {
							throw new CustAppAPI.CustAppException('Unhandled event:' + reqBody.event);
						}
					}
				}
			}
		} catch (Exception e) {
			if (sp != null) { Database.rollback(sp); }
			String emailBody = CommonMethodsLibrary.constructErrEmail('Error from CustAppCallback', e.getStackTraceString(), e.getMessage()
				  + '\n\nRequest:\n' + req.requestBody.toString());
			CommonMethodsLibrary.sendErrorEmail(CustAppAPI.EMAIL_LIST, emailBody);
			res.statusCode = 500;
			CallbackError err = new CallbackError();
			err.message = e.getMessage();
			res.responseBody = Blob.valueOf(JSON.serialize(err));
		}
	}

	global class CallbackReq {
		public String event;
	}

	global class CallbackError {
		public String message;
	}
}