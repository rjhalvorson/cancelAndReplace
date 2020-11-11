@isTest
public class QueryTest {
	
	/**
	 * Tests:
	 * 	- The provided complex query parses successfully
	 *  - The running user (Sys Admin) has full access to all objects/fields
	 **/
	@isTest
	static void validateCRUDFLS_full() {
		Long startMillis	= System.currentTimeMillis();
		String query1 = 'SELECT Id, '+
								'CloseDate, '+
								'SUM(Amount), '+
								'Account.Name, '+
								'Account.Owner.Name, '+
								'(SELECT Id, '+
										'FUNCTION(Contact.Name), '+
										'Contact.Account.Name '+
								   'FROM OpportunityContactRoles), '+
								'(SELECT Id, '+
										'AccountToId '+
								   'FROM OpportunityPartnersFrom) '+
						  ' FROM Opportunity';
		Query q = Query.parse(query1);
		System.debug(LoggingLevel.WARN, 'Parse Time: ' + (System.currentTimeMillis()-startMillis));
		startMillis	= System.currentTimeMillis();
		q.validateCRUDFLS(true, true);
		System.debug(LoggingLevel.WARN, 'Validate Time: ' + (System.currentTimeMillis()-startMillis));

		System.assert(true);
	}
	
	@isTest
	static void validateCRUDFLS_full2() {
		String query1 = 'SELECT Id FROM Account';
		Query q = Query.parse(query1);
		q.validateCRUDFLS(true, true);
		System.assert(true);
	}
	
	@isTest
	static void validateCRUDFLS_full3() {
		String query1 = 'SELECT COUNT() FROM Account';
		Query q = Query.parse(query1);
		q.validateCRUDFLS(true, true);
		System.assert(true);
	}

