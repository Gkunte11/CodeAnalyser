public with sharing class ClaudeServiceCall {

    private static final String namedCred = 'callout:ClaudeAI';

    @AuraEnabled
    
    public static Id startFileAnalysis(String contentDocumentId, Boolean lineByLine, Boolean optimizationRequested){


        Code_Analysis_History__c historyRecord = new Code_Analysis_History__c(
            
            Input_code__c = null,
            Line_by_Line__c = lineByLine,
            Optimization_Requested__c = optimizationRequested,
            Status__c = 'Queued',
            Processed__c = false
        );

        insert historyRecord;

        Database.executeBatch(new CodeAnalysisBatchJob(contentDocumentId, historyRecord.Id, lineByLine, optimizationRequested), 1);

        return historyRecord.Id;
    }



    @AuraEnabled
    public static string explainFileCode(String codeSnippet, Boolean lineByLine, Boolean optimizationRequested){
        
        try{


                Anthropic_Credential__mdt cred = [
                    SELECT Api_Key__c FROM Anthropic_Credential__mdt LIMIT 1
                ];
    
                String apiKey = cred.Api_Key__c;


                if(codeSnippet == null || codeSnippet == ''){
                    throw new CalloutException('Code snippet cannot be empty');
                }

                String prompt = 'You are an expert software engineer. Analyze the provided code. ' +
                        'Return a JSON object with two fields: ' +
                        '"explanation" (a clear explanation of what the code does) and ' +
                        '"optimizations" (suggested improvements or performance/best-practice changes). ' +
                        'If a line-by-line explanation is requested, include that inside "explanation".' +
                        '\n\nCode:\n' + codeSnippet;
            
                
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
                    
                    return claudeResponse;
                }

                else{
                    throw new CalloutException('Callout failed with the following message' + resp.getStatusCode() + ' ' + resp.getBody());
                }


        }
        
        catch(Exception e){

            throw new CalloutException('Callout failed with the following message' + e.getMessage());
        }
 

        
    }

    @AuraEnabled
    public static String startPasteAnalysis(String codeSnippet, Boolean lineByLine, Boolean optimizationRequested){

        try{


            Anthropic_Credential__mdt cred = [
                SELECT Api_Key__c FROM Anthropic_Credential__mdt LIMIT 1
            ];

            String apiKey = cred.Api_Key__c;


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
                
                return claudeResponse;
            }

            else{
                throw new CalloutException('Callout failed with the following message' + resp.getStatusCode() + ' ' + resp.getBody());
            }


        }
    
        catch(Exception e){

            throw new CalloutException('Callout failed with the following message' + e.getMessage());
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

    @AuraEnabled
    public static String getHistoryResults(String historyId){

        System.debug('I\'m in the history results section to test polling');
        if (historyId == null){

            throw new AuraHandledException('Missing historyId');
        }
        
        

        Code_Analysis_History__c history = [
            SELECT Id, Claude_Response__c, Optimization_Suggestions__c, Input_Code__c, Explanation__c, Status__c
            FROM Code_Analysis_History__c
            WHERE Id = :historyId LIMIT 1
        ];

        Map<String,Object> out = new Map<String,Object>{
            'historyId' => history.Id,
            'rawResponse' => (history.Claude_Response__c == null ? '' : history.Claude_Response__c),
            'optimizationSuggestions' => (history.Optimization_Suggestions__c == null ? '' : history.Optimization_Suggestions__c),
            'explanation' => (history.Explanation__c == null ? '' : history.Explanation__c),
            'inputCode' => (history.Input_Code__c == null ? '' : history.Input_Code__c),
            //'createdDate' => String.valueOf(h.CreatedDate),
            'status' => (history.Status__c == null ? '' : history.Status__c)
        };
        return JSON.serialize(out);

    }

    @AuraEnabled
    public static String getHistoryStatus(Id historyId) {
       
        Code_Analysis_History__c hist = [
            SELECT Id, Status__c, Processed__c
            FROM Code_Analysis_History__c
            WHERE Id = :historyId
            LIMIT 1
        ];

        Map<String, Object> result = new Map<String, Object>();
        result.put('status', hist.Status__c);
        result.put('processed' , (hist.Processed__c == null ? false : hist.Processed__c));
        //result.put('explanation', hist.Explanation__c);
        //result.put('optimizations', hist.Optimizations__c);

        return JSON.serialize(result);
    }

}