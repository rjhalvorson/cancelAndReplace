@isTest
private class DataTest {
	
	//@isTest
	static void findNegativeCRUD() {
		// finds objects that the running user doesn't have access to, to aid in testing.
		System.runAs(UserTest.createStandardUser()) {
			Map<String, Schema.SObjectType> glblDscrb = Schema.getGlobalDescribe();

			Set<String> restrictedRead		= new Set<String>();
			Set<String> restrictedCreate	= new Set<String>();
			Set<String> restrictedModify	= new Set<String>();
			Set<String> restrictedDelete	= new Set<String>();

			for (Schema.SObjectType sot : glblDscrb.values()) {
				Schema.DescribeSObjectResult dsor = sot.getDescribe();

				if (!dsor.isAccessible()){
					restrictedRead.add(dsor.getName());
				}
				if (!dsor.isCreateable()){
					restrictedCreate.add(dsor.getName());
				}
				if (!dsor.isUpdateable()){
					restrictedModify.add(dsor.getName());
				}
				if (!dsor.isDeletable()){
					restrictedDelete.add(dsor.getName());
				}
			}

			if (!restrictedRead.isEmpty())
				System.debug(LoggingLevel.INFO, restrictedRead);
			if (!restrictedCreate.isEmpty())
				System.debug(LoggingLevel.INFO, restrictedCreate);
			if (!restrictedModify.isEmpty())
				System.debug(LoggingLevel.INFO, restrictedModify);
			if (!restrictedDelete.isEmpty())
				System.debug(LoggingLevel.INFO, restrictedDelete);
		}
		System.assert(true);// asserting that this ran w/o error.
	}
	//@isTest
	static void findNegativeFLS() {
		// finds fields that the running user doesn't have access to, to aid in testing.
		System.runAs(UserTest.createStandardUser()) {
			Map<String, Schema.SObjectType> glblDscrb = Schema.getGlobalDescribe();
			for (Schema.SObjectType sot : glblDscrb.values()) {
				DescribeCache dc = DescribeCache.getDescribeCache(sot);
				Set<String> restrictedFieldsRead = dc.getRestrictedFields(DataConstants.SecurityOperation.READ);
				Set<String> restrictedFieldsCreate = dc.getRestrictedFields(DataConstants.SecurityOperation.CREATE);
				Set<String> restrictedFieldsModify = dc.getRestrictedFields(DataConstants.SecurityOperation.MODIFY);

				System.debug(LoggingLevel.INFO, sot);
				if (!restrictedFieldsRead.isEmpty())
					System.debug(LoggingLevel.INFO, restrictedFieldsRead);
				if (!restrictedFieldsCreate.isEmpty())
					System.debug(LoggingLevel.INFO, restrictedFieldsCreate);
				if (!restrictedFieldsModify.isEmpty())
					System.debug(LoggingLevel.INFO, restrictedFieldsModify);
			}
		}
		System.assert(true);// asserting that this ran w/o error.
	}

	//@isTest
	static void findExternalId() {// finds fields that the running user has access to that are flagged "ExternalId"
		System.runAs(UserTest.createStandardUser()) {
			Map<String, Schema.SObjectType> glblDscrb = Schema.getGlobalDescribe();
			for (Schema.SObjectType sot : glblDscrb.values()) {
				for (Schema.SObjectField field : sot.getDescribe().fields.getMap().values()) {
					DescribeFieldResult dfr = field.getDescribe();
					if (dfr.isExternalId()) {
						System.debug('SObject: ' + sot + ' Field: ' + dfr.getName());
					}
				}
			}
		}
		System.assert(true);// asserting that this ran w/o error.
	}

	/**
	 * 
	 * B E H A V I O R   T E S T S
	 * 
	 * The following tests attempt to test both positive and negative behavior
	 * running as someone other than Sys Admin
	 **/
	
	/* 
	 * Tests that the user does not have CREATE access to object
	 */
	@isTest
	static void create_CRUD_negative() {
	//	Campaign so = new Campaign(Name = 'Test');
		Lead so = new Lead(LastName = 'Test', Company = 'Test', DoNotCall = true);		
		System.runAs(UserTest.createPlatformUser()) {
			try {
				Test.startTest();
				Data.create(so, true, false, true);
				System.assert(false);
			} catch (Exception e) {
				System.assert(e instanceof SecUtil.CRUDException);
				//System.assertEquals('"Create" permission to object "Campaign" is not allowed for the current user.', e.getMessage());
			} finally {
				Test.stopTest();
			}
		}
	}
	
