/**
 * A helper class modeled off of the standard System.Database class
 * that provides automatic CRUD, FLS and Sharing Rule enforcement.
 * <p>
 * This class models all the System.Database methods, albeit with
 * different verbs to avoid conflicts with reserved words. This class
 * currently supports all of the same methods except for SOSL search
 * and upsert-like functionality as Database.upsert supports only
 * concrete SObjects and this library references only the base
 * SObject class.
 * Additionally, this class supports only SOQL strings, and does not
 * automagically parse inline SOQL statements (e.g. 'SELECT...'
 * not [SELECT...]), as that would by crazy impossible. However,
 * bind variables ARE supported, but do need to be provided via a
 * Map&lt;String=BindVariableName,Object=Value&gt;.
 * <p>
 * This class supports data mocking for Unit Testing, which provides
 * a mechanism for highly isolated, deterministic, and more
 * performant tests.
 * <p>
 * Things that are being considered for future functionality:<br>
 * <ul>
 * <li>SOSL/searches</li>
 * <li>Custom SObject class that wraps and detects dirty fields and provides method for listing fields. Could provide a more performant approach than standard class.</li>
 * </ul>
 * <p>
 * Examples:<br>
 * <code>
 * // Create an Account Record<br/>
 * Account a = new Account(Name = 'Test');<br/>
 * Data.create(a, true, true, true);<br/>
 * <br/>
 * // Update the Account record<br/>
 * a.BillingState = 'CA';<br/>
 * Data.modify(a, true, true, true);<br/>
 * <br/>
 * // Delete the Account<br/>
 * Data.remove(a, true, true, true);<br/>
 * <br/>
 * // Query for the record<br/>
 * Data.read('SELECT Id FROM Account WHERE Id = :accountId', new Map&lt;String,Object&gt;{'accountId'=>a.Id}, true, true, true);
 * // Query for aggregate results<br/>
 * Data.read('SELECT MAX(Amount, StageName FROM Opportunity WHERE CloseDate < :closeDate GROUP BY StageName', new Map&lt;String,Object&gt;{'closeDate'=>System.Today()}, true, true, true);
 * </code>
 *
 *
 * @see Query
 * @author Eddie Blazer, CodeScience
 * @date January 7th, 2015
 */
 
// Per Robert Sussland (SFDC):  This class doesn't need/have a sharing declaration because it doesn't perform any DML itself, it uses DBWithShare and DBWithoutShare.
public class Data {
	private static final Map<Schema.SObjectType,Map<String,Schema.DescribeFieldResult>> OBJ_FIELDS	= new Map<Schema.SObjectType,Map<String,Schema.DescribeFieldResult>>();
	private static final Map<Schema.SObjectType,Map<String,Schema.SObjectType>> OBJ_CHILDS			= new Map<Schema.SObjectType,Map<String,Schema.SObjectType>>();
	private static final Set<String> SYSTEM_FIELDS	= new Set<String>{
		'Id','CreatedById','CreatedDate','LastModifiedById','LastModifiedDate','SystemModStamp','CurrencyIsoCode'
	}; // Might need to make this object-specific

	private static Data.DB dmlWithShr	    = new Data.DBWithShare();
	private static Data.DB dmlWithoutShr	= new Data.DBWithoutShare();

	public static Integer VALIDATE_METHOD = 3; // @see code comments for validateList()


    @TestVisible // Code coverage
	private Data() {} // prevent instantiation

	/**
	 * Enables injectable data mocking for unit tests
	 *
	 * @param dml The Data.DB instance that enables data mocking.
	 */
	@TestVisible
	private static void injectDML(Data.DB dml) {
		dmlWithShr		= dml;
		dmlWithoutShr	= dml;
	}




	/**
	 * Create (Insert) the specified records into the Salesforce database, validating CRUD, FLS and Sharing rules as specified.
	 * <p>
	 * Example:<br/>
	 * <code>
	 * List<Account> accts = new List<Account>{<br/>
	 *		new Account(<br/>
	 *			Name = 'Test Account'<br/>
	 *		)<br/>
	 * };<br/>
	 * Data.create(accts);<br/>
	 * </code>
	 * @see Database.DMLOptions
	 * @param records The list of records to be inserted. Note: that this DOES support mixed-type collections.
	 * @param options The Database.DMLOptions. See the Apex docs for this.
	 * @param enforceCRUD If true, enforces CRUD validation.
	 * @param enforceFLS If true, enforces FLS validation.
	 * @param enforceShr If true, enforces Sharing Rules, throws DMLException if the user doesn't have access to the record.
	 * @return List&lt;Database.SaveResult&gt; The save results of the save. The return value and behavior is exaclty the same as Database.insert(...);
	 * @throws Data.CRUDException if the user does not have CREATE access to the object(s).
	 * @throws Data.FLSException if the user does not have CREATE access to any field referenced in the provided records.
	 */
	public static List<Database.SaveResult> create(List<SObject> records, Database.DMLOptions options, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr, Set<String> exceptions) {
		return (List<Database.SaveResult>)performDML(DataConstants.SecurityOperation.CREATE, records, options, enforceCRUD, enforceFLS, enforceShr, exceptions);
	}
	
	/** 
	 * Helper to match old signature without exceptions
	 */
	public static List<Database.SaveResult> create(List<SObject> records, Database.DMLOptions options, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr) {
		return create(records, options, enforceCRUD, enforceFLS, enforceShr, new Set<String>());
	}
	/**
	 * This method is the same as calling <code>Data.create(List&lt;SObject&gt; records, options, true, true, true);</code> with a default DMLOptions of <code>AllOrNone=true</code>.
	 */
	public static List<Database.SaveResult> create(List<SObject> records, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr) {
		Database.DMLOptions dmo = new Database.DMLOptions();
		dmo.optAllOrNone		= true;
		return create(records, dmo, enforceCRUD, enforceFLS, enforceShr);
	}
	/**
	 * Helper method that wraps the provided record into a list
	 */
	public static List<Database.SaveResult> create(SObject record, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr) {
		return create(new List<SObject>{record}, enforceCRUD, enforceFLS, enforceShr);
	}
	/**
	 * This method is the same as calling <code>Data.create(records, true, true, true);</code>
	 */
	public static List<Database.SaveResult> create(List<SObject> records) {
		return create(records, true, true, true);
	}
	/**
	 * Helper method that wraps the provided record into a list
	 */
	public static List<Database.SaveResult> create(SObject record) {
		return create(new List<SObject>{record});
	}


