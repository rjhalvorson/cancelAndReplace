/****************************************************************************************
Name            : QuoteLineSelector
Revision Log    : 8/24/2020 Bryan
                :
                :
Use             : Used to query records from SBQQ__QuoteLine__c
*****************************************************************************************/
public with sharing class QuoteLineSelector {

    public static List<SBQQ__QuoteLine__c> queryQuoteLinesByReplacementQuote(String replacementQuoteId){
        String queryString = buildQueryStringWithAllFields();
        queryString += ' WHERE SBQQ__Quote__r.Replacement_Quote__c = :replacementQuoteId';
        return (List<SBQQ__QuoteLine__c>)Database.query(queryString);
    }


    public static String buildQueryStringWithAllFields(){
        String queryString = 'SELECT Id';
        for(String fName:Schema.getGlobalDescribe().get('SBQQ__QuoteLine__c').getDescribe().fields.getMap().keySet()){
            if(fName.toLowerCase() != 'sbqq__quote__c' && fName.toLowerCase() != 'id'){
                queryString += ',' + fName;
            }
        }
        queryString += ' FROM SBQQ__QuoteLine__c';
        return queryString;
    }

}