/****************************************************************************************
Name            : QuoteSelector
Revision Log    : 8/21/2020 Bryan
                :
                :
Use             : Used to query Quotes
*****************************************************************************************/
public with sharing class QuoteSelector {
    public static List<SBQQ__Quote__c> getChildQuotesByParentId(Set<Id> parentQuotes) {
        return [
            SELECT Id,Name, SBQQ__Ordered__c, SBQQ__StartDate__c,Replacement_Quote__c
            FROM SBQQ__Quote__c
            WHERE Replacement_Quote__c IN :parentQuotes
            WITH SECURITY_ENFORCED
        ];
    }

    public static SBQQ__Quote__c getQuoteById( String quoteId ){
        return [SELECT Id, Name, SBQQ__PricebookId__c FROM SBQQ__Quote__c WHERE Id =:quoteId WITH SECURITY_ENFORCED];
    }
}