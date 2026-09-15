import { LightningElement, wire } from 'lwc';
// LMS Subscribe utilities import kar rahe hain
import { subscribe, MessageContext } from 'lightning/messageService';
import RECRUITMENT_CHANNEL from '@salesforce/messageChannel/RecruitmentChannel__c';

export default class RecruitmentStatusBoard extends LightningElement {
    activeStageFilter = 'All';
    subscription = null;

    @wire(MessageContext)
    messageContext;

    // Component DOM me insert hote hi subscriber initialize hoga
    connectedCallback() {
        this.subscribeToChannel();
    }

    subscribeToChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                RECRUITMENT_CHANNEL,
                (message) => this.handleMessage(message)
            );
        }
    }

    // Radio signal receive hone par filter value update hogi
    handleMessage(message) {
        this.activeStageFilter = message.selectedStage;
    }

    // Getter function dynamic conditionally UI logic ke liye
    get isAllSelected() {
        return this.activeStageFilter === 'All';
    }
}