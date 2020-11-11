/**
 * Provides a mechanism for parsing and representing SOSL queries.
 * <p>
 * This class uses REGEX to parse a SOSL query. This works pretty well 
 * so far, but it has some shortcomings.
 */
public with sharing class Find {
	private static final Pattern P1 = Pattern.compile('(?i)FIND.+?RETURNING (.+?)(?: WITH| LIMIT| UPDATE|$)');
	private static final Pattern P2 = Pattern.compile('(?i)(\\w+)(?: \\((.+?)(?: WHERE \\w+){0,1}\\))?(?:, )?');//'
	
	private String fullQuery;
	private String queryPart;
	private FindFrom fromObj;
	private List<FindField> fields;

	/**
	 * Validate the CRUD and FLS for this find.
	 * <p>
	 * 
	 * @param validateCRUD Specifiying true will validate the user has READ access to all objects referenced by the query
	 * @param validateFLS Specifying true will validate that the user has READ access to all fields referenced by the query
	 * @throws Data.CRUDException If the user doesn't have READ access to any object referenced by the query.
	 * @throws Data.FLSException If the user doesn't have READ access to any field referenced by the query.
	 */
	public void validateCRUDFLS(Boolean validateCRUD, Boolean validateFLS) {
		if (DataConstants.ENABLED && (validateCRUD || validateFLS)) {
			if (validateCRUD) {
				this.fromObj.validateCRUD();
			}
			if (validateFLS) {
				for (FindField ff : this.fields) {
					ff.validateFLS();
				}
			}
		}
	}

	/**
	 * Factory method for parsing a SOSL string into multiple Find instances.
	 *
	 * @param query A string of the SOSL Query
	 * @return List<Find> A collection of Find instances, 1 for each object defined in the "RETURNING" statement.
	 * @throws Data.FindException If the SOSL query cannot be parsed.
	 */
	public static List<Find> parse(String query) {
		LimitsSnapshot ls = new LimitsSnapshot('Query_parse');

		List<Find> finds = new List<Find>();

		if (!DataConstants.ENABLED)
			return finds;

		query = query.normalizeSpace();

		Matcher m1 = P1.matcher(query);
		if (m1.matches()) {
			String s2 = m1.group(1);
			System.debug(DataConstants.LOGGING_LEVEL, s2);

			Matcher m2 = p2.matcher(s2);
			while (m2.find()) {
				String part	= m2.group(0);
				String obj	= m2.group(1);
				String flds	= m2.group(2);
				System.debug(DataConstants.LOGGING_LEVEL, part);
				System.debug(DataConstants.LOGGING_LEVEL, obj);
				System.debug(DataConstants.LOGGING_LEVEL, flds);


				DescribeCache describe = DescribeCache.getDescribeCache(obj);

				Find f		= new Find();
				f.queryPart	= part;
				f.fullQuery = query;
				f.fromObj	= new FindFrom(describe);
				f.fields 	= new List<FindField>();

				if (flds != null) {
					flds 		= flds.replaceAll(' ', '');
					for (String fld : flds.split(',')) {
						Schema.DescribeFieldResult dfr = describe.getFieldDescribe(fld);

						if (dfr == null) {
							throw new FindException(String.format(System.Label.DAE_FieldDoesNotExist, new List<String>{fld,describe.objectName}));
						}

						f.fields.add(new FindField(dfr, describe.objectToken, fld));
					}
				}

				finds.add(f);
			}
		} else {
			System.debug(DataConstants.LOGGING_LEVEL, 'Bad query: ' + query);
			throw new FindException(System.Label.DAE_BadQuery);
		}

		ls.toLog(LoggingLevel.WARN);
		return finds;
	}

	/** An object representing exceptions when parsing SOSL queries */
	public class FindException extends Exception {}

	/**
	 * Represents a field referenced in a SOSL query.
	 * <p>
	 */
	public class FindField {
		/** The DescribeFieldResult for this field */
		public Schema.DescribeFieldResult fieldDescribe	{get; private set;}
		/** The SObjectType that this field lives on */
		public Schema.SObjectType soType 				{get; private set;}
		/** The field expression for this field. Example "Contact.Account.Name" */
		public String fieldExpression 					{get; private set;}

		public FindField(Schema.DescribeFieldResult fieldDescribe,
						 Schema.SObjectType soType,
						 String fieldExpression) {
			this.fieldDescribe		= fieldDescribe;
			this.soType				= soType;
			this.fieldExpression	= fieldExpression;
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
		}
	}
	
	/**
	 * Represents a RETURNING object in a SOSL query.
	 * <p>
	 */
	public class FindFrom {
		private DescribeCache sotDescribe;

		public FindFrom(DescribeCache sotDescribe) {
			this.sotDescribe 	= sotDescribe;
		}

		public void validateCRUD() {
			System.debug(DataConstants.LOGGING_LEVEL, 'Validating sobject "' + sotDescribe.objectName + '"');
			
			SecUtil.checkCRUD(DataConstants.SecurityOperation.READ, sotDescribe);
		}
	}
}