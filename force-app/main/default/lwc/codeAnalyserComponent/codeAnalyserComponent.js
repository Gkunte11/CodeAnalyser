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

    
    resultsAvailable = false;

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


    // startAnalyzingFile(){

    //     if(!this.uploadedFileId){
    //         this.processingMessage = 'Please upload a file';
    //         return;
    //     }

    //     console.log('File upload started');
    //     this.processingMessage = 'Analyzing the file contents...';
    //     this.isProcessing = true;

    //     startFileAnalysis({contentDocumentId: this.uploadedFileId, lineByLine: this.lineByLine,optimizationRequested: this.optimizationRequested})
    //         .then(historyId => {

    //             this.currentHistoryId = historyId;
    //             this.processingMessage = 'Processing the file contents of record ' + historyId + '...';

    //             //start polling to continuously check for updates

    //             this.startPolling();
    //             this.activeTab = 'results';
    //         })

    //         .catch(error =>{

    //             this.isProcessing = false;
    //             this.processingMessage = 'File analysis error: ' + error;
    //         })           

    // }

    // analyzePaste(){

    //     if(!this.code){
    //         this.processingMessage = 'Please paste the code in the text area';
    //         return;
    //     }

    //     this.isProcessing = true;
    //     this.processingMessage = 'Analyzing the pasted code...';

    //     startPasteAnalysis({ codeSnippet: this.code, lineByLine: this.lineByLine, optimizationRequested: this.optimizationRequested})
    //         .then(jsonString => {

    //             const out = JSON.parse(jsonString);
    //             this.currentHistoryId = out.historyId;
                
    //             this.processingMessage = 'Analysis completed';
    //             this.isProcessing = false;

    //             this.fetchResults(out.historyId);
    //             this.activeTab = 'results';

                
    //         })

    //         .catch(error =>{

    //             this.isProcessing = false;
    //             this.processingMessage = 'Pasted code analysis error: ' + error;
    //         })
    // }

    
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
                this.optimizations = out.optimizations || 'No optimizations available';
                this.resultsAvailable = true;
                console.log('i am inside the get history results call of the js file');
                // attempt to parse line-by-line from rawResponse if model produced a JSON candidate
            })
            .catch(error => {
                this.resultsAvailable = false;
                console.error('Error while fetching results', error);
            });
    }

}