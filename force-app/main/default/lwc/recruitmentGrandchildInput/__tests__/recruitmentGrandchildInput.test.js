import { createElement } from '@lwc/engine-dom';
import RecruitmentGrandchildInput from 'c/recruitmentGrandchildInput';
describe('c-recruitment-grandchild-input', () => {
    // Har test case ke baad DOM clean kar rahe hain
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('dispatches candidatechange event with detail payload on input change', () => {
        // Component ka virtual instance bana rahe hain
        const element = createElement('c-recruitment-grandchild-input', {
            is: RecruitmentGrandchildInput
        });
        document.body.appendChild(element);

        // Mock event listener function
        const handler = jest.fn();
        element.addEventListener('candidatechange', handler);

        // Input element target karke sample text type event simulate kar rahe hain
        const inputElement = element.shadowRoot.querySelector('lightning-input');
        inputElement.value = 'Candidate cleared technical round.';
        inputElement.dispatchEvent(new CustomEvent('change'));

        // Async DOM update resolve assert kar rahe hain
        return Promise.resolve().then(() => {
            expect(handler).toHaveBeenCalledTimes(1);
            const eventObj = handler.mock.calls[0][0];
            
            // Assert detail payload value
            expect(eventObj.detail.candidateNote).toBe('Candidate cleared technical round.');
            // Assert event bubbling flags
            expect(eventObj.bubbles).toBe(true);
            expect(eventObj.composed).toBe(true);
        });
    });
});