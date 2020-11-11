/****************************************************************************************
Name            : AccountCancelReplaceControllerTest
Revision Log    : 8/11/2020 Bryan
                :
                :
Use             : Cancel and replace test class
*****************************************************************************************/
@IsTest
private class AccountCancelReplaceControllerTest {
    private static final String ADMIN_USER_EMAIL = 'AccountCancelReplaceControllerTest@cpqcr.com';

    @TestSetup
    private static void makeData() {
        TestUserFactory.createUserAdmin(ADMIN_USER_EMAIL);
    }

    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Email = :ADMIN_USER_EMAIL];
    }
    // This method will be updated to remove data. We need to build out a test setup that is going to create all of the basic records for us
    @IsTest
    static void getContracts_noContracts_emptyList() {
        System.runAs(getAdminUser()) {
            // Arrange
            Account account = TestDataFactory.generateAccount('TestAccount');
            insert account;
            // Act
            Test.startTest();
            List<ContractMsg> contracts = AccountCancelReplaceController.getContracts(
                new List<String>{ account.Id },
                'All'
            );
            test.stopTest();

            System.assertEquals(0, contracts.size(), 'We should not have any contracts for an account');
        }

    }

    @IsTest
    static void getContracts_OneContract_ListOfOne() {
        System.runAs(getAdminUser()) {
            // Arrange
            Account account = TestDataFactory.generateAccount('TestAccount');
            insert account;
            Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
            update standardPricebook;

            //Create Product
            Product2 pro = new Product2(Name = 'iPhone X', Family = 'Mobile');
            insert pro;

            //Create the PricebookEntry
            PricebookEntry pbe = new PricebookEntry(
                Pricebook2Id = standardPricebook.Id,
                Product2Id = pro.Id,
                UnitPrice = 1020,
                IsActive = true
            );
            insert pbe;

            Opportunity opp = new Opportunity(
                Name = 'Test',
                PriceBook2 = standardPricebook,
                CloseDate = System.today(),
                AccountId = account.Id,
                StageName = 'Prospecting',
                Probability = 100
            );

            insert opp;
            OpportunityLineItem lineItem1 = new OpportunityLineItem(
                OpportunityID = opp.id,
                PriceBookEntryID = pbe.id,
                quantity = 4,
                totalprice = 200
            );
            insert lineItem1;

            SBQQ__Quote__c quote = new SBQQ__Quote__c(
                SBQQ__Account__c = account.Id,
                SBQQ__Opportunity2__c = opp.Id,
                SBQQ__PriceBook__c = standardPricebook.Id,
                SBQQ__Primary__c = true,
                SBQQ__StartDate__c = System.today(),
                SBQQ__SubscriptionTerm__c = 36
            );
            insert quote;
            opp.SBQQ__Contracted__c = true;
            update opp;
            Contract contract = new Contract(
                AccountId = account.Id,
                SBQQ__Opportunity__c = opp.Id,
                SBQQ__Quote__c = quote.Id,
                StartDate = System.today().addDays(1),
                ContractTerm = 11
            );
            insert contract;
            contract.Status = 'Activated';
            update contract;

            // Act
            Test.startTest();
            List<ContractMsg> contracts = AccountCancelReplaceController.getContracts(
                new List<String>{ account.Id },
                '5'
            );
            Test.stopTest();

            System.assertEquals(1, contracts.size(), 'We should not have any contracts for an account');
        }

    }

    @IsTest
    static void amendContracts_OneContract_newQuote() {
        System.runAs(getAdminUser()) {
            // Arrange
            Account account = TestDataFactory.generateAccount('TestAccount');
            insert account;
            Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
            update standardPricebook;

            //Create Product
            Product2 pro = new Product2(Name = 'iPhone X', Family = 'Mobile');
            insert pro;

            //Create the PricebookEntry
            PricebookEntry pbe = new PricebookEntry(
                Pricebook2Id = standardPricebook.Id,
                Product2Id = pro.Id,
                UnitPrice = 1020,
                IsActive = true
            );
            insert pbe;

            Opportunity opp = new Opportunity(
                Name = 'Test',
                PriceBook2 = standardPricebook,
                CloseDate = System.today(),
                AccountId = account.Id,
                StageName = 'Prospecting',
                Probability = 100
            );

            insert opp;
            OpportunityLineItem lineItem1 = new OpportunityLineItem(
                OpportunityID = opp.id,
                PriceBookEntryID = pbe.id,
                quantity = 4,
                totalprice = 200
            );
            insert lineItem1;

            SBQQ__Quote__c quote = new SBQQ__Quote__c(
                SBQQ__Account__c = account.Id,
                SBQQ__Opportunity2__c = opp.Id,
                SBQQ__PriceBook__c = standardPricebook.Id,
                SBQQ__Primary__c = true,
                SBQQ__StartDate__c = System.today(),
                SBQQ__SubscriptionTerm__c = 36
            );
            insert quote;
            opp.SBQQ__Contracted__c = true;
            update opp;
            Contract contract = new Contract(
                AccountId = account.Id,
                SBQQ__Opportunity__c = opp.Id,
                SBQQ__Quote__c = quote.Id,
                StartDate = System.today()
            );
            insert contract;
            contract.Status = 'Activated';
            update contract;

            // Act
            Test.startTest();
            AmendContractsMsg amendContractMsg = new AmendContractsMsg();
            amendContractMsg.contractIds = new List<String>{ contract.Id };
            amendContractMsg.startDate = String.valueOf(System.today());
            amendContractMsg.opportunityStage = 'Prospecting';
            amendContractMsg.opportunityName = 'Test Name';
            amendContractMsg.accountId = account.Id;
            amendContractMsg.termLength = 24;
            AmendContractJobMsg jobmsg = AccountCancelReplaceController.amendContracts(amendContractMsg);
            List<String> jobIds = new List<String>();
            for (AmendContractJobMsg.JobStatus job : jobmsg.jobs) {
                jobIds.add(job.jobId);
            }
            List<AmendContractJobStatusMsg> jobStatuses = AccountCancelReplaceController.getJobStatus(jobIds);
            Test.stopTest();

            // Assert
            Opportunity opportunity = [SELECT Id, Name, StageName FROM Opportunity WHERE Name = 'Test Name'];
            SBQQ__Quote__c newQuote = [
                SELECT Id, SBQQ__Primary__c, SBQQ__SubscriptionTerm__c, SBQQ__StartDate__c, (SELECT Id FROM ChildQuotes__r)
                FROM SBQQ__Quote__c
                WHERE SBQQ__Opportunity2__r.Name = 'Test Name'
            ];
            System.assertEquals(3, [SELECT Id FROM SBQQ__Quote__c].size());
            System.assertEquals(
                amendContractMsg.opportunityStage,
                opportunity.StageName,
                'A new Opportunity should have been created'
            );
            System.assertEquals(
                Date.valueOf(amendContractMsg.startDate),
                newQuote.SBQQ__StartDate__c,
                'Start Date should have been set to the value we passed in'
            );
            System.assertEquals(
                amendContractMsg.termLength,
                newQuote.SBQQ__SubscriptionTerm__c,
                'Start Date should have been set to the value we passed in'
            );
            System.assertEquals(1, newQuote.ChildQuotes__r.size());
            System.assertEquals(1, jobStatuses.size());
        }

    }

    @IsTest
    private static void getOpportunityStageValues_valuesReturned() {
        // Act
        Test.startTest();
        List<PicklistMsg> picklistValues = AccountCancelReplaceController.getOpportunityStageValues();
        Test.stopTest();

        // Assert
        System.assert(picklistValues.size() > 1, 'We should have had picklist Values Returned');
    }

    @IsTest
    private static void getAccounts_231Records_231Returned() {
        System.runAs(getAdminUser()) {
            // Arrange
            Account parentAccount = TestDataFactory.generateAccount('parentAccount');
            insert parentAccount;
            List<Account> level2Accounts = TestDataFactory.inflateChildAccountsWithNamePrefix( new List<Account>{parentAccount},'level2 ',5);
            insert level2Accounts;

            List<Account> level3Accounts = TestDataFactory.inflateChildAccountsWithNamePrefix( level2Accounts,'level3 ',3);
            insert level3Accounts;

            List<Account> level4Accounts = TestDataFactory.inflateChildAccountsWithNamePrefix( level3Accounts,'level4 ',2);
            insert level4Accounts;

            List<Account> level5Accounts = TestDataFactory.inflateChildAccountsWithNamePrefix( level4Accounts,'level5 ',2);
            insert level5Accounts;

            List<Account> level6Accounts = TestDataFactory.inflateChildAccountsWithNamePrefix( level5Accounts,'level6 ',2);
            insert level6Accounts;

            // Act
            Test.startTest();
            List<String> accountIds = AccountCancelReplaceController.getAccounts(level4Accounts[3].Id);
            Test.stopTest();

            // Assert
            System.assertEquals(231, accountIds.size(), 'We should returned all 231 accounts');
        }

    }
}