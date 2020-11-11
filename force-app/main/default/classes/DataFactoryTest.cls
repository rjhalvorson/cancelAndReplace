/****************************************************************************************
Name            : DataFactoryTestTest
Revision Log    : 8/16/2020 riunyan
                :
                :
Use             : Cancel and replace test class
*****************************************************************************************/
@IsTest
private class DataFactoryTest {
    private static final String ADMIN_USER_EMAIL = 'DataFactoryTestTest@cpqcr.com';

    @TestSetup
    private static void makeData() {
        TestUserFactory.createUserAdmin(ADMIN_USER_EMAIL);
    }

    private static User getAdminUser() {
        return [SELECT Id FROM User WHERE Email = :ADMIN_USER_EMAIL];
    }


    // This method will be updated to remove data. We need to build out a test setup that is going to create all of the basic records for us
    @IsTest
    static void getProductData() {
        System.runAs(getAdminUser()) {

            Test.startTest();
            DataFactory.loadData();
            Test.stopTest();

            System.assertEquals(4, [SELECT Id FROM Product2].size(), 'We should have 4 products');
 
        }

    }
    
    @IsTest
    static void getAccountData() {
        System.runAs(getAdminUser()) {

            Test.startTest();
            DataFactory.loadData();
            Test.stopTest();

            System.assertEquals(5, [SELECT Id FROM Account].size(), 'We should have 5 accounts');
 
        }

    }

   


   
}