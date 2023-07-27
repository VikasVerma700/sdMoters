public class UtilPhone {
   // private noltic_libphone.PhoneNumberUtil Util;

	public string input {
		get;
		set { input = value; parse(); } 
	}
	//public noltic_libphone.PhoneNumber output { get; private set; }
    public PhoneNumber output { get; private set; }
       
	public UtilPhone() {
       // System.debug('noltic_libphone.PhoneNumberUtil.getInstance() : '+noltic_libphone.PhoneNumberUtil.getInstance());
		//Util = noltic_libphone.PhoneNumberUtil.getInstance();
	}
	public UtilPhone(string phone) {
		this();
		input = phone;
	}
	
	public void parse() {
		/** Check length */
       // system.debug('input : '+input);
		if (String.isBlank(input) || input.replaceAll('\\D', '').length() < 6 || input == null) {
			output = null;
           // phonewrp = new PhoneNumber();
			return;
		}

		/** Check if starts with '0' - assume country code = MY */
		string nmbr = input.replaceAll('\\D', '');			// number only
        // system.debug('nmbr : '+nmbr);
		string pref = '+' + input;
		try {
			if (nmbr.startsWith('0') || nmbr.startsWith('1300') || nmbr.startsWith('1800')) {
              //  output = Util.parse(nmbr, 'MY');
                PhoneNumber wrp = new PhoneNumber();
                wrp.countryCode = 60;
                wrp.numberOfLeadingZeros = 1;
                wrp.countryCodeSource ='UNSPECIFIED';
                wrp.nationalNumber = nmbr.left(0)+nmbr.right(nmbr.length()-0-1); 
                output = wrp;
                return;
			}
			else {
				//output = Util.parse(pref, '');
                //system.debug('Util.parse : '+Util.parse(pref, ''));
                PhoneNumber wrp = new PhoneNumber();
                wrp.countryCode = 60;
                wrp.numberOfLeadingZeros = 1;
                wrp.countryCodeSource ='UNSPECIFIED';
                wrp.nationalNumber = nmbr.left(0)+nmbr.right(nmbr.length()-0-1); 
				output = wrp;
				return;
			}
		}
		catch (noltic_libphone.NumberParseException e) {
			/*switch on e.getMessage() {
				when 'Missing or invalid default region.' {
					output = Util.parse(input, 'MY');
					return;
				}
				when 'Could not interpret numbers after plus-sign.' {
					output = Util.parse(input.replace('+', ''), 'MY');
					return;
				}
				when 'The string supplied is too long to be a phone number.' {
					output = null;
					return;
				}
			} */
		}
    }
	/**
	 * Returns country code in ISO 3166-1 Alpha-2 format
	 * https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes
	 */
    public string getRegion() {
        return output.countryCodeSource = output.countryCode == 60 ? 'MY' : '' ;
        //return output == null ? null : Util.getRegionCodeForNumber(output);
    }
	/**
	 * Return country code in ISO-3166-1 Numeric format
	 * https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes
	 */
	public Integer getCountryCode() {
        return output.countryCode == null ? null : output.countryCode ;
		//return output == null ? null : output.getCountryCode();
	}

	/**
	 * Return phone number in E.164 format
	 * https://en.wikipedia.org/wiki/E.164
	 */
	public string toE164() {
		//if (output == null) { return null; } 
       if (output == null) { return null; }
        /** Do not append for 1300 / 1800 */
        // string national = Util.format(output, noltic_libphone.PhoneNumberUtil.PhoneNumberFormat.NATIONAL);
        // if (national.startsWith('1-300') || national.startsWith('1-800')) {
        //     return national;
        // }
        system.debug('input : '+input);
         String toE164 ;
        if(input.startsWith('0')){
            toE164 = '+6'+input.replace(' ', '');
        }
        if(input.startsWith('1')){
            toE164 = '+60'+input.replace(' ', '');
        }
        if(input.startsWith('6')){
            toE164 = '+'+input.replaceAll('\\D', '');
        }
        if(input.startsWith('+')){
            toE164 = '+'+input.replaceAll('\\D', '');
        }        
        if(input.isAlpha() || input.replaceAll('\\D', '').length() > 12){
            return null; 
        }
		//string ret = up.toE164();
      //  system.debug('toE164 : '+ret);
         return toE164;
        
      //  return (input.startsWith('0') ? '+6' : '+') + input.replace(' ', '');

       // return Util.format(output, noltic_libphone.PhoneNumberUtil.PhoneNumberFormat.E164);
    }
	public static string toE164(string phone) {
       String toE164 ;
		UtilPhone up = new UtilPhone(phone);
        if (up.input == null) { return null; }
        system.debug('input : '+up.input);
        if(up.input.startsWith('0')){
            toE164 = '+6'+up.input.replace(' ', '');
        }
        if(up.input.startsWith('1')){
            toE164 = '+60'+up.input.replace(' ', '');
        }
        if(up.input.startsWith('6')){
            toE164 = '+'+up.input.replaceAll('\\D', '');
        }
        if(up.input.startsWith('+')){
            toE164 = '+'+up.input.replaceAll('\\D', '');
        }        
        if(up.input.isAlpha() || up.input.replaceAll('\\D', '').length() > 12){
            return null; 
        }
		//string ret = up.toE164();
      //  system.debug('toE164 : '+ret);
         return toE164;
		//return ret; // == null ? phone : ret;
	}
	
	public string toNational() {
		if (output == null) { return null; }

        /** Do not append for 1300 / 1800 */
        // string national = Util.format(output, noltic_libphone.PhoneNumberUtil.PhoneNumberFormat.NATIONAL);
        // if (national.startsWith('1-300') || national.startsWith('1-800')) {
        //     return national;
       
        system.debug('national output : '+input);
        // system.debug(' national : '+Util.format(output, noltic_libphone.PhoneNumberUtil.PhoneNumberFormat.NATIONAL));
        if(input.containsWhitespace() ){
            
            system.debug('input.containsWhitespace() : '+input.containsWhitespace());
            
            List<String> res = input.split(' ', 2);
            return input == null ? null : (input.startsWith('0') ? res[0]+'-'+res[1] : input.replace(' ', '-') );
                
                }else{
                    return input == null ? null : input ;
                }
        
        
		//return Util.format(output, noltic_libphone.PhoneNumberUtil.PhoneNumberFormat.NATIONAL);
	}

	public string toInternational() {
		if (output == null) { return null; }

        /** Do not append for 1300 / 1800 */
        // string national = Util.format(output, noltic_libphone.PhoneNumberUtil.PhoneNumberFormat.NATIONAL);
        // if (national.startsWith('1-300') || national.startsWith('1-800')) {
        //     return national;
        // }
       // system.debug('International output : '+output);
         //system.debug(' International : '+Util.format(output, noltic_libphone.PhoneNumberUtil.PhoneNumberFormat.INTERNATIONAL));
        List<String> res = (input.left(0)+input.right(input.length()-0-1)).split(' ', 2);
        String tempStr = '+60 '+res[0]+'-'+res[1];
		 return input == null ? null : input.startsWith('0') ?  '+60 '+res[0]+'-'+res[1]: '+60 '+input.replace(' ', '-');
		//return Util.format(output, noltic_libphone.PhoneNumberUtil.PhoneNumberFormat.INTERNATIONAL);
	}

	public string toNoPrefixNumber() {
		if (input == null) { return null; }
		string e164 = toE164();

		return e164.removeStart('+60').removeStart('+65');
		// return to164().removeStart('+60').removeStart('+65');
        // system.debug('input 196 : '+input); 
		// String rem = input.replaceAll('\\D', '');
        // return input == null ? null : (rem.startsWith('0') ?  rem.removeStart('0') : rem) ;

		//string cc = '+' + String.valueOf(output.getCountryCode());
		//(rem .startsWith('0') ?  rem.removeStart('0') :
		//return Util.format(output, noltic_libphone.PhoneNumberUtil.PhoneNumberFormat.E164).replace(cc, '');
	}

	/**
	 * Fixed-line, Mobile, Toll-free, Premium Rate, Shared Cost, VoIP, Personal Numbers
	 * UAN, Pager, Voicemail (whenever feasible).
	 */
	public string getType() {
        system.debug('phonewrp.nationalNumber : '+output.nationalNumber); 
       //  system.debug('Util.getNumberType : '+String.valueOf(Util.getNumberType(output)));
		
        return output == null ? null : output.nationalNumber.startsWith('01') ? 'MOBILE' : 'STD';

       // return output == null ? null : String.valueOf(Util.getNumberType(output));
	}

	/**
	 * Match: EXACT_MATCH, NSN_MATCH, SHORT_NSN_MATCH 
	 * No match: NO_MATCH, NOT_A_NUMBER
	 */
	public string isMatchText(string phone) {
		if (output == null) { return null; }
		//noltic_libphone.PhoneNumberUtil.MatchType match = Util.isNumberMatch(output, phone);

        String matchStr ;
        if(output.nationalNumber != null){
            if('+6'+output.nationalNumber.replace(' ', '') == phone.replace(' ', '') || output.nationalNumber.replace(' ', '') == phone.replace(' ', '')){
                matchStr = 'EXACT_MATCH';
            }else if('6'+output.nationalNumber.replace(' ', '') == phone.replace(' ', '')){
                 matchStr = 'NSN_MATCH';
            }else if(output.nationalNumber.replace(' ', '') != phone.replaceAll(' ', '') && phone.isNumeric()){
                 matchStr = 'NO_MATCH';
            }else if(phone.isAlpha() ){
                 matchStr = 'NOT_A_NUMBER';
            }
        } 

        return matchStr;
		//return String.valueOf(match);
	}
	public Boolean isMatch(string phone) {
		switch on isMatchText(phone) {
			when 'EXACT_MATCH', 'NSN_MATCH', 'SHORT_NSN_MATCH' {
				return true;
			}
			when else { return false; }
		}
	}
    
    public class PhoneNumber{
        public Integer countryCode;
        public string countryCodeSource;
        public string extension;
        public String isItalianLeadingZero;
        public string nationalNumber;
        public Integer numberOfLeadingZeros;
        public string preferredDomesticCarrierCode;
        public string rawInput;
    }
}