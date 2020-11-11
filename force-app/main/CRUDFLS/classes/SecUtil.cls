public with sharing class SecUtil {
	public static final Set<String> SYSTEM_FIELDS	= new Set<String>{
		'Id','CreatedById','CreatedDate','LastModifiedById','LastModifiedDate','SystemModStamp','CurrencyIsoCode'
	}; // Might need to make this object-specific
	public static Boolean CHECK_CRUD	= true;
	public static Boolean CHECK_FLS		= true;

	public static DataConstants CONSTANTS;

	public static void checkCRUD(DataConstants.SecurityOperation op, Schema.DescribeSObjectResult dsor) {
		if (CHECK_CRUD && 
			(
				(op == DataConstants.SecurityOperation.READ && !dsor.isAccessible()) ||
				(op == DataConstants.SecurityOperation.CREATE && !dsor.isCreateable()) ||
				(op == DataConstants.SecurityOperation.MODIFY && !dsor.isUpdateable()) ||
				(op == DataConstants.SecurityOperation.REMOVE && !dsor.isDeletable()) ||
				(op == DataConstants.SecurityOperation.UNREMOVE && !dsor.isUndeletable())
			)
		) {
			throw new CRUDException(op, dsor.getName());
		}
	}
	public static void checkCRUD(DataConstants.SecurityOperation o, String objName) {
		DescribeCache dc = DescribeCache.getDescribeCache(objName);
		checkCRUD(o, dc);
	}
	public static void checkCRUD(DataConstants.SecurityOperation o, Schema.SObjectType sot) {
		DescribeCache dc = DescribeCache.getDescribeCache(sot);
		checkCRUD(o, dc);
	}
	public static void checkCRUD(DataConstants.SecurityOperation o, DescribeCache dc) {
		checkCRUD(o, dc.objectDescribe);
	}

	public static void checkFLS(DataConstants.SecurityOperation op, Schema.DescribeSObjectResult dsor, Schema.DescribeFieldResult dfr) {
		System.debug(DataConstants.LOGGING_LEVEL, 'checkFLS:: SecurityOperation = ' + op);
		System.debug(DataConstants.LOGGING_LEVEL, 'checkFLS:: DescribeSObjectResult' + dsor);
		System.debug(DataConstants.LOGGING_LEVEL, 'checkFLS:: DescribeFieldResult = ' +  dfr);
		if (CHECK_FLS && dfr.isPermissionable()) {
			if (op == DataConstants.SecurityOperation.READ) {
				if (!dfr.isAccessible()) {
					throw new FLSException(op, dsor.getName(), dfr.getName());
				}
			} else if (op == DataConstants.SecurityOperation.CREATE) {
				if (!dfr.isCreateable() && !dfr.isCalculated()) {
					throw new FLSException(op, dsor.getName(), dfr.getName());
				}
			} else if (op == DataConstants.SecurityOperation.MODIFY) {
				/*if (SYSTEM_FIELDS.contains(dfr.getName())) {
					return; // No sense checking permissions on system-controlled fields like Id, Name, etc
				} else*/
				if (!dfr.isUpdateable() && !dfr.isCalculated()) {
					throw new FLSException(op, dsor.getName(), dfr.getName());
				}
			} else if (op == DataConstants.SecurityOperation.REMOVE || op == DataConstants.SecurityOperation.UNREMOVE) {
				return ; // No sense validating FLS when deleting a record, which is why DescribeFieldResult has no method for checking field deleteability.
			}
		}
	}
	public static void checkFLS(DataConstants.SecurityOperation op, String objName, String fieldName) {
		DescribeCache dc = DescribeCache.getDescribeCache(objName);
		checkFLS(op, dc, fieldName);
	}
	public static void checkFLS(DataConstants.SecurityOperation op, Schema.SObjectType sot, String fieldName) {
		DescribeCache dc = DescribeCache.getDescribeCache(sot);
		checkFLS(op, dc, fieldName);
	}
	public static void checkFLS(DataConstants.SecurityOperation op, DescribeCache dc, String fieldName) {
		DescribeFieldResult dfr = dc.getFieldDescribe(fieldName);
		checkFLS(op, dc.objectDescribe, dfr);
	}


	public virtual class SecurityException extends Exception {
		public final DataConstants.SecurityOperation o;
		public final String message;
		public final String obj;
		public final String field;

		public SecurityException (DataConstants.SecurityOperation o, String messageUnformatted, String obj, String field) {
			this.o			= o;
			this.message	= messageUnformatted;
			this.obj 	= obj;
			this.field 		= field;

			String opFormatted	= o.name().toLowerCase().capitalize(); // "READ" becomes "Read"
			String message = String.format(messageUnformatted, new List<String>{opFormatted,obj,field});
			this.setMessage(message);
		}
	}

	/** An object representing exceptions specfic to CRUD access */
	public class CRUDException extends SecurityException {
		public CRUDException(DataConstants.SecurityOperation o, String obj) {
			super(o, System.Label.DAE_ObjectNotAccessible, obj, null);
		}
	}

	/** An object representing exceptions specfic to FLS access */
	public class FLSException extends SecurityException {
		public FLSException(DataConstants.SecurityOperation o, String obj, String field) {
			super(o, System.Label.DAE_FieldNotAccessible, obj, field);
		}
	}

}