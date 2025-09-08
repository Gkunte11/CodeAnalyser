/* 

    Phase 1 of this project: Create a simple LWC component that takes in a code snippet and returns a JSON response from Claude AI. 
    
    Phase 2 of this project: 
    
        1. Add the ability to upload a file or paste the code snippet 
        2. Add the optional ability to explain the code line by line 
        3. Add the ability to upload only a selected type of files. 
    

    Phase 3 of this project:
        1. Include Batch Processing for larger files or bigger codes 
        2. Optimization suggestion option
        3. Whenever the code is pasted or when the file is uploaded, create a record of the interaction on a custom object that stores the input code, 
           optimization suggestions, claude raw response and file attachments

    Phase 4 of this project:
        1. Ensure the security checks are consistent as there shouldn't be any malicious files or codes being uploaded
        2. Ensure the file size is not more than 1 mb as it might lead to performance issues with Claude
*/




public with sharing class ClaudeServiceCall {

    private static final String namedCred = 'callout:ClaudeAI';

    @AuraEnabled(cacheable=false)
    public static string explainCode(String codeSnippet, Boolean lineByLine, Boolean optimizationRequested){
        


        if(codeSnippet == null || codeSnippet == ''){
            throw new CalloutException('Code snippet cannot be empty');
        }

        String prompt = 'You are an expert Software Engineer. Analyse the code and provide  an explanation of the code.';
        
        if(lineByLine){

            prompt += ' Provide a line-by-line explanation of the code in JSON format. The JSON format should return with fields: explanation, line_by_line. ';
        }

        if(optimizationRequested){

            prompt += ' Provide suggestions on how to make the code optimized, if there are any performance improvement steps to carry and if there are any best practices that need to be followed';
        }
            
        prompt += '\n\nHere is the code: \n' + codeSnippet;

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

        String claudeResponse = resp.getBody();
        

        if(resp.getStatusCode() >= 200 && resp.getStatusCode() < 300){

            String optimizations;

            if(optimizationRequested){

                optimizations = getOptimizationSuggestions(claudeResponse);
            }
            Code_Analysis_History__c history = new 	Code_Analysis_History__c(

                Input_code__c = codeSnippet,
                Line_by_Line__c = lineByLine,
                Claude_Response__c = claudeResponse,
                Optimization_Suggestions__c = optimizations,
                Optimization_Requested__c = optimizationRequested
                // = 
                //Status__c = 
                //User__c = 
            );

            insert history;
            return claudeResponse;
        }

        else{
            throw new CalloutException('Callout failed with the following message' + resp.getStatusCode() + ' ' + resp.getBody());
        }

        
    }

    //deserializing the JSON response and extracting the "text" key to check if the keywords exist based on performance improvement or optimization suggestions and returning the text
    public static String getOptimizationSuggestions(String claudeResponse){

        if (String.isBlank(claudeResponse)) {
            return '';
        }

        try {
            
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(claudeResponse);
            if(responseMap.containsKey('content')){
                
                List<Object> content = (List<Object>) responseMap.get('content');
                
                if(!content.isEmpty()){
                    
                    Map<String, Object> contentMap = (Map<String, Object>) content[0];
                    
                    String optText = (String) contentMap.get('text');
                    
                    if(optText != null && (optText.toLowerCase().contains('optimize') || optText.toLowerCase().contains('improve')) || optText.toLowerCase().contains('best practices') || optText.toLowerCase().contains('performance') || optText.toLowerCase().contains('optimization')){
                        return optText;
                    }
                    else{
                        return 'No optimizations were suggested by Claude';
                    }
                }
            }
        } 
            

        catch (Exception e) {
            System.debug(e.getMessage());
        }

        return 'No optimizations were suggested by Claude';
    }
}