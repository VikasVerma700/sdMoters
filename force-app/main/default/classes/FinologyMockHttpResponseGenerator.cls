@isTest
global class FinologyMockHttpResponseGenerator implements HttpCalloutMock {
    global static HTTPResponse respond(HTTPRequest req) {
        HttpResponse mockResp = new HttpResponse();
        mockResp.setHeader('Content-Type', 'application/json');
        FinologyVehicleInfo.Vehicle_details vs = new FinologyVehicleInfo.Vehicle_details();
        vs.vehicle_registration_no = '';
        vs.chassis_no = '';
        vs.engine_no = '';
        vs.nvic_code = '';
        vs.vehicle_cc = '2';
        vs.vehicle_make = '';
        vs.vehicle_model = '';
        vs.vehicle_model_code = '';
        vs.vehicle_make_year = '';
        vs.ism_insured_value = '200';
        vs.vehicle_class = '';
        vs.vehicle_seat = '5';
        vs.vehicle_transmission_type = '';
        vs.vehicle_use = '';
        vs.market_value = '1500';
        vs.vehicle_fuel_type = '';
        vs.vehicle_build_type = '';
            
        FinologyVehicleInfo.Ncd_details ncd = new FinologyVehicleInfo.Ncd_details();
        ncd.next_ncd_percent = '3';
        ncd.current_ncd_expiry_date = String.valueOf(date.today());
        
        FinologyVehicleInfo.Response resp = new FinologyVehicleInfo.Response();
        resp.ncd_details = ncd;
        resp.vehicle_details = vs;

        FinologyVehicleInfo.Detail dtl = new FinologyVehicleInfo.Detail();
        dtl.ncd_details = ncd;
        dtl.vehicle_details = vs;
        
        FinologyVehicleInfo.Errors err = new FinologyVehicleInfo.Errors();
        err.message = 'test';
        err.error_code = 'L44';
        err.detail = dtl;
        
        FinologyVehicleInfo.ErrorResponse errResp = new FinologyVehicleInfo.ErrorResponse();
        errResp.code = 200;
        errResp.errors = err;

        FinologyVehicleInfo.GetResponse key = new FinologyVehicleInfo.GetResponse();
        key.code = 200; 
        key.vix_transaction_code = '200';
        key.message = 'this is test API';
        key.ref_code = UserInfo.getOrganizationId();
        key.response = resp;
        
        mockResp.setBody(JSON.serialize(key));
        mockResp.setStatusCode(200);
        return mockResp;
    }
}