	/**
	 * Modify (Update) records.
	 *
	 * @param records The list of records to be updated. Note: that this DOES support mixed-type collections.
	 * @param options The Database.DMLOptions. See the Apex docs for this.
	 * @param enforceCRUD If true, enforces CRUD validation.
	 * @param enforceFLS If true, enforces FLS validation.
	 * @param enforceShr If true, enforces Sharing Rules
	 * @return List&lt;Database.SaveResult&gt; The save results of the save. The return value and behavior is exaclty the same as Database.update(...);
	 * @throws Data.CRUDException if the user does not have EDIT access to the object(s).
	 * @throws Data.FLSException if the user does not have EDIT access to any field referenced in the provided records.
	 * @throws DMLException if the user doesn't have access to the record.
	 */
	public static List<Database.SaveResult> modify(List<SObject> records, Database.DMLOptions options, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr, Set<String> exceptions) {
		return (List<Database.SaveResult>)performDML(DataConstants.SecurityOperation.MODIFY, records, options, enforceCRUD, enforceFLS, enforceShr, exceptions);
	}
	
	/** 
	 * Helper to match old signature without exceptions
	 */
	public static List<Database.SaveResult> modify(List<SObject> records, Database.DMLOptions options, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr) {
		return modify(records, options, enforceCRUD, enforceFLS, enforceShr, new Set<String>());
	}
	/**
	 * This method is the same as calling <code>Data.modify(records, options, true, true, true);</code> with a default DMLOptions of <code>AllOrNone=true</code>.
	 */
	public static List<Database.SaveResult> modify(List<SObject> records, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr) {
		Database.DMLOptions dmo = new Database.DMLOptions();
		dmo.optAllOrNone		= true;
		return modify(records, dmo, enforceCRUD, enforceFLS, enforceShr);
	}
	/**
	 * Helper method that wraps the provided record into a list
	 */
	public static List<Database.SaveResult> modify(SObject record, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr) {
		return modify(new List<SObject>{record}, enforceCRUD, enforceFLS, enforceShr);
	}
	/**
	 * This method is the same as calling <code>Data.modify(records, options, true, true, true);</code>.
	 */
	public static List<Database.SaveResult> modify(List<SObject> records, Database.DMLOptions options) {
		return modify(records, options, true, true, true);
	}
	/**
	 * This method is the same as calling <code>Data.modify(records, true, true, true);</code>.
	 */
	public static List<Database.SaveResult> modify(List<SObject> records) {
		return modify(records, true, true, true);
	}
	/**
	 * Helper method that wraps the provided record into a list
	 */
	public static List<Database.SaveResult> modify(SObject record) {
		return modify(new List<SObject>{record});
	}


	/**
	 * Upsert records.
	 * <p>
	 * Reflects the Database.upsert() method. Use this method sparingly. Because Database.upsert() does not accept
	 * generic SObjects, this method reinvented the upsert wheel by determining which records exist and which do not,
	 * and delegating to modify() and create() respectively. It does this by performing a query, looking for records
	 * that match the specified external Id. This query can be costly in high data volume situations and will consume
	 * more SOQL Records than you may expect. If you can, only use this method when absolutely needed.
	 *
	 * @param records The records to upsert
	 * @param externalIdField The SObjectField token of the field to match
	 * @param options The DMLOptions
	 * @param enforceCRUD If true, enforces CRUD validation.
	 * @param enforceFLS If true, enforces FLS validation.
	 * @param enforceShr If true, enforces Sharing Rules
	 * @param exceptions The set of field names to ignore FLS validation.
	 * @return List&lt;Database.SaveResult&gt; The save results of the save. The return value and behavior is exaclty the same as Database.update(...);
	 * @throws Data.CRUDException if the user does not have EDIT access to the object(s).
	 * @throws Data.FLSException if the user does not have EDIT access to any field referenced in the provided records.
	 * @throws DMLException if the user doesn't have access to the record.
	 */
	public static List<Database.UpsertResult> upsurt(List<SObject> records, Schema.SObjectField externalIdField, Database.DMLOptions options, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr, Set<String> exceptions) {
		if (externalIdField != null && String.valueOf(externalIdField) != 'Id') {
			DescribeFieldResult dfr = externalIdField.getDescribe();
			if (!dfr.isExternalId() && !dfr.isIdLookup()) {
				throw new DMLException(
						String.format(System.Label.DAE_InvalidExternalId, new List<String>{
								String.valueOf(records.getSObjectType()),
								String.valueOf(externalIdField)
						}
						)
				);
			}

			// Get the externalIds so we can query for them
			Map<String, SObject> idObjectMap = new Map<String, SObject>();
			for (SObject so : records) {
				String externalIdValue = (String) so.get(externalIdField);
				if (idObjectMap.containsKey(externalIdValue)) {
					// Duplicate record. Throw an exception
					throw new DMLException(
							String.format(System.Label.DAE_DuplicateRecordForUpsert, new List<String>{externalIdValue})
					);
				} else {
					idObjectMap.put(externalIdValue, so);
				}
			}

			// Query for matching records
			Set<String> externalIds = idObjectMap.keySet();
 			String externalIdStr = String.escapeSingleQuotes(String.valueOf(externalIdField));
			String escapedObjName = String.escapeSingleQuotes(String.valueOf(records[0].getSObjectType().getDescribe().getName()));
  			List<SObject> matchingRecords	= Database.query('SELECT Id, ' + externalIdStr + ' FROM ' + escapedObjName + ' WHERE ' + externalIdStr + ' IN :externalIds');
			for (SObject matchingRecord : matchingRecords) {
				// put the Id into the new record
				String externalIdValue = (String) matchingRecord.get(externalIdField);
				SObject record = idObjectMap.get(externalIdValue);
				record.put('Id', matchingRecord.Id);
			}
		}

		Map<Integer,Integer> havesIdxs		= new Map<Integer,Integer>();
		Map<Integer,Integer> haveNotsIdxs	= new Map<Integer,Integer>();

		List<SObject> haves		= new List<SObject>();
		List<SObject> haveNots	= new List<SObject>();
		for (Integer i=0, j=records.size(); i<j; i++) {
			SObject so = records.get(i);
			if (so.get('Id') == null) {
				haveNots.add(so);
				haveNotsIdxs.put(haveNots.size()-1, i);
			} else {
				haves.add(so);
				havesIdxs.put(haves.size()-1, i);
			}
		}

		List<Database.UpsertResult> allResults	= new Database.UpsertResult[records.size()];
		List<Database.SaveResult> haveNotsRslts	= create(haveNots, options, enforceCRUD, enforceFLS, enforceShr, exceptions);
		for (Integer i=0,j=haveNotsRslts.size(); i<j; i++) {
			allResults.set(haveNotsIdxs.get(i), upsertResultFromSaveResult(haveNotsRslts.get(i), true));
		}
		List<Database.SaveResult> havesRslts	= modify(haves, options, enforceCRUD, enforceFLS, enforceShr, exceptions);
		for (Integer i=0,j=havesRslts.size(); i<j; i++) {
			allResults.set(havesIdxs.get(i), upsertResultFromSaveResult(havesRslts.get(i), false));
		}

		return allResults;
	}

