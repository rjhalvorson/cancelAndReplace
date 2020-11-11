/****************************************************************************************
Name            : TestUserFactory
Revision Log    : 8/12/2020 Bryan
                :
                :
Use             : Factory for creating a user with cpq and cancel and replace permissions
*****************************************************************************************/
@IsTest
public with sharing class TestUserFactory {
    private static final String PROFILE_ADMIN = 'System Administrator';
    private static final String PROFILE_STANDARD = 'Standard User';
    private static final String PERMSET_CANCEL_AND_REPLACE = 'Salesforce_CPQ_Cancel_and_Replace';
    private static final String PERMSET_CPQ_USER = 'SteelBrickCPQUser';
    private static final String PERMSET_CPQ_ADMIN = 'SteelBrickCPQAdmin';
    private static final String CPQ_NAMESPACE = 'SBQQ';
    private static final String PKG_NAMESPACE = 'cpqlabs';

    private static final Map<String, Id> mapProfileNameToId = new Map<String, Id>();
    private static Map<UserType, Id> permSetIdByUserTypeMap;
    private static Map<UserType, Id> cpqPermSetIdByUserTypeMap;

    public static Map<UserType, String> permSetNameByUserTypeMap = new Map<UserType, String>{
        UserType.ADMIN => PERMSET_CANCEL_AND_REPLACE,
        UserType.STANDARD => PERMSET_CANCEL_AND_REPLACE
    };

    public static Map<UserType, String> cpqPermSetNameByUserTypeMap = new Map<UserType, String>{
        UserType.ADMIN => PERMSET_CPQ_ADMIN,
        UserType.STANDARD => PERMSET_CPQ_USER
    };

    public enum UserType {
        ADMIN,
        STANDARD
    }

    public static string getRandomEmail() {
        Integer i = (integer) (Math.random() * 1000);
        return 'test-' + i.format() + '@test.com';
    }

    /**
     * creates an admin user with admin perm set and random email
     * @return   user
     */
    public static User createUserAdmin() {
        return createUserAdmin(getRandomEmail());
    }

    /**
     * creates an admin user with admin perm set with specified email
     * @param  email email description
     * @return       user
     */

    public static User createUserAdmin(String email) {
        return createUserWithAdminProfile(UserType.ADMIN, email);
    }

    /**
     * creates an standard user with standard perm set with specified email
     * @param  email email description
     * @return       user
     */

    public static User createUserStandard(String email) {
        return createUserWithStandardProfile(UserType.STANDARD, email);
    }

    /**
     * Create Admin User with admin permission set
     * @param  email   supplied email
     * @return         User
     */
    public static User createUserWithAdminProfile(UserType usrType, String email) {
        loadPermSets();

        // create the user
        User user = setupUserWithProfile(PROFILE_ADMIN, email);
        insert user;
        List<PermissionSetAssignment> assignments = addPermissionSetsForUser(user.Id, usrType);
        insert assignments;
        return user;
    }

    /**
     * Create Standard User with standard permission set
     * @param  email   supplied email
     * @return         User
     */
    public static User createUserWithStandardProfile(UserType usrType, String email) {
        loadPermSets();

        // create the user
        User user = setupUserWithProfile(PROFILE_STANDARD, email);
        insert user;
        List<PermissionSetAssignment> assignments = addPermissionSetsForUser(user.Id, usrType);
        insert assignments;
        return user;
    }

    /**
     * Setup User with Profile
     **/
    /**
     * override to handle old test classes (temporary)
     * @param  profileId profileId to assign to the user
     * @param  email     email for user
     * @return           return an uninserted user
     */
    public static User setupUserWithProfile(String profileName, String email) {
        return setupUser(profileName, email);
    }

    /**
     * setupUser description
     * @param  profileId profileId to assign to the user
     * @param  email     email for user
     * @return           return an uninserted user
     */
    public static User setupUser(String profileName, String email) {
        return setupUser(profileName, 'Test', 'User ', null, email);
    }

    /**
     * Setup User with Profile, name and number
     **/
    public static User setupUser(
        String profileName,
        String firstName,
        String lastName,
        String employeeNumber,
        String email
    ) {
        if (email == null) {
            email = 'unit.test.user@' + UserInfo.getOrganizationId() + '.apextest.com';
        }
        User u = new User();
        u.FirstName = firstName;
        u.LastName = lastName;
        u.EmployeeNumber = employeeNumber;
        u.Email = email;
        u.Username = email;
        u.Alias = 'tuser' + String.valueOf(Integer.valueOf((Math.random() * 999)));
        u.ProfileId = getIdForProfile(profileName);
        u.TimeZoneSidKey = 'America/Los_Angeles';
        u.LocaleSidKey = 'en_US';
        u.EmailEncodingKey = 'ISO-8859-1';
        u.LanguageLocaleKey = 'en_US';

        if (UserInfo.isMultiCurrencyOrganization()) {
            ((SObject) u).put('CurrencyIsoCode', 'USD');
        }

        return u;
    }

    /**
     * Get Id For Profile
     *
     * @param profileName
     * @return Profile Id
     **/

    private static Id getIdForProfile(String profileName) {
        if (!mapProfileNameToId.containsKey(profileName.toUpperCase())) {
            for (Profile p : [SELECT Id, Name FROM Profile WHERE Name = :profileName]) {
                mapProfileNameToId.put(p.Name.toUpperCase(), p.Id);
            }
        }

        return mapProfileNameToId.get(profileName.toUpperCase());
    }

    /**
     * loads permission sets into the static map by usertype
     * @return   none
     */
    public static void loadPermSets() {
        // load permset ids by usertype if not already loaded
        if (permSetIdByUserTypeMap == null) {
            permSetIdByUserTypeMap = mapPermsetToUserType(permSetNameByUserTypeMap,getPackagePermissionSets());
        }

        // load permset ids by usertype if not already loaded
        if (cpqPermSetIdByUserTypeMap == null) {
            cpqPermSetIdByUserTypeMap = mapPermsetToUserType(cpqPermSetNameByUserTypeMap,getCPQPermissionSets());
        }
    }

    public static Map<UserType, Id> mapPermsetToUserType(  Map<UserType, String> permSetUserTypeToName, Map<String, Id> permSetIdByNameMap  ) {
        Map<UserType, Id> userTypeToIdMap = new Map<UserType, Id>();
        for (UserType uType : UserType.values()) {
            String permSetName = permSetUserTypeToName.get(uType);
            Id permSetId = permSetIdByNameMap.get(permSetName);

            if (permSetId != null) {
                userTypeToIdMap.put(uType, permSetId);
            }
        }
        return userTypeToIdMap;
    }

    public static Map<String, Id> getPackagePermissionSets() {
        Set<String> permSetNameSet = new Set<String>();
        permSetNameSet.addAll(permSetNameByUserTypeMap.values());
        // TODO: Setup utility class to get namespace
        return getPermissionSets(permSetNameSet, PKG_NAMESPACE);
    }

    public static Map<String, Id> getCPQPermissionSets() {
        Set<String> permSetNameSet = new Set<String>();
        permSetNameSet.addAll(cpqPermSetNameByUserTypeMap.values());
        return getPermissionSets(permSetNameSet, CPQ_NAMESPACE);
    }

    public static List<PermissionSetAssignment> addPermissionSetsForUser(Id userId, UserType usrType) {
        List<PermissionSetAssignment> permissionSets = new List<PermissionSetAssignment>();

        Id permSetId = permSetIdByUserTypeMap.get(usrType);
        Id cpqPermSetId = cpqPermSetIdByUserTypeMap.get(usrType);

        permissionSets.add(addPermissionSet(userId, permSetId));
        permissionSets.add(addPermissionSet(userId, cpqPermSetId));

        return permissionSets;
    }

    /**
     * Add Permission Set
     *
     * @param userId
     * @param permissionSetId
     *
     * @return fully formed PermissionSetAssignment record
     **/
    public static PermissionSetAssignment addPermissionSet(Id userId, Id permissionSetId) {
        PermissionSetAssignment psa = new PermissionSetAssignment();
        psa.AssigneeId = userId;
        psa.PermissionSetId = permissionSetId;
        return psa;
    }

    /**
     * Get Permission Sets
     *
     * @param permissionSetNames
     *
     * @return Map of PermissionSet.Name to PermissionSet.Id
     **/
    public static Map<String, Id> getPermissionSets(Set<String> permissionSetNames, String namespace) {
        System.debug(permissionSetNames);
        System.debug(namespace);
        List<PermissionSet> pss = [
            SELECT Id, Name
            FROM PermissionSet
            WHERE Name IN :permissionSetNames AND NamespacePrefix = :namespace
        ];
        Map<String, Id> psMap = new Map<String, Id>();

        for (PermissionSet ps : pss) {
            psMap.put(ps.Name, ps.Id);
        }

        return psMap;
    }
}