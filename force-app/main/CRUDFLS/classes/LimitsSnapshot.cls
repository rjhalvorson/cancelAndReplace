/**
 * A helper class for profiling consumption of Apex Governor Limits throughout
 * Apex code.
 * <p>
 * Typically this class is used during development to profile limit consumption
 * of sections of code. Normally, this information is sent to the debug log with
 * a default <code>LoggingLevel</code> of <code>DEBUG</code> but can also have
 * any logging level, or optionally be saved to the Salesforce database in a
 * custom object called "LimitsSnapshot__c".
 * <p>
 * !!It should be clearly understood that this class does *not* capture total 
 * consumption thus far for the entire transaction, but rather only the consumption
 * of limits between the instantiation of this class and the point at which the
 * instance is told to stop monitoring consumption (typically through the invocation
 * of toLog()).
 * <p>
 * This class captures consumption of all Apex governor limits within a single
 * transaction and therefor cannot capture platform-wide limits (async calls,
 * emails, etc). Additionally, this class captures total execution time, something
 * standard profiling does not do.
 * <p>
 * Example usage:<br>
 * <code>
 * LimitsSnapshot ls = new LimitsSnapshot('[Name of this capture profile]');<br/>
 * // do work to be profiled here... <br/>
 * ls.toLog(LoggingLevel.INFO);<br/>
 * </code>
 * <p>
 * Results in the following output on the trace log:<br/>
 * <code>
 * 16:20:40.723 (723250043)|USER_DEBUG|[93]|INFO|** CONSUMED LIMITS :: [Name of this capture profile] **<br/>
 * Execution Time: 2<br/>
 * CpuTime: 0<br/>
 * HeapSize: 100<br/>
 * Queries: 0<br/>
 * QueryRows: 0<br/>
 * QueryLocatorRows: 0<br/>
 * AggregateQueries: 0<br/>
 * DMLStatements: 0<br/>
 * DMLRows: 0<br/>
 * FutureCalls: 0<br/>
 * Callouts: 0<br/>
 * EmailInvocations: 0<br/>
 * MobilePushApexCalls: 0<br/>
 * </code>
 * <p>
 * Additionally, this class provides methods for obtaining and calculating the total consumption
 * of any given limit both during capture and after capture, enabling an Apex class
 * to programmatically behave on that information. For example, an apex class may
 * wish to dynamically decide whether to perform an additional webservice callout
 * if the total consumed limit is already 10.
 * 
 * 
 * @see AccountSelectorTest
 * @author Eddie Blazer, CodeScience
 * @date January 7th, 2015
 */