	private static Database.UpsertResult upsertResultFromSaveResult(Database.SaveResult dsr, Boolean create) {
		String jsn = JSON.serialize(dsr);
		jsn = jsn.left(jsn.length()-1);
		jsn += ',"created":' + create + '}';
		return (Database.UpsertResult)JSON.deserialize(jsn, Type.forName('Database.UpsertResult'));
	}
	
	/** 
	 * Helpers to match old signature without exceptions
	 */
	public static List<Database.UpsertResult> upsurt(List<SObject> records, Database.DMLOptions options, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr) {
		return upsurt(records, null, options, enforceCRUD, enforceFLS, enforceShr, new Set<String>());
	}
	public static List<Database.UpsertResult> upsurt(List<SObject> records, Database.DMLOptions options, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr, Set<String> exceptions) {
		return upsurt(records, null, options, enforceCRUD, enforceFLS, enforceShr, new Set<String>());
	}
	public static List<Database.UpsertResult> upsurt(List<SObject> records) {
		return upsurt(records, true, true, true);
	}
	public static List<Database.UpsertResult> upsurt(List<SObject> records, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr) {
		Database.DMLOptions dmo = new Database.DMLOptions();
		dmo.optAllOrNone		= true;
		
		return upsurt(records, null, dmo, enforceCRUD, enforceFLS, enforceShr, new Set<String>());
	}
	public static List<Database.UpsertResult> upsurt(SObject record, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr) {
		return upsurt(new List<sObject>{record}, enforceCRUD, enforceFLS, enforceShr);
	}
	public static List<Database.UpsertResult> upsurt(SObject record) {
		return upsurt(record, true, true, true);
	}
	public static List<Database.UpsertResult> upsurt(List<SObject> records, Schema.SObjectField externalIdField, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr, Set<String> exceptions) {
		Database.DMLOptions dmo = new Database.DMLOptions();
		dmo.optAllOrNone		= true;

		return upsurt(records, externalIdField, dmo, enforceCRUD, enforceFLS, enforceShr, exceptions);
	}
	public static List<Database.UpsertResult> upsurt(List<SObject> records, Schema.SObjectField externalIdField, Set<String> exceptions) {
		return upsurt(records, externalIdField, true, true, true, exceptions);
	}
	public static List<Database.UpsertResult> upsurt(List<SObject> records, Schema.SObjectField externalIdField) {
		return upsurt(records, externalIdField, new Set<String>());
	}
	public static List<Database.UpsertResult> upsurt(SObject record, Schema.SObjectField externalIdField) {
		return upsurt(new List<SObject>{record}, externalIdField);
	}

	/**
	 * Remove (Delete) records.
	 *
	 * @param recordIDs The list of record IDs to be deleted. Note: that this DOES support mixed-type collections.
	 * @param allOrNone If true, throws exception if any of the records fail to be deleted and rolls back the entire transaction.
	 * @param enforceCRUD If true, enforces CRUD validation.
	 * @param enforceShr If true, enforces Sharing Rules.
	 * @return List<Database.DeleteResult> The save results of the save. The return value and behavior is exaclty the same as Database.delete(...);
	 * @throws Data.CRUDException if the user does not have DELETE access to the object(s).
	 * @throws DMLException if the user doesn't have access to the record.
	 */
	public static List<Database.DeleteResult> remove(List<Id> recordIDs, Boolean allOrNone, Boolean enforceCRUD, Boolean enforceShr) {
		if (enforceCRUD) {
			validateCRUDonIDs(recordIDs, DataConstants.SecurityOperation.REMOVE);
		}

		if (enforceShr) {
			return dmlWithShr.doRemove(recordIDs, allOrNone);
		} else {
			return dmlWithoutShr.doRemove(recordIds, allOrNone);
		}
	}
	/**
	 * Helper method that wraps the provided recordId into a list
	 */
	public static List<Database.DeleteResult> remove(Id recordID, Boolean allOrNone, Boolean enforceCRUD, Boolean enforceShr) {
		return remove(new List<Id>{recordID}, allOrNone, enforceCRUD, enforceShr);
	}
	/**
	 * This method is the same as calling <code>Data.remove(recordIDs, true, true, true);</code>
	 */
	public static List<Database.DeleteResult> remove(List<Id> recordIDs) {
		return remove(recordIDs, true, true, true);
	}
	/**
	 * Helper method that wraps the provided recordId into a list
	 */
	public static List<Database.DeleteResult> remove(Id recordID) {
		return remove(new List<Id>{recordID});
	}
	/**
	 * Remove (Delete) records.
	 *
	 * @param records The list of records to be deleted. Note: that this DOES support mixed-type collections.
	 * @param allOrNone If true, throws exception if any of the records fail to be deleted and rolls back the entire transaction.
	 * @param enforceCRUD If true, enforces CRUD validation.
	 * @param enforceShr If true, enforces Sharing Rules.
	 * @return List<Database.DeleteResult> The save results of the save. The return value and behavior is exaclty the same as Database.delete(...);
	 * @throws Data.CRUDException if the user does not have DELETE access to the object(s).
	 * @throws DMLException if the user doesn't have access to the record.
	 */
	public static List<Database.DeleteResult> remove(List<SObject> records, Boolean allOrNone, Boolean enforceCRUD, Boolean enforceShr) {
		Database.DMLOptions dmo = new Database.DMLOptions();
		dmo.optAllOrNone		= allOrNone;
		return (List<Database.DeleteResult>)performDML(DataConstants.SecurityOperation.REMOVE, records, dmo, enforceCRUD, false, enforceShr, new Set<String>());
	}
	/**
	 * Helper method that wraps the provided recordId into a list
	 */
	public static List<Database.DeleteResult> remove(SObject record, Boolean allOrNone, Boolean enforceCRUD, Boolean enforceShr) {
		return remove(new List<SObject>{record}, allOrNone, enforceCRUD, enforceShr);
	}
	/**
	 * This method is the same as calling <code>Data.remove(records, true, true, true);</code>
	 */
	public static List<Database.DeleteResult> remove(List<SObject> records) {
		return remove(records, true, true, true);
	}
	/**
	 * Helper method that wraps the provided recordId into a list
	 */
	public static List<Database.DeleteResult> remove(SObject record) {
		return remove(new List<SObject>{record});
	}


