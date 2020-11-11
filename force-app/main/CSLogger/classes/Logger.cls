public with sharing class Logger {

    public Enum Level {ERROR, WARN, DEBUG, INFO}

    private static Logger LOGGER_INSTANCE = null;

    private Boolean allowMultiple = false;
    private LoggerSettings settings;
    private List<LogEvent__e> logEvents;

    /**
     * Private constructor that sets the allowing of multiple logs, and gets the settings
     * @param  inMultiple TRUE if we allow multiple logs in one instance, FALSE if we want to publish immediately
     */
    private Logger(Boolean inMultiple) {
        this.allowMultiple = inMultiple;
        this.logEvents = new List<LogEvent__e>();
        this.settings = new LoggerSettings();
    }

    /**
     * Public getter of an instance. Really used to get the same instance across multiple classes like triggers
     * @param  inMultiple TRUE if we allow multiple logs in one instance, FALSE if we want to publish immediately
     * @return            A Logger instance
     */
    public static Logger getInstance(Boolean inMultiple) {
        if (LOGGER_INSTANCE == null) {
            LOGGER_INSTANCE = new Logger(inMultiple);
        }
        return LOGGER_INSTANCE;
    }
    public static Logger getInstance() {
        return Logger.getInstance(false);
    }

    /**
     * Creates a Log Platform Event, if logging is enabled, that will then create a Log object outside of the current process
     * @param  className    Class Name (where this action happened)
     * @param  level        Level enum (ERROR, WARN, DEBUG, INFO)
     * @param  objectName   Object Name (if we are doing DML statemets)
     * @param  objectIdList List of Object IDs Affected
     * @param  message      Message
     * @param  stackTrace   Exception Stack Trace
     * @param  inJSON       JSON From API
     */
    public void log(String className, Level level, String objectName, List<Id> objectIdList, String message, String stackTrace, String inJSON) {
        if (settings.enableLogging) {
            String objectIds;
            if ((objectIdList != null) && (!objectIdList.isEmpty())) {
                objectIds = String.join(objectIdList, ',');
            }

            LogEvent__e le = new LogEvent__e(
                ClassName__c = className,
                Level__c = level.name(),
                ObjectName__c = objectName,
                ObjectIDs__c = objectIds,
                Message__c = message,
                StackTrace__c = stackTrace,
                JSON__c = inJSON
            );

            if (this.allowMultiple) {
                logEvents.add(le);
            } else {
                EventBus.publish(le);
            }
        }
    }

    /**
     * Called at the end of an execution context to bulkify the publishing of log events in the case of allowMultiple = TRUE
     */
    public void finalize() {
        if (this.allowMultiple) {
            if (!logEvents.isEmpty()) {
                EventBus.publish(logEvents);
            }
        }
    }

    // Overrides
    public void log(String className, String message) {
        log(className, Level.ERROR, null, null, message, null, null);
    }
    public void log(String className, Level level, String message) {
        log(className, level, null, null, message, null, null);
    }
    public void log(String className, String message, String inJSON) {
        log(className, Level.ERROR, null, null, message, null, inJSON);
    }
    public void log(String className, Level level, String message, String inJSON) {
        log(className, level, null, null, message, null, inJSON);
    }
    public void log(String className, String objectName, List<Id> objectIdList, String message) {
        log(className, Level.ERROR, objectName, objectIdList, message, null, null);
    }
    public void log(String className, String objectName, Set<Id> objectIdSet, String message) {
        List<Id> objectIdList;
        if (objectIdSet != null) {
            objectIdList = new List<Id>(objectIdSet);
        }
        log(className, Level.ERROR, objectName, objectIdList, message, null, null);
    }
    public void log(String className, Level level, String objectName, List<Id> objectIdList, String message) {
        log(className, level, objectName, objectIdList, message, null, null);
    }
    public void log(String className, Level level, String objectName, Set<Id> objectIdSet, String message) {
        List<Id> objectIdList;
        if (objectIdSet != null) {
            objectIdList = new List<Id>(objectIdSet);
        }
        log(className, level, objectName, objectIdList, message, null, null);
    }

    // Exception handling
    public void log(String className, Exception e) {
        log(className, Level.ERROR, null, null, e.getMessage(), e.getStackTraceString(), null);
    }
    public void log(String className, Exception e, String inJSON) {
        log(className, Level.ERROR, null, null, e.getMessage(), e.getStackTraceString(), inJSON);
    }
    public void log(String className, String objectName, Exception e) {
        log(className, Level.ERROR, objectName, null, e.getMessage(), e.getStackTraceString(), null);
    }
    public void log(String className, String objectName, Exception e, String inJSON) {
        log(className, Level.ERROR, objectName, null, e.getMessage(), e.getStackTraceString(), inJSON);
    }

    // DML Error Handling
    public Boolean log(String className, String objectName, List<Database.SaveResult> results) {
        Boolean result = true;
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                String errorMsg = '';
                for (Database.Error err : sr.getErrors()) {
                    errorMsg += err.getMessage() + '\n';
                }
                log(className, Level.ERROR, objectName, null, errorMsg, null, null);
                result = false;
            }
        }
        return result;
    }
    public Boolean log(String className, String objectName, List<Database.UpsertResult> results) {
        Boolean result = true;
        for (Database.UpsertResult sr : results) {
            if (!sr.isSuccess()) {
                String errorMsg = '';
                for (Database.Error err : sr.getErrors()) {
                    errorMsg += err.getMessage() + '\n';
                }
                log(className, Level.ERROR, objectName, null, errorMsg, null, null);
                result = false;
            }
        }
        return result;
    }

    /**
     * Check the custom metadata type if pruning is enabled to prevent org limits
     */
    public void pruneLogs() {
        Log__c firstLogToPrune;

        // If it's off, end here
        if (!settings.enablePruning) {
            return;
        }

        Integer logCount = [SELECT COUNT() FROM Log__c];
        // If it's less than the max, end here
        if (logCount < settings.maxLogs) {
            return;
        }

        // Get the CreatedDate of the first log to prune
        try {
            firstLogToPrune = [SELECT CreatedDate FROM Log__c ORDER BY CreatedDate DESC LIMIT 1 OFFSET :settings.maxLogs];
        } catch (Exception e) {
            // If this throws an exception, then there's a mismatch or some other race condition. Just exit and it'll correct
            // itself on the next run.
            return;
        }

        // Seed the Queueable and queue it up
        LogPruneQueueable lpq = new LogPruneQueueable(firstLogToPrune.CreatedDate);
        System.enqueueJob(lpq);
    }

    /**
     * Check the custom metadata type for the interfaced classes and call them in order
     * @param  logEvents Trigger.new from the Log Event trigger
     */
    public void write(List<LogEvent__e> logEvents) {
        if (logEvents.size() > 0) {
            List<String> values = settings.classOrder.split(',');

            for (String v: values) {
                try {
                    ILogWriter customType = (ILogWriter)Type.forName(v).newInstance();
                    customType.write(logEvents);
                } catch (Exception e) {
                    System.debug(e.getMessage());
                }
            }
        }
    }

    /**
     * Modify the constructor of this class if you wish to use something other than a Custom Metadata Type
     * to store these settings
     */
    public class LoggerSettings {
        public Boolean enableLogging;
        public Boolean enablePruning;
        public String classOrder;
        public Integer maxLogs;

        public LoggerSettings() {
            // If we are in a Unit Test, we want to fake the settings. Custom Metadata runs with SeeAllData=true
            if (Test.isRunningTest()) {
                this.enableLogging = true;
                this.enablePruning = true;
                this.classOrder = 'LogToObject';
                this.maxLogs = 10;
            } else {
                Log_Settings__mdt lsSettings = [SELECT Enable_Logging__c, Enable_Pruning__c, Interfaced_Class_Order__c, Max_Number_Of_Logs__c FROM Log_Settings__mdt WHERE DeveloperName = 'Log_Settings'];
                this.enableLogging = lsSettings.Enable_Logging__c;
                this.enablePruning = lsSettings.Enable_Pruning__c;
                this.classOrder = lsSettings.Interfaced_Class_Order__c;
                this.maxLogs = Integer.valueOf(lsSettings.Max_Number_Of_Logs__c);
            }
        }

    }

}
