import { LightningElement, api } from 'lwc';

export default class RecruitmentGrandchildInput extends LightningElement {
    // @api decorator se Parent/Child se data DOWN pass ho sakta hai
    @api candidateNote = '';

    // Input field change hone par ye handler chalega
    handleInputChange(event) {
        // User dwara type kiya gaya new value pick kar rahe hain
        const updatedNote = event.target.value;

        // Custom Event create kar rahe hain
        // bubbles: true se event upar ki taraf traverse karega
        // composed: true se event Shadow DOM boundary cross karega
        const noteChangeEvent = new CustomEvent('candidatechange', {
            detail: { candidateNote: updatedNote },
            bubbles: true,
            composed: true
        });

        // Event ko dispatch/fire kar rahe hain UPward direction me
        this.dispatchEvent(noteChangeEvent);
    }
}