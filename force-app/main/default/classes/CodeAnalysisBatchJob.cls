public with sharing class CodeAnalysisBatchJob implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts{

    private String contentDocumentId;
    private Id historyId;
    private Boolean lineByLine;
    private Boolean optimizationRequested;

    private StringBuilder explanations = new StringBuilder();
    private StringBuilder optimizationsResult = new StringBuilder();

    public CodeAnalysisBatchJob(String contentDocumentId, Id historyId, Boolean lineByLine, Boolean optimizationRequested) {
        this.contentDocumentId = contentDocumentId;
        this.historyId = historyId;
        this.lineByLine = lineByLine; 
        this.optimizationRequested = optimizationRequested;

    }

    public Database.QueryLocator start(Database.BatchableContext context){
        return Database.getQueryLocator([SELECT Id FROM User WHERE Id = :UserInfo.getUserId()]);
    }

    public void execute(Database.BatchableContext context, List<SObject> scope){

        ContentVersion cv = [
            SELECT VersionData 
            FROM ContentVersion 
            WHERE ContentDocumentId = :contentDocumentId 
            ORDER BY VersionNumber DESC 
            LIMIT 1
        ];
        
        String content =  cv.VersionData.toString();

        List<String> chunks = ChunkUtils.chunkCode(content, 200);
        

        String finalExplanation = '';

        for(String chunk: chunks){

            String response = ClaudeServiceCall.explainFileCode(chunk, lineByLine, optimizationRequested);

            Map<String, Object> parsedString = (Map<String,Object>) JSON.deserializeUntyped(response);
            if(parsedString.containsKey('explanation')){

                explanations.append((String) parsed.get('explanation')).append('\n\n');

            }

            if(parsedString.containsKey('optimizations')){

                optimizations.append((String) parsed.get('optimizations')).append('\n\n');

            }
            finalExplanation += response + '\n\n';
        }
        
        Code_Analysis_History__c history = [Select Id from Code_Analysis_History__c where Id =: historyId limit 1];

        history.Claude_Response__c = response;
        history.Explanation__c = 
        history.Processed__c = true;
        history.Status__c = 'Completed';

        update history;
    }

    public void finish(Database.BatchableContext bc) {
        
    }
}