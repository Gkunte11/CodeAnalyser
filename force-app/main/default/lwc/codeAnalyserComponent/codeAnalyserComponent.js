import { LightningElement } from 'lwc';
import explainCode from '@salesforce/apex/ClaudeServiceCall.explainCode';
import fileBatch from '@salesforce/apex/ClaudeFileHandler.fileBatch';

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

        
    }


}