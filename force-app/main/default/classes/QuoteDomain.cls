/****************************************************************************************
Name            : QuoteDomain
Revision Log    : 8/21/2020 Bryan
                :
                :
Use             : Used for quote Trigger
*****************************************************************************************/
public with sharing class QuoteDomain {
    @TestVisible
    private static Cancelled_Quote_Settings__mdt quoteSettings = getSettings();

    public void onUpdate(Map<Id, SBQQ__Quote__c> newQuoteMap, Map<Id, SBQQ__Quote__c> oldQuoteMap) {
        // GUARD CLAUSE: If either field is false we are going to stop here without processing
        if (!quoteSettings.Sync_Orders__c && !quoteSettings.Sync_QuoteStartDate__c) {
            return;
        }
        Map<Id, SBQQ__Quote__c> quoteWithUpdatedOrdered = new Map<Id, SBQQ__Quote__c>();
        Map<Id, SBQQ__Quote__c> quoteWithUpdatedStartDate = new Map<Id, SBQQ__Quote__c>();

        for (SBQQ__Quote__c quote : newQuoteMap.values()) {
            SBQQ__Quote__c oldQuote = oldQuoteMap.get(quote.Id);
            // Only want to update the child quotes if the replacement quote ordered value was update to true
            if (quoteSettings.Sync_Orders__c && quote.SBQQ__Ordered__c && !oldQuote.SBQQ__Ordered__c) {
                quoteWithUpdatedOrdered.put(quote.Id, quote);
            }
            if (quoteSettings.Sync_QuoteStartDate__c && quote.SBQQ__StartDate__c != oldQuote.SBQQ__StartDate__c) {
                quoteWithUpdatedStartDate.put(quote.Id, quote);
            }
        }
        Set<Id> updatedRecords = new Set<Id>();
        updatedRecords.addAll(quoteWithUpdatedStartDate.keySet());
        updatedRecords.addAll(quoteWithUpdatedOrdered.keySet());

        List<SBQQ__Quote__c> childQuotes = QuoteSelector.getChildQuotesByParentId(updatedRecords);
        Map<Id, SBQQ__Quote__c> childQuotesToUpdate = new Map<Id, SBQQ__Quote__c>();
        for (SBQQ__Quote__c quote : childQuotes) {
            if (quoteWithUpdatedOrdered.containsKey(quote.Replacement_Quote__c)) {
                SBQQ__Quote__c parentQuote = quoteWithUpdatedOrdered.get(quote.Replacement_Quote__c);
                if (quote.SBQQ__Ordered__c != parentQuote.SBQQ__Ordered__c) {
                    quote.SBQQ__Ordered__c = parentQuote.SBQQ__Ordered__c;
                    childQuotesToUpdate.put(quote.Id, quote);
                }
            }
            if (quoteWithUpdatedStartDate.containsKey(quote.Replacement_Quote__c)) {
                SBQQ__Quote__c parentQuote = quoteWithUpdatedStartDate.get(quote.Replacement_Quote__c);
                if (quote.SBQQ__StartDate__c != parentQuote.SBQQ__StartDate__c) {
                    quote.SBQQ__StartDate__c = parentQuote.SBQQ__StartDate__c;
                    childQuotesToUpdate.put(quote.Id, quote);
                }
            }
        }

        if (childQuotesToUpdate.size() > 0) {
            Database.DMLOptions options = new Database.DMLOptions();
            options.optAllOrNone = false;
            List<SBQQ__Quote__c> childRecords = childQuotesToUpdate.values();
            List<Database.SaveResult> results = Data.modify(childRecords,options);
            for( Integer i = 0; i < results.size(); i++ ){
                Database.SaveResult sr = results[i];
                if ( !sr.isSuccess()) {
                    SBQQ__Quote__c quote = childRecords[i];
                    SBQQ__Quote__c parentQuote = newQuoteMap.get(quote.Replacement_Quote__c);
                    for(Database.Error err : sr.getErrors()) {
                        parentQuote.addError(String.format(System.Label.ReplacementQuoteUpdateError, new List<Object>{quote.Name,err.getMessage()}));
                    }
                }
            }
        }
    }

    /**
     * Returns settings for syncing a newly created quote with amended quotes
     * This looks for at least 1 record in the custom metadata type and if there is, it will use if, if none
     * are found it will default to having the settings off
     *
     * @return Cancelled_Quote_Settings__mdt
     */
    private static Cancelled_Quote_Settings__mdt getSettings() {
        if ( quoteSettings == null ){
            List<Cancelled_Quote_Settings__mdt> settings = [
                    SELECT Sync_Orders__c, Sync_QuoteStartDate__c
                    FROM Cancelled_Quote_Settings__mdt
                    LIMIT 1
            ];
            if (settings.isEmpty()) {
                return new Cancelled_Quote_Settings__mdt(Sync_Orders__c = false,Sync_QuoteStartDate__c = false);
            } else {
                return settings[0];
            }
        }
        return quoteSettings;
    }
}