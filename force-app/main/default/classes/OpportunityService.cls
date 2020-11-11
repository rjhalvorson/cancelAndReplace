/****************************************************************************************
Name            : OpportunityService
Revision Log    : 8/19/2020 Bryan
                :
                :
Use             : Service class for Opportunity
*****************************************************************************************/
public with sharing class OpportunityService {

    /**
    * Creates a contract related to an opportunity
    *

    * @param  amendContracts  contains the AccountId, opportunity stage, close date, and name for a new opportunity
    * @return Opportunity returns a newly created Opportunity
    */
    public static Opportunity createOpportunity( AmendContractsMsg amendContracts){
        Opportunity opp = new Opportunity();
        opp.AccountId = amendContracts.accountId;
        opp.Name = amendContracts.opportunityName;
        opp.StageName = amendContracts.opportunityStage;
        opp.CloseDate = Date.valueOf(amendContracts.startDate);
        Data.create(opp);
        return opp;
    }

    public static List<PicklistMsg> getStageNamePicklistValues(){
        List<PicklistMsg> picklistValues = new List<PicklistMsg>();
        Schema.DescribeFieldResult dfr = Opportunity.StageName.getDescribe();

        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            picklistValues.add(new PicklistMsg(pe.getValue(), pe.getLabel()));
        }
        return picklistValues;
    }

}