	/**
	 * Unremove (Undelete) records.
	 *
	 * @param records The list of record IDs to be undeleted. Note: that this DOES support mixed-type collections.
	 * @param allOrNone If true, throws exception if any of the records fail to be undeleted and rolls back the entire transaction.
	 * @param enforceCRUD If true, enforces CRUD validation.
	 * @param enforceShr If true, enforces Sharing Rules.
	 * @return List<Database.UndeleteResult> The save results of the save. The return value and behavior is exaclty the same as Database.undelete(...);
	 * @throws Data.CRUDException if the user does not have UNDELETE access to the object(s).
	 * @throws DMLException if the user doesn't have access to the record.
	 */
	public static List<Database.UndeleteResult> unremove(List<Id> recordIDs, Boolean allOrNone, Boolean enforceCRUD, Boolean enforceShr) {
		if (enforceCRUD) {
			validateCRUDonIDs(recordIDs, DataConstants.SecurityOperation.REMOVE);
		}

		if (enforceShr) {
			return dmlWithShr.doUnremove(recordIDs, allOrNone);
		} else {
			return dmlWithoutShr.doUnremove(recordIds, allOrNone);
		}
	}
	/**
	 * Helper method that wraps the provided recordId into a list
	 */
	public static List<Database.UndeleteResult> unremove(Id recordID, Boolean allOrNone, Boolean enforceCRUD, Boolean enforceShr) {
		return unremove(new List<Id>{recordID}, allOrNone, enforceCRUD, enforceShr);
	}
	/**
	 * This method is the same as calling <code>Data.unremove(recordIDs, true, true, true);</code>.
	 */
	public static List<Database.UndeleteResult> unremove(List<Id> recordIDs) {
		return unremove(recordIDs, true, true, true);
	}
	/**
	 * Helper method that wraps the provided recordId into a list
	 */
	public static List<Database.UndeleteResult> unremove(Id recordID) {
		return unremove(new List<Id>{recordID});
	}
	/**
	 * Unremove (Undelete) records.
	 *
	 * @param records The list of records to be undeleted. Note: that this DOES support mixed-type collections.
	 * @param allOrNone If true, throws exception if any of the records fail to be undeleted and rolls back the entire transaction.
	 * @param enforceCRUD If true, enforces CRUD validation.
	 * @param enforceShr If true, enforces Sharing Rules.
	 * @return List<Database.UndeleteResult> The save results of the save. The return value and behavior is exaclty the same as Database.undelete(...);
	 * @throws Data.CRUDException if the user does not have UNDELETE access to the object(s).
	 * @throws DMLException if the user doesn't have access to the record.
	 */
	public static List<Database.UndeleteResult> unremove(List<SObject> records, Boolean allOrNone, Boolean enforceCRUD, Boolean enforceShr) {
		Database.DMLOptions dmo = new Database.DMLOptions();
		dmo.optAllOrNone		= allOrNone;
		return (List<Database.UndeleteResult>)performDML(DataConstants.SecurityOperation.UNREMOVE, records, dmo, enforceCRUD, false, enforceShr, new Set<String>());
	}
	/**
	 * Helper method that wraps the provided recordId into a list
	 */
	public static List<Database.UndeleteResult> unremove(SObject record, Boolean allOrNone, Boolean enforceCRUD, Boolean enforceShr) {
		return unremove(new List<SObject>{record}, allOrNone, enforceCRUD, enforceShr);
	}
	/**
	 * This method is the same as calling <code>Data.unremove(records, true, true, true);</code>.
	 */
	public static List<Database.UndeleteResult> unremove(List<SObject> records) {
		return unremove(records, true, true, true);
	}
	/**
	 * Helper method that wraps the provided recordId into a list
	 */
	public static List<Database.UndeleteResult> unremove(SObject record) {
		return unremove(new List<SObject>{record});
	}


	/**
	 * Gets a query locator for the records found for the specified SOQL query.
	 * <p>
	 * Example: <code>Data.locator('SELECT Id FROM Account WHERE Name = :acctName', new Map<String,Object>{'acctName', 'Acme Inc.'});</code>
	 *
	 * @param soqlQuery The SOQL Query to execute
	 * @param params A Map of the parameter names and values referenced in the SOQL query.
	 * @param enforceCRUD If true, enforces CRUD validation.
	 * @param enforceFLS If true, enforces FLS validation.
	 * @param enforceShr If true, enforces Sharing Rules, and limits returned records to only those that the user has access to.
	 * @return Database.QueryLocator A query locator for the found results.
	 * @throws Data.CRUDException if the user does not have READ access to the object(s).
	 * @throws Data.FLSException if the user does not have READ access to any field referenced in the provided records.
	 */
	public static Database.QueryLocator locator(String soqlQuery, Map<String,Object> params, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr) {
		Query qry = Query.parse(soqlQuery);
		qry.validateCRUDFLS(enforceCRUD, enforceFLS);

		if (enforceShr) {
			return dmlWithShr.doLocator(soqlQuery, params);
		} else {
			return dmlWithoutShr.doLocator(soqlQuery, params);
		}
	}
	/**
	 * This method is the same as calling <code>Data.locator(soqlQuery, params, true, true, true);</code>.
	 */
	public static Database.QueryLocator locator(String soqlQuery, Map<String,Object> params) {
		return locator(soqlQuery, params, true, true, true);
	}
	public static Database.QueryLocator locator(String soqlQuery) {
		return locator(soqlQuery, new Map<String,Object>());
	}

