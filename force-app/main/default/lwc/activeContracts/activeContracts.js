import { LightningElement, track, api } from 'lwc';
import { subscribe, unsubscribe } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import cancelAndReplaceButton from '@salesforce/label/c.cancelAndReplaceBtn';
import cancelAndReplaceHeader from '@salesforce/label/c.cancelAndReplaceHeader';
import contracts from '@salesforce/label/c.contracts';
import account from '@salesforce/label/c.account';
import contractTerm from '@salesforce/label/c.contractTerm';
import endDate from '@salesforce/label/c.endDate';
import start from '@salesforce/label/c.start';
import noActiveContractsFound from '@salesforce/label/c.noActiveContractsFound';
import includeChildContracts from '@salesforce/label/c.includeChildContracts';
import dateIsInThePastWarning from '@salesforce/label/c.dateIsInThePastWarning';
import netAmount from '@salesforce/label/c.netAmount';
import updating from '@salesforce/label/c.updating';
import getContracts from '@salesforce/apex/AccountCancelReplaceController.getContracts';
import getAccounts from '@salesforce/apex/AccountCancelReplaceController.getAccounts';
import getJobStatus from '@salesforce/apex/AccountCancelReplaceController.getJobStatus';
import getNamespacePrefix from '@salesforce/apex/CancelAndReplaceUtility.getNamespaceWithUnderScore';
import { NavigationMixin } from 'lightning/navigation';

/**
 * A component created to display a list of active 
 * contracts for a given account
 *
 * @author Chris Shatrov, CodeScience
 * @date August 11th, 2020
 */

export default class ActiveContracts extends NavigationMixin(LightningElement) {

    label = {
        cancelAndReplaceButton: cancelAndReplaceButton,
        cancelAndReplaceHeader: cancelAndReplaceHeader,
        contracts: contracts,
        account: account,
        contractTerm: contractTerm,
        endDate: endDate,
        start: start,
        noActiveContractsFound: noActiveContractsFound,
        includeChildContracts: includeChildContracts,
        netAmount: netAmount,
        dateIsInThePastWarning: dateIsInThePastWarning,
        updating: updating
    };

    // Record ID for this particular account.
    @api recordId;
    @track activeContracts = [];
    // Used to display the empty state illustration.
    @track noDataFound = true;
    // Used to display View All / View less footer btn.
    @track viewingAllRecords = false;
    // Used to enable and disable the cancelAndReplace btn.
    @track contractsNotSelected = true;
    // Keeping track of what active contracts the user selected.
    @track listOfSelectedContracts = [];
    @track displayGoToNewQuoteCard = false;
    // 3 variables that come back after update process has started.
    @track quoteId;
    @track quoteName;
    @track opportunityId;
    @track jobs;
    @track jobStatuses;
    @track childContractsIncluded = false;
    @track allAccountIds = [];
    @track namespacePrefix;
    // Channel name to use while subbing and listening to update event.
    @track channelName = 'Cancel_Replace__e';

    /**
     * Display a spinner while data is loading.
     */
    @track isLoading = false;

    /**
     * On component connection, load the contract data (total of 5 at first).
     */
    connectedCallback() {
        this.viewFiveContracts();
        this.getAllAccounts();
        // Get namespace to make sure event listener does not fail.
        this.isLoading = true;
        getNamespacePrefix()
        .then(res => {
            this.namespacePrefix = res;
            this.channelName = '/event/' + this.namespacePrefix + this.channelName;
            this.isLoading = false;
        })
        .catch(error => {
            console.log('ERROR GETTING NAMESPACE PREFIX!' + error);
            this.isLoading = false;
        });
    }

    // Loads only 5 records. On page load, or when user clicks 'View less'.
    viewFiveContracts() {
        this.isLoading = true;
        this.unSelectAllContracts();
        let accountIds = this.childContractsIncluded ? this.allAccountIds : [this.recordId];
        if (accountIds == null) {
            accountIds = [this.recordId];
        }
        // Get the list of packages
        getContracts({
            recordIds: accountIds,
            amountOfRecords: 5
        })
            .then(res => {
                this.activeContracts = res;
                this.viewingAllRecords = false;
                this.noDataFound = !res.length;
                this.setupDataOnRefresh();
                this.isLoading = false;
            })
            .catch(error => {
                console.log('ERROR GETTING FIVE ACTIVE CONTRACTS!' + error);
                this.isLoading = false;
            });
    }

    getAllAccounts() {
        this.isLoading = true;
        getAccounts({
            recordId: this.recordId
        })
        .then(res => {
            this.allAccountIds = res;
        })
        .catch(error => {
            console.log('ERROR GETTING ALL RELATED ACCOUNTS!' + error);
        });

    }

