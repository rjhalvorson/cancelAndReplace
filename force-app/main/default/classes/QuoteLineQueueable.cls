/****************************************************************************************
Name            : QuoteLineQueueable
Revision Log    : 8/24/2020 Bryan
                :
                :
Use             : Queueable to clone quote lines from amended contracts to a single quote
*****************************************************************************************/
public with sharing class QuoteLineQueueable implements Queueable, Database.AllowsCallouts {
    Set<String> jobIds { get; set; }
    String quoteId { get; set; }

    // this classes doesn't care how the jobs finished, as long as they are considered done it will process the quote lines
    // if an amend quote job failed, it will still considered it done for the purpose of making quote lines
    private static final Set<String> FINISHED_STATUSES = new Set<String>{ 'aborted', 'completed', 'failed' };

    public QuoteLineQueueable(Set<String> jobIds, String quoteId) {
        this.jobIds = jobIds;
        this.quoteId = quoteId;
    }

    public void execute(QueueableContext context) {
        execute();
    }

    public void execute(){
        try {
            Boolean haveJobsFinished = haveJobsFinished();

            if (haveJobsFinished) {
                cloneQuoteLines();
            } else {
                QuoteLineQueueable quoteLineQueueable = new QuoteLineQueueable(jobIds, quoteId);
                Id jobId = System.enqueueJob(quoteLineQueueable);
            }
        } catch (Exception e) {
            Logger.getInstance().log(AsyncAmendAndZero.class.getName(), e);
            throw e;
        }
    }

    private Boolean haveJobsFinished(){

        List<AmendContractJobStatusMsg> jobs = ApexJobSelector.getJobStatusById(jobIds);
        Boolean jobsFinished = true;
        for (AmendContractJobStatusMsg job : jobs) {
            if (!FINISHED_STATUSES.contains(job.jobStatus.toLowerCase())) {
                jobsFinished = false;
            }
        }
        // Test classes cannot chain jobs, defaulting it to true for this case
        return Test.isRunningTest() ? true :jobsFinished;

    }

    public void cloneQuoteLines(){
        SBQQ__Quote__c quote = QuoteSelector.getQuoteById(quoteId);
        List<SBQQ__QuoteLine__c> quoteLines = QuoteLineSelector.queryQuoteLinesByReplacementQuote(quoteId);
        QuoteLineCloner cloner = new QuoteLineCloner(quote, quoteLines);
        List<SBQQ__QuoteLine__c> clonedQuoteLines = cloner.cloneQuoteLines();

        SBQQ.TriggerControl.disable();
        Data.create(clonedQuoteLines);
        cloner.populateRequiredBys(clonedQuoteLines);
        SBQQ.TriggerControl.enable();
        updateQuotes(JSON.serialize(clonedQuoteLines));

    }
    /**
     * Future method for updating the quote line items
     * This is done in a future method due to callout issues with updating quote line items
     *

     * @param  jsonRecords  quote string that can be converted to a list of quotes to be updated
     */
    @Future
    private static void updateQuotes(String jsonRecords) {
        try {
            List<SBQQ__QuoteLine__c> quoteLines = (List<SBQQ__QuoteLine__c>) JSON.deserialize(
                jsonRecords,
                List<SBQQ__QuoteLine__c>.class
            );
            Data.modify(quoteLines);
        } catch (Exception e) {
            Logger.getInstance().log(AsyncAmendAndZero.class.getName(), e);
            throw e;
        }
    }
}