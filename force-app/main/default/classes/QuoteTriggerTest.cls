/****************************************************************************************
Name            : QuoteTriggerTest
Revision Log    : 8/24/2020 Bryan
                :
                :
Use             : Tests for the Quote Trigger
*****************************************************************************************/
@IsTest
private class QuoteTriggerTest {
    private static final String ADMIN_USER_EMAIL = 'QuoteTriggerTest@cpqcr.com';

    @TestSetup
    private static void makeData() {
        TestUserFactory.createUserAdmin(ADMIN_USER_EMAIL);
    }

    private static User getStandardUser() {
        return [SELECT Id FROM User WHERE Email = :ADMIN_USER_EMAIL];
    }

    @IsTest
    private static void updateStartDate_oneChild_oneUpdate(){
        QuoteDomain.quoteSettings = new Cancelled_Quote_Settings__mdt(Sync_Orders__c = true, Sync_QuoteStartDate__c = true );
        System.runAs(getStandardUser()) {
            // Arrange
            Account account = TestDataFactory.generateAccount('TestAccount');
            insert account;
            Pricebook2 standardPricebook = new Pricebook2(
                    Id = Test.getStandardPricebookId(),
                    IsActive = true
            );
            Update standardPricebook;

            //Create Product
            Product2 pro = new Product2(Name = 'iPhone X', Family = 'Mobile');
            Insert pro;

            //Create the PricebookEntry
            PricebookEntry pbe = new PricebookEntry(
                    Pricebook2Id = standardPricebook.Id,
                    Product2Id = pro.Id,
                    UnitPrice = 1020,
                    IsActive = true
            );
            Insert pbe;

            Opportunity opp = new Opportunity(Name='Test',
                    PriceBook2 = standardPricebook,
                    CloseDate = System.today(),
                    AccountId=account.Id,
                    StageName='Prospecting',
                    Probability=100);

            insert opp;
            OpportunityLineItem lineItem1 = new OpportunityLineItem (OpportunityID=opp.id,PriceBookEntryID=pbe.id, quantity=4, totalprice=200);
            insert lineItem1;

            SBQQ__Quote__c quote = new SBQQ__Quote__c( SBQQ__Account__c = account.Id, SBQQ__Opportunity2__c = opp.Id,SBQQ__PriceBook__c = standardPricebook.Id,SBQQ__Primary__c = TRUE,SBQQ__StartDate__c = System.today(), SBQQ__SubscriptionTerm__c = 36);
            insert quote;

            opp.SBQQ__PrimaryQuote__c = quote.Id;
            opp.SBQQ__Contracted__c = true;
            update opp;
            SBQQ__Quote__c childQuote = new SBQQ__Quote__c( Replacement_Quote__c = quote.Id, SBQQ__Account__c = account.Id, SBQQ__Opportunity2__c = opp.Id,SBQQ__PriceBook__c = standardPricebook.Id,SBQQ__Primary__c = TRUE,SBQQ__StartDate__c = System.today(), SBQQ__SubscriptionTerm__c = 36);
            insert childQuote;


            // Act
            Test.startTest();
            quote.SBQQ__StartDate__c = System.Today().addDays(3);
            update quote;
            Test.stopTest();

            // Assert
            System.AssertEquals(quote.SBQQ__StartDate__c,[SELECT Id,SBQQ__StartDate__c FROM SBQQ__Quote__c WHERE Id = :childQuote.Id].SBQQ__StartDate__c,'The Start date should match the replacement quote');

        }






    }
}