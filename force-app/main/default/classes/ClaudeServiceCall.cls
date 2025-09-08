/* 

    Phase 1 of this project: Create a simple LWC component that takes in a code snippet and returns a JSON response from Claude AI. 
    
    Phase 2 of this project: 
    
        1. Add the ability to upload a file or paste the code snippet 
        2. Add the optional ability to explain the code line by line 
        3. Add the ability to upload only a selected type of files. 
    

    Phase 3 of this project:
        1. Include Batch Processing for larger files or bigger codes 
        2. Pptimization suggestion option
        3. Whenever the code is pasted or when the file is uploaded, create a record of the interaction on a custom object that stores the input code, 
           optimization suggestions, claude raw response and file attachments

    Phase 4 of this project:
        1. Ensure the security checks are consistent as there shouldn't be any malicious files or codes being uploaded
        2. Ensure the file size is not more than 1 mb as it might lead to performance issues with Claude
*/




public with sharing class ClaudeServiceCall {

    private static final String namedCred = 'callout:ClaudeAI';

    @AuraEnabled(cacheable=false)
    public static string explainCode(String codeSnippet, Boolean lineByLine){
        

            String prompt = 'You\'re an expert Software Engineer. Explain the code';
            
            if(lineByLine){

                prompt += ' in a line-by-line JSON format. The JSON format should return with fields: explanation, line_by_line';
            }
                
            prompt += ':\n\n' + codeSnippet;

            /*
            
            Apex doesn’t have a direct JSON object literal like JavaScript. 
            The easiest way to construct JSON is to build an Apex Map<String, Object> for key-value pairs, and List<Object> for arrays. 
            Then we call JSON.serialize() to convert them into a valid JSON string.

            */

            Map<String,Object> payload = new Map<String,Object>{

                'model' => 'claude-sonnet-4-20250514',
                'max_tokens' => 2000,
                'messages' => new List<Object>{
                    new Map<String,Object>{
                        'role' => 'user',
                        'content' => prompt
                    }
                }
            };

            Anthropic_Credential__mdt cred = [
                SELECT Api_Key__c FROM Anthropic_Credential__mdt LIMIT 1
                ];
        
            String apiKey = cred.Api_Key__c;

            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndPoint(namedCred + '/v1/messages');
            req.setMethod('POST');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('anthropic-version', '2023-06-01');
            req.setHeader('x-api-key', apiKey);

            req.setTimeout(120000);

            req.setBody(JSON.serialize(payload));
            HttpResponse resp = http.send(req);

            if(resp.getStatusCode() >= 200 && resp.getStatusCode() < 300){
                //System.debug('Successful Callout' + resp.getBody());
                return resp.getBody();
            }

            else{
                throw new CalloutException('Callout failed with the following message' + resp.getStatusCode() + ' ' + resp.getBody());
            }

        
    }
}