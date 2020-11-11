/**
 * Provides a mechanism for parsing and representing SOQL queries.
 * <p>
 * This class uses REGEX to parse a SOQL query. This works pretty well 
 * so far, but it has some shortcomings.
 * <p>
 * Currently Supports:<br/>
 * <ul>
 * 		<li>Sub-selects (organized as the last parts of the select)</li>
 * 		<li>Parent relationships (Opportunity.Contact.Account.ParentAccount.Name)</li>
 * 		<li>One FROM object</li>
 * 		<li>Aggregate functions. e.g. SELECT SUM(Amount)</li>
 * 		<li>Date functions. e.g. SELECT CALENDAR_YEAR(CloseDate)</li>
 * 		<li>convertCurrency()</li>
 * </ul>
 * <br/>
 * The following are not supported and will break the parser:<br/>
 * <ul>
 * 		<li>Polymorphic Relationship Fields. e.g. SELECT TYPEOF What
 *                                                       WHEN Account THEN Phone
 *                                                     ELSE Name
 * 													   END</li>
 * 		<li>FROM object aliasing. e.g. SELECT c.FirstName FROM Contact c</li>
 * 		<li>
 * 			Multiple FROM Objects/joins. e.g. FROM Opportunity o, o.Contract.CustomerSigned.Account a<br/>
 * 			This will require updating the PARENT_PATTER RegEx to:<br/>
 *			(?i)SELECT (.+?)((?:, \\(SELECT (?:.+?)\\)){0,3}?) FROM (.+?)(?: USING| WHERE| WITH| GROUP| ORDER| LIMIT| OFFSET| FOR| UPDATE| ROLLUP| CUBE|$)
 * 		</li>
 * </ul>
 * <br/>
 * The following are not supported, but won't break the parser:<br/>
 * <ul>
 * 		<li>Validate CRUD/FLS on any filters, semi-joins, anti-joins</li>
 * 		<li>Validate ORDER BY, HAVING, WHERE etc</li>
 * </ul>
 *
 *
 * Note: The author is considering making this an inner class within Data. Originally considered
 * keeping this class public and adding QueryFactory-like functionality but QF is bloat-ish
 * (low cost/benefit ratio):<br/>
 * <ul>
 * 		<li>SOQL is simple &amp; powerful: Why take that away from devs? Rebuilding that power
 *			into a factory is difficult and introduces even more tech debt as SOQL changes.</li>
 * 		<li>Ramp-up time &amp; Velocity: Factories require the developer 
 *			utilizing the factory to learn yet another thing. Factories also
 *			require the developer to write more code than just a simple SOQL.</li>
 * 		<li>Maintenance: code that utilizes a factory is bigger than a simple SOQL.</li>
 * 		<li>The best bang-for-buck is with Selector layer.</li>
 * 		<li>Performance: executing code to figure out what SOQL statement to run adds overhead.</li>
 * </ul>
 * Counter Argument:<br/>
 * <ul>
 * 		<li>Factory can be another place to simplify/automate CRUD/FLS</li>
 * 		<li>Good in dynamic situations utilizing FieldSets or other User-Definable queries. This
 * 			could also be done in the base Selector class/layer.</li>
 * </ul>
 * 		
 * 
 * 
 * @see Data
 * @author Eddie Blazer, CodeScience
 * @date January 7th, 2015
 */
