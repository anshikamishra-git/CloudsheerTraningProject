import { LightningElement, api } from 'lwc';

export default class RecruitmentChildCard extends LightningElement {
    // Parent se data receive karne ke liye public properties
    @api candidateName = '';
    @api candidateNote = '';
}