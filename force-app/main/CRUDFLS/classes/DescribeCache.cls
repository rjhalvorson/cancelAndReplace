// @todo: namespace testing. If this code is namespaced, how does it work when un-namespaced names are passed in?
public with sharing class DescribeCache {
	private static final Map<Schema.SObjectType,DescribeCache> CACHE 	= new Map<Schema.SObjectType,DescribeCache>();

	private Map<String,Schema.SObjectField> objectFieldTokens			= new Map<String,Schema.SObjectField>();
	private Map<String,Schema.DescribeFieldResult> objectFieldDescribes	= new Map<String,Schema.DescribeFieldResult>();
	private Map<String,SObjectType> objectChildren						= new Map<String,Schema.SObjectType>();
	private Map<DataConstants.SecurityOperation,Set<String>> restrictedFields 		= new Map<DataConstants.SecurityOperation,Set<String>>();
	private Map<String,Schema.RecordTypeInfo> recordTypes;
	
	private String currentNamespace 									= DescribeCache.class.getName().substringBefore('DescribeCache').removeEnd('.');

	public Schema.SObjectType objectToken 								{get; private set;}
	public Schema.DescribeSObjectResult objectDescribe 					{get; private set;}
	public String objectName											{
		get {
			if (objectName == null)
				objectName = String.valueOf(this.objectToken);
			return objectName;
		}
		private set;
	}
	
	private DescribeCache(Schema.SObjectType sot) {
		this.objectToken		= sot;
		this.objectDescribe		= sot.getDescribe();
	}

	public Schema.SObjectField getFieldToken(String fieldName) {
		Schema.SObjectField token = this.objectFieldTokens.get(fieldName);

		if (token == null) {
			token 		= this.objectDescribe.fields.getMap().get(fieldName); // Let's not cache every field token = large heap!

			// If the token wasn't found and there is a current namespace, then perhaps this field was not namespaced by the developer
			// Add it here and try to query for it
			if ((token == null) && (!String.isBlank(currentNamespace))) {
				String newName = currentNamespace + '__' + fieldName;
				token = this.objectDescribe.fields.getMap().get(newName);
			}

			// If the token wasn't found, it could be because fieldName is a parent reference.
			// i.e. Parent__r instead of the foreign key Parent__c
			if (token == null) {
				fieldName	= fieldName.replace('__r','__c'); // 58% faster than String.endsWithIgnorCase + String.removeEnd
				token		= this.objectDescribe.fields.getMap().get(fieldName);

				// If the token STILL wasn't found, it could be namespaced. This would handle a namespaced __r.
				if ((token == null) && (!String.isBlank(currentNamespace))) {
					String newName = currentNamespace + '__' + fieldName;
					token = this.objectDescribe.fields.getMap().get(newName);
				}

				// If the token still wasn't found, it could be a standard field reference.
				// i.e. Account instead of AccountId
				if (token == null) {
					fieldName	= fieldName + 'Id';
					token		= this.objectDescribe.fields.getMap().get(fieldName);
				}
			}

			this.objectFieldTokens.put(fieldName, token); // Cache the relationship name
		}

		return token;
	}

	public Schema.DescribeFieldResult getFieldDescribe(String fieldName) {
		if (!this.objectFieldDescribes.containsKey(fieldName)) {
			Schema.SObjectField token = getFieldToken(fieldName);
			if (token != null) {
				this.objectFieldDescribes.put(fieldName, token.getDescribe());
			}
		}
		return this.objectFieldDescribes.get(fieldName);
	}

	public SObjectType getChildSObject(String fieldName) {
		System.debug(DataConstants.LOGGING_LEVEL, 'Looking for child relationship "' + fieldName + '".');
		if (!this.objectChildren.containsKey(fieldName)) {
			for (Schema.ChildRelationship cr : this.objectDescribe.getChildRelationships()) {
				if (cr.getRelationshipName() == null)
					continue;
				this.objectChildren.put(cr.getRelationshipName(), cr.getChildSObject());
			}
		}

		SObjectType sot = this.objectChildren.get(fieldName);
		if (sot == null)
			sot = this.objectChildren.get(currentNamespace + '__' + fieldName);
		if (sot == null)
			sot = this.objectChildren.get(currentNamespace.toUpperCase() + '__' + fieldName);
		if (sot == null)
			sot = this.objectChildren.get(currentNamespace.toLowerCase() + '__' + fieldName);

		return sot;
	}

	public Set<String> getRestrictedFields(DataConstants.SecurityOperation o) {
		if (!this.restrictedFields.containsKey(o)) {
			// Hasn't been called yet.
			Set<String> readRestricted		= new Set<String>();
			Set<String> createRestricted	= new Set<String>();
			Set<String> modifyRestricted	= new Set<String>();

			for (Schema.SObjectField sof : this.objectDescribe.fields.getMap().values()) {
				Schema.DescribeFieldResult dfr = sof.getDescribe();
				if (dfr.isPermissionable()) {
					if (!dfr.isAccessible())
						readRestricted.add(dfr.getName());
					if (!dfr.isCreateable() && !dfr.isCalculated())
						createRestricted.add(dfr.getName());
					if (!dfr.isUpdateable() && !dfr.isCalculated())
						modifyRestricted.add(dfr.getName());
				}
			}

			this.restrictedFields.put(DataConstants.SecurityOperation.READ, readRestricted);
			this.restrictedFields.put(DataConstants.SecurityOperation.CREATE, createRestricted);
			this.restrictedFields.put(DataConstants.SecurityOperation.MODIFY, modifyRestricted);
		}
		return this.restrictedFields.get(o);
	}

	public Id getRecordTypeId(String recordTypeName) {
		if (recordTypeName != null && recordTypeName != '') {
			if (this.recordTypes == null) {
				this.recordTypes = this.objectDescribe.getRecordTypeInfosByName();
			}
			Schema.RecordTypeInfo recTypeInfo = this.recordTypes.get(recordTypeName);
			if (recTypeInfo != null)
				return recTypeInfo.getRecordTypeId();
		}

		throw new RecordTypeNotFoundException('RecordType \'' + recordTypeName + '\' was not found for SObjectType \'' + objectName + '\'.');
	}

	public List<SelectOption> getPicklistOptions(String fieldName) {
		List<SelectOption> options = new List<SelectOption>();

		Schema.DescribeFieldResult fieldResult = getFieldDescribe(fieldName);
		for(Schema.PicklistEntry f : fieldResult.getPicklistValues()) {
			options.add(new SelectOption(f.getValue(), f.getLabel()));
		}

		return options;
	}



	public static DescribeCache getDescribeCache(String objectName) {
		Schema.SObjectType sot;
		
		//Certain objects such as Network and Location can fail as they resolve to System.Location and System.Network rather than Schema.Location and Schema.Location
		//It's recommended to return: if (objectName == 'Location'){ sot = Schema.Location.getSObjectType(); }
		//However we do not include this in the default implementation of this library due to how that adds a dependency on Communities and Field Service Lightning
		//Runtime error if Location is passed due to System namespace: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_class_system_Location.htm
		//Runtime error if Network is passed due to System namespace: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_network.htm#apex_classes_network
		Type candidateObjectType = Type.forName(objectName);

		if (SObject.class.isAssignableFrom(candidateObjectType)) {
			sot = ((SObject) Type.forName(objectName).newInstance()).getSobjectType(); // this is faster than describeSObject/globalDescribe
		}
		return getDescribeCache(sot);
	}

	public static DescribeCache getDescribeCache(Schema.SObjectType objectType) {
		if (objectType != null && !CACHE.containsKey(objectType)) {
			CACHE.put(objectType, new DescribeCache(objectType));
		}
		return CACHE.get(objectType);
	}


	public class RecordTypeNotFoundException extends Exception {}
}