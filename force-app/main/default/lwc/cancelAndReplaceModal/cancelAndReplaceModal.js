import { LightningElement, api, track } from 'lwc';
import cancel from '@salesforce/label/c.cancel';
import continueBtn from '@salesforce/label/c.continue';
import chooseADate from '@salesforce/label/c.chooseADate';
import term from '@salesforce/label/c.term';
import whenDoYouWantToStart from '@salesforce/label/c.whenDoYouWantToStart';
import opportunity from '@salesforce/label/c.opportunity';
import stage from '@salesforce/label/c.stage';
import amendmentError from '@salesforce/label/c.amendmentError';
import getOpportunityStageValues from '@salesforce/apex/AccountCancelReplaceController.getOpportunityStageValues';
import amendContracts from '@salesforce/apex/AccountCancelReplaceController.amendContracts';

/**
 * LWC that allows the user to view a modal and select the date
 * from when the new contract should start, as well as the term.
 *
 * @author Chris Shatrov, CodeScience
 * @date August 14th, 2020
 */
export default class CancelAndReplaceModal extends LightningElement {

    /**
     * Is the modal visible?
     */
    visible = true;

    /**
     * The class to apply to the main HTML structure when open.
     */
    openClass = 'slds-fade-in-open';

    /**
     * The class to apply to the backdrop when open.
     */
    backdropClass = 'slds-backdrop_open';

    /**
     * Expose Salesforce custom labels.
     */
    label = {
        cancel: cancel,
        continueBtn: continueBtn,
        chooseADate: chooseADate,
        term: term,
        whenDoYouWantToStart: whenDoYouWantToStart,
        opportunity: opportunity,
        stage: stage,
        amendmentError: amendmentError
    };

    /**
     * Display a spinner while data is loading.
     */
    @track isLoading = false;
    // Data variables.
    @track disableContinueBtn = true;
    @track termLength = '';
    @track selectedStartDate = '';
    @track enteredOpportunity = '';
    @track opportunityStageValues;
    @track stageSelected = '';
    @track showCreateAmendmentsError = false;
    @api selectedContracts;
    @api accountId;

    /**
     * Open the modal, toggling visibility classes and setting
     * values for both the contact card and email defaults.
     */
    @api
    open() {
        this.disableContinueBtn = true;
        const el = this.template.querySelector('.slds-modal');
        const bg = this.template.querySelector('.slds-backdrop');
        this.visible = true;
        if (!this.visible) {
            el.classList.remove(this.openClass);
            bg.classList.remove(this.backdropClass);
        } else {
            el.classList.add(this.openClass);
            bg.classList.add(this.backdropClass);
        }
        // Load the stage pickList values.
        this.getStageVals();
    }

    /**
     * Close the modal, toggling visibility classes.
     */
    close() {
        this.visible = false;
        const el = this.template.querySelector('.slds-modal');
        const bg = this.template.querySelector('.slds-backdrop');
        if (!this.visible) {
            el.classList.remove(this.openClass);
            bg.classList.remove(this.backdropClass);
        } else {
            el.classList.add(this.openClass);
            bg.classList.add(this.backdropClass);
        }
    }

    /**
     * Helper method to see if Continue button can be enabled.
     * And to make sure all fields are valid.
     */  
    checkTheForm() {
        if (this.selectedStartDate.length > 0 &&
            this.checkTheTerm() &&
            this.checkTheOpportunity() &&
            this.checkStage()) {
                this.disableContinueBtn = false;
            }
            else {
                this.disableContinueBtn = true;
            }
    }

    /**
     * Checks the date to see if it's in the past.
     */
    checkIfDateIsPast(date) {
        if (this.beforeToday(date)) {
            // Creates the event.
            const selectedEvent = new CustomEvent('showtoast');
            // Dispatches the event.
            this.dispatchEvent(selectedEvent);  
        }
    }

