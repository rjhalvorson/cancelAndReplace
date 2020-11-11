@isTest
private class DescribeCacheTest {
	@isTest
	static void getRestrictedFields() {
		System.runAs(UserTest.createStandardUser()) {
			DescribeCache dc = DescribeCache.getDescribeCache('Lead');

			Set<String> flds = dc.getRestrictedFields(DataConstants.SecurityOperation.CREATE);

			System.assertNotEquals(null, flds);
		}
	}
    
	@isTest
	static void getFieldTokenNamespace() {
		System.runAs(UserTest.createStandardUser()) {
			DescribeCache dc = DescribeCache.getDescribeCache('Lead');

			Schema.SObjectField sof = dc.getFieldToken('NS__AggregateQueries__c');

			System.assert(true);
		}
	}
	
	@isTest
	static void getRecordTypeId() {
		System.runAs(UserTest.createStandardUser()) {
			DescribeCache dc = DescribeCache.getDescribeCache('Lead');

			try {
				dc.getRecordTypeId('Test');
				System.assert(false);
			} catch (DescribeCache.RecordTypeNotFoundException rtnfe) {
				System.assert(true);
			}
		}
	}
	
	@isTest
	static void getPicklistOptions() {
		System.runAs(UserTest.createStandardUser()) {
			DescribeCache dc = DescribeCache.getDescribeCache('Account');

			List<SelectOption> lso = dc.getPicklistOptions('Type');

			System.assertNotEquals(null, lso);
		}
	}

	@isTest
	static void getNonSObjectTypeDescribe() {
		System.runAs(UserTest.createStandardUser()) {
			DescribeCache dc = DescribeCache.getDescribeCache('System.Network');

			System.assertEquals(null, dc, 'System.Network should not be described.');
		}
	}
}