// import LightningModal from 'lightning/modal';
// import { api } from 'lwc';

// export default class FullScreenModal extends LightningModal {
//     @api recordId; // passed in when opening the modal

//     handleClose() {
//         this.close('closed');
//     }
// }
import { LightningElement, api } from 'lwc';

export default class OpenFullScreenComponent extends LightningElement {
    @api recordId;
    isOpen = false;

    handleOpen() {
        this.isOpen = true;
    }

    handleClose() {
        this.isOpen = false;
    }
}