/****************************************************************************************
Name            : QuoteModel
Revision Log    : 8/12/2020 Bryan
                :
                :
Use             : Used with the CPQ API, DO NOT UPDATE VARIABLES UNLESS API CHANGES
*****************************************************************************************/
public with sharing class QuoteModel {
    public SBQQ__Quote__c record {get; set;}
    public QuoteLineModel[] lineItems {get; set;}
    public QuoteLineGroupModel[] lineItemGroups {get; set;}
    public Integer nextKey;
    public Boolean applyAdditionalDiscountLast;
    public Boolean applyPartnerDiscountFirst;
    public Boolean channelDiscountsOffList;
    public Decimal customerTotal;
    public Decimal netTotal;
    public Decimal netNonSegmentTotal;
}