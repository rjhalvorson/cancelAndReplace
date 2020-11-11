/****************************************************************************************
Name            : QuoteService
Revision Log    : 8/19/2020 Bryan
                :
                :
Use             : Service Class for Quotes
*****************************************************************************************/
public with sharing class QuoteService {

    /**
    * Creates a contract related to an opportunity
    *

    * @param  amendContracts  contains the start date and term length for a newly created contract
    * @param  opportunity  opportunity that we are linking the quote we are going to create
    * @return SBQQ__Quote__c returns a newly created quote
    */

    public static SBQQ__Quote__c createQuote( AmendContractsMsg amendContracts, Opportunity opportunity ){
        SBQQ__Quote__c quote = new SBQQ__Quote__c();
        quote.SBQQ__Primary__c = true;
        quote.SBQQ__Opportunity2__c = opportunity.Id;
        quote.SBQQ__StartDate__c = Date.valueOf(amendContracts.startDate);
        quote.SBQQ__SubscriptionTerm__c = amendContracts.termLength;
        Data.create(quote);
        return quote;
    }
}