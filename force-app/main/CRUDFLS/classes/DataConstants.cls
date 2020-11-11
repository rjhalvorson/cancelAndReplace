public with sharing class DataConstants {
	/*
		projects may wish to declaratively enable/disable CRUD/FLS/SHR checks
		via a protected custom setting. Update the line below to point to the
		PCS.
		
		Example:

		ENABLED = CustomSetting__c.getOrgDefaults().CRUDFLS_Enabled__c;
	 */
	public static Boolean ENABLED = true;
	public static System.LoggingLevel LOGGING_LEVEL = LoggingLevel.DEBUG;

	public enum SecurityOperation {READ,CREATE,MODIFY,REMOVE,UNREMOVE}

}