    /**
     * Check the start date input.
     */
    checkTheDate(event) {
        // We have to have a non standard validation here because we do not want to display the toast multiple times.
        var input = this.template.querySelector(".date");
        if (input.value != null) {
            this.selectedStartDate = input.value;
            // Check to see if a past date toast need to be displayed. Run only once.
            this.checkIfDateIsPast(input.value);
            this.checkTheForm();
        }
        else {
            this.selectedStartDate = '';
            this.disableContinueBtn = true;
        }
    }

    /**
     * Check the term input.
     */
    checkTheTerm(event) {
        var input = this.template.querySelector(".term");
        if (input.validity.valid) {
            this.termLength = input.value;
            return true;
        }
        else {
            return false;
        }
    }

    /**
     * Check the term input.
     */
    checkTheOpportunity (event) {
        var input = this.template.querySelector(".opportunity");
        if (input.validity.valid) {
            this.enteredOpportunity = input.value;
            return true;
        }
        else {
            return false;
        }
    }

    /**
     * Check the stage input.
     */
    checkStage (event) {
        var input = this.template.querySelector(".selectedstage");
        if (input.validity.valid) {
            this.stageSelected = input.value;
            return true;
        }
        else {
            return false;
        }
    }

    /**
     * Handles modal's Continue btn click.
     */
    handleContinueClick() {
        let parameterObject = {
            contractIds: this.selectedContracts,
            startDate: this.selectedStartDate,
            termLength: parseInt(this.termLength),
            opportunityStage: this.stageSelected,
            opportunityName: this.enteredOpportunity,
            accountId: this.accountId
        };
        this.isLoading = true;
        amendContracts({ amendContracts: parameterObject })
            .then(res => {
                this.resetFormValues();
                this.isLoading = false;
                this.unSelectAllContracts();
                this.close();
                // Creates the event.
                const selectedEvent = new CustomEvent('markcontractupdating', {
                    detail: {
                        quoteId: res.quoteId,
                        // OK for now, but needs to be quote name
                        quoteName: res.quoteName,
                        opportunityId: res.opportunityId,
                    }
                });
                // // Dispatches the event.
                this.dispatchEvent(selectedEvent);
            })
            .catch(error => {
                this.showCreateAmendmentsError = true;
                this.isLoading = false;
            });
    }

    /**
     *  checkIfDateIsPast helper function.
     */
    beforeToday(date) {
        var selectedDate = new Date(date);
        var now = new Date();
        var beforeToday = false;
        // Fix so we can properly convert and compare the dates, allowing today's date not be in the past.
        if(selectedDate.getYear() < now.getYear()) {
            beforeToday = true;
        }
        else if (selectedDate.getDate() + 1 < now.getDate() && selectedDate.getMonth() <= now.getMonth() && selectedDate.getYear() < now.getYear() + 1) {
            beforeToday = true;
        }
        else if (selectedDate.getDate() + 1 > now.getDate() && selectedDate.getMonth() < now.getMonth() && selectedDate.getYear() < now.getYear() + 1) {
            beforeToday = true;
        }
        return beforeToday;
    }

    /**
     *  Upon modal load, get a list of opportunity stage values.
     */
    getStageVals() {
        this.isLoading = true;
        // Get the list of packages
        getOpportunityStageValues()
            .then(res => {
                this.opportunityStageValues = res;
                this.isLoading = false;
            })
            .catch(error => {
                console.log('ERROR GETTING OPPORTUNITY STAGE VALUES!' + error);
                this.isLoading = false;
            });
    }

    /**
     *  Upon modal close, clear out the list of selected contracts.
     */
    unSelectAllContracts () {
        // Creates the event.
        const selectedEvent = new CustomEvent('onunselectallcontracts');
        // Dispatches the event.
        this.dispatchEvent(selectedEvent);  
    }

    resetFormValues() {
        // Resetting form and var values.
        this.template.querySelector(".selectedstage").value = undefined;
        this.template.querySelector(".opportunity").value = undefined;
        this.template.querySelector(".term").value = undefined;
        this.template.querySelector(".date").value = undefined;
        this.termLength = '';
        this.selectedStartDate = '';
        this.enteredOpportunity = '';
        this.stageSelected = '';
    }
}