import { LightningElement } from 'lwc';
import explainCode from '@salesforce/apex/ClaudeServiceCall.explainCode';

export default class CodeAnalyserComponent extends LightningElement {

    code = '';
    explanation = ''
    lineByLine = false;

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


            getFileContent({ contentVersionId: file.contentVersionId })
                .then(result => { this.code = result; })
                .catch(error => { console.error(error); });


        }
    }

    explainCodeSnippet(){
        explainCode({codeSnippet: this.code})
            .then(result => {
                this.explanation = result;
            })
            .catch(error => {
                console.error(error);
            });
    }
}