	/**
	 * Returns the records found for the specified SOQL query.
	 * <p>
	 * Example: <code>Data.read('SELECT Id FROM Account WHERE Name = :acctName', new Map<String,Object>{'acctName', 'Acme Inc.'});</code>
	 * <p>
	 * This method also may be used for aggregate queries.
	 * Current performance: 87ms total execution time, ~40ms CPU Time, 8kB heap for a semi-complex query (parent relationships, child relationships)
	 *
	 * @param soqlQuery The SOQL Query to execute
	 * @param params A Map of the parameter names and values referenced in the SOQL query.
	 * @param enforceCRUD If true, enforces CRUD validation.
	 * @param enforceFLS If true, enforces FLS validation.
	 * @param enforceShr If true, enforces Sharing Rules, and limits returned records to only those that the user has access to.
	 * @return List<SObject> The retrieved result set.
	 * @throws Data.CRUDException if the user does not have READ access to the object(s).
	 * @throws Data.FLSException if the user does not have READ access to any field referenced in the provided records.
	 */
	public static List<SObject> read(String soqlQuery, Map<String,Object> params, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr) {
		Query qry = Query.parse(soqlQuery);
		qry.validateCRUDFLS(enforceCRUD, enforceFLS);

		if (enforceShr) {
			return dmlWithShr.doRead(soqlQuery, params);
		} else {
			return dmlWithoutShr.doRead(soqlQuery, params);
		}
	}
	/**
	 * This method is the same as calling <code>Data.read(soqlQuery, params, true, true, true);</code>.
	 */
	public static List<SObject> read(String soqlQuery, Map<String,Object> params) {
		return read(soqlQuery, params, true, true, true);
	}

	public static List<SObject> read(String soqlQuery) {
		return read(soqlQuery, new Map<String,Object>());
	}
	public static Integer countQuery(String soqlQuery, Map<String,Object> params, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr) {
		Query qry = Query.parse(soqlQuery);
		qry.validateCRUDFLS(enforceCRUD, enforceFLS);

		if (enforceShr) {
			return dmlWithShr.doCountQuery(soqlQuery, params);
		} else {
			return dmlWithoutShr.doCountQuery(soqlQuery, params);
		}
	}
	public static Integer countQuery(String soqlQuery, Map<String,Object> params) {
		return countQuery(soqlQuery, params, true, true, true);
	}
	public static Integer countQuery(String soqlQuery) {
		return countQuery(soqlQuery, new Map<String, Object>());
	}

	public static List<List<SObject>> find(String sosl, Map<String,Object> params) {
		return find(sosl, params, true, true, true);
	}
	public static List<List<SObject>> find(String sosl, Map<String,Object> params, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr) {
		List<Find> finds = Find.parse(sosl);
		for (Find f : finds) {
			f.validateCRUDFLS(enforceCRUD, enforceFLS);
		}

		if (enforceShr) {
			return dmlWithShr.doFind(sosl, params);
		} else {
			return dmlWithoutShr.doFind(sosl, params);
		}
	}


	@TestVisible
	private static Object performDML(DataConstants.SecurityOperation op, List<SObject> records, Database.DMLOptions options, Boolean enforceCRUD, Boolean enforceFLS, Boolean enforceShr, Set<String> exceptions) {
		validateCRUDFLS(records, op, enforceCRUD, enforceFLS, exceptions);

		if (enforceShr) {
			if (op == DataConstants.SecurityOperation.CREATE)
				return dmlWithShr.doCreate(records, options);
			else if (op == DataConstants.SecurityOperation.MODIFY)
				return dmlWithShr.doModify(records, options);
			else if (op == DataConstants.SecurityOperation.REMOVE)
				return dmlWithShr.doRemove(records, options.optAllOrNone);
			else if (op == DataConstants.SecurityOperation.UNREMOVE)
				return dmlWithShr.doUnremove(records, options.optAllOrNone);
		} else {
			if (op == DataConstants.SecurityOperation.CREATE)
				return dmlWithoutShr.doCreate(records, options);
			else if (op == DataConstants.SecurityOperation.MODIFY)
				return dmlWithoutShr.doModify(records, options);
			else if (op == DataConstants.SecurityOperation.REMOVE)
				return dmlWithoutShr.doRemove(records, options.optAllOrNone);
			else if (op == DataConstants.SecurityOperation.UNREMOVE)
				return dmlWithoutShr.doUnremove(records, options.optAllOrNone);
		}
		return null;
	}



	/*****
	 *
	 * BEGIN INTERNALS/MAGIC-SAUSSE
	 *
	 *****/

	/**
	 *
	 * This method validates CRUD and FLS for DML operations.
	 *
	 */
	private static void validateCRUDFLS(List<SObject> data, DataConstants.SecurityOperation o, Boolean validateCRUD, Boolean validateFLS, Set<String> exceptions) {
		LimitsSnapshot ls = new LimitsSnapshot('validateCRUDFLS');

		if (DataConstants.ENABLED && (validateCRUD || validateFLS)) {
			try {
				Schema.SObjectType sot = data.getSObjectType(); // returns null on empty, mixed or generic types

				if (sot != null) {
					validateList(sot, data, o, validateCRUD, validateFLS, exceptions);
				} else if (data.size() >= 1) {
					// sot == null && data.size() >= 1 means that the collection has mixed SObjectTypes (or is generic),
					// Group the records by type, then process each group
					Map<Schema.SObjectType, List<SObject>> sotRecMap = new Map<Schema.SObjectType, List<SObject>>();
					for (SObject so : data) {
						Schema.SObjectType sotm = so.getSObjectType();
						if (!sotRecMap.containsKey(sotm)) {
							sotRecMap.put(sotm, new List<SObject>());
						}
						sotRecMap.get(sotm).add(so);
					}
					for (Schema.SObjectType sotm : sotRecMap.keySet()) {
						List<SObject> records = sotRecMap.get(sotm);
						validateList(sotm, records, o, validateCRUD, validateFLS, exceptions);
					}
				}
			} catch (Exception e) {
				throw e;
			} finally {
				ls.toLog();
			}
		}
	}

