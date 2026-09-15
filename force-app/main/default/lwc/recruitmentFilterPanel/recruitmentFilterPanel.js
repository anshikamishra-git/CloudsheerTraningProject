import { LightningElement, wire } from 'lwc';
// LMS utilities import kar rahe hain
import { publish, MessageContext } from 'lightning/messageService';
import RECRUITMENT_CHANNEL from '@salesforce/messageChannel/RecruitmentChannel__c';

export default class RecruitmentFilterPanel extends LightningElement {
    selectedStage = 'All';

    // LMS Context wire service
    @wire(MessageContext)
    messageContext;

    // JavaScript Getter options render karne ke liye (Getter-driven reactivity)
    get stageOptions() {
        return [
            { label: 'All Stages', value: 'All' },
            { label: 'Applied', value: 'Applied' },
            { label: 'Screening', value: 'Screening' },
            { label: 'Interview', value: 'Interview' },
            { label: 'Offered', value: 'Offered' }
        ];
    }

    // Dropdown change handler
    handleStageChange(event) {
        this.selectedStage = event.detail.value;
        const payload = { selectedStage: this.selectedStage };

        // LMS Channel par message Publish kar rahe hain
        publish(this.messageContext, RECRUITMENT_CHANNEL, payload);
    }
}