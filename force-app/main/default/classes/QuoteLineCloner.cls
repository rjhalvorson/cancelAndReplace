/****************************************************************************************
Name            : QuoteLineCloner
Revision Log    : 8/24/2020 Bryan
                :
                :
Use             : Used to clone quote lines to a selected contract
*****************************************************************************************/
public with sharing class QuoteLineCloner {
    public SBQQ__Quote__c replacementQuote;
    List<SBQQ__QuoteLine__c> oldQuoteLines;
    Map<Integer, Integer> reqByMap;

    public QuoteLineCloner(SBQQ__Quote__c replacementQuote,List<SBQQ__QuoteLine__c> oldQuoteLines){
        this.replacementQuote = replacementQuote;
        this.oldQuoteLines = oldQuoteLines;
        createRequiredByMap(this.oldQuoteLines);
    }

    private void createRequiredByMap(List<SBQQ__QuoteLine__c> oldQlList) {
        Map<Id, Integer> idIndexMap = new Map<Id, Integer>();
        reqByMap = new Map<Integer, Integer>();


        for(Integer i=0;i<oldQlList.size();i++){
            idIndexMap.put(oldQlList[i].Id, i);
        }

        for (Integer i = 0; i < oldQlList.size(); i++) {
            if (oldQlList[i].SBQQ__RequiredBy__c != null) {
                reqByMap.put(i, idIndexMap.get(oldQlList[i].SBQQ__RequiredBy__c));
            }
        }
    }

    public List<SBQQ__QuoteLine__c> cloneQuoteLines(){
        return updateAndRemoveExistingData(oldQuoteLines.deepClone(false, false, false));
    }

    //Populate SBQQ__RequiredBy__c on QLs using map data
    private List<SBQQ__QuoteLine__c> populateRequiredBys(
        List<SBQQ__QuoteLine__c> newQlList,
        Map<Integer, Integer> reqByMap
    ) {
        for (Integer i : reqByMap.keySet()) {
            newQlList[i].SBQQ__RequiredBy__c = newQlList[reqByMap.get(i)].Id;
        }
        return newQlList;
    }

    List<SBQQ__QuoteLine__c> cloneQuoteLines(List<SBQQ__QuoteLine__c> oldQlList) {
        return updateAndRemoveExistingData(oldQlList.deepClone(false, false, false));
    }

    //Populate SBQQ__RequiredBy__c on QLs using map data
    public List<SBQQ__QuoteLine__c> populateRequiredBys(List<SBQQ__QuoteLine__c> newQlList){
        for(integer i:reqByMap.keySet()){
            newQlList[i].SBQQ__RequiredBy__c = newQlList[reqByMap.get(i)].id;
        }
        return newQlList;
    }

    // Remove fields that indicate quote is amendment or relate to data specific to old quote (have to remove Quote and Quote Line Ids later from string)
    private List<SBQQ__QuoteLine__c> updateAndRemoveExistingData(List<SBQQ__QuoteLine__c> newQlList) {
        Integer i = 1;
        for (SBQQ__QuoteLine__c ql : newQlList) {
            ql.SBQQ__Quantity__c = ql.SBQQ__PriorQuantity__c;
            ql.SBQQ__PriorQuantity__c = null;
            ql.SBQQ__UpgradedSubscription__c = null;
            ql.SBQQ__UpgradedSubscription__r = null;
            ql.SBQQ__Existing__c = false;
            ql.SBQQ__RequiredBy__c = null;
            ql.SBQQ__Group__c = null;
            ql.SBQQ__StartDate__c = null;
            ql.SBQQ__EndDate__c = null;
            ql.SBQQ__SubscriptionTerm__c = null;
            ql.SBQQ__UpgradedAsset__c = null;
            ql.SBQQ__Quote__c = this.replacementQuote.Id;
            ql.SBQQ__Number__c = i; // Use loop iterator to ensure the bundles appear in order needed
            i++;
        }
        return newQlList;
    }


}