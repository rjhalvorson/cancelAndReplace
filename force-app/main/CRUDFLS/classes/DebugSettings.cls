public with sharing class DebugSettings {
	public Boolean isLimitsSnapshotEnabled;
	
    public DebugSettings () {
    	DebugSettings__c settings = DebugSettings__c.getInstance();
    	
    	isLimitsSnapshotEnabled = (settings.EnableLimitsSnapshot__c == null) ? false : settings.EnableLimitsSnapshot__c;
    }
}