    // Loads all the records. When user clicks 'View All'.
    viewAllContracts() {
        this.isLoading = true;
        this.unSelectAllContracts();
        let accountIds = this.childContractsIncluded ? this.allAccountIds : [this.recordId];
        // Get the list of packages
        getContracts({
            recordIds: accountIds,
            amountOfRecords: 'All'
        })
            .then(res => {
                this.activeContracts = res;
                this.viewingAllRecords = true;
                this.noDataFound = !res.length;
                this.setupDataOnRefresh();
                this.isLoading = false;
            })
            .catch(error => {
                console.log('ERROR GETTING ALL ACTIVE CONTRACTS!' + error);
                this.isLoading = false;
            });
    }

    openModal (evt) {
        this.template.querySelector('c-cancel-and-replace-modal').open(evt.detail);
    }

    contractSelected (event) {
        if (event.target.checked === true) {
            this.listOfSelectedContracts.push(event.target.value);
        }
        else {
            var index = this.listOfSelectedContracts.indexOf(event.target.value);
            if (index > -1) {
                this.listOfSelectedContracts.splice(index, 1);
            }
        }
        // Check to make sure that at least 1 item is selected
        if(this.listOfSelectedContracts.length > 0) {
            this.contractsNotSelected = false;
        }
        else {
            this.contractsNotSelected = true;
        }
    }

    unSelectAllContracts () {
        this.listOfSelectedContracts = [];
        this.contractsNotSelected = true;
        const checkboxes = this.template.querySelectorAll('input[name="contractCheckbox"]');
        for (var i = 0; i < checkboxes.length; i++) {
            checkboxes[i].checked = false;
        }
    }

    // Used to unmark contracts one by one, as they are done updating.
    contractIsDoneUpdating (contractId) {
        for (var i = 0; i < this.activeContracts.length; i++) {
            // Splice removes quotes here.
            if (contractId.slice(1, -1) === this.activeContracts[i].id) {
                this.activeContracts[i].updateInProgress = false;
                this.activeContracts[i].customRowClass = "slds-hint-parent";
                // Put this object in end of the array, so the the rest of orange rows appear on top.
                var item = this.activeContracts.splice(i,1);   // removes the contact object.
                this.activeContracts.push(item[0]);         // adds it back to the end.
            }
        }
        // When there are no more jobs left to listen to, finish everything up and unsub.
        let unProcessedRecords = this.activeContracts.filter( contract => { return contract.updateInProgress === true});
        if(unProcessedRecords.length === 0){
            this.displayGoToNewQuoteCard = true;
            // leaving a blank callback, we are not doing anything when we unsubscribe
            const messageCallback = response => {};
            unsubscribe(this.channelName, -1, messageCallback);
        }
    }

    // Used to temporarily mark each selected / edited contract as 'Updating'.
    markContractUpdating(event) {
        this.isLoading = true;
        this.displayGoToNewQuoteCard = false;
        this.quoteId = event.detail.quoteId;
        this.quoteName = event.detail.quoteName;
        this.opportunityId = event.detail.opportunityId;
        this.jobs = event.detail.jobs;

        for (var i = 0; i < this.listOfSelectedContracts.length; i++) {
            for (var j = 0; j < this.activeContracts.length; j++) {
                if (this.listOfSelectedContracts[i] === this.activeContracts[j].id) {
                    this.activeContracts[j].updateInProgress = true;
                    this.activeContracts[j].customRowClass = "slds-hint-parent orange-background";
                    // Put this object in front of the array, so the all appear on top.
                    var item = this.activeContracts.splice(j,1);   // removes the contact object.
                    this.activeContracts.unshift(item[0]);         // adds it back to the beginning.
                }
            }
        }
        this.isLoading = false;
        this.contractsNotSelected = true;
        // Callback invoked whenever a new event message is received
        const messageCallback = response => {
            this.contractIsDoneUpdating(JSON.stringify(response.data.payload[(this.namespacePrefix) + 'ContractId__c']));
        };

        // Invoke subscribe method of empApi. Pass reference to messageCallback
        subscribe(this.channelName, -1, messageCallback);
    }

    showToast() {
        const event = new ShowToastEvent({
            title: '',
            message: this.label.dateIsInThePastWarning,
            variant: 'error'
        });
        this.dispatchEvent(event);
    }

    // Redirects user to contract record screen.
    goToContract (event) {
        if (event.target.dataset.id) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: event.target.dataset.id,
                    actionName: 'view',
                },
            });
        }
    }

    // Helper method that sets up data with proper CSS and update progress status.
    setupDataOnRefresh () {
        for (var i = 0; i < this.activeContracts.length; i++) {
            this.activeContracts[i].updateInProgress = false;
            this.activeContracts[i].customRowClass = "slds-hint-parent";
        }
        this.contractsNotSelected = true;
    }
    
    // This function is used to keep getting jobs' statuses and handle the logic.
    getJobStatus(jobs) {
        getJobStatus({
            jobIds: jobs
        })
            .then(res => {
                this.jobStatuses = res;
            })
            .catch(error => {
                console.log('ERROR GETTING JOB STATUS!' + error);
            });
    }

    handleChildContractsIncluded(event) {
        if (event.target.checked === true) {
            this.childContractsIncluded = true;
        }
        else {
            this.childContractsIncluded = false;
        }
        this.viewFiveContracts();
    }
}