public with sharing class LimitsSnapshot {
	private final Map<LimitEnum,Integer> startLimits	= new Map<LimitEnum,Integer>();
	private final Map<LimitEnum,Integer> endLimits		= new Map<LimitEnum,Integer>();
	private String identifier;
	private Long startMillis; // Not the same as CpuTime, this is "execution time"
	private Long endMillis; // Not the same as CpuTime, this is "execution time"
	private Boolean isThisEnabled;

	
	/**
	 * Constructs a new instance of LimitsSnapshot using the provided identifier
	 * which will be used when writing to the trace log. Construction automatically
	 * captures consumption of all limits for comparison to the end capture.
	 * Construction also captures the timestamp of Construction for the purpose of
	 * measuring the total transaction time.
	 */
	public LimitsSnapshot(String identifier) {
		isThisEnabled = new DebugSettings().isLimitsSnapshotEnabled;
		if (!isThisEnabled) {
			return;
		}
		this.identifier		= identifier;
		this.startMillis	= System.currentTimeMillis();
		takeSnapshot(this.startLimits);
	}
	/**
	 * This constructor is the same as calling <code>LimitsSnapshot(null);</code>.
	 */
	public LimitsSnapshot() {
		this(null);
	}

	/**
	 * Instructs the LimitsSnapshot instance to stop capturing limits and compute
	 * total consumption from the time the instance was constructed. This method
	 * is automatically called by toLog() and toDatabase()
	 */
	public void takeEndSnapshot() {
		if (!isThisEnabled) {
			return;
		}
		
		if (this.endMillis == null)
			this.endMillis	= System.currentTimeMillis();
		takeSnapshot(this.endLimits);
	}

	/**
	 * Gets the consumption of the specified limit. This method effectively returns
	 * the delta between getLimitEnd(le) and getLimitStart(le).
	 *
	 * @param le The Limit to calculate consumption for.
	 * @return Integer The total consumption of the specified limit as measured during tracking. If tracking has not been ended, this method returns -1.
	 */
	public Integer getLimitConsumed(LimitEnum le) {
		Integer startLimit  = this.startLimits.get(le);
		Integer endLimit    = this.endLimits.get(le);
		Integer consumed    = endLimit == null ? -1 : endLimit - startLimit;

		return consumed;
	}

	/**
	 * Get the total consumption up-to the point of instantiation of this instance.
	 *
	 * @param le The Limit to calculate consumption for.
	 * @return Integer The total consumption up-to the point of instantiation of this instance.
	 */
	public Integer getLimitStart(LimitEnum le) {
		return this.startLimits.get(le);
	}

	/**
	 * Get the total consumption up-to the point of when tracking was stopped.
	 *
	 * @param le The Limit to calculate consumption for.
	 * @return Integer The total consumption up-to the point of when tracking was stopped.
	 */
	public Integer getLimitEnd(LimitEnum le) {
		return this.endLimits.get(le);
	}

	/**
	 * Stop measuring consumption, calculate total consumption and log consumption
	 * of all Limits to Trace Log at the specified LoggingLevel.
	 *
	 * @param level The LoggingLevel to use for the trace log. Default is LoggingLevel.DEBUG
	 */
	public void toLog(LoggingLevel level) {
		if (!isThisEnabled) {
			return;
		}
		
		takeEndSnapshot();

		if (level == null)
			level = LoggingLevel.DEBUG;

		String message;

		if (identifier == null)
			message = '** CONSUMED LIMITS **';
		else
			message = '** CONSUMED LIMITS :: ' + identifier + ' **';

		message += '\nExecution Time: ' + (endMillis - startMillis).format();

		List<LimitEnum> limitKeys = LimitEnum.values();
		for (LimitEnum limitKey : limitKeys) {
			Integer consumed    = getLimitConsumed(limitKey);

			message += '\n' + limitKey.name() + ': ' + consumed.format();
		}

		System.debug(level, message);
	}
	/**
	 * This method is the same as executing <code>toLog(LoggingLevel.DEBUG);</code>.
	 */
	public void toLog() {
		toLog(LoggingLevel.DEBUG);
	}

	/**
	 * Stop measuring consumption, calculate total consumption and log consumption
	 * of all Limits to the Salesforce database on the "LimitsSnapshot__c" object,
	 * IF THE OBJECT EXISTS.
	 *
	 * @param level The LoggingLevel to use for the trace log. Default is LoggingLevel.DEBUG
	 */
	public void toDatabase() {
		if (!isThisEnabled) {
			return;
		}
		
		takeEndSnapshot();

		Type logObject	= Type.forName('LimitsSnapshot__c');
		if (logObject != null) {
			SObject so = (SObject)logObject.newInstance();
			so.put('Identifier__c', this.identifier);

			Long totalTime = (endMillis - startMillis);
			so.put('ExecutionTime__c', totalTime.intValue());
			List<LimitEnum> limitKeys = LimitEnum.values();
			for (LimitEnum limitKey : limitKeys) {
				Integer consumed    = getLimitConsumed(limitKey);

				so.put(limitKey + '__c', consumed);
			}

			insert so;
		}
	}

	private void takeSnapshot(Map<LimitEnum,Integer> snapshot) {
		if (!isThisEnabled) {
			return;
		}
		
		if (snapshot.size() == 0) {
			snapshot.put(LimitEnum.CpuTime,				Limits.getCpuTime());
			snapshot.put(LimitEnum.HeapSize,			Limits.getHeapSize());
			snapshot.put(LimitEnum.Queries,				Limits.getQueries());
			snapshot.put(LimitEnum.QueryRows,			Limits.getQueryRows());
			snapshot.put(LimitEnum.QueryLocatorRows,	Limits.getQueryLocatorRows());
			snapshot.put(LimitEnum.AggregateQueries,	Limits.getAggregateQueries());
			snapshot.put(LimitEnum.DMLStatements,		Limits.getDMLStatements());
			snapshot.put(LimitEnum.DMLRows,				Limits.getDMLRows());
			snapshot.put(LimitEnum.AsyncCalls,			Limits.getAsyncCalls());
			snapshot.put(LimitEnum.Callouts,			Limits.getCallouts());
			snapshot.put(LimitEnum.EmailInvocations,	Limits.getEmailInvocations());
			snapshot.put(LimitEnum.MobilePushApexCalls,	Limits.getMobilePushApexCalls());
		}
	}

	/**
	 * All of the Apex Limits that are tracked.
	 */
	public enum LimitEnum {
		CpuTime,
		HeapSize,
		Queries,
		QueryRows,
		QueryLocatorRows,
		AggregateQueries,
		DMLStatements,
		DMLRows,
		AsyncCalls,
		Callouts,
		EmailInvocations,
		MobilePushApexCalls
	}
}
