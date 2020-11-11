/**
 * This test class should be used as a central place for creating all
 * personas user records, and assigning those user records to any
 * permission sets utilized by the application.
 * <p>
 * This class should be modified to include methods for each persona.
 */
@isTest
public class UserTest {
	private static Integer userNumber = 0;
	
	public static User createStandardUser() {
		return createUserWithProfile([SELECT Id FROM Profile WHERE Name = 'Standard User'].Id);
	}

	public static User createPlatformUser() {
		return createUserWithProfile([SELECT Id FROM Profile WHERE Name = 'Standard Platform User'].Id);
	}
	
	public static User createUserWithProfile(Id profileId) {
		Integer userNum = userNumber++;
		String email = 'unit.test.user+' + userNum + '@' + UserInfo.getOrganizationId() + '.test.com';
		User u = new User(
			FirstName           = 'Test',
			LastName            = 'User ',
			Email               = email,
			Username            = email,
			Alias               = ('tuser' + userNum).right(8),
			Phone               = '503-555-1212',
			ProfileId           = profileId,
			TimeZoneSidKey      = 'America/Los_Angeles',
			LocaleSidKey        = 'en_US',
			EmailEncodingKey    = 'ISO-8859-1',
			LanguageLocaleKey   = 'en_US'
		);
		if(Userinfo.isMultiCurrencyOrganization()) {
			((SObject)u).put('CurrencyIsoCode','USD');
		}
		insert u;
		
		return u;
	}

	/**
	 * Example showing how to create a user with a default assignment of some permission
	 * sets.
	 */
	public static User createUserWithPerms() {
		return createUser(new List<String>{'permission_set_name_1','permission_set_name_2'});
	}

	private static User createUser(List<String> permissionSets) {
		User u = createStandardUser();

		// add user to perm sets
		List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
		for (PermissionSet ps : [SELECT Id, Name
								   FROM PermissionSet
								  WHERE Name IN :permissionSets]) {
			psas.add(
				new PermissionSetAssignment(
					AssigneeId				= u.Id,
					PermissionSetId			= ps.Id
				)
			);
		}
		insert psas;

		return u;
	}
}