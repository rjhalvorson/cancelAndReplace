/****************************************************************************************
Name            : AccountService
Revision Log    : 8/25/2020 Bryan
                :
                :
Use             : Service class to work with accounts
*****************************************************************************************/
public with sharing class AccountService {

    /**
    * Returns a set of account Ids that are in the same hierarchy as the list of account ids that are passed in.
     * Will consume queries and records until it hits the max rows, max queries, or no more records can be returned
    *
    * @param  accountId  account Id that we are going to use to return accounts in the hierarchy
    * @return List<String> returns all related account Ids
    */
    public static  List<String> getRelatedAccounts( String accountId ){
        Integer maxRecords = Limits.getLimitQueryRows();
        Integer recordsRetrieved = Limits.getQueryRows();
        Integer maxQueries = Limits.getLimitQueryRows();
        Integer queriesLeft = Limits.getQueries();
        Boolean hasMoreRecords = true;
        Set<String> accountIds = new Set<String>{ accountId};

        // Will keep doing queries until we get max rows, max queries, or all related accounts
        while( recordsRetrieved < maxRecords && hasMoreRecords && queriesLeft < maxQueries ){
            Integer remainingRecords = maxRecords - recordsRetrieved;
            Set<String> recordsReturned = AccountSelector.getRelatedAccounts(accountIds,remainingRecords);
            // If no records are returned we will stop the loop
            if ( recordsReturned.isEmpty() ) {
                hasMoreRecords = false;
            } else {
                accountIds.addAll(recordsReturned);
            }

            recordsRetrieved = Limits.getQueryRows();
            queriesLeft = Limits.getQueries();
        }

        return new List<String>(accountIds);
    }

}