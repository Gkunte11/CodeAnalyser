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

        const file = event.detail.files[0];
        const allowedFileExtensions = ['.java','.py','.js','.html','.css','.php','.c','.cpp','.cs','.cls'];
        const maxFileSize = 1000000;
        if(file){

            const ext = file.name.split('.').pop().toLowerCase();

            if(allowedFileExtensions.includes(ext)){
                this.code = file;
            }else{
                alert('Please upload a valid file. Only ${this.allowedExtensions.join(', ')} files are allowed.`');
            }

            if(file.size > maxFileSize){

                alert('File size should be less than 1 MB');
                return;
            }

            getFileContent(file)
                .then(content => {
                    this.code = content;
                })
                .catch(error => {
                    console.error(error);
                });


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