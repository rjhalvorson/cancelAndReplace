import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import goToQuoteDesc from '@salesforce/label/c.goToQuoteDesc';
import goToNewQuote from '@salesforce/label/c.goToNewQuote';
import havePendingChanges from '@salesforce/label/c.havePendingChanges';

/**
 * Go to new quote card LWC component.
 *
 * @author Chris Shatrov, CodeScience
 * @date August 21st, 2020
 */
export default class GoToNewQuote extends NavigationMixin(LightningElement) {

    /**
     * Expose Salesforce custom labels.
     */
    label = {
        goToQuoteDesc: goToQuoteDesc,
        goToNewQuote: goToNewQuote,
        havePendingChanges: havePendingChanges
    };

    @api quoteId;
    @api quoteName;

    /**
     * Redirects user to quote record screen.
     */
    navigateToQuote (event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.quoteId,
                actionName: 'view',
            },
        });
    }
}