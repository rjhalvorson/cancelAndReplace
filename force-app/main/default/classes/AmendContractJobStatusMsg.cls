/****************************************************************************************
Name            : AmendContractJobStatusMsg
Revision Log    : 8/18/2020 Bryan
                :
                :
Use             : Message class to store the status of a job
*****************************************************************************************/
public with sharing class AmendContractJobStatusMsg {
    @AuraEnabled
    public String jobId { get; set; }
    @AuraEnabled
    public String jobStatus { get; set; }

    public AmendContractJobStatusMsg(String jobId, String jobStatus) {
        this.jobId = jobId;
        this.jobStatus = jobStatus;
    }
}