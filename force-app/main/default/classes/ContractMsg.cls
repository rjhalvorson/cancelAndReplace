/****************************************************************************************
Name            : AmendmentContractMsg
Revision Log    : 8/11/2020 Bryan
                :
                :
Use             : Data class to store contract info
*****************************************************************************************/
public with sharing class ContractMsg {
    @AuraEnabled
    public String id { get; set; }
    @AuraEnabled
    public String accountName { get; set; }
    @AuraEnabled
    public String contractNumber { get; set; }
    @AuraEnabled
    public Date startDate { get; set; }
    @AuraEnabled
    public Date endDate { get; set; }
    @AuraEnabled
    public Boolean terminate { get; set; }
    @AuraEnabled
    public Date terminationDate { get; set; }
    @AuraEnabled
    public Integer contractTerm { get; set; }
}