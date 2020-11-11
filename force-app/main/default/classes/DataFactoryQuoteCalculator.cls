/****************************************************************************************
Name            : DataFactory
Revision Log    : 8/19/2020 runyan
                :
                :
Use             : QuoteCalulator to add products and bundles needed to test Cancel and Replace
*****************************************************************************************/
global with sharing class DataFactoryQuoteCalculator  implements Queueable, Database.AllowsCallouts, SBQQ.CalculateCallback  {

    String quoteId {get;set;}
    Id pbId {get;set;}  
    Id prodId {get;set;}  
    QuoteCalculator calculator = new QuoteCalculator();         // calculator has a QuoteModel constructor called read()
    ProductManager manager = new ProductManager();              // CPQ's way of querying and building quote lines from products to add to a Quote
    ProductModel product = new ProductModel();
    ProductModel[] products = new List<ProductModel>();         // Quote Model needs lines in an array of Product Model format
    QuoteModel model = new QuoteModel();                        // CPQ's way of calculating and saving Quotes to the databasa
    String curr = 'USD';                                        // our test data is US only
    Integer groupKey;

    // this fails when public, why does it need to be global?
    global DataFactoryQuoteCalculator(){
    }

        // built to be queuable and generate 1 quote at a time 
        public DataFactoryQuoteCalculator (String quoteId,  Id pbId, Id prodId) {
            this.quoteId = quoteId;
            this.pbId = pbId;
            this.prodId = prodId;
            Id jobId = System.enqueueJob(this);
            System.debug('Job Id ' + jobId + ' has been successfully enqueued');

        }

        public void execute(QueueableContext context){

            // construct a QuoteModel from quote Id
            model = calculator.read(quoteId);
            product = manager.readProduct(prodId, pbId, curr);
            // this is the magic that adds the product bundles based on product options
            LoadRuleRunner runner = new LoadRuleRunner();       
            product = runner.load(prodId, model, null, null, product.configuration, null);
            // we only need one product, but we add to an array because that's how it's done
            products.add(product); 
            System.debug('This is the pricebookid text field ' + model.record.SBQQ__PricebookId__c);
            model = manager.addProduct(model, products, groupKey);
            calculator.calculate(model, 'DataFactoryQuoteCalculator');
          
        }
        

        global void callback(String quote){
            //saves the quote returned by loading the SBQQ.QuoteAPI.QuoteCalculator
            SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', quote);     
        }


}