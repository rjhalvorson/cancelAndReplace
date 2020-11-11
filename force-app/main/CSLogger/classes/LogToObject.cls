public with sharing class LogToObject implements ILogWriter {
    public LogToObject() {

    }

    /**
     * Write to the actual Log object from a Platform Event trigger
     * @param  logEvents Trigger.new from the Log Event trigger
     */
    public void write(List<LogEvent__e> logEvents) {
        List<Log__c> logs = new List<Log__c>();

        for (LogEvent__e le : logEvents) {
            logs.add(
                new Log__c(
                    ClassName__c = le.ClassName__c,
                    Level__c = le.Level__c,
                    ObjectName__c = le.ObjectName__c,
                    ObjectIDs__c = le.ObjectIDs__c,
                    Message__c = le.Message__c,
                    StackTrace__c = le.StackTrace__c,
                    JSON__c = le.JSON__c,
                    User__c = le.CreatedById
                )
            );
        }

        if (!logs.isEmpty()) {
            // We don't give users access to create log entries manually, so ignore CRUD/FLS here
            // Data.create(logs, false, false, false);
            insert logs;
        }
    }
}