	/**
	 *
	 * This method validates CRUD and FLS for DML operations.
	 *
	 * In order to validate FLS on an object, you need to know what fields are on that object. The
	 * System.SObject class does not define any methods for obtaining the list of fields on an
	 * object instance that are set/retrieved. To work around this limitation, there are two
	 * established ways for finding the fields on an object.
	 *
	 * 1) Use JSON to serialize an SObject instance into a string, and then deserialize that JSON
	 *    string into a Map<String,Object>, where the fields can then be easily retrieved via
	 *	  keySet().
	 * 2) Don't attempt to find the fields on the object, but instead pre-build a list of fields
	 *    on the entire SObject definition that are restricted and then check to see if any of
	 *    those fields are present on the SObject record instance.
	 * 3) Hybrid. Do both #1 and #2 obtaining a list of fields on the SObject via JSON and then
	 *    compare that to the list of restricted fields on the SObject.
	 *
	 * Both methods have the same performance considerations:
	 * 1) They both use looping, which impacts CPUTime
	 * 2) They both use HEAP. #1 uses HEAP via JSON serialization. #2 Uses heap in a whole bunch
	 *    of DescribeFieldResult calls.
	 *
	 * Basic Performance Tests:
	 *  There's not a huge difference between the 3 options, but interestingly enough #3 is
	 *  the best performing, when you'd think it'd be the worst.
	 */
	private static void validateList(Schema.SObjectType sot, List<SObject> data, DataConstants.SecurityOperation o, Boolean validateCRUD, Boolean validateFLS, Set<String> exceptions) {
		DescribeCache dc = DescribeCache.getDescribeCache(sot);

		if (DataConstants.ENABLED && validateCRUD) {
			SecUtil.checkCRUD(o, dc);
		}

		if (DataConstants.ENABLED && validateFLS && o != DataConstants.SecurityOperation.REMOVE) {
			if (VALIDATE_METHOD == 1) {
				// This is method 1
				// ExecTime: 81ms, 53ms
				// CPUTime: 38ms, 42ms
				// Heap: 2255b, 1351b
				Set<String> fieldNames = getFieldsInSObjects(data);
				for (String fieldName : fieldNames) {
					// TAL -<< blame me, if exceptions has this field, don't enforce it.
					if (exceptions.contains(fieldName)) {
						continue;
					}
					SecUtil.checkFLS(o, dc, fieldName);
				}
			} else if (VALIDATE_METHOD == 2) {
				// This is method 2
				// ExecTime: 65ms, 10ms
				// CPUTime: 22ms, 4ms
				// Heap: 2400b, 993b
				Set<String> restrictedFieldNames = dc.getRestrictedFields(o);
				for (String fld : restrictedFieldNames) {
					for (SObject so : data) {
						try {
							if (so.get(fld) != null) {
								throw new SecUtil.FLSException(o, dc.objectName, fld);
							}
						} catch (System.SObjectException e) {
							//ignore, "SObject row was retrieved via SOQL without querying the requested field"
						}
					}
				}
			} else {
				// This is method 3
				// ExecTime: 52ms, 14ms
				// CPUTime: 8ms, 4ms
				// Heap: 2333b, 993b
				Set<String> restrictedFieldNames	= dc.getRestrictedFields(o);
				if (restrictedFieldNames != null && !restrictedFieldNames.isEmpty()) {
					for (SObject so : data) {
						Set<String> fieldNames				= getFieldsInSObject(so);

						Set<String> restrictedFieldNames2 = restrictedFieldNames.clone();
						restrictedFieldNames2.retainAll(fieldNames);
						if (restrictedFieldNames2.size() > 0) {
							throw new SecUtil.FLSException(o, dc.objectName, String.join(new List<String>(restrictedFieldNames2), ', '));
						}
					}
				}
			}
		}
	}

	private static void validateCRUDonIDs(List<Id> recordIds, DataConstants.SecurityOperation o) {
		if (DataConstants.ENABLED) {
			for (Id rId : recordIds) {
				DescribeCache dc = DescribeCache.getDescribeCache(rId.getSObjectType());
				SecUtil.checkCRUD(o, dc);
			}
		}
	}

	/* This method uses a dirty, dirty hack for obtaining all of the fields that are referenced in an SObject.
	 * Secret sauce here is to JSON serialize then deserialize the record into a Map where the key is the field.
	 * Salesforce will not serialize fields that aren't referenced by the record and will still serialize null fields.
	 *
	 * We have to do this because the Salesforce Engineer that designed the SObject interface did not
	 * anticipate the need to know what fields are referenced by an SObject instance, even though SObject is
	 * modeled very closely to Map<String,Object>. If at some point in the future SObject supports a keySet() or
	 * getFields() method, this should be refactored.
	 *
	 * The other option is to loop through all fields on the object and check to see if the record instance has a value
	 * for that field. However this will produce false negatives in that some fields could intentially be set to
	 * null on the SObject record.
	 */
	@TestVisible
	private static Set<String> getFieldsInSObjects(List<SObject> records) {
		Set<String> fieldNames = new Set<String>();
		for (SObject so : records) {
			fieldNames.addAll(getFieldsInSObject(so));
		}
		return fieldNames;
	}
	private static Set<String> getFieldsInSObject(SObject record) {
        	// @todo, update this line when Summer'16 is GA AND SFDC resolves error with parent references.
		Set<String> fieldNames = ((Map<String,Object>)JSON.deserializeUntyped(JSON.serialize(record))).keySet();//record.getPopulatedFieldsAsMap().keySet();
		fieldNames.remove('attributes');
		return fieldNames;
	}