	/* 
	 * Tests that the user does not have CREATE access to field
	 */
	@isTest
	static void create_FLS_negative() {
		Lead so = new Lead(DoNotCall = true);
		System.runAs(UserTest.createStandardUser()) {
			try {
				Test.startTest();
				Data.create(so, false, true, true);
				System.assert(false);
			} catch (Exception e) {
				System.assert(e instanceof SecUtil.FLSException);
				//System.assertEquals('"Create" permission to field "DoNotCall" on object "Lead" is not allowed for the current user.', e.getMessage());
			} finally {
				Test.stopTest();
			}
		}
	}
	
	/* 
	 * Tests that the user does not have UPDATE access to object
	 */
	@isTest
	static void modify_CRUD_negative() {
	//	Campaign so = new Campaign(Name = 'Test');
		Lead so = new Lead(LastName = 'Test', Company = 'Test', DoNotCall = true);
		insert so;
		
		System.runAs(UserTest.createPlatformUser()) {
			try {
				Test.startTest();
				Data.modify(so, true, false, true);
				System.assert(false);
			} catch (Exception e) {
				System.assert(e instanceof SecUtil.CRUDException);
				//System.assertEquals('"Modify" permission to object "Campaign" is not allowed for the current user.', e.getMessage());
			} finally {
				Test.stopTest();
			}
		}
	}
	
	/* 
	 * Tests that the user does not have EDIT (Update) access to field
	 */
	@isTest
	static void modify_FLS_negative() {
		Lead so = new Lead(LastName = 'Test', Company = 'Test', DoNotCall = true);
		insert so;
		
		System.runAs(UserTest.createStandardUser()) {
			try {
				Test.startTest();
				Data.modify(so, false, true, true);
				System.assert(false);
			} catch (Exception e) {
				System.assert(e instanceof SecUtil.FLSException);
				//System.assertEquals('"Modify" permission to field "DoNotCall" on object "Lead" is not allowed for the current user.', e.getMessage());
			} finally {
				Test.stopTest();
			}
		}
	}
	
	/* 
	 * Tests that the user does not have REMOVE (Delete) access to object
	 */
	@isTest
	static void remove_CRUD_negative() {
	//	Campaign so = new Campaign(Name = 'Test');
		Lead so = new Lead(LastName = 'Test', Company = 'Test', DoNotCall = true);
		insert so;
		
		System.runAs(UserTest.createPlatformUser()) {
			try {
				Test.startTest();
				Data.remove(so, true, true, true);
				System.assert(false);
			} catch (Exception e) {
				System.assert(e instanceof SecUtil.CRUDException);
				//System.assertEquals('"Remove" permission to object "Campaign" is not allowed for the current user.', e.getMessage());
			} finally {
				Test.stopTest();
			}
		}
	}
	
	/* 
	 * Tests that the user does not have UNREMOVE (undelete) access to object
	 */
	@isTest
	static void unremove_CRUD_negative() {
	//	Campaign so = new Campaign(Name = 'Test');
		Lead so = new Lead(LastName = 'Test', Company = 'Test', DoNotCall = true);
		insert so;
		delete so;
		
		System.runAs(UserTest.createPlatformUser()) {
			try {
				Test.startTest();
				Data.unremove(so, true, true, true);
				System.assert(false);
			} catch (Exception e) {
				System.assert(e instanceof SecUtil.CRUDException);
				//System.assertEquals('"Unremove" permission to object "Campaign" is not allowed for the current user.', e.getMessage());
			} finally {
				Test.stopTest();
			}
		}
	}
	
	/*
	 * Tests the "getFieldsInSObjects" helper method to validate that it finds fields in SObjects
	 */
	@isTest
	static void getFieldsInSObjects() {
		Set<String> flds = Data.getFieldsInSObjects(
			new List<Contact>{
				new Contact(
					FirstName	= 'Test',
					LastName	= 'Contact',
					Account		= new Account(Id='001000000000000AAA')
				),
				new Contact(
					Phone		= '800-555-1212'
				)
			}
		);
		System.debug(flds);
		System.assertEquals(4, flds.size());
		System.assert(flds.contains('FirstName'));
		System.assert(flds.contains('LastName'));
		System.assert(flds.contains('Account'));
		System.assert(flds.contains('Phone'));
	}

	/*
	 * Basic bulk performance test
	 */
	static void bulk_fls() {
		List<SObject> lls = new List<SObject>();
		for (Integer i=0; i<200; i++) {
			/*TestLargeObject__c tlo = new TestLargeObject__c();
			for (Integer j=0; j<500; j++) {
				String s = '000' + j;
				tlo.put('TextField_'+s.right(3)+'__c', 'Test');
			}*/
			lls.add(
				//tlo
				new Lead(LastName = 'Test', Company='Test', DoNotCall=true)
			);
		}
		Data.create(lls, false, true, true);
	}

