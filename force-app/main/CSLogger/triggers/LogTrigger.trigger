trigger LogTrigger on Log__c (after insert) {
	Logger logInstance = Logger.getInstance();
	logInstance.pruneLogs();
}