import { LightningElement } from 'lwc';

export default class RecruitmentParentOverview extends LightningElement {
    // Candidate default data
    candidateName = 'Anshika Mishra';
    currentCandidateNote = 'Initial profile screening completed.';

    // Grandchild se bubbled event catch hone par ye function run hoga
    handleGrandchildCandidateChange(event) {
        // Event payload se new note extract karke UI update kar rahe hain
        this.currentCandidateNote = event.detail.candidateNote;
    }
}