import { LightningElement } from 'lwc';
import startFileAnalysis from '@salesforce/apex/ClaudeServiceCall.startFileAnalysis';
import startPasteAnalysis from '@salesforce/apex/ClaudeServiceCall.startPasteAnalysis';
import getHistoryResults from '@salesforce/apex/ClaudeServiceCall.getHistoryResults';
import getHistoryStatus from '@salesforce/apex/ClaudeServiceCall.getHistoryStatus';

export default class CodeAnalyserComponent extends LightningElement {


    code = '';
    explanation = ''
    optimizationSuggestions = '';
    lineByLine = false;
    uploadedFileName = '';
    optimizationRequested = false;
    uploadedFileId = '';

    isProcessing = false;
    currentHistoryId = null;
    
    pollHandle;
    pollingIntervals = 3000;
    processingMessage;

    showQuickTest = true;
    
    resultsAvailable = false;

    get buttonLabel(){
        return this.showQuickTest ? 'Use File Upload' : 'Use Quick Test';
    }

    toggleQuickTest() {
        this.showQuickTest = !this.showQuickTest;
    }

    handleInputChange(event){
        this.code = event.target.value;
    }

    handleOptimizations(event){
        this.optimizationRequested = event.detail.checked;
    }

    handleTabChange(event){
        this.activeTab = event.detail.value;
    }

    handleUploadFinished(event){

        const uploadedfile = event.detail.files;
        
        if(uploadedfile.length > 0){

            const file = uploadedfile[0];
            this.uploadedFileName = file.name;
            this.uploadedFileId = file.documentId;
            
            const allowedFileExtensions = ['java','py','js','html','css','php','c','cpp','cs','cls'];
            const ext = file.name.split('.').pop().toLowerCase();

            if(!allowedFileExtensions.includes(ext)){
                alert('Please upload a valid file. Only the following files are allowed: ' + allowedFileExtensions.join(','));
                return;
            }

        }
        
    }

    explainCodeSnippet(){

        this.isProcessing = true;
        this.processingMessage = 'Analyzing the code...';

        if(this.code){

            startPasteAnalysis({ codeSnippet: this.code, lineByLine: this.lineByLine, optimizationRequested: this.optimizationRequested})
            .then(result => {

                const parsedContent = JSON.parse(result);
                this.currentHistoryId = parsedContent.historyId;
                
                this.startPolling();
            });

        } else if(this.uploadedFileId){

            startFileAnalysis({contentDocumentId: this.uploadedFileId, lineByLine: this.lineByLine,optimizationRequested: this.optimizationRequested})
            .then(result => {

                this.currentHistoryId = result;
                this.startPolling();
            });

        }
    }

    
    startPolling(){
        // clear prior handle

        console.log('i am inside the polling call');

        if (this.pollHandle) {
            clearInterval(this.pollHandle);
            this.pollHandle = null;
        }
        
        this.pollHandle = setInterval(() => {
            if (!this.currentHistoryId) {

                return;
            }
            
            getHistoryStatus({ historyId: this.currentHistoryId })
                .then(jsonStr => {
                    const st = JSON.parse(jsonStr);
                    this.processingMessage = 'Status: ' + st.status;
                    
                    if (st.processed === true) {
                        // done - stop polling and fetch results
                        clearInterval(this.pollHandle);
                        this.pollHandle = null;
                        this.isProcessing = false;
                        
                        this.fetchResults(this.currentHistoryId);

                        console.log('i am inside the history status return call of the js file to test the polling');
                       
                    }
                })
                .catch(err => {
                    // log but keep polling (transient errors)
                    console.error('Polling error', err);
                });
        }, this.pollingIntervals);
    }

    fetchResults(historyId) {
        if (!historyId) {
            return;
        }
        
        getHistoryResults({ historyId: historyId })
            .then(jsonStr => {
                
                const out = JSON.parse(jsonStr);
                
                this.explanation = out.explanation || 'No explanation available';
                this.optimizations = out.optimizationSuggestions || 'No optimizations available';
                this.resultsAvailable = true;
                console.log('i am inside the get history results call of the js file');
                // attempt to parse line-by-line from rawResponse if model produced a JSON candidate
            })
            .catch(error => {
                this.resultsAvailable = false;
                console.error('Error while fetching results', error);
            });
    }

    get historyLink() {
        return this.currentHistoryId ? `/lightning/r/Code_Analysis_History__c/${this.currentHistoryId}/view` : null;
    }

}