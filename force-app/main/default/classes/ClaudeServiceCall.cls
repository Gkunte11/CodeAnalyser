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

            throw new CalloutException('Callout failed with the following message' + ex.getMessage());
        }

    }


    //deserializing the JSON response and extracting the "text" key to check if the keywords exist based on performance improvement or optimization suggestions and returning the text
    public static Map<String, String> parseContent(String claudeResponse) {
        
        Map<String, String> result = new Map<String, String>{
            'explanation' => '',
            'optimizations' => ''
        };
                    
        if(String.isBlank(claudeResponse)) {          
            return result;         
        }
        
        //System.debug('parseContent - RAW RESPONSE: ' + claudeResponse);
        
        // Helper: try to extract a likely JSON/text payload from various wrapper formats
        
        String candidate = claudeResponse.trim();
        
        // 1) If it's valid JSON, attempt to find usable text fields
        
        try {
            
            Object topObj = JSON.deserializeUntyped(candidate);
            if (topObj instanceof Map<String, Object>) {
                
                Map<String, Object> topMap = (Map<String, Object>) topObj;
                
                // Common wrapper keys that may contain the inner text/json
                List<String> wrapperKeys = new List<String>{'text','completion','output','response','result','message','choices','body'};
                            
                    // Try to extract a string payload from those keys
                    for (String k : wrapperKeys) {
                        if (topMap.containsKey(k) && topMap.get(k) != null) {
                            Object v = topMap.get(k);
                            
                            // string -> use it
                            if (v instanceof String) {
                                candidate = (String) v;
                                break;
                            }
                            
                            // list -> look for first usable element (choices/messages)
                            if (v instanceof List<Object>) {
                                List<Object> lst = (List<Object>) v;
                                if (!lst.isEmpty()) {
                                    Object first = lst[0];
                                    if (first instanceof String) {
                                        candidate = (String) first;
                                        break;
                                    } else if (first instanceof Map<String, Object>) {
                                        Map<String, Object> fm = (Map<String, Object>) first;
                                        // look for message.content or text inside choice object
                                        if (fm.containsKey('message')) {
                                            Object msg = fm.get('message');
                                            if (msg instanceof Map<String, Object>) {
                                                Map<String, Object> mm = (Map<String, Object>) msg;
                                                // content could be string or map
                                                if (mm.containsKey('content') && mm.get('content') instanceof String) {
                                                    candidate = (String) mm.get('content');
                                                    break;
                                                }
                                                // some formats: content -> {type: 'text', parts: [...]}
                                                if (mm.containsKey('content') && mm.get('content') instanceof List<Object>) {
                                                    List<Object> parts = (List<Object>) mm.get('content');
                                                    String joined = '';
                                                    for (Object p : parts) joined += (p == null ? '' : String.valueOf(p));
                                                    if (!String.isBlank(joined)) {
                                                        candidate = joined;
                                                        break;
                                                    }
                                                }
                                            }
                                        }
                                        if (fm.containsKey('text') && fm.get('text') instanceof String) {
                                            candidate = (String) fm.get('text');
                                            break;
                                        }
                                    }
                                }
                            }
                            
                            // map -> maybe content string inside map
                            if (v instanceof Map<String, Object>) {
                                Map<String, Object> m = (Map<String, Object>) v;
                                if (m.containsKey('content') && m.get('content') instanceof String) {
                                    candidate = (String) m.get('content');
                                    break;
                                }
                                if (m.containsKey('text') && m.get('text') instanceof String) {
                                    candidate = (String) m.get('text');
                                    break;
                                }
                            }
                        }
                    }
                
                // If none of the wrapper keys yielded a candidate, keep candidate as original JSON (we will attempt inner parsing later).
            }
        } catch (Exception ex) {
            // Not parseable JSON at top-level — we'll try to extract inner JSON/code-fence next.
        }
        
        // 2) Remove Apex map-like wrapper if present: e.g. {text=```json\n{...}\n``` , type=text}
        //    Look for 'text=' pattern and extract until a likely delimiter (', type=' or end brace).
        Integer textIdx = candidate.toLowerCase().indexOf('text=');
        if (textIdx > -1) {
            Integer start = textIdx + 5;
            Integer delim = candidate.toLowerCase().indexOf(', type=', start);
            if (delim == -1) delim = candidate.lastIndexOf('}');
            if (delim == -1) delim = candidate.length();
            String extracted = candidate.substring(start, Math.min(delim, candidate.length())).trim();
            // if extracted starts with backticks, keep it (further cleaning below)
            if (!String.isBlank(extracted)) candidate = extracted;
        }
        
        candidate = candidate.trim();
        
        // 3) Strip triple-backtick fences if present (```json ... ``` or ``` ... ```)
        Integer fenceStart = candidate.indexOf('```');
        if (fenceStart != -1) {
            Integer fenceEnd = candidate.lastIndexOf('```');
            if (fenceEnd > fenceStart) {
                candidate = candidate.substring(fenceStart + 3, fenceEnd).trim();
            } else {
                // remove remaining fences
                candidate = candidate.replace('```','').trim();
            }
        }
        
        // 4) If candidate contains leading language tag like: "json\n{...}", find first '{'
        Integer firstBrace = candidate.indexOf('{');
        Integer lastBrace = candidate.lastIndexOf('}');
        if (firstBrace > -1 && lastBrace > firstBrace) {
            String innerJson = candidate.substring(firstBrace, lastBrace + 1);
            // Try to parse this inner JSON
            try {
                Object innerObj = JSON.deserializeUntyped(innerJson);
                if (innerObj instanceof Map<String, Object>) {
                    Map<String, Object> innerMap = (Map<String, Object>) innerObj;
                    
                    // Explanation keys
                    List<String> explanationKeys = new List<String>{'explanation','explanations','code_explanation','explain','output','analysis','text'};
                        for (String k : explanationKeys) {
                            if (innerMap.containsKey(k) && innerMap.get(k) != null) {
                                Object v = innerMap.get(k);
                                if (v instanceof String) {
                                    result.put('explanation', String.valueOf(v));
                                } else if (v instanceof List<Object>) {
                                    // join list items
                                    List<Object> lst = (List<Object>) v;
                                    String joined = '';
                                    for (Object it : lst) joined += (it == null ? '' : String.valueOf(it)) + '\n';
                                    result.put('explanation', joined.trim());
                                } else {
                                    result.put('explanation', String.valueOf(v));
                                }
                                break;
                            }
                        }
                    
                    // Optimizations keys
                    List<String> optimizationKeys = new List<String>{'optimizations','optimization','optimization_suggestions','suggestions','improvements'};
                        for (String k : optimizationKeys) {
                            if (innerMap.containsKey(k) && innerMap.get(k) != null) {
                                Object v = innerMap.get(k);
                                
                                // If it's a list of strings
                                if (v instanceof List<Object>) {
                                    List<Object> lst = (List<Object>) v;
                                    List<String> flat = new List<String>();
                                    for (Object o : lst) {
                                        if (o instanceof String) {
                                            flat.add(String.valueOf(o));
                                        } else if (o instanceof Map<String, Object>) {
                                            // If item is an object (e.g. {category:..., suggestions:[...]})
                                            Map<String, Object> itemMap = (Map<String, Object>) o;
                                            if (itemMap.containsKey('category') && itemMap.containsKey('suggestions')) {
                                                String cat = String.valueOf(itemMap.get('category'));
                                                flat.add('Category: ' + cat);
                                                Object suggs = itemMap.get('suggestions');
                                                if (suggs instanceof List<Object>) {
                                                    for (Object s : (List<Object>) suggs) {
                                                        flat.add('- ' + String.valueOf(s));
                                                    }
                                                }
                                            } else {
                                                // fallback: stringify the map
                                                flat.add(String.valueOf(JSON.serialize(itemMap)));
                                            }
                                        } else {
                                            flat.add(String.valueOf(o));
                                        }
                                    }
                                    // join with newlines
                                    if (!flat.isEmpty()) {
                                        result.put('optimizations', String.join(flat, '\n'));
                                    }
                                } else if (v instanceof String) {
                                    result.put('optimizations', String.valueOf(v));
                                } else {
                                    result.put('optimizations', String.valueOf(v));
                                }
                                break;
                            }
                        }
                    
                    // If explanation still blank, pick the longest string-like value from innerMap
                    if (String.isBlank(result.get('explanation'))) {
                        String best = '';
                        for (Object val : innerMap.values()) {
                            if (val instanceof String) {
                                String s = (String) val;
                                if (s.length() > best.length()) best = s;
                            } else if (val instanceof List<Object>) {
                                String joined = '';
                                for (Object o : (List<Object>) val) joined += (o == null ? '' : String.valueOf(o)) + '\n';
                                if (joined.length() > best.length()) best = joined;
                            }
                        }
                        if (!String.isBlank(best)) result.put('explanation', best.trim());
                    }
                    
                    return result;
                }
            } catch (Exception ex) {
                // inner not JSON or parse failed — fall back to text heuristics below
                System.debug('parseContent - innerJson parse failed: ' + ex.getMessage());
            }
        }
        
        // 5) If we couldn't parse inner JSON, treat candidate as plain text and attempt a heuristic split
        String plain = candidate;
        String lowerPlain = plain.toLowerCase();
        Integer idxA = lowerPlain.indexOf('optimizations');
        Integer idxB = lowerPlain.indexOf('optimization');
        Integer idxC = lowerPlain.indexOf('suggestion');
        Integer idxOpt = Math.max(idxA, Math.max(idxB, idxC));
        
        if (idxOpt > 0) {
            result.put('explanation', plain.substring(0, idxOpt).trim());
            result.put('optimizations', plain.substring(idxOpt).trim());
            return result;
        }
        
        // 6) Last-resort: if candidate contains JSON-like substring (no outer braces detection), attempt to find first '{' and '}' anyway
        if (firstBrace > -1 && lastBrace > firstBrace) {
            String attempted = candidate.substring(firstBrace, lastBrace + 1);
            try {
                Object attemptObj = JSON.deserializeUntyped(attempted);
                if (attemptObj instanceof Map<String, Object>) {
                    // recursively call parseContent with the cleaned JSON
                    return parseContent(attempted);
                }
            } catch (Exception e) {
                // ignore
            }
        }
        
        // 7) Final fallback: put whole cleaned text into explanation
        result.put('explanation', plain);
        result.put('optimizations', '');
        
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

            String baseExp = historyRecord.Explanation__c == null ? '' : historyRecord.Explanation__c + '\n\n';
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