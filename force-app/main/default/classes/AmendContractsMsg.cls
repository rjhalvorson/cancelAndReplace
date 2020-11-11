/****************************************************************************************
Name            : AmendContractsMsg
Revision Log    : 8/18/2020 Bryan
                :
                :
Use             : Message class that stores data for amending contracts and creating a new opportunity and quote
*****************************************************************************************/
public with sharing class AmendContractsMsg {
    @AuraEnabled
    public List<String> contractIds { get; set; }
    @AuraEnabled
    public String startDate { get; set; }
    @AuraEnabled
    public String accountId { get; set; }
    @AuraEnabled
    public Integer termLength { get; set; }
    @AuraEnabled
    public String opportunityStage { get; set; }
    @AuraEnabled
    public String opportunityName { get; set; }


}