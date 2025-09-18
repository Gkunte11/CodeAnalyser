public with sharing class ClaudeServiceCall {

    private static final String namedCred = 'callout:ClaudeAI';


    // This function is to start async processing of files with bigger codes
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
        
        


        Anthropic_Credential__mdt cred = [ SELECT Api_Key__c FROM Anthropic_Credential__mdt LIMIT 1];
    
        String apiKey = cred.Api_Key__c;
    
        /*

            Apex doesn’t have a direct JSON object literal like JavaScript. 
            The easiest way to construct JSON is to build an Apex Map<String, Object> for key-value pairs, and List<Object> for arrays. 
            Then we call JSON.serialize() to convert them into a valid JSON string.

        */

        String prompt = 'You are an expert software engineer. Analyze the provided code. ' +
                'Return a JSON object with two fields: ' +
                '"explanation" (a clear explanation of what the code does) and ' +
                '"optimizations" (suggested improvements or performance/best-practice changes). ' +
                '\n\nCode:\n' + codeSnippet;

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
        
        try{

            HttpResponse resp = http.send(req);

            if(resp.getStatusCode() >= 200 && resp.getStatusCode() < 300){

                return resp.getBody();
            }

            else{
                throw new CalloutException('HTTP call failed with the following message ' + resp.getStatusCode() + ' ' + resp.getBody());
            }
        }

        catch(Exception ex){
            throw new CalloutException('Callout failed with the following message' + ex.getMessage());
        }
        
        
    }

    // This function is to handle code analysis synchronously for smaller code snippets
    @AuraEnabled
    public static String startPasteAnalysis(String codeSnippet, Boolean lineByLine, Boolean optimizationRequested){

        if(codeSnippet == null || codeSnippet == ''){
            throw new CalloutException('Code snippet cannot be empty');
        }

        // Code_Analysis_History__c historyRecord = new Code_Analysis_History__c(

        //     Input_code__c = codeSnippet,
        //     Line_by_Line__c = lineByLine,
        //     Optimization_Requested__c = optimizationRequested,
        //     Status__c = 'Processing',
        //     Processed__c = false
        // );

        // insert historyRecord;

        try{

            String rawResponse = explainFileCode(codeSnippet, lineByLine, optimizationRequested);

            Code_Analysis_History__c historyRecord = new Code_Analysis_History__c(

                Input_code__c = codeSnippet,
                Line_by_Line__c = lineByLine,
                Optimization_Requested__c = optimizationRequested,
                Status__c = 'Processing',
                Processed__c = false
            );

            insert historyRecord;

            Map<String, String> parsedResponse = parseContent(rawResponse);

            saveAnalysisAsRecord(historyRecord.Id, parsedResponse.get('explanation'), parsedResponse.get('optimizations'), rawResponse);

            historyRecord.Status__c = 'Completed';
            historyRecord.Processed__c = true;
            update historyRecord;

            Map<String,Object> out = new Map<String,Object>{
                'historyId' => historyRecord.Id,
                'rawResponse' => rawResponse
            };

            return JSON.serialize(out);

        }

        catch(Exception ex){

            // historyRecord.Status__c = 'Failed';
            // historyRecord.Processed__c = true;
            // historyRecord.Claude_Response__c = ex.getMessage();
            // update historyRecord;

            throw new CalloutException('Callout failed with the following message' + ex.getMessage());
        }

    }


    //deserializing the JSON response and extracting the "text" key to check if the keywords exist based on performance improvement or optimization suggestions and returning the text
    public static Map<String, String> parseContent(String claudeResponse){

        Map<String, String> result = new Map<String, String>{

            'explanation' => '',
            'optimizations' => ''
        };
        
        if (String.isBlank(claudeResponse)) {
            return result;
        }

        try {
            

            Object parsed = JSON.deserializeUntyped(claudeResponse);

            if(parsed instanceof Map<String, Object>){

                Map<String, Object> parsedString = (Map<String, Object>) parsed;

                List<String> explanationKeys = new List<String>{'explanation','explanations','code_explanation','explain','output'};
                List<String> optimizationKeys = new List<String>{'optimizations','optimization','optimization_suggestions','suggestions'};

                // find the explanation key and append the string to the main result
                for (String str : explanationKeys) {
                    if (parsedString.containsKey(str) && parsedString.get(str) != null) {
                        result.put('explanation', String.valueOf(parsedString.get(str)));
                        break;
                    }
                }

                // find optimizations and append to the result
                for (String str : optimizationKeys) {
                    if (parsedString.containsKey(str) && parsedString.get(str) != null) {
                        result.put('optimizations', String.valueOf(parsedString.get(str)));
                        break;
                    }
                }

                //If Claude didn’t explicitly return an explanation, then take the longest text field (or concatenated list of texts) from the JSON and use that as the explanation
                if (String.isBlank(result.get('explanation'))) {
                    // iterate values and pick the longest string value as explanation
                    String best = '';
                    for (Object value : parsedString.values()) {
                        
                        if (value instanceof String) {
                            String str = (String) value;
                            
                            if (str.length() > best.length()) {
                                best = str;
                            }

                        } 
                        //If the field is a list (Claude sometimes returns lists of sentences/steps)
                        else if (value instanceof List<Object>) {
                            // join list strings
                            List<Object> lst = (List<Object>) value;
                            String joined = '';
                            
                            for (Object o : lst) {
                                joined += (o == null ? '' : String.valueOf(o)) + '\n';
                            }
                            
                            if (joined.length() > best.length()) {
                                best = joined;
                            }
                        }
                    }
                    if (!String.isBlank(best)) {

                        result.put('explanation', best);
                    }
                }

                // final fallback: serialize entire parsed object
                if (String.isBlank(result.get('explanation'))) {
                    result.put('explanation', JSON.serialize(parsed));
                }
                return result;

            }
        }

        catch(Exception ex) {

        }
            
        return result;
    }

    @AuraEnabled
    public static void saveAnalysisAsRecord(String historyId, String explanation, String optimizationSuggestions, String claudeResponse){

        if(String.isBlank(historyId)){
            return;
        }

        Code_Analysis_History__c historyRecord = [SELECT Id, Explanation__c, Optimization_Suggestions__c, Claude_Response__c FROM Code_Analysis_History__c WHERE Id = :historyId LIMIT 1];
        
        // appending the explanation and optimization suggestions as the batch processing will add explanation of small chunks of code
        if(!String.isBlank(explanation)){

            String baseExp = historyRecord.Explanation__c == null ? '' : historyRecord.Explanation__c;
            historyRecord.Explanation__c = baseExp + '\n\n' + explanation;
            
        }

        if(!String.isBlank(optimizationSuggestions)){

            String baseOpt = historyRecord.Optimization_Suggestions__c == null ? '' : historyRecord.Optimization_Suggestions__c;
            historyRecord.Optimization_Suggestions__c = baseOpt + '\n\n' + optimizationSuggestions;
            
        }

        if(!String.isBlank(claudeResponse)){

            String baseRaw = historyRecord.Claude_Response__c == null ? '' : historyRecord.Claude_Response__c;
            historyRecord.Claude_Response__c = baseRaw + '\n\n' + claudeResponse;
            
        }

        update historyRecord;

    }

    @AuraEnabled
    public static String getHistoryResults(String historyId){

        System.debug('I\'m in the history results section to test polling');
        if (historyId == null){

            throw new AuraHandledException('Missing history record');
        }
        
        

        Code_Analysis_History__c history = [
            SELECT Id, Claude_Response__c, Optimization_Suggestions__c, Input_Code__c, Explanation__c, Status__c
            FROM Code_Analysis_History__c
            WHERE Id = :historyId LIMIT 1
        ];

        Map<String,Object> response = new Map<String,Object>{
            'historyId' => history.Id,
            'rawResponse' => (history.Claude_Response__c == null ? '' : history.Claude_Response__c),
            'optimizationSuggestions' => (history.Optimization_Suggestions__c == null ? '' : history.Optimization_Suggestions__c),
            'explanation' => (history.Explanation__c == null ? '' : history.Explanation__c),
            'inputCode' => (history.Input_Code__c == null ? '' : history.Input_Code__c),
            'status' => (history.Status__c == null ? '' : history.Status__c)
        };
        return JSON.serialize(response);

    }

    @AuraEnabled
    public static String getHistoryStatus(Id historyId) {
       
        if (historyId == null){

            throw new AuraHandledException('Missing history record');
        }
        
        Code_Analysis_History__c hist = [
            SELECT Id, Status__c, Processed__c
            FROM Code_Analysis_History__c
            WHERE Id = :historyId
            LIMIT 1
        ];

        Map<String, Object> result = new Map<String, Object>();
        result.put('status', hist.Status__c);
        result.put('processed' , (hist.Processed__c == null ? false : hist.Processed__c));

        return JSON.serialize(result);
    }

}