/****************************************************************************************
Name            : CancelAndReplaceUtility
Revision Log    : 8/13/2020 Bryan
                :
                :
Use             : Utility class for working with Cancel and Replace
*****************************************************************************************/
public with sharing class CancelAndReplaceUtility {

    /**
     * provides string of namespace
     *
     * @return namespace
     **/
    @AuraEnabled
    public static String getNamespace() {
        return CancelAndReplaceUtility.class.getName().substringBefore('CancelAndReplaceUtility').removeEnd('.');
    }

    @AuraEnabled
    public static String getNamespaceWithUnderScore() {
        String ns = getNamespace();
        return String.isNotBlank(ns) ? ns + '__' : ns;
    }

}