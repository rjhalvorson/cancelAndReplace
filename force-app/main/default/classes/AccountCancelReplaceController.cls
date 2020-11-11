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
        * Returns a list of accounts in the the accounts hierarchy with the passed in account id. It will also
        * return the account id that was passed in. It has a limit of 10,000 records
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
            Opportunity opportunity = OpportunityService.createOpportunity(amendContracts);
            SBQQ__Quote__c quote = QuoteService.createQuote( amendContracts, opportunity);
            // Querying the quote to get the name field for display
            quote = QuoteSelector.getQuoteById(quote.Id);
            AmendContractJobMsg amendContractJob = new AmendContractJobMsg();
            amendContractJob.opportunityId = opportunity.Id;
            amendContractJob.quoteId = quote.Id;
			amendContractJob.quoteName = quote.Name;

            Set<String> jobIds = new Set<String>();
            // we are not going to iterate over the last record.
            // We will do it independently so we can pass all of the job ids to the last job to check if all of the jobs
            // are complete and create quote line items
            Integer lastContractPosition = amendContracts.contractIds.size() -1;
            for(Integer i = 0; i < lastContractPosition; i++ ){
                String contractId = amendContracts.contractIds[i];
                Id jobId = System.enqueueJob(new AsyncAmendAndZero(contractId, amendContracts.startDate,quote.Id));
                jobIds.add(jobId);
                amendContractJob.jobs.add(new AmendContractJobMsg.JobStatus(contractId, jobId));
            }
            String contractId = amendContracts.contractIds[lastContractPosition];
            AsyncAmendAndZero lastContract = new AsyncAmendAndZero(contractId, amendContracts.startDate,quote.Id,true,jobIds);
            Id jobId = System.enqueueJob(lastContract);
            amendContractJob.jobs.add(new AmendContractJobMsg.JobStatus(contractId, jobId));

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
        try {
            return OpportunityService.getStageNamePicklistValues();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<AmendContractJobStatusMsg> getJobStatus(List<String> jobIds ) {
        try {
            return ApexJobSelector.getJobStatusById(jobIds);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String getNamespacePrefix(){
        return CancelAndReplaceUtility.getNamespaceWithUnderScore();
    }
}