	/**
	 * This class is responsible for performing the underlying Database operations
	 * after the appropriate CRUD/FLS checks. This access modifier for this class
	 * has been deliberately left blank as this class should not be used directly,
	 * but instead one should opt to use one of the two sub-classes that do specify
	 * an access modifier.
	 * <p>
	 * Of particular note in this class is the internal mechanisms utilized to support
	 * binding of "complex" variables, which is not natively supported by Salesforce's
	 * dyanmical SOQL.
	 *
	 *
	 * @see DBWithShare
	 * @see DBWithoutShare
	 */
	public abstract class DB {
		public abstract List<Database.SaveResult> doCreate(List<SObject> records, Database.DMLOptions options);
		public abstract List<Database.SaveResult> doModify(List<SObject> records, Database.DMLOptions options);
		public abstract List<Database.DeleteResult> doRemove(List<Id> recordIDs, Boolean allOrNone);
		public abstract List<Database.DeleteResult> doRemove(List<SObject> records, Boolean allOrNone);
		public abstract List<Database.UndeleteResult> doUnremove(List<Id> recordIDs, Boolean allOrNone);
		public abstract List<Database.UndeleteResult> doUnremove(List<SObject> records, Boolean allOrNone);
		public abstract List<SObject> doRead(String query, Map<String,Object> params);
		public abstract Database.QueryLocator doLocator(String query, Map<String,Object> params);
		public abstract Integer doCountQuery(String query, Map<String,Object> params);
		public abstract List<List<SObject>> doFind(String sosl, Map<String,Object> params);
	}


	/**
	 * DML Class that explicitly does not enforce sharing rules
	 * <p>
	 * This is used internally by Data.read, Data.locator and Data.countQuery methods
	 */
	public without sharing class DBWithoutShare extends DB {
		private Map<String,Object> params;
		private Map<String,String> pVals;
		public Object p0 {get { return params.get(pVals.get('p0'));} private set;}
		public Object p1 {get { return params.get(pVals.get('p1'));} private set;}
		public Object p2 {get { return params.get(pVals.get('p2'));} private set;}
		public Object p3 {get { return params.get(pVals.get('p3'));} private set;}
		public Object p4 {get { return params.get(pVals.get('p4'));} private set;}
		public Object p5 {get { return params.get(pVals.get('p5'));} private set;}
		public Object p6 {get { return params.get(pVals.get('p6'));} private set;}
		public Object p7 {get { return params.get(pVals.get('p7'));} private set;}
		public Object p8 {get { return params.get(pVals.get('p8'));} private set;}
		public Object p9 {get { return params.get(pVals.get('p9'));} private set;}

		public override List<Database.SaveResult> doCreate(List<SObject> records, Database.DMLOptions options) {
			return Database.insert(records, options);
		}
		public override List<Database.SaveResult> doModify(List<SObject> records, Database.DMLOptions options) {
			return Database.update(records, options);
		}
		public override List<Database.DeleteResult> doRemove(List<Id> recordIDs, Boolean allOrNone) {
			return Database.delete(recordIds, allOrNone);
		}
		public override List<Database.DeleteResult> doRemove(List<SObject> records, Boolean allOrNone) {
			return Database.delete(records, allOrNone);
		}
		public override List<Database.UndeleteResult> doUnremove(List<Id> recordIDs, Boolean allOrNone) {
			return Database.undelete(recordIds, allOrNone);
		}
		public override List<Database.UndeleteResult> doUnremove(List<SObject> records, Boolean allOrNone) {
			return Database.undelete(records, allOrNone);
		}
		public override List<SObject> doRead(String query, Map<String,Object> params) {
			return Database.query(setParams(query, params));
		}
		public override Database.QueryLocator doLocator(String query, Map<String,Object> params) {
			return Database.getQueryLocator(setParams(query, params));
		}
		public override Integer doCountQuery(String query, Map<String,Object> params) {
			return Database.countQuery(setParams(query, params));
		}
		public override List<List<SObject>> doFind(String sosl, Map<String,Object> params) {
			return Search.query(setSOSLParams(sosl, params));
		}
		/**
		 * This method is an ugly hack. Database.query() method only supports "simple bind variables".
		 * e.g. ":MyStringVar" works, ":myObject.Method()" and "myCollection[idx]" do not work.
		 *
		 * Since the user will be accessing this class by passing in a collection of bind variables,
		 * this method finds those bind variables and maps them to "simple" variables.
		 */
		@TestVisible
		private String setParams(String query, Map<String,Object> params) {
			System.debug(DataConstants.LOGGING_LEVEL, 'setParms: Original Query:: ' + query);
			this.params 		= params;
			this.pVals 			= new Map<String,String>();
			this.p0 			= null;
			this.p1 			= null;
			this.p2 			= null;
			this.p3 			= null;
			this.p4 			= null;
			this.p5 			= null;
			this.p6 			= null;
			this.p7 			= null;
			this.p8 			= null;
			this.p9 			= null;

			Set<String> capturedParms 	= new Set<String>();
			String qret = query;

			Integer i=0;
			Matcher m = Pattern.compile('(?i)(?:<|>|<=|>=|=|IN|LIKE|LIMIT)\\s{0,1}:\\s{0,1}(\\w+)\\s{0,1}').matcher(query);
			while (m.find()) {
				String parmName = m.group(1);
				String newParm	= 'p' + i;
				System.debug(DataConstants.LOGGING_LEVEL, parmName);

				if (!capturedParms.contains(parmName) && i<10) {
					i++;
					pVals.put(newParm, parmName);
					capturedParms.add(parmName);
					qret = qret.replaceAll(parmName, newParm);
				}
			}
			System.debug(DataConstants.LOGGING_LEVEL, 'setParms: Parsed Query:: ' + qret);
			return qret;
		}
		@TestVisible
		private String setSOSLParams(String sosl, Map<String,Object> params) {
			System.debug(DataConstants.LOGGING_LEVEL, 'setParms: Original Query:: ' + sosl);
			this.params 		= params;
			this.pVals 			= new Map<String,String>();
			this.p0 			= null;
			this.p1 			= null;
			this.p2 			= null;
			this.p3 			= null;
			this.p4 			= null;
			this.p5 			= null;
			this.p6 			= null;
			this.p7 			= null;
			this.p8 			= null;
			this.p9 			= null;

			Set<String> capturedParms 	= new Set<String>();
			String qret = sosl;

			Integer i=0;
			Matcher m = Pattern.compile('(?i):\\s{0,1}(\\w+)\\s{0,1}').matcher(sosl);
			while (m.find()) {
				String parmName = m.group(1);
				String newParm	= 'p' + i;
				System.debug(DataConstants.LOGGING_LEVEL, parmName);

				if (!capturedParms.contains(parmName) && i<10) {
					i++;
					pVals.put(newParm, parmName);
					capturedParms.add(parmName);
					qret = qret.replaceAll(parmName, newParm);
				}
			}
			System.debug(DataConstants.LOGGING_LEVEL, 'setParms: Parsed Query:: ' + qret);
			return qret;
		}
	}


