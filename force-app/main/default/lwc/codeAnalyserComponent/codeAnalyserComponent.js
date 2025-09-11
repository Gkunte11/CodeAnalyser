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

    handleInputChange(event){
        this.code = event.target.value;
    }

    handleLineByLineChange(event){

        this.lineByLine = event.target.checked;
    }

    handleOptimizations(event){
        this.optimizationRequested = event.target.checked;
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

    explainCodeSnippet(){
        // explainCode({codeSnippet: this.code , lineByLine: this.lineByLine, optimizationRequested: this.optimizationRequested})
        //     .then(result => {
        //         this.explanation = result;
        //     })
        //     .catch(error => {
        //         console.error(error);
        //     });

        // Modifying the above action to handle file upload and copy/paste process differently. The File upload will be handled via batch processing as the code files might be bigger in size

        if(this.uploadedFileId){

            console.log("In the uploadedFileId block");
            console.log("this.uploadedFileId: " + this.uploadedFileId);
            fileBatch({

                contentDocumentId: this.uploadedFileId,
                lineByLine: this.lineByLine,
                optimizationRequested: this.optimizationRequested
            })
            .then(result => {
                this.explanation = 'Batch processing started for the uploaded file. The following Code Analysis History record will be updated as soon as the processing has completed: ' + result;
            })
            .catch(error => {
                console.error(error);
                this.explanation = 'Error: ' + error;
            });

        }

        else if(this.code){

            explainCode({
                codeSnippet: this.code, 
                lineByLine: this.lineByLine, 
                optimizationRequested: this.optimizationRequested
            })
            .then(result => {
                this.explanation = 'The pasted code will be handled synchronously. Code Analysis History record: ' + result;
            })
            .catch(error => {
                console.error(error);
                this.explanation = 'Error: ' + error;
            });

        }

        else{

            this.explaination = 'Please upload a file or paste the code in the text area.';
        }
    }
}