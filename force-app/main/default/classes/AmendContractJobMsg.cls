/****************************************************************************************
Name            : AmendContractJobMsg
Revision Log    : 8/18/2020 Bryan
                :
                :
Use             : Message class to store contract ids to job ids
*****************************************************************************************/
public with sharing class AmendContractJobMsg {
    @AuraEnabled
    public String opportunityId { get; set; }
    @AuraEnabled
    public String quoteId { get; set; }
    @AuraEnabled
    public String quoteName { get; set; }
    @AuraEnabled
    public List<JobStatus> jobs { get; set; }

    public AmendContractJobMsg(){
        jobs = new List<JobStatus>();
    }



    public class JobStatus {
        @AuraEnabled
        public String contractId { get; set; }
        @AuraEnabled
        public String jobId { get; set; }

        public JobStatus( String contractId, String jobId){
            this.contractId = contractId;
            this.jobId = jobId;
        }

    }

}