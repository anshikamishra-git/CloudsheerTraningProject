import { LightningElement, api, wire } from 'lwc';
import getInterviewRounds from '@salesforce/apex/HiringServiceLWC.getInterviewRounds';
import statusBreakdown from '@salesforce/apex/HiringServiceLWC.statusBreakdown';
import saveInterviewRounds from '@salesforce/apex/HiringServiceLWC.saveInterviewRounds';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Round Name', fieldName: 'Name', type: 'text' },
    { label: 'Completed', fieldName: 'Completed__c', type: 'boolean', editable: true },
    { label: 'Due Date', fieldName: 'Due_Date__c', type: 'date', editable: true },
    { label: 'Planned Hours', fieldName: 'Planned_Hours__c', type: 'number', editable: true }
];

export default class InterviewCommandCenter extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    
    rounds = [];
    summaryData = [];
    draftValues = [];

    wiredRoundsResult;
    wiredSummaryResult;

    // 1. Wired read for interview rounds
    @wire(getInterviewRounds, { jobOpeningId: '$recordId' })
    wiredRounds(result) {
        this.wiredRoundsResult = result;
        if (result.data) {
            this.rounds = result.data;
        } else if (result.error) {
            this.showToast('Error Loading Rounds', this.reduceError(result.error), 'error');
        }
    }

    // 2. Wired read for top summary strip
    @wire(statusBreakdown, { jobOpeningId: '$recordId' })
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        if (result.data) {
            // Converts Map object into uppercase label array for summary UI
            this.summaryData = Object.keys(result.data).map(key => ({
                key: key.toUpperCase(),
                value: result.data[key]
            }));
        } else if (result.error) {
            this.showToast('Error Loading Summary', this.reduceError(result.error), 'error');
        }
    }

    get hasData() {
        return this.rounds && this.rounds.length > 0;
    }

    // 3. Imperative Save Handler
    async handleSave(event) {
        // Collect edited values from datatable
        const updatedFields = event.detail.draftValues;

        try {
            // Imperative call to Apex save method
            await saveInterviewRounds({ roundsToUpdate: updatedFields });
            
            this.showToast('Success', 'Interview rounds updated successfully.', 'success');

            // FIX: Explicitly clear datatable component's internal draft state
            const datatable = this.template.querySelector('lightning-datatable');
            if (datatable) {
                datatable.draftValues = [];
            }
            this.draftValues = [];

            // Concurrent cache busting for wired components
            await Promise.all([
                refreshApex(this.wiredRoundsResult),
                refreshApex(this.wiredSummaryResult)
            ]);

        } catch (error) {
            // Graceful error handling: Draft values are preserved so user doesn't lose inputs
            const cleanError = this.reduceError(error);
            this.showToast('Save Failed', cleanError, 'error');
        }
    }

    handleCancel() {
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.draftValues = [];
        }
        this.draftValues = [];
    }

    // Error reducer: Reduces complex Apex/Validation errors to 1 single clean message string
    reduceError(error) {
        if (typeof error === 'string') return error;
        if (error.body && typeof error.body.message === 'string') return error.body.message;
        if (error.message) return error.message;
        return 'An unknown error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}


/*
import { LightningElement, api, wire } from 'lwc';
import getInterviewRounds from '@salesforce/apex/HiringServiceLWC.getInterviewRounds';
import statusBreakdown from '@salesforce/apex/HiringServiceLWC.statusBreakdown';
import saveInterviewRounds from '@salesforce/apex/HiringServiceLWC.saveInterviewRounds';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Round Name', fieldName: 'Name', type: 'text' },
    { label: 'Completed', fieldName: 'Completed__c', type: 'boolean', editable: true },
    { label: 'Due Date', fieldName: 'Due_Date__c', type: 'date', editable: true },
    { label: 'Planned Hours', fieldName: 'Planned_Hours__c', type: 'number', editable: true }
];

export default class InterviewCommandCenter extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    
    rounds = [];
    summaryData = [];
    draftValues = [];

    wiredRoundsResult;
    wiredSummaryResult;

    @wire(getInterviewRounds, { jobOpeningId: '$recordId' })
    wiredRounds(result) {
        this.wiredRoundsResult = result;
        if (result.data) {
            this.rounds = result.data;
        } else if (result.error) {
            this.showToast('Error', this.reduceError(result.error), 'error');
        }
    }

    @wire(statusBreakdown, { jobOpeningId: '$recordId' })
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        if (result.data) {
            this.summaryData = Object.keys(result.data).map(key => ({
                key: key,
                value: result.data[key]
            }));
        }
    }

    get hasData() {
        return this.rounds && this.rounds.length > 0;
    }

    async handleSave(event) {
        const updatedFields = event.detail.draftValues;

        try {
            await saveInterviewRounds({ roundsToUpdate: updatedFields });
            this.showToast('Success', 'Interview rounds updated successfully.', 'success');
            this.draftValues = [];

            await Promise.all([
                refreshApex(this.wiredRoundsResult),
                refreshApex(this.wiredSummaryResult)
            ]);
        } catch (error) {
            const cleanError = this.reduceError(error);
            this.showToast('Save Failed', cleanError, 'error');
        }
    }

    handleCancel() {
        this.draftValues = [];
    }

    reduceError(error) {
        if (typeof error === 'string') return error;
        if (error.body && typeof error.body.message === 'string') return error.body.message;
        if (error.message) return error.message;
        return 'An unknown error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}*/