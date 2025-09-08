import { LightningElement } from 'lwc';
import explainCode from '@salesforce/apex/ClaudeServiceCall.explainCode';
import getFileContent from '@salesforce/apex/ClaudeFileHandler.getFileContent';

export default class CodeAnalyserComponent extends LightningElement {

    code = '';
    explanation = ''
    lineByLine = false;
    uploadedFileName = '';

    handleInputChange(event){
        this.code = event.target.value;
    }

    handleLineByLineChange(event){

        this.lineByLine = event.target.checked;
    }

    handleUploadFinished(event){

        const uploadedfile = event.detail.files;
        
        if(uploadedfile.length > 0){

            const file = uploadedfile[0];
            const allowedFileExtensions = ['java','py','js','html','css','php','c','cpp','cs','cls'];
            
            const ext = file.name.split('.').pop().toLowerCase();

            if(!allowedFileExtensions.includes(ext)){
                alert('Please upload a valid file. Only the following files are allowed: ' + allowedFileExtensions.join(','));
                return;
            }


            getFileContent({ contentDocumentId: file.documentId })
                .then(result => { this.code = result; })
                .catch(error => { console.error(error); });

            this.uploadedFileName = file.name;

        }

        
    }

    explainCodeSnippet(){
        explainCode({codeSnippet: this.code , lineByLine: this.lineByLine})
            .then(result => {
                this.explanation = result;
            })
            .catch(error => {
                console.error(error);
            });
    }
}