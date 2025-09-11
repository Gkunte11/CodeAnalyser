public with sharing class CodeAnalysisBatchJob implements Queueable, Database.AllowCallouts{

    private String contentDocumentId;
    private Id historyId;
    private Boolean lineByLine;
    private Boolean optimizationRequested;

    public CodeAnalysisBatchJob(String contentDocumentId, Id historyId, Boolean lineByLine, Boolean optimizationRequested) {
        this.contentDocumentId = contentDocumentId;
        this.historyId = historyId;
        this.lineByLine = lineByLine; 
        this.optimizationRequested = optimizationRequested;

    }

    public void execute(QueueableContext context){

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

            String response = ClaudeServiceCall.explainCode(chunk, lineByLine, optimizationRequested);

            finalExplanation += response + '\n\n';
        }
        
        Code_Analysis_History__c history = [Select Id from Code_Analysis_History__c where Id =: historyId limit 1];

        history.Claude_Response__c = finalExplanation;
        history.Processed__c = true;
        history.Status__c = 'Completed';

        update history;
    }
}