public with sharing class Query {
	private static final Pattern PARENT_PATTERN 	= Pattern.compile('(?i)SELECT (.+?)((?:, \\(SELECT (?:.+?)\\)){0,3}?) FROM (\\w+)');
	private static final Pattern SUBSELECT_PATTERN	= Pattern.compile('(?i)\\((SELECT .*? FROM (?:\\w+))\\)');//(?i)\\((SELECT\\s(.+?)\\sFROM\\s(?:\\w+)(?:[^\\)])*)\\)');//Pattern.compile('(?i)\\((SELECT\\s(?:[\\w\\.\\s,]|(?:[\\w]\\([\\w_\\.]*\\)))+\\sFROM\\s(?:\\w)+(?:[^\\)])*)\\)');
	
	/** All of the fields that were parsed from the SOQL query */
	public final List<SOQLField> fields;
	/** All of the FROMS (currently supports 1) that were parsed from the SOQL query */
	public final List<SOQLFrom> froms;
	/** All of the sub-selects (child queries) that were parsed from the SOQL query */
	public final List<Query> subSelects;
	/** This query's parent query, if this query is a child query */
	public final Query parentQuery;
	/** The string representation of the *normalized* SOQL query that was parsed. Normalized = stripping of extraneous whitespace */
	public String soqlQuery {get; private set;}


	private Query() {
		this.fields 		= new List<SOQLField>();
		this.froms 			= new List<SOQLFrom>();
		this.subSelects 	= new List<Query>();
	}

	/**
	 * Validate the CRUD and FLS for this query.
	 * <p>
	 * If this query has child/sub-queries and/or parent relationship fields, this method
	 * will recurse those structures to validate full CRUD and FLS.
	 * <p>
	 * If validating CRUD only, and the query has any parent relationship fields,
	 * this method will validate CRUD on those relationship fields to ensure
	 * that the user does have READ permission to the object referenced by
	 * the relationship field.
	 * 
	 * @param validateCRUD Specifiying true will validate the user has READ access to all objects referenced by the query
	 * @param validateFLS Specifying true will validate that the user has READ access to all fields referenced by the query
	 * @throws Data.CRUDException If the user doesn't have READ access to any object referenced by the query.
	 * @throws Data.FLSException If the user doesn't have READ access to any field referenced by the query.
	 */
	public void validateCRUDFLS(Boolean validateCRUD, Boolean validateFLS) {
		if (DataConstants.ENABLED && (validateCRUD || validateFLS)) {
			Set<Schema.SObjectType> sots = new Set<Schema.SObjectType>();
			
			if (validateCRUD) {
				for (SOQLFrom frm : this.froms) {
					frm.validateCRUD();
				}
			}
			for (SOQLField f : this.fields) {
				if (validateCRUD) {
					sots.addAll(f.getAllObjects());
				}
				if (validateFLS) {
					f.validateFLS();
				}
			}
			if (validateCRUD) {
				for (Schema.SObjectType sot : sots) {
					SecUtil.checkCRUD(DataConstants.SecurityOperation.READ, sot);
				}
			}
			
			for (Query subQ : subSelects) {
				subQ.validateCRUDFLS(validateCRUD, validateFLS);
			}
		}
	}


	/**
	 * Factory method for parsing a SOQL string into a Query instance.
	 *
	 * @param soqlQuery A string of the SOQL Query
	 * @return Query A query instance representing the parsed results.
	 * @throws Data.QueryException If the SOQL query cannot be parsed.
	 */
	public static Query parse(String soqlQuery) {
		LimitsSnapshot ls = new LimitsSnapshot('Query_parse');
		Query q = parse(soqlQuery, null);
		ls.toLog(DataConstants.LOGGING_LEVEL);
		return q;
	}

	private static Query parse(String soqlQuery, SOQLFrom parentFrom) {
		Query q = new Query();

		q.soqlQuery = soqlQuery.normalizeSpace(); // Get rid of extraneous/unnecessary whitespaces (space, tab (\t), new line (\n), carriage return (\r), and form feed (\f))

		if (!DataConstants.ENABLED)
			return q;
		
		Matcher parentQueryMatcher = PARENT_PATTERN.matcher(q.soqlQuery);
		if (parentQueryMatcher.find()) {
			String fields		= parentQueryMatcher.group(1);
			String subSelects	= parentQueryMatcher.group(2);
			String fromObj		= parentQueryMatcher.group(3);

			System.debug(DataConstants.LOGGING_LEVEL, 'PARENT_PATTERN match group count: ' + parentQueryMatcher.groupCount());
			System.debug(DataConstants.LOGGING_LEVEL, 'Group 0 (Matching Query): ' + parentQueryMatcher.group(0));
			System.debug(DataConstants.LOGGING_LEVEL, 'Group 1 (Matching Fields): ' + fields);
			System.debug(DataConstants.LOGGING_LEVEL, 'Group 2 (Matching Sub-Selects): ' + subSelects);
			System.debug(DataConstants.LOGGING_LEVEL, 'Group 3 (Matching From): ' + fromObj);

			SOQLFrom frm = new SOQLFrom();
			frm.fromExpression	= fromObj;


			if (parentFrom == null) {
				frm.sotDescribe		= DescribeCache.getDescribeCache(fromObj);
				parentFrom			= frm;
			} else {
				Schema.SObjectType childSOT = parentFrom.sotDescribe.getChildSObject(fromObj);
				frm.sotDescribe 			= DescribeCache.getDescribeCache(childSOT);

				if (frm.sotDescribe == null) {
					throw new QueryException(String.format(System.Label.DAE_BadRelationshipName, new List<String>{fromObj}));
				}
			}
			
			q.froms.add(frm);

			for (String fld : fields.split(',')) {
				fld = fld.trim().substringBefore(' '); // ignore field expression/aliases
				SOQLField f = parseFieldExpression(fld, frm.sotDescribe);
				if (f != null)
					q.fields.add(f);
			}

			if (subSelects != null) {
				Matcher subSelMatcher = SUBSELECT_PATTERN.matcher(subSelects);
				while (subSelMatcher.find()) {

					String subSelect		= subSelMatcher.group(1);

					System.debug(DataConstants.LOGGING_LEVEL, 'SUBSELECT_PATTERN match group count: ' + subSelMatcher.groupCount());
					System.debug(DataConstants.LOGGING_LEVEL, 'Group 0 (Matching Sub Query): ' + subSelMatcher.group(0));
					System.debug(DataConstants.LOGGING_LEVEL, 'Group 1 (Matching Sub Query NoParens): ' + subSelect);

					q.subSelects.add(parse(subSelect, parentFrom));
				}
			}
		} else {
			System.debug(DataConstants.LOGGING_LEVEL, 'Bad query: ' + q.soqlQuery);
			throw new QueryException(System.Label.DAE_BadQuery);
		}

		return q;
	}

	/*
	 * This method should recursively call itself, validating each field until it reaches the last field in the expression
	 * It should only throw an exception if the field is inaccessible
	 * Example fieldExpression (field on the OpportunityContactRole): Opportunity.Account.Name
	 * This method should test that the user has access to the following fields:
	 * 			- OpportunityContactRole.OpportunityId
	 * 			- Opportunity.AccountId
	 * 			- Account.Name
	 */
	private static SOQLField parseFieldExpression(String fieldExpression, DescribeCache describe) {
		System.debug(DataConstants.LOGGING_LEVEL, 'Parsing field "' + fieldExpression + '"" on sobject "' + describe.objectName + '".');
		
		SOQLField fld;
		
		// If the field is a function, strip the function and get just the name part
		if (fieldExpression.indexOf('(') < fieldExpression.indexOf(')')) {
			fieldExpression	= fieldExpression.substringBetween('(', ')');
		}

		if (fieldExpression != '') {
			String fieldPart = fieldExpression.substringBefore('.'); // this is about 25% faster than a String.split/list approach and 40% less heap

			Schema.DescribeFieldResult dfr = describe.getFieldDescribe(fieldPart);//Data.getFieldResultByTypeAndField(sot, fieldPart);

			if (dfr == null) {
				throw new QueryException(String.format(System.Label.DAE_FieldDoesNotExist, new List<String>{fieldPart,describe.objectName}));
			}

			SOQLField nextPart;
			if (fieldExpression.contains('.')) {
				nextPart = parseFieldExpression(fieldExpression.substringAfter('.'), DescribeCache.getDescribeCache(dfr.getReferenceTo()[0]));
			}
			
			fld = new SOQLField(dfr, describe.objectToken, fieldExpression, nextPart);
		}
		
		return fld;
	}

	/** An object representing exceptions when parsing SOQL queries */
	public class QueryException extends Exception {}

	/**
	 * Represents a field referenced in a SOQL query.
	 * <p>
	 * If a SOQL query references a relationship field, "Contract.Account.Owner.Name"
	 * for example, then the parent Query instance would have 1 SOQLField instance 
	 * that represents the first field (Contract) in the full field expression. This 
	 * SOQLField instance would then in turn reference the next field in the full 
	 * expression (Account) which would then reference the next field (Owner), etc.
	 * <p>
	 * Each SOQLField instance has knowledge of the field through a DescribeFieldResult
	 * reference, the Object that the field lives on through a SObjectType reference,
	 * and the field expression for that field and all subsequent parts.
	 * <p>
	 * This class is referenced by 
	 */
	public class SOQLField {
		/** The DescribeFieldResult for this field */
		public Schema.DescribeFieldResult fieldDescribe	{get; private set;}
		/** The SObjectType that this field lives on */
		public Schema.SObjectType soType 				{get; private set;}
		/** The field expression for this field. Example "Contact.Account.Name" */
		public String fieldExpression 					{get; private set;}
		/** 
		 * The SOQLField for the next part of the field expression
		 *<p>
		 * If this SOQLField instance is for "Contact", then the next part would
		 * be for "Account", and it in turn would have a nextPart for "Name".
		 */
		public SOQLField nextPart 						{get; private set;}

		public SOQLField(Schema.DescribeFieldResult fieldDescribe,
						 Schema.SObjectType soType,
						 String fieldExpression,
						 SOQLField nextPart) {
			this.fieldDescribe		= fieldDescribe;
			this.soType				= soType;
			this.fieldExpression	= fieldExpression;
			this.nextPart			= nextPart;
		}
		
		/**
		 * Validates the FLS for this field.
		 * <p>
		 * This method recursively calls itself if the instance has a nextPart defined.
		 *
	 	 * @throws Data.FLSException If the user doesn't have READ access to any field referenced by the query.
		 */
		public void validateFLS() {
			System.debug(DataConstants.LOGGING_LEVEL, 'Validating field "' + fieldExpression + '"" on sobject "' + soType + '"');
			
			SecUtil.checkFLS(DataConstants.SecurityOperation.READ, soType.getDescribe(), this.fieldDescribe);

			if (nextPart != null) {
				nextPart.validateFLS();
			}
		}
		
		/**
		 * Retrieves all SObjectTypes referenced by a SOQLField, recursing as necessary.
		 * <p>
		 * This is helper method used by Query.validateCRUDFLS().
		 * 
		 * @return Set<Schema.SObjectType> A set of unique SObjects referenced by this (and child) fields.
		 */
		public Set<Schema.SObjectType> getAllObjects() {
			Set<Schema.SObjectType> sots = new Set<Schema.SObjectType>();
			
			sots.add(soType);
			if (nextPart != null)
				sots.addAll(nextPart.getAllObjects());
			
			return sots;
		}
	}

	/**
	 * Represents a FROM object in a SOQL query.
	 * <p>
	 * Query.parse() supports only a single FROM in the SOQL query, however
	 * SOQL itself does support more than one FROM (very useful for shortening
	 * SOQL statements). Eventually when .parse() supports multiple FROMs,
	 * this class will be infinitely more useful as it will know the object
	 * and the alias used to reference the object.
	 */
	public class SOQLFrom {
		/** The SObjectType that this instance references */
		//public Schema.SObjectType sObjType				{get; private set;}

		private DescribeCache sotDescribe;

		/** 
		 * The expression used in the SOQL query to generate this SOQLFrom.
		 * <p>
		 * Examples:<br/>
		 * <code>
		 * FROM Account<br/>
		 * FROM ChildObjects__r<br/>
		 * FROM Contract c, c.SignedByContact.Account a // will eventually result in TWO SOQLFrom instances
		 * </code>
		 */
		public String fromExpression 					{get; private set;}
		
		/** 
		 * The alias used in the fromExpression
		 */
		//public String objAlias 							{get; private set;}
		//public String nextPart 							{get; private set;}

		public SOQLFrom(){} // @todo delete this

		/*public SOQLFrom(DescribeCache sotDescribe,
						String fromExpression,
						String objAlias,
						String nextPart) {
			this.sotDescribe 	= sotDescribe;
			this.fromExpression	= fromExpression;
			this.objAlias		= objAlias;
			this.nextPart		= nextPart;
		}*/

		public void validateCRUD() {
			System.debug(DataConstants.LOGGING_LEVEL, 'Validating sobject "' + sotDescribe.objectName + '"');
			
			SecUtil.checkCRUD(DataConstants.SecurityOperation.READ, sotDescribe);
		}
	}
}