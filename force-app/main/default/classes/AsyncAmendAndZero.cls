/****************************************************************************************
Name            : AsyncAmendAndZero
Revision Log    : 8/12/2020 Bryan
                :
                :
Use             : Process to amend one quote at a time
*****************************************************************************************/
global with sharing class AsyncAmendAndZero implements Queueable, Database.AllowsCallouts, SBQQ.CalculateCallback {
    ProductManager productManager { get; set; }
    String contractId { get; set; }
    Date startDate { get; set; }
    String quoteId { get; set; }
    // Used to kick off another queueable to see if all of the amended contracts are done then creates
    // queue line items based off the amended contracts
    Boolean calculateQuoteLines { get; set; }
    Set<String> jobIds { get; set; }
    String namespace { get; set; }

    public AsyncAmendAndZero(String contractId, String startDate, String quoteId) {
        this(contractId, startDate, quoteId, false, new Set<String>());
    }
    public AsyncAmendAndZero(
        String contractId,
        String startDate,
        String quoteId,
        Boolean calculateQuoteLines,
        Set<String> jobIds
    ) {
        this.contractId = contractId;
        this.startDate = Date.valueOf(startDate);
        this.quoteId = quoteId;
        this.calculateQuoteLines = calculateQuoteLines;
        this.jobIds = jobIds;
        this.namespace = CancelAndReplaceUtility.getNamespace();
    }

    // Required to be global so Quote Calculator can call back to this class and save the newly amended quote
    global AsyncAmendAndZero() {
    }

    public void execute(QueueableContext context) {
        // Adding this job id to the jobIds list, this is for when we call the QuoteLineQueueable
        // so we can check the status of all of the jobs before we process quote lines
        jobIds.add(context.getJobId());
        execute(context.getJobId());
    }

    public void execute(String jobId) {
        try {
            productManager = new ProductManager();
            QuoteModel model = productManager.load(contractId);
            QuoteCalculator calculator = new QuoteCalculator();
            model = calculator.read(model.record.Id);
            model.record.Replacement_Quote__c = quoteId;
            model.record.SBQQ__StartDate__c = startDate;
            for (QuoteLineModel line : model.lineItems) {
                line.record.SBQQ__Quantity__c = 0;
            }
            if(namespace != ''){
                calculator.calculate(model, namespace + '.' + 'AsyncAmendAndZero');
            } else {
                calculator.calculate(model, 'AsyncAmendAndZero');
            }
            createEvent(jobId, quoteId,contractId);
            if (calculateQuoteLines) {
                QuoteLineQueueable quoteLineQueueable = new QuoteLineQueueable(jobIds, quoteId);
                // Test classes cannot chain queueables, we are just going to directly execute it
                if (Test.isRunningTest()) {
                    quoteLineQueueable.execute();
                } else {
                    System.enqueueJob(quoteLineQueueable);
                }
            }
        } catch (Exception e) {
            Logger.getInstance().log(AsyncAmendAndZero.class.getName(), e);
            throw new AmendAndZeroException(e.getMessage());
        }
    }

    // Creates an event with the jobId and the amended quote for the lwc can listen for when the job is done
    private void createEvent(String jobId, String quoteId, String contractId ) {
        Cancel_Replace__e cancelReplaceEvent = new Cancel_Replace__e();
        cancelReplaceEvent.JobId__c = jobId;
        cancelReplaceEvent.QuoteId__c = quoteId;
        cancelReplaceEvent.ContractId__c = contractId;
        // Call method to publish events
        Database.SaveResult sr = EventBus.publish(cancelReplaceEvent);
        // Inspect publishing result
        if (sr.isSuccess()) {
            System.debug('Successfully published event.');
        } else {
            for (Database.Error err : sr.getErrors()) {
                Logger.getInstance().log(AsyncAmendAndZero.class.getName(), err.getMessage());
            }
        }
    }

    global void callback(String quote) {
        // save the quote
        SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', quote);
    }

    public class AmendAndZeroException extends Exception {
    }
}