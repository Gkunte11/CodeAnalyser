public with sharing class AnthropicService {

    private static final String namedCred = 'callout:ClaudeAI'

    @AuraEnabled(cacheable=false)
    public static string explainCode(){
        try {
            
            HttpRequest req = new HttpRequest();
            req.setEndPoint(namedCred + '/v1/messages');
            req.setMethod('POST');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');

            Http http = new Http();
            HttpResponse resp = http.send(req);

            if(resp.getStatusCode() == 200){
                System.debug('Successful Callout' + resp.getBody());
                return resp.getBody();
            }

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}