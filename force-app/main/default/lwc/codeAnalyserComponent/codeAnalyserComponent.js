import { LightningElement } from 'lwc';
import explainCode from '@salesforce/apex/ClaudeServiceCall.explainCode';

export default class CodeAnalyserComponent extends LightningElement {

    code = '';
    explanation = ''

    handleInputChange(event){
        this.code = event.target.value;
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