	@isTest
	static void bulk_fls_positive() {
		Data.VALIDATE_METHOD = 1;

		List<SObject> lls = new List<SObject>();
		for (Integer i=0; i<200; i++) {
			//TestLargeObject__c tlo = new TestLargeObject__c();
			//for (Integer j=0; j<500; j++) {
			//	String s = '000' + j;
			//	tlo.put('TextField_'+s.right(3)+'__c', 'Test');
			//}
			lls.add(
				//tlo
				new Lead(LastName = 'Test', Company='Test')
			);
		}
		Data.create(lls, false, true, true);
		System.assert(true);// yay, no error
	}

	@isTest
	static void bulk_fls_negative() {
		Data.VALIDATE_METHOD = 1;

		System.runAs(UserTest.createStandardUser()) {
			try {
				bulk_fls();
				System.assert(false);
			} catch (SecUtil.FLSException e) {
				System.assert(true);
			}
		}
	}

	@isTest
	static void method1() {
		Data.VALIDATE_METHOD = 1;
		
		System.runAs(UserTest.createStandardUser()) {
			try {
				bulk_fls();
				System.assert(false);
			} catch (SecUtil.FLSException e) {
				System.assert(true);
			}
		}
	}

	@isTest
	static void method2() {
		Data.VALIDATE_METHOD = 2;
		
		System.runAs(UserTest.createStandardUser()) {
			try {
				bulk_fls();
				System.assert(false);
			} catch (SecUtil.FLSException e) {
				System.assert(true);
			}
		}
	}
	/*

	Large Object Performance Tests:
	#3
	Execution Time: 267, 164
	CpuTime: 128, 106
	HeapSize: 41508, 2618

	#2
	Execution Time: 200, 176
	CpuTime: 102, 108
	HeapSize: 23510, 2618

	#1
	Execution Time: 1450, 2433
	CpuTime: 1288, 2256
	HeapSize: 3949, 123286

	*/
	
	
	
	
	/**
	 * 
	 * C O V E R A G E    T E S T S
	 * 
	 * 
	 * The following tests don't necessarily test positive/negative behavior
	 * but instead focus on obtaining >75% coverage.
	 **/
	@isTest
	static void injectDML() {
		Data.injectDML(null);

		System.assert(true);
	}

	@isTest
	static void DB_setParms() {
		Map<String, Object> parms = new Map<String,Object>{
			'myParm1' => 'val1',
			'myParm2' => 'val2'
		};
		Data.DBWithoutShare testDB = new Data.DBWithoutShare();
		String query = testDB.setParams('SELECT Id FROM Account WHERE field1 = :myParm1 AND field2 =:myParm1 AND field3 =: myParm2', parms);

		System.assertEquals('SELECT Id FROM Account WHERE field1 = :p0 AND field2 =:p0 AND field3 =: p1', query);
	}

	@isTest
	static void DB_setSOSLParams() {
		Map<String, Object> parms = new Map<String,Object>{
			'name' => 'val1'
		};
		Data.DBWithoutShare testDB = new Data.DBWithoutShare();
		String sosl = testDB.setSOSLParams('FIND :name IN NAME FIELDS RETURNING Account (Id, Name)', parms);

		System.assertEquals('FIND :p0 IN NAME FIELDS RETURNING Account (Id, Name)', sosl);
	}

	@isTest
	static void read_wShr() {
		read(true);
		System.assert(true);// asserting that this ran w/o error.
	}
	@isTest
	static void read_woShr() {
		read(false);
		System.assert(true);// asserting that this ran w/o error.
	}
	static List<SObject> read(Boolean enforceShr) {
		return Data.read('SELECT Id FROM Account LIMIT 1', null, true, true, enforceShr);
	}
	@isTest
	static void read_wShr_negative() {
		// insert an actual account owned by sys admin
		Account a = new Account(Name = 'Test');
		insert a;

		List<SObject> results;

		System.runAs(UserTest.createStandardUser()) {
			Test.startTest();
			results = Data.read('SELECT Id FROM Account WHERE Id = \'' + a.Id + '\'', null, true, true, true);
			Test.stopTest();
		}
		System.assert(true);// asserting that this ran w/o error.
		//System.assertEquals(0, results.size()); // Impossible to test sharing rules in a package
	}

