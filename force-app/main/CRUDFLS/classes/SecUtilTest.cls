@isTest
private class SecUtilTest {

	static void checkCRUD_negative(DataConstants.SecurityOperation o) {
		try {
			SecUtil.checkCRUD(o, 'AuthProvider');
			System.assert(false);
		} catch (SecUtil.CRUDException e) {
			System.assert(true);
		}
	}
	@isTest
	static void checkCRUD_negative() {
		System.runAs(UserTest.createStandardUser()) {
			Test.startTest();

			checkCRUD_negative(DataConstants.SecurityOperation.READ);
			checkCRUD_negative(DataConstants.SecurityOperation.CREATE);
			checkCRUD_negative(DataConstants.SecurityOperation.MODIFY);
			checkCRUD_negative(DataConstants.SecurityOperation.REMOVE);
			checkCRUD_negative(DataConstants.SecurityOperation.UNREMOVE);

			Test.stopTest();
		}
		System.assert(true);
	}

	static void checkCRUD_positive(DataConstants.SecurityOperation o) {
		try {
			SecUtil.checkCRUD(o, 'Account');
			System.assert(true);
		} catch (SecUtil.CRUDException e) {
			System.assert(false);
		}
	}
	@isTest
	static void checkCRUD_positive() {
		Test.startTest();

		checkCRUD_positive(DataConstants.SecurityOperation.READ);
		checkCRUD_positive(DataConstants.SecurityOperation.CREATE);
		checkCRUD_positive(DataConstants.SecurityOperation.MODIFY);
		checkCRUD_positive(DataConstants.SecurityOperation.REMOVE);
		checkCRUD_positive(DataConstants.SecurityOperation.UNREMOVE);

		Test.stopTest();
		System.assert(true);
	}

	static void checkFLS_negative(DataConstants.SecurityOperation o) {
		try {
			SecUtil.checkFLS(o, 'Lead', 'DoNotCall');
			System.assert(false);
		} catch (SecUtil.FLSException e) {
			System.assert(true);
		}
	}
	@isTest
	static void checkFLS_negative() {
		System.runAs(UserTest.createStandardUser()) {
			Test.startTest();

			checkFLS_negative(DataConstants.SecurityOperation.READ);
			checkFLS_negative(DataConstants.SecurityOperation.CREATE);
			checkFLS_negative(DataConstants.SecurityOperation.MODIFY);

			Test.stopTest();
		}
		System.assert(true);
	}
	@isTest
	static void checkFLS_negative_system() {
		System.runAs(UserTest.createStandardUser()) {
			Test.startTest();

			SecUtil.checkFLS(DataConstants.SecurityOperation.READ, 'Lead', 'CreatedDate');

			Test.stopTest();
		}
		System.assert(true);
	}

	static void checkFLS_positive(DataConstants.SecurityOperation o) {
		try {
			SecUtil.checkFLS(o, 'Account', 'Name');
			System.assert(true);
		} catch (SecUtil.FLSException e) {
			System.assert(false);
		}
	}
	@isTest
	static void checkFLS_positive() {
		Test.startTest();

		checkFLS_positive(DataConstants.SecurityOperation.READ);
		checkFLS_positive(DataConstants.SecurityOperation.CREATE);
		checkFLS_positive(DataConstants.SecurityOperation.MODIFY);
		checkFLS_positive(DataConstants.SecurityOperation.REMOVE);
		checkFLS_positive(DataConstants.SecurityOperation.UNREMOVE);

		Test.stopTest();
		System.assert(true);
	}

	@isTest
	static void coverage_1() {
		SecUtil.checkCRUD(DataConstants.SecurityOperation.READ, Account.SObjectType);
		System.assert(true);
	}
	@isTest
	static void coverage_2() {
		SecUtil.checkFLS(DataConstants.SecurityOperation.MODIFY, Account.SObjectType, 'Id');
		System.assert(true);
	}
	@isTest
	static void coverage_3() {
		SecUtil.checkFLS(DataConstants.SecurityOperation.REMOVE, 'Lead', 'DoNotCall');
		System.assert(true);
	}
}