	/**
	 * Tests:
	 *  - The provided query parses successfully
	 *  - The running user (a new user with the "Standard User" profile) does not have Read access to "AuthProvider" object
	 **/
	@isTest
	static void validateCRUD_negative() {
		String query1 = 'SELECT Id '+
						  'FROM AuthProvider';
		
		System.runAs(UserTest.createStandardUser()) {
			Query q = Query.parse(query1);
			try {
				Test.startTest();
				q.validateCRUDFLS(true, false);
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
			Query q = Query.parse(query1);
			try {
				Test.startTest();
				q.validateCRUDFLS(false, true);
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
	 * Tests the SOQL parser:
	 * 	- This SOQL has extra whitespaces in it, the parser should clean that up.
	 *  - Extracts fieldname from within a Function()
	 *  - Handles SubQueries
	 *  - Handles functions within SubQueries (even though the SOQL engine does not support aggregates within subqueries, except COUNT())
	 *  - Relationship Queries
	 *  - Validates the number of fields in the query
	 *  - The FROM object
	 */
	@isTest
	static void parse() {
		String query1 = 'SELECT Id,   \t  \r \n'+
								'CloseDate, '+
								'SUM(Amount), '+
								'Account.Name, '+
								'Contract.Account.Name, '+
								'(SELECT Id, \n'+
										'FUNCTION(Contact.Name), '+
										'Contact.Account.Name '+
								   'FROM OpportunityContactRoles), '+
								'(SELECT Id, '+
										'AccountToId '+
								   'FROM OpportunityPartnersFrom) '+
						  ' FROM Opportunity';
		Query q = Query.parse(query1);

		System.assertEquals(5, q.fields.size());
		System.assertEquals('Id', q.fields.get(0).fieldExpression);
		System.assertEquals('CloseDate', q.fields.get(1).fieldExpression);
		System.assertEquals('Amount', q.fields.get(2).fieldExpression);

		System.assertEquals('Account.Name', q.fields.get(3).fieldExpression);
		System.assertEquals('Name', q.fields.get(3).nextPart.fieldExpression);
		
		System.assertEquals('Contract.Account.Name', q.fields.get(4).fieldExpression);
		System.assertEquals('Account.Name', q.fields.get(4).nextPart.fieldExpression);
		System.assertEquals('Name', q.fields.get(4).nextPart.nextPart.fieldExpression);

		//compareFroms(new Set<String>{'Opportunity','Account','Contract'}, q.froms);

		// Validate Sub-Selects
		System.assertEquals(2, q.subSelects.size());

		System.assertEquals(3, q.subSelects.get(0).fields.size());
		System.assertEquals('Id', q.subSelects.get(0).fields.get(0).fieldExpression);
		System.assertEquals('Contact.Name', q.subSelects.get(0).fields.get(1).fieldExpression);
		System.assertEquals('Name', q.subSelects.get(0).fields.get(1).nextPart.fieldExpression);
		System.assertEquals('Contact.Account.Name', q.subSelects.get(0).fields.get(2).fieldExpression);
		System.assertEquals('Account.Name', q.subSelects.get(0).fields.get(2).nextPart.fieldExpression);
		System.assertEquals('Name', q.subSelects.get(0).fields.get(2).nextPart.nextPart.fieldExpression);
		
		//compareFroms(new Set<String>{'OpportunityContactRole','Account','Contact'}, q.subSelects.get(0).froms);

		System.assertEquals(2, q.subSelects.get(1).fields.size());
		System.assertEquals('Id', q.subSelects.get(1).fields.get(0).fieldExpression);
		System.assertEquals('AccountToId', q.subSelects.get(1).fields.get(1).fieldExpression);
		
		//compareFroms(new Set<String>{'OpportunityPartner'}, q.subSelects.get(1).froms);
	}
	
	private static void compareFroms(Set<String> fromObjNamesExpctd, Set<Query.SOQLFrom> froms) {
		Set<String> fromObjNamesActual = new Set<String>();
		for (Query.SOQLFrom frm : froms) {
			fromObjNamesActual.add(frm.fromExpression);
		}
		System.debug(fromObjNamesActual);
		System.assertEquals(fromObjNamesExpctd.size(), froms.size());
		System.assertEquals(fromObjNamesExpctd.size(), fromObjNamesActual.size());
		System.assert(fromObjNamesActual.containsAll(fromObjNamesExpctd));
		System.assert(fromObjNamesExpctd.containsAll(fromObjNamesActual));
	}

	/**
	 * Tests Negative Behavior of the parser:
	 *  - The provided query is bad (REGEX doesn't match)
	 **/
	@isTest
	static void parse_BadQuery1() {
		try {
			Query q = Query.parse('SELECT');
			System.assert(false);
		} catch (Exception e) {
			System.assert(e instanceof Query.QueryException);
			system.debug('here is the exception: ' + e);
			System.assertEquals(System.Label.DAE_BadQuery, e.getMessage());
		}
	}

	/**
	 * Tests Negative Behavior of the parser:
	 *  - The provided subquery references a non-existent relationship
	 **/
	@isTest
	static void parse_BadRelationship() {
		try {
			Query q = Query.parse('SELECT Id, (SELECT Id FROM HoogaboogaZoom__d) FROM Account');
			System.assert(false);
		} catch (Query.QueryException e) {
			System.assertEquals('Subquery through relationship "HoogaboogaZoom__d" does not exist. Bad relationship name?', e.getMessage());
		}
	}

	/**
	 * Tests Negative Behavior of the parser:
	 *  - The provided subquery references a non-existent field
	 **/
	@isTest
	static void parse_BadField() {
		try {
			Query q = Query.parse('SELECT Id, HoogaboogaZoom__d FROM Account');
			System.assert(false);
		} catch (Query.QueryException e) {
			System.assertEquals('Field "HoogaboogaZoom__d" on object "Account" does not exist.', e.getMessage());
		}
	}

	/**
	 * Tests the regex with a really large query (20k)
	 *
	 **/
	@isTest
	static void parse_20kQuery() {
		String largeQuery = 'SELECT '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Parent.Parent.Parent.Parent.Parent.Id,  Parent.Parent.Parent.Parent.Parent.Name,  Parent.Parent.Parent.Parent.Parent.Owner,  Parent.Parent.Parent.Parent.Parent.Site,,  Parent.Parent.Parent.Parent.Parent.AnnualRevenue, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' Id, Name, AccountNumber, Owner, Site, AccountSource, AnnualRevenue, BillingStreet, BillingCity, BillingState, BillingPostalCode, CreatedBy, Description, NumberOfEmployees, Fax, Industry, LastModifiedBy, Ownership, Parent, Phone, Rating, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, TickerSymbol, Type, Website, '+
							' (SELECT Id, AssistantName, AssistantPhone, Birthdate, Owner, CreatedBy, Department, Description, DoNotCall, Email, Fax, HomePhone, LastModifiedBy, LeadSource, MailingStreet, MailingCity, MailingState, MailingPostalCode, MobilePhone, FirstName, LastName, OtherStreet, OtherCity, OtherState, OtherPostalCode, OtherPhone, Phone, Title, Account.Parent.Parent.Parent.Parent.Id, Account.Parent.Parent.Parent.Parent.Name FROM Contacts), '+
							' (SELECT Id, Name, CreatedBy, CreatedDate, LastModifiedBy, LastModifiedDate, Owner, Amount, CloseDate, Contract, Description, ExpectedREvenue, ForecastCategoryName, LeadSource, NextStep, Campaign, IsPrivate, Probability, TotalOpportunityQuantity, StageName, Type FROM Opportunities) '+
							' (SELECT Id, CreatedBy, CreatedDate, LastModifiedBy, LastModifiedDate, Owner, Asset, BusinessHoursId, CaseNumber, Origin, Reason, ContactId, ClosedDate, Description, IsEscalated, ParentId, Priority, Status, Subject, Type, SuppliedCompany, SuppliedEmail, SuppliedName, SuppliedPhone FROM Cases) '+
							' FROM Account';
		Long startMillis	= System.currentTimeMillis();
		Query q = Query.parse(largeQuery);
		System.debug(LoggingLevel.WARN, 'Parse Time: ' + (System.currentTimeMillis()-startMillis));
		
		System.assert(true);
	}

	@isTest
	static void disabled() {
		DataConstants.ENABLED = false;
		String query1 = 'SELECT Id FROM Account';
		Query q = Query.parse(query1);
		q.validateCRUDFLS(true, true);
		System.assert(true);
	}
}