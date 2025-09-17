import { LightningElement } from 'lwc';
import startFileAnalysis from '@salesforce/apex/ClaudeServiceCall.startFileAnalysis';
import startPasteAnalysis from '@salesforce/apex/ClaudeServiceCall.startPasteAnalysis';
import getHistoryResults from '@salesforce/apex/ClaudeServiceCall.getHistoryResults';
import getHistoryStatus from '@salesforce/apex/ClaudeServiceCall.getHistoryStatus';
//import fileBatch from '@salesforce/apex/ClaudeFileHandler.fileBatch';

export default class CodeAnalyserComponent extends LightningElement {


    code = '';
    explanation = ''
    lineByLine = false;
    uploadedFileName = '';
    optimizationRequested = false;
    uploadedFileId = '';

    isProcessing = false;
    currentHistoryId = null;
    
    pollHandle = null;
    pollingIntervals = 3000;
    processingMessage = '';

    results = {};
    resultsAvailable = false;

    lineByLineItems = [];

    activeTab = 'analyze';


    handleInputChange(event){
        this.code = event.target.value;
    }

    handleLineByLineChange(event){

        this.lineByLine = event.target.checked;
    }

    handleOptimizations(event){
        this.optimizationRequested = event.detail.activeTabValue;
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


            // getFileContent({ contentDocumentId: file.documentId })
            //     .then(result => { this.code = result; })
            //     .catch(error => { console.error(error); });

            // The above code commented code will be handled in a different class as it will be used for batch processing

        }
        
    }

    startAnalyzingFile(){

        if(!this.uploadedFileId){
            this.processingMessage = 'Please upload a file';
            return;
        }

        console.log('File upload started');
        this.processingMessage = 'Analyzing the file contents...';
        this.isProcessing = true;

        startFileAnalysis({contentDocumentId: this.uploadedFileId, lineByLine: this.lineByLine,optimizationRequested: this.optimizationRequested})
            .then(historyId => {

                this.currentHistoryId = historyId;
                this.processingMessage = 'Processing the file contents of record ' + historyId + '...';

                //start polling to continuously check for updates

                this.startPolling();
                this.activeTab = 'results';
            })

            .catch(error =>{

                this.isProcessing = false;
                this.processingMessage = 'File analysis error: ' + error;
            })           

    }

    analyzePaste(){

        if(!this.code){
            this.processingMessage = 'Please paste the code in the text area';
            return;
        }

        this.isProcessing = true;
        this.processingMessage = 'Analyzing the pasted code...';

        startPasteAnalysis({ codeSnippet: this.code, lineByLine: this.lineByLine, optimizationRequested: this.optimizationRequested})
            .then(jsonString => {

                const out = JSON.parse(jsonString);
                this.currentHistoryId = out.historyId;
                
                this.processingMessage = 'Analysis completed';
                this.isProcessing = false;

                this.fetchResults(out.historyId);
                this.activeTab = 'results';

                
            })

            .catch(error =>{

                this.isProcessing = false;
                this.processingMessage = 'Pasted code analysis error: ' + error;
            })
    }

    
    startPolling(){
        // clear prior handle

        console.log('i am inside the polling call');

        if (this.pollHandle) {
            clearInterval(this.pollHandle);
            this.pollHandle = null;
        }
        this.isProcessing = true;
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
                this.results = {
                    historyId: out.historyId,
                    rawResponse: out.rawResponse || '',
                    optimizationSuggestions: out.optimizationSuggestions || '',
                    inputCode: out.inputCode
                
                };
                this.resultsAvailable = true;
                console.log('i am inside the get history results call of the js file');
                // attempt to parse line-by-line from rawResponse if model produced a JSON candidate
                this._tryParseLineByLine(out.rawResponse);
            })
            .catch(error => {
                this.resultsAvailable = false;
                console.error('Error while fetching results', error);
            });
    }

    _tryParseLineByLine(raw) {
        // If the model purposely returned a JSON block with "line_by_line" or "line_by_line" array,
        // attempt to extract it. This is heuristic — if model output isn't JSON this will fail silently.
        this.lineByLineItems = [];
        this.lineByLine = false;
        if (!raw) return;

        // Try parse as JSON (models sometimes return wrapped text; use a try/catch)
        try {
            const parsed = JSON.parse(raw);
            // Common schema: parsed.line_by_line = [ { line: n, explanation: '...' }, ... ]
            const candidates = parsed.line_by_line || parsed.lineByLine || parsed.line_by_line || parsed.line_by_line_items;
            if (Array.isArray(candidates)) {
                this.lineByLineItems = candidates.map(c => {
                    return { line: c.line, explanation: c.explanation || c.text || c.comment || '' };
                });
                this.hasLineByLine = this.lineByLineItems.length > 0;
            }
        } catch (e) {
            // Not JSON — ignore
            this.hasLineByLine = false;
        }
    }

}