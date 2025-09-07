public with sharing class AnthropicService {

    private static final String namedCred = 'callout:ClaudeAI'

    @AuraEnabled(cacheable=false)
    public static string explainCode(String codeSnippet){
        try {
            
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndPoint(namedCred + '/v1/messages');
            req.setMethod('POST');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');

            String prompt = 'Explain the provided apex code line by line in the Json format. The return response format should be with ' + 
                        'fields: explanation (string), ' +
                        'line_by_line (array of {line, explanation}). ' +
                        'Explain this Apex code line-by-line:\n\n' + codeSnippet;

            /*
            
            Apex doesn’t have a direct JSON object literal like JavaScript. 
            The easiest way to construct JSON is to build an Apex Map<String, Object> for key-value pairs, and List<Object> for arrays. 
            Then we call JSON.serialize() to convert them into a valid JSON string.

            */

            Map<String,Object> payload = new Map<String,Object>{

                'model' => 'claude-sonnet-4-20250514',
                'max_tokens' => 1000,
                'messages' => new List<Object>{
                    new Map<String,Object>{
                        'role' => 'user',
                        'content' => prompt
                    }
                }
            };

            req.setBody(JSON.deSerialize(payload));

            
            HttpResponse resp = http.send(req);

            if(resp.getStatusCode() >= 200 && resp.getStatusCode() < 300){
                System.debug('Successful Callout' + resp.getBody());
                return resp.getBody();
            }

        } catch (Exception e) {
            throw new CalloutException('Callout failed with the following message' + e.getMessage());
        }
    }
}