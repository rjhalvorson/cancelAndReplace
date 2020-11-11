/****************************************************************************************
Name            : TestDataFactory
Revision Log    : 8/11/2020 Bryan
                :
                :
Use             : TestDataFactory to create records that are needed for CPQ Cancel and Replace
*****************************************************************************************/
@IsTest
public class TestDataFactory {
    public static Account generateAccount(String accountName) {
        Account account = new Account(name = accountName, SBQQ__RenewalModel__c = 'Contract Based');
        return account;
    }

    public static List<Account> inflateChildAccountsWithNamePrefix(List<Account> parentAccounts, String name, Integer totalAccounts){
        List<Account> accounts = new List<Account>();
        for (Account account : parentAccounts) {
            accounts.addAll(inflateAccounts(account.Id,name,totalAccounts));
        }
        return accounts;
    }

    public static List<Account> inflateAccounts(String parentId, String name, Integer totalAccounts) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < totalAccounts; i++) {
            accounts.add(new Account(Name = name, ParentId = parentId,SBQQ__RenewalModel__c = 'Contract Based'));
        }
        return accounts;
    }
}