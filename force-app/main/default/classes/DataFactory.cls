/****************************************************************************************
Name            : DataFactory
Revision Log    : 8/19/2020 runyan
                :
                :
Use             : DataFactory to create records that are needed for CPQ Cancel and Replace.
*****************************************************************************************/
public with sharing class DataFactory {

    
    public static String[] loadData() { 
         Map<String, Product2> productCodes = DataFactory.createProducts();                              // insert Products, map helps with prices and line items later
         DataFactory.loadStandardPrices(productCodes);                                                   // salesforce requires a standard price
         Pricebook2 custPriceBook = DataFactory.loadCustomPriceBook();                                   // using custom pricebook for test data becuase its easier to wipe and reload
         DataFactory.loadCustomPrices(productCodes, custPriceBook);                                      // using custom prices for test data becuase its easier to wipe and reload
         DataFactory.loadProductOptions(productCodes);                                                   // creates a Parent Bundle that requires Annual and Monthly Scubscription products
         List<Account> accounts = DataFactory.loadAccounts(5);                                           // creates an account hierarchy 5 levels deep                                                                                             
         List<Opportunity> opportunities = DataFactory.loadOpportunities(accounts, custPriceBook, 2);    // SBBQ Triggers add the PriceBook to the Quote when you save it on the Oppty                               // specify the # of opps you want                                                            
         List<SBQQ__Quote__c> quotes = DataFactory.loadQuotes(opportunities, custPriceBook);                       

         // build the return that gets passed into DataFactoryQuoteCalculator to generate the correct quote lines
         List<String> bundledQuotes = new List<String>();
         for (SBQQ__Quote__c quote : quotes) {
            Id quoteLineProdId;
            if (quote.SBQQ__Introduction__c.contains('Bundle')) { 
                quoteLineProdId = productCodes.get('PB01').Id;
            } else {
                quoteLineProdId = productCodes.get('QS01').Id;
            }

             QuoteToBundle quote2Bundle = new QuoteToBundle();
                quote2Bundle.quoteId = quote.Id;
                quote2Bundle.priceBookId = quote.SBQQ__PriceBook__c;
                quote2Bundle.productId = quoteLineProdId;
            bundledQuotes.add(JSON.serialize(quote2Bundle));
        }
        return bundledQuotes;
    }

        //used to construct a JSON return to manage an async call to the DataFactoryQuoteCalculator
        public class QuoteToBundle {
            public String quoteId {get;set;}
            public Id priceBookId {get;set;}
            public Id productId {get;set;}
        }


        // insert products meant for bundlings
        private static Map<String, Product2> createProducts(){
            List<Product2> products = new List<Product2>();
            Product2 prod1 = new Product2(
                Name = 'ParentBundle',
                ProductCode = 'PB01',
                IsActive = true,
                SBQQ__PricingMethod__c = 'List',
                SBQQ__SubscriptionPricing__c = 'Fixed Price',
                SBQQ__SubscriptionTerm__c = 12
            );
            products.add(prod1);

                Product2 prod2 = new Product2(
                Name = 'Annual Subscription',
                ProductCode = 'AS01',
                IsActive = true,
                SBQQ__PricingMethod__c = 'List',
                SBQQ__SubscriptionPricing__c = 'Fixed Price',
                SBQQ__SubscriptionTerm__c = 12
            );
            products.add(prod2);

            Product2 prod3 = new Product2(
                Name = 'Monthly Subscription',
                ProductCode = 'MS01',
                IsActive = true,
                SBQQ__PricingMethod__c = 'List',
                SBQQ__SubscriptionPricing__c = 'Fixed Price',
                SBQQ__SubscriptionTerm__c = 1
            );
            products.add(prod3);

            Product2 prod4 = new Product2(
                Name = 'Quarterly Subscription',
                ProductCode = 'QS01',
                IsActive = true,
                SBQQ__PricingMethod__c = 'List',
                SBQQ__SubscriptionPricing__c = 'Fixed Price',
                SBQQ__SubscriptionTerm__c = 3
            );
            products.add(prod4);
        
            insert products;

            // utility map for working with line items and product bundles
            Map<String, Product2> productCodes = new Map<String, Product2>();
                productCodes.put(products[0].ProductCode,products[0]);    //PB01 ParentBundle
                productCodes.put(products[1].ProductCode,products[1]);    //AS01 Annual Subscription
                productCodes.put(products[2].ProductCode,products[2]);    //MS01 Monthly Subscription
                productCodes.put(products[3].ProductCode,products[3]);    //QS01 Quarterly Subscription

            return productCodes;

        }
    

        // required to have std prices to use a price from any pricebook
        private static void loadStandardPrices(Map<String, Product2> productCodes){
            Pricebook2 stdPriceBook = new Pricebook2();
            if( Test.isRunningTest()){
                stdPriceBook.Id = Test.getStandardPricebookId();
            } else {
                stdPriceBook = [SELECT ID FROM Pricebook2 WHERE IsStandard=true WITH SECURITY_ENFORCED];
            }
            List<PricebookEntry>  stdPrices = new List<PricebookEntry>();
            for (String key : productCodes.keySet()) {
                PricebookEntry pbe = new PricebookEntry(
                    Pricebook2Id = stdPriceBook.Id,
                    Product2Id = productCodes.get(key).Id,
                    IsActive = true,
                    UnitPrice = 1
                    );
                    stdPrices.add(pbe);
            }
            insert stdPrices;
        }


        // create the cpq pricebook
        private static Pricebook2 loadCustomPriceBook(){
            Pricebook2 custPriceBook = new Pricebook2(Name='CPQ Price Book', IsActive=true);
            insert custPriceBook;
            return custPriceBook;
        }

        // create the pq products, bundles and prices we will work with
        private static void loadCustomPrices(Map<String, Product2> productCodes, PriceBook2 custPriceBook) {
            List<PricebookEntry> cpqPrices = new List<PricebookEntry>();

            PricebookEntry parentBundle = new PricebookEntry(
                Pricebook2Id = custPriceBook.Id,
                Product2Id = productCodes.get('PB01').Id,
                IsActive = true,
                UnitPrice = 0
                );
            cpqPrices.add(parentBundle);

            PricebookEntry annualSubsription = new PricebookEntry(
                Pricebook2Id = custPriceBook.Id,
                Product2Id = productCodes.get('AS01').Id,
                IsActive = true,
                UnitPrice = 1200
                );
            cpqPrices.add(annualSubsription);

            PricebookEntry monthlySubscription = new PricebookEntry(
                Pricebook2Id = custPriceBook.Id,
                Product2Id = productCodes.get('MS01').Id,
                IsActive = true,
                UnitPrice = 100
                );
            cpqPrices.add(monthlySubscription);

            PricebookEntry quarterlySubscription = new PricebookEntry(
                Pricebook2Id = custPriceBook.Id,
                Product2Id = productCodes.get('QS01').Id,
                IsActive = true,
                UnitPrice = 200
                );
            cpqPrices.add(quarterlySubscription);

            insert cpqPrices;
        }

        // create product bundles
        private static void loadProductOptions(Map<String, Product2> productCodes){
            List<SBQQ__ProductOption__c> productOptions = new List<SBQQ__ProductOption__c>();
            SBQQ__ProductOption__c annualParentBundle = new SBQQ__ProductOption__c(
                SBQQ__Number__c = 10,
                SBQQ__Quantity__c = 1,
                SBQQ__Required__c = true,
                SBQQ__OptionalSKU__c = productCodes.get('AS01').Id,
                SBQQ__ConfiguredSKU__c = productCodes.get('PB01').Id
                );
            productOptions.add(annualParentBundle);

            SBQQ__ProductOption__c monthlyParentBundle = new SBQQ__ProductOption__c(
                SBQQ__Number__c = 20,
                SBQQ__Quantity__c = 1,
                SBQQ__Required__c = true,
                SBQQ__OptionalSKU__c = productCodes.get('MS01').Id,
                SBQQ__ConfiguredSKU__c = productCodes.get('PB01').Id
                );
            productOptions.add(monthlyParentBundle);

            insert productOptions;
        }

        // create account hierarchy
        private static List<Account> loadAccounts(Integer numAccounts) {
            List<Account> accounts = new List<Account>();
                for (Integer i = 0; i < numAccounts; i++) {
                    if (i == 0) {
                        Account ultimageParent = new Account();
                        ultimageParent.Name = 'Ultimate Parent';
                        ultimageParent.SBQQ__RenewalModel__c = 'Contract Based';
                        accounts.add(ultimageParent);
                    } else {
                        Account childAccount = new Account();
                        childAccount.Name = 'Child ' + i;
                        childAccount.SBQQ__RenewalModel__c = 'Contract Based';
                        accounts.add(childAccount);
                    }
                }
                insert accounts;

                // set parent hierarchy
                    for (Integer i=0; i < accounts.size(); i++){
                        if (i==0){
                            // ultimate parent has no parent
                            } else {
                            accounts[i].ParentId = accounts[i-1].Id;
                        }
                    }
                    update accounts;
                    return accounts;
        }


        // create opportunities
        private static List<Opportunity> loadOpportunities(List<Account> accounts, Pricebook2 custPriceBook, Integer numOppsPerAccount){
            List<Opportunity> opportunities = new List<Opportunity>();
            for (Account a : accounts){
                for (Integer i = 0; i < numOppsPerAccount; i++) {
                    String oppName = '';
                    if(Math.mod(i,2)==1){
                        oppName = 'Quarterly Subscription Opp';
                    } else {
                        oppName = 'Parent Bundle Opp';
                    }
                    Opportunity opp = new Opportunity();
                    opp.AccountId = a.Id;
                    opp.Name = oppName;
                    opp.CloseDate = Date.today();
                    opp.StageName = 'Prospecting';
                    opp.Pricebook2 = custPriceBook;
                    opportunities.add(opp);
                }
            }
            insert opportunities;
            return opportunities;
        }

        // create a primary quote for each opportunity
        private static List<SBQQ__Quote__c> loadQuotes(List<Opportunity> opportunities, Pricebook2 custPriceBook) {
            List<SBQQ__Quote__c> quotes = new  List<SBQQ__Quote__c>();
            Integer term;
            for (Opportunity opp : opportunities) {
                if (opp.Name.contains('Parent')){
                    term = 24;
                } else {
                    term=36;
                }
                SBQQ__Quote__c quote = new SBQQ__Quote__c(
                    SBQQ__Account__c = opp.AccountId,
                    SBQQ__Opportunity2__c = opp.Id,
                    SBQQ__Primary__c = true,
                    SBQQ__StartDate__c = Date.today(),
                    SBQQ__SubscriptionTerm__c = term,
                    SBQQ__Introduction__c = opp.Name,
                    SBQQ__PricebookId__c = custPriceBook.Id
                    );
                quotes.add(quote);
            }
            insert quotes;
            return quotes;
        }

        
}