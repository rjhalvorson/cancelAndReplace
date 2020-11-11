/****************************************************************************************
Name            : ContractSelector
Revision Log    : 8/11/2020 Bryan
                :
                :
Use             : Used to query records from the Contract Table
*****************************************************************************************/
public with sharing class ContractSelector {
    /**
     * Returns a list of contracts that are related to a giving account
     *
     * @param  accountIds the accounts that the contracts are related to
     * @param amountOfRecords Can pass a specific amount of records to get, or pass 'All'.
     * @return List<Contract> a list of contracts linked to an account
     */
    public List<Contract> getContractsByAccount(List<String> accountIds, String amountOfRecords) {
        String query = 'SELECT Id, AccountId, Account.Name, ContractNumber, StartDate, EndDate, ContractTerm';
        query += ' FROM Contract';
        query += ' WHERE Status = \'Activated\' AND AccountId in :accountIds AND EndDate > TODAY';
        query += ' WITH SECURITY_ENFORCED';
        // Only going to use amountOfRecords if it is numeric, if its not we are assuming we want all records returned
        if (String.isNotBlank(amountOfRecords) && amountOfRecords.isNumeric()) {
            query += ' LIMIT ' + integer.valueof(amountOfRecords);
        }
        return (List<Contract>) Database.query(query);
    }


}