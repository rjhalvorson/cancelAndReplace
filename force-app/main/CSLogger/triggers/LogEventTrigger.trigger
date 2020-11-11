trigger LogEventTrigger on LogEvent__e (after insert) {
	Logger logInstance = Logger.getInstance();
	logInstance.write(Trigger.new);
}