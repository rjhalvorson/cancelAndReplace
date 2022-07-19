/****************************************************************************************
Name            : QuoteLineQueueable
Revision Log    : 8/24/2020 Bryan
                :
                :
Use             : Queueable to clone quote lines from amended contracts to a new quote
*****************************************************************************************/
public with sharing class QuoteLineQueueable implements Queueable, Database.AllowsCallouts {
    String quoteId { get; set; }

    // this classes doesn't care how the jobs finished, as long as they are considered done it will process the quote lines
    // if an amend quote job failed, it will still considered it done for the purpose of making quote lines
    private static final Set<String> FINISHED_STATUSES = new Set<String>{ 'aborted', 'completed', 'failed' };

    public QuoteLineQueueable(String quoteId) {
        this.quoteId = quoteId;
    }

    public void execute(QueueableContext context) {
        execute();
    }

    public void execute(){
        try {
            cloneQuoteLines();  
        } catch (Exception e) {
            Logger.getInstance().log(AsyncAmendAndZero.class.getName(), e);
            throw e;
        }
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
        
        //Since this class called from Batch finish, we can't invoke future method using test
        //We need future method when not testing due to callout issues with updating quote line items
        if(Test.isRunningTest()) {
            updateQuotes(JSON.serialize(clonedQuoteLines));
        } else {
            updateQuotesFuture(JSON.serialize(clonedQuoteLines));
        }
    }

    /**
     * Future method for updating the quote line items
     * This is done in a future method due to callout issues with updating quote line items
     *

     * @param  jsonRecords  quote string that can be converted to a list of quotes to be updated
     */
    @Future
    private static void updateQuotesFuture(String jsonRecords) {
        updateQuotes(jsonRecords);
    }

    public static void updateQuotes(String jsonRecords) {
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