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

        
    }
}