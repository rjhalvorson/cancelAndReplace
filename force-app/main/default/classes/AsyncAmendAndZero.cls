/****************************************************************************************
Name            : AsyncAmendAndZero
Revision Log    : 8/12/2020 Bryan
                :
                :
Use             : Batchable process to amend previous contracts and create cancellation quotes
                  Once the batch is finished, quote lines are added to replacement quote and calculated
Update          : 7/19/2022
Converted this class to function as Batchable instead of Queueable but 
Since it is managed package and the class is Global
Couldn't remove System.Queueable and it's execute method from class
*****************************************************************************************/


global with sharing class AsyncAmendAndZero implements System.Queueable, Database.Batchable<String>, Database.AllowsCallouts, SBQQ.CalculateCallback {
    ProductManager productManager { get; set; }
    List<String> contractIdList { get; set; }
    Date startDate { get; set; }
    String quoteId { get; set; }
    // Used to kick off another queueable to see if all of the amended contracts are done then creates
    // queue line items based off the amended contracts
    String namespace { get; set; }

    public AsyncAmendAndZero(List<String> contractIdList, String startDate, String quoteId) {
        this.contractIdList = contractIdList;
        this.startDate = Date.valueOf(startDate);
        this.quoteId = quoteId;
        this.namespace = CancelAndReplaceUtility.getNamespace();
    }

    // Required to be global so Quote Calculator can call back to this class and save the newly amended quote
    global AsyncAmendAndZero() {
    }

    public Iterable<String> start(Database.BatchableContext bc) {
        return this.contractIdList;
    }

    // Deprecated Ignore - Queuable execute is not used
    public void execute(QueueableContext context) {
    }

    public void execute(Database.BatchableContext bc, List<String> contractIdList) {
        // Adding this job id to the jobIds list, this is for when we call the QuoteLineQueueable
        // so we can check the status of all of the jobs before we process quote lines
        String jobId = bc.getJobId();
        for(String contractId: contractIdList) {
            execute(jobId, contractId);
        }
    }

    public void execute(String jobId, String contractId) {
        try {
            productManager = new ProductManager();

            // Creates cancellation quotes
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

            // Send the event back to LWC to update the status 
            createEvent(jobId, quoteId,contractId);

        } catch (Exception e) {
            Logger.getInstance().log(AsyncAmendAndZero.class.getName(), e);
            throw new AmendAndZeroException(e.getMessage());
        }
    }

    public void finish(Database.BatchableContext bc){
        // QuoteLines are cloned from previous contracts to new quote and calculated
        QuoteLineQueueable quoteLineQueueable = new QuoteLineQueueable(quoteId);
        
        // Test classes cannot chain queueables, we are just going to directly execute it
        if (Test.isRunningTest()) {
            System.debug(quoteLineQueueable);
            quoteLineQueueable.execute();
        } else {
            System.enqueueJob(quoteLineQueueable);
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

    // Once the calculation is done, SBQQ oprtion calls this method
    // New Quote is saved
    global void callback(String quote) {
        // save the quote
        SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', quote);
    }

    public class AmendAndZeroException extends Exception {
    }
}