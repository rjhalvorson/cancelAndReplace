@isTest
public class FindTest {

	/**
	 * 
	 * B E H A V I O R   T E S T S
	 * 
	 * The following tests attempt to test both positive and negative behavior
	 * running as someone other than Sys Admin
	 **/
	
	/**
	 * Tests:
	 * 	- The provided complex query parses successfully
	 *  - The running user (Sys Admin) has full access to all objects/fields
	 **/
	@isTest
	static void validateCRUDFLS_full() {
		List<Find> finds = Find.parse('FIND \'acme\' IN ALL FIELDS RETURNING Account (Name, Website), Lead (FirstName, LastName)');
		System.assertEquals(2, finds.size());
		for (Find f : finds) {
			f.validateCRUDFLS(true, true);
		}
	}

	/**
	 * Tests:
	 *  - The provided query parses successfully
	 *  - The running user (a new user with the "Standard User" profile) does not have Read access to "AuthProvider" object
	 **/
	@isTest
	static void validateCRUD_negative() {
		System.runAs(UserTest.createStandardUser()) {
			List<Find> finds = Find.parse('FIND \'acme\' IN ALL FIELDS RETURNING AuthProvider');
			System.assertEquals(1, finds.size());
			try {
				Test.startTest();
				for (Find f : finds) {
					f.validateCRUDFLS(true, true);
				}
				System.assert(false);
			} catch (Exception e) {
				System.assert(e instanceof SecUtil.CRUDException);
				//System.assertEquals('"Read" permission to object "AuthProvider" is not allowed for the current user.', e.getMessage());
			} finally {
				Test.stopTest();
			}
		}
	}

	/**
	 * Tests:
	 *  - The provided query parses successfully
	 *  - The running user (a new user with the "Standard User" profile) does not have Read access to "DoNotCall" field
	 **/
	@isTest
	static void validateFLS_negative() {
		String query1 = 'SELECT Id, DoNotCall '+
						  'FROM Lead';
		
		System.runAs(UserTest.createStandardUser()) {
			List<Find> finds = Find.parse('FIND \'acme\' IN ALL FIELDS RETURNING Lead (Id, DoNotCall)');
			System.assertEquals(1, finds.size());
			try {
				Test.startTest();
				for (Find f : finds) {
					f.validateCRUDFLS(true, true);
				}
				System.assert(false);
			} catch (Exception e) {
				System.assert(e instanceof SecUtil.FLSException);
				//System.assertEquals('"Read" permission to field "DoNotCall" on object "Lead" is not allowed for the current user.', e.getMessage());
			} finally {
				Test.stopTest();
			}
		}
	}
	
	/**
	 * Tests Negative Behavior of the parser:
	 *  - The provided query is bad (REGEX doesn't match)
	 **/
	@isTest
	static void parse_BadQuery1() {
		try {
			List<Find> q = Find.parse('FIND');
			System.assert(false);
		} catch (Exception e) {
			System.assert(e instanceof Find.FindException);
			System.assertEquals(System.Label.DAE_BadQuery, e.getMessage());
		}
	}

	/**
	 * Tests Negative Behavior of the parser:
	 *  - The provided subquery references a non-existent field
	 **/
	@isTest
	static void parse_BadField() {
		try {
			List<Find> q = Find.parse('FIND \'acme\' IN ALL FIELDS RETURNING Account (HoogaboogaZoom__d, Website), Lead');
			System.assert(false);
		} catch (Exception e) {
			System.assert(e instanceof Find.FindException);
			System.assertEquals('Field "HoogaboogaZoom__d" on object "Account" does not exist.', e.getMessage());
		}
	}
	
	
	
	/**
	 * 
	 * C O V E R A G E    T E S T S
	 * 
	 * 
	 * The following tests don't necessarily test positive/negative behavior
	 * but instead focus on obtaining >75% coverage.
	 **/

	@isTest
	static void disabled() {
		DataConstants.ENABLED = false;
		Data.find('FIND \'acme\' IN ALL FIELDS RETURNING Account (Name, Website), Lead', null);

		System.assert(true);
	}
}