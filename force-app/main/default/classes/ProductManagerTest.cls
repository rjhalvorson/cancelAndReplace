/****************************************************************************************
Name            : ProductManagerTest
Revision Log    : 8/14/2020 Bryan
                :
                :
Use             : Test class for Product manager
*****************************************************************************************/
@IsTest
public with sharing class ProductManagerTest {

    private static final String ADMIN_USER_EMAIL = 'ProductManagerTest@cpqcr.com';

    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Email = :ADMIN_USER_EMAIL];
    }

    @TestSetup
    private static void makeData() {
        TestUserFactory.createUserAdmin(ADMIN_USER_EMAIL);

    }

    @IsTest
    private static void addProduct_nullProduct_emtpyResult(){
        System.runAs(getAdminUser()){

            // Arrange
            Account account = TestDataFactory.generateAccount('TestAccount');
            insert account;
            Pricebook2 standardPricebook = new Pricebook2(
                    Id = Test.getStandardPricebookId(),
                    IsActive = true
            );
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
            opp.SBQQ__Contracted__c = TRUE;
            update opp;
            Contract contract = new Contract( AccountId = account.Id, SBQQ__Opportunity__c = opp.Id,SBQQ__Quote__c = quote.Id,StartDate = System.today());
            insert contract;

            // Act
            Test.startTest();
            ProductManager productManager = new ProductManager();
            QuoteModel model = productManager.load(contract.Id);
            ProductModel productModel = productManager.readProduct(pro.Id, standardPricebook.Id, 'USD');
            QuoteModel addedProductModel = productManager.addProduct(model, new List<ProductModel>{productModel}, 1);
            Test.stopTest();

            // Assert
            System.AssertEquals(1,addedProductModel.lineItems.size(),'Should have 1 product line item added');
        }

    }
}