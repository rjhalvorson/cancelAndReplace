/****************************************************************************************
Name            : AccountSelector
Revision Log    : 8/24/2020 Bryan
                :
                :
Use             : Queries accounts
*****************************************************************************************/
public with sharing class AccountSelector {

    /**
    * Returns a set of account Ids that are in the same hierarchy as the list of account ids that are passed in.
    *

    * @param  accountIds  account ids that we are using to get related accounts, we are also ignoring retrieving accounts
     *                      that are already in this list
    * @param  maxRecords  the max amount of records we want to return in the query
    * @return Set<String> returns all related account Ids
    */
    public static Set<String> getRelatedAccounts(Set<String> accountIds, Integer maxRecords ) {
        Set<String> retrievedIds = new Set<String>();
        List<Account> accounts =
                [
                        SELECT Id,
                                ParentId,
                                Parent.ParentId,
                                Parent.Parent.ParentId,
                                Parent.Parent.Parent.ParentId
                        FROM   Account
                        WHERE ((ParentId IN :accountIds) OR
                        (Parent.ParentId IN :accountIds) OR
                        (Parent.Parent.ParentId IN :accountIds) OR
                        (Parent.Parent.Parent.ParentId IN :accountIds))
                        AND Id NOT IN :accountIds
                         WITH SECURITY_ENFORCED  LIMIT :maxRecords];

        for( Account account : accounts ){
            retrievedIds.add(account.Id);
            retrievedIds.add(account.ParentId);
            retrievedIds.add(account.Parent.ParentId);
            retrievedIds.add(account.Parent.Parent.ParentId);
            retrievedIds.add(account.Parent.Parent.Parent.ParentId);
        }
        // Removing any null values from the parent records. Saves us from doing a bunch of if checks
        retrievedIds.remove(null);
        return  retrievedIds;

    }

}