public with sharing class CodeAnalysisBatchJob implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts{

    private String contentDocumentId;
    private Id historyId;
    private Boolean lineByLine;
    private Boolean optimizationRequested;

    private String explanations = '';
    private String optimizationsResult = '';

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

            try{

                String response = ClaudeServiceCall.explainFileCode(chunk, lineByLine, optimizationRequested);

                Map<String, String> parsedResponse = ClaudeServiceCall.parseContent(response);

                ClaudeServiceCall.saveAnalysisAsRecord(historyId, parsedResponse.get('explanation'), parsedResponse.get('optimizations'), response);

            }

            catch(Exception ex){

                System.debug('Error: ' + ex.getMessage());
            }

        }
        
    }

    public void finish(Database.BatchableContext bc) {
        
        Code_Analysis_History__c history = [Select Id, Status__c, Processed__c from Code_Analysis_History__c where Id =: historyId limit 1];

        history.Processed__c = true;
        history.Status__c = 'Completed';

        update history;
    }
}