	/**
	 * DML Class that explicitly enforces sharing rules
	 * <p>
	 * This is used internally by Data.read, Data.locator and Data.countQuery methods
	 */
	public with sharing class DBWithShare extends DB {
		private Map<String,Object> params;
		private Map<String,String> pVals;
		public Object p0 {get { return params.get(pVals.get('p0'));} private set;}
		public Object p1 {get { return params.get(pVals.get('p1'));} private set;}
		public Object p2 {get { return params.get(pVals.get('p2'));} private set;}
		public Object p3 {get { return params.get(pVals.get('p3'));} private set;}
		public Object p4 {get { return params.get(pVals.get('p4'));} private set;}
		public Object p5 {get { return params.get(pVals.get('p5'));} private set;}
		public Object p6 {get { return params.get(pVals.get('p6'));} private set;}
		public Object p7 {get { return params.get(pVals.get('p7'));} private set;}
		public Object p8 {get { return params.get(pVals.get('p8'));} private set;}
		public Object p9 {get { return params.get(pVals.get('p9'));} private set;}

		public override List<Database.SaveResult> doCreate(List<SObject> records, Database.DMLOptions options) {
			return Database.insert(records, options);
		}
		public override List<Database.SaveResult> doModify(List<SObject> records, Database.DMLOptions options) {
			return Database.update(records, options);
		}
		public override List<Database.DeleteResult> doRemove(List<Id> recordIDs, Boolean allOrNone) {
			return Database.delete(recordIds, allOrNone);
		}
		public override List<Database.DeleteResult> doRemove(List<SObject> records, Boolean allOrNone) {
			return Database.delete(records, allOrNone);
		}
		public override List<Database.UndeleteResult> doUnremove(List<Id> recordIDs, Boolean allOrNone) {
			return Database.undelete(recordIds, allOrNone);
		}
		public override List<Database.UndeleteResult> doUnremove(List<SObject> records, Boolean allOrNone) {
			return Database.undelete(records, allOrNone);
		}
		public override List<SObject> doRead(String query, Map<String,Object> params) {
			return Database.query(setParams(query, params));
		}
		public override Database.QueryLocator doLocator(String query, Map<String,Object> params) {
			return Database.getQueryLocator(setParams(query, params));
		}
		public override Integer doCountQuery(String query, Map<String,Object> params) {
			return Database.countQuery(setParams(query, params));
		}
		public override List<List<SObject>> doFind(String sosl, Map<String,Object> params) {
			return Search.query(setSOSLParams(sosl, params));
		}
		/**
		 * This method is an ugly hack. Database.query() method only supports "simple bind variables".
		 * e.g. ":MyStringVar" works, ":myObject.Method()" and "myCollection[idx]" do not work.
		 *
		 * Since the user will be accessing this class by passing in a collection of bind variables,
		 * this method finds those bind variables and maps them to "simple" variables.
		 */
		@TestVisible
		private String setParams(String query, Map<String,Object> params) {
			System.debug(DataConstants.LOGGING_LEVEL, 'setParms: Original Query:: ' + query);
			this.params 		= params;
			this.pVals 			= new Map<String,String>();
			this.p0 			= null;
			this.p1 			= null;
			this.p2 			= null;
			this.p3 			= null;
			this.p4 			= null;
			this.p5 			= null;
			this.p6 			= null;
			this.p7 			= null;
			this.p8 			= null;
			this.p9 			= null;

			Set<String> capturedParms 	= new Set<String>();
			String qret = query;

			Integer i=0;
			Matcher m = Pattern.compile('(?i)(?:<|>|<=|>=|=|IN|LIKE|LIMIT)\\s{0,1}:\\s{0,1}(\\w+)\\s{0,1}').matcher(query);
			while (m.find()) {
				String parmName = m.group(1);
				String newParm	= 'p' + i;
				System.debug(DataConstants.LOGGING_LEVEL, parmName);

				if (!capturedParms.contains(parmName) && i<10) {
					i++;
					pVals.put(newParm, parmName);
					capturedParms.add(parmName);
					qret = qret.replaceAll(parmName, newParm);
				}
			}
			System.debug(DataConstants.LOGGING_LEVEL, 'setParms: Parsed Query:: ' + qret);
			return qret;
		}
		@TestVisible
		private String setSOSLParams(String sosl, Map<String,Object> params) {
			System.debug(DataConstants.LOGGING_LEVEL, 'setParms: Original Query:: ' + sosl);
			this.params 		= params;
			this.pVals 			= new Map<String,String>();
			this.p0 			= null;
			this.p1 			= null;
			this.p2 			= null;
			this.p3 			= null;
			this.p4 			= null;
			this.p5 			= null;
			this.p6 			= null;
			this.p7 			= null;
			this.p8 			= null;
			this.p9 			= null;

			Set<String> capturedParms 	= new Set<String>();
			String qret = sosl;

			Integer i=0;
			Matcher m = Pattern.compile('(?i):\\s{0,1}(\\w+)\\s{0,1}').matcher(sosl);
			while (m.find()) {
				String parmName = m.group(1);
				String newParm	= 'p' + i;
				System.debug(DataConstants.LOGGING_LEVEL, parmName);

				if (!capturedParms.contains(parmName) && i<10) {
					i++;
					pVals.put(newParm, parmName);
					capturedParms.add(parmName);
					qret = qret.replaceAll(parmName, newParm);
				}
			}
			System.debug(DataConstants.LOGGING_LEVEL, 'setParms: Parsed Query:: ' + qret);
			return qret;
		}
	}
}