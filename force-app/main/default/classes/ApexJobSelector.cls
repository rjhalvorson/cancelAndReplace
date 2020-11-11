/****************************************************************************************
Name            : ApexJobSelector
Revision Log    : 8/20/2020 Bryan
                :
                :
Use             : Class to query the Apex Job Selector
*****************************************************************************************/
public with sharing class ApexJobSelector {

    public static List<AmendContractJobStatusMsg> getJobStatusById(List<String> jobIds){
        return getJobStatusById(new Set<String>(jobIds));
    }

    public static List<AmendContractJobStatusMsg> getJobStatusById(Set<String> jobIds){
        List<AmendContractJobStatusMsg> jobStatuses = new List<AmendContractJobStatusMsg>();
        // Not enforcing sharing since we want to get these records back to get the status
        List<AsyncApexJob> jobs = [SELECT Id,ApexClass.Name, Status FROM AsyncApexJob WHERE Id IN :jobIds ];
        for(AsyncApexJob job : jobs ){
            jobStatuses.add( new AmendContractJobStatusMsg( job.Id,job.Status) );
        }
        return jobStatuses;
    }

}