Trigger EmailMessage on EmailMessage(before insert, after insert){
    /*
    List<EmailMessage> emailMsgList = new List<EmailMessage>();
    if(Trigger.isAfter){
        List<Messaging.SingleEmailMessage> singleEmailList = new List<Messaging.SingleEmailMessage>();
        for(EmailMessage emailMsg: Trigger.new){
            if(emailMsg.subject.contains('Report Results')){
                Messaging.SingleEmailMessage copyMsg = new Messaging.SingleEmailMessage();
                copyMsg.setPlainTextBody(emailMsg.TextBody);
                copyMsg.setSubject('Report');
                List<String> recipientList = new List<String>();
                if(emailMsg.subject != null){
                    recipientList.addAll(emailMsg.ToAddress.split(';'));
                }
                recipientList.add('harsh_c@iconresources.com');

                copyMsg.setToAddresses(recipientList);
                System.debug(copyMsg.getToAddresses());
                singleEmailList.add(copyMsg);
            }
        }
        Messaging.sendEmail(singleEmailList);
    }
    /*
    else{
        for(EmailMessage emailMsg: Trigger.new){
            if(true){
                System.debug('before');
                System.debug(emailMsg.ToAddress);
                List<String> currentAddressList = emailMsg.ToAddress.split(';');
                currentAddressList.add('cw.tham@simedarby.com');
                emailMsg.ToAddress = String.join(currentAddressList, ';');
                System.debug(emailMsg.ToAddress);
            }
        }
    }
*/

}