/****************************************************************************************
Name            : AccountCancelReplaceController
Revision Log    : 8/11/2020 Bryan
                :
                :
Use             : Controller for account to use the cancel and replace functionality
*****************************************************************************************/
public with sharing class AccountCancelReplaceController {
    /**
     * Returns a list of contracts that are linked to the accounts that have been passed in
     *

     * @param  recordIds  account Ids that we are using to get the related contract
     * @param amountOfRecords Can pass a specific amount of records to get, or pass 'All'.
     * @return List<AmendmentContractMsg> a list of amendment contracts linked to an account
     */
    @AuraEnabled
    public static List<ContractMsg> getContracts(List<String> recordIds, String amountOfRecords) {
        try {
            return ContractService.getAmendmentContractsByAccountId(recordIds, amountOfRecords);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
    * Returns a list of accounts in the the accounts hierarchy with the passed in account id. It will also
    * return the account id that was passed in. It has a limit of 10,000 records
    *

    * @param  recordId  account Id that we are using to get related accounts
    * @return List<String> a list of account Ids
    */
    @AuraEnabled
    public static List<String> getAccounts(String recordId) {
        try {
            return AccountService.getRelatedAccounts(recordId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }


     /**
        * Amends the contracts and creates cancellation quotes for the contracts
        * Then generates a replacement quote copying all the products from the contracts
        *

        * @param  amendContracts  contract message the data needed to amend contracts and create a new opportunity and quote
        * @return AmendContractJobMsg contains the new opportunity that was created, the new quote and a list of contracts and job ids
        */
    @AuraEnabled
    public static AmendContractJobMsg amendContracts(AmendContractsMsg amendContracts) {
        try {
            // GUARD CLAUSE: We only want to create a new contract and quote if we have passed in contracts
            if( amendContracts.contractIds == null || amendContracts.contractIds.size() < 1){
                return null;
            }

            // Opportunity for the replacement quote (New Quote with products from previous contracts)
            Opportunity opportunity = OpportunityService.createOpportunity(amendContracts);

            // New/Replacement Quote
            SBQQ__Quote__c quote = QuoteService.createQuote( amendContracts, opportunity);
            
            // Querying the quote to get the name field for display
            quote = QuoteSelector.getQuoteById(quote.Id);

            // Populate Return Type
            AmendContractJobMsg amendContractJob = new AmendContractJobMsg();
            amendContractJob.opportunityId = opportunity.Id;
            amendContractJob.quoteId = quote.Id;
			amendContractJob.quoteName = quote.Name;
            
            // Batch is created to amend previous contracts and create cancellation quotes
            // Once the batch is finished, quote lines are added to replacement quote and calculated
            AsyncAmendAndZero asyncAmendZero = new AsyncAmendAndZero(amendContracts.contractIds, amendContracts.startDate,quote.Id);
            Id batchProcessId = Database.executeBatch(asyncAmendZero, 1);

            return amendContractJob;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
        * Grabs all of the available picklist values for the stage field on opportunity
        *

        * @return List<PicklistMsg> a list picklist values with label and value
        */
    @AuraEnabled
    public static List<PicklistMsg> getOpportunityStageValues() {
        return OpportunityService.getStageNamePicklistValues();
    }

    @AuraEnabled
    public static String getNamespacePrefix(){
        return CancelAndReplaceUtility.getNamespaceWithUnderScore();
    }
}