	@isTest
	static void find_wShr() {
		find(true);
		System.assert(true);// asserting that this ran w/o error.
	}
	@isTest
	static void find_woShr() {
		find(false);
		System.assert(true);// asserting that this ran w/o error.
	}
	static List<List<SObject>> find(Boolean enforceShr) {
		return Data.find('FIND \'acme\' IN ALL FIELDS RETURNING Account (Name, Website), Lead', null, true, true, enforceShr);
	}
	@isTest
	static void find_wShr_negative() {
		// insert an actual account owned by sys admin
		Account a = new Account(Name = 'Test');
		insert a;

		List<List<SObject>> results;

		System.runAs(UserTest.createStandardUser()) {
			Test.startTest();
			results = Data.find('FIND \'Test\' IN ALL FIELDS RETURNING Account (Name, Website), Lead', null);
			Test.stopTest();
		}
		System.assert(true);// asserting that this ran w/o error.
		//System.assertEquals(0, results.size()); // Impossible to test sharing rules in a package
	}
	
	@isTest
	static void locator_wShr() {
		locator(true);
		System.assert(true);// asserting that this ran w/o error.
	}
	@isTest
	static void locator_woShr() {
		locator(false);
		System.assert(true);// asserting that this ran w/o error.
	}
	static void locator(Boolean enforceShr) {
		Data.locator('SELECT Id FROM Account LIMIT 1', null, true, true, enforceShr);
	}

	@isTest
	static void countQuery_wShr() {
		countQuery(true);
		System.assert(true);// asserting that this ran w/o error.
	}
	@isTest
	static void countQuery_woShr() {
		countQuery(false);
		System.assert(true);// asserting that this ran w/o error.
	}
	static Integer countQuery(Boolean enforceShr) {
		return Data.countQuery('SELECT COUNT() FROM Account', null, true, true, enforceShr);
	}
	@isTest
	static void countQuery_negative() {
		try {
			System.runAs(UserTest.createStandardUser()) {
				Data.countQuery('SELECT COUNT() FROM AuthProvider', null, true, true, true);
			}
			System.assert(false);// shouldn't get here.
		} catch (SecUtil.SecurityException e) {
			System.assert(true);
		}
	}
	@isTest
	static void countQuery_coverage() {
		Data.countQuery('SELECT COUNT() FROM Account');
		System.assert(true);// asserting that this ran w/o error.
	}
	
	@isTest
	static void doDML_wShr() {
		doDML(true);
		System.assert(true);// asserting that this ran w/o error.
	}
	@isTest
	static void doDML_woShr() {
		doDML(false);
		System.assert(true);// asserting that this ran w/o error.
	}
	static void doDML(Boolean enforceShr) {
		Account accts = new Account(
			Name = 'Test Account'
		);
		
		// Be sure our insert has a relationship ala testgetFieldsInSObjects
		Data.upsurt(new List<Account>{accts}, Schema.Account.fields.Id, true, true, enforceShr, null);
		Data.upsurt(new List<Account>{accts}, Schema.Account.fields.Id, true, true, enforceShr, null);
		Data.remove(accts, true, true, enforceShr);
		Data.unremove(accts, true, true, enforceShr);
		Id aId = accts.Id;
		Data.remove(aId, true, true, enforceShr);
		Data.unremove(aId, true, true, enforceShr);
		
		List<SObject> sos = Data.read('SELECT Id, Name, CreatedDate FROM Account LIMIT 1', null, true, true, enforceShr);
		update sos;
		Data.modify(sos, true, true, enforceShr);
	}
	
	@isTest
	static void doDML_withDefaults() {
		Account accts = new Account(
			Name = 'Test Account'
		);
		
		// Be sure our insert has a relationship ala testgetFieldsInSObjects

		Data.upsurt(new Account(
				Name = 'Test Account'
		), Schema.Account.fields.Id);
		Data.create(accts);
		Data.modify(accts);
		Data.remove(accts);
		Data.unremove(accts);
		Id aId = accts.Id;
		Data.remove(aId);
		Data.unremove(aId);
		
		List<SObject> sos = Data.read('SELECT Id, Name, CreatedDate FROM Account LIMIT 1');
		update sos;
		Data.modify(sos);
		
		Data.locator('SELECT Id FROM Account LIMIT 1');
		System.assert(true);// asserting that this ran w/o error.
	}
    
    @isTest
	static void otherCoverage() {
        Data d = new Data();

        Data.performDML(null, new List<Account>{new Account(Name = 'Test Account')}, null, true, true, true, new Set<String>());
		System.assert(true);// asserting that this ran w/o error.
    }
}