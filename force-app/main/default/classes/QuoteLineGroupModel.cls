/****************************************************************************************
Name            : QuoteLineGroupModel
Revision Log    : 8/12/2020 Bryan
                :
                :
Use             : Used with the CPQ API, DO NOT UPDATE VARIABLES UNLESS API CHANGES
*****************************************************************************************/
public with sharing class QuoteLineGroupModel {
    public SBQQ__QuoteLineGroup__c record;
    public Decimal netNonSegmentTotal;
    public Integer key;
}