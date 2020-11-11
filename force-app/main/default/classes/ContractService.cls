/****************************************************************************************
Name            : ContractService
Revision Log    : 8/11/2020 Bryan
                :
                :
Use             : Service class to work with contracts
*****************************************************************************************/
public with sharing class ContractService {
    /**
     * Takes an account Id and queries contracts that are linked to them. Then converts the data to a message class to pass back
     *
     * @param  accountIds  the accounts that the contracts are related to
     * @param  amountOfRecords  String that could say 'All' or be a numeric value. if it's numeric it will return only that amount
     * @return List<AmendmentContractMsg> a list of all amendment contracts linked to an account
     */
    public static List<ContractMsg> getAmendmentContractsByAccountId(List<String> accountIds, String amountOfRecords) {
        List<Contract> contracts = new ContractSelector().getContractsByAccount(accountIds, amountOfRecords);

        List<ContractMsg> amendmentContracts = new List<ContractMsg>();

        for (Contract contract : contracts) {
            ContractMsg amendmentContract = new ContractMsg();
            amendmentContract.id = contract.Id;
            amendmentContract.accountName = contract.Account.Name;
            amendmentContract.contractNumber = contract.ContractNumber;
            amendmentContract.startDate = contract.StartDate;
            amendmentContract.endDate = contract.EndDate;
            amendmentContract.terminationDate = Date.today();
            amendmentContract.terminate = false;
            amendmentContract.contractTerm = contract.contractTerm;
            amendmentContracts.add(amendmentContract);
        }
        return amendmentContracts;
    }
}