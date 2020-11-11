/****************************************************************************************
Name            : FeatureModel
Revision Log    : 8/12/2020 Bryan
                :
                :
Use             : Used with the CPQ API, DO NOT UPDATE VARIABLES UNLESS API CHANGES
*****************************************************************************************/
public with sharing class FeatureModel {
    public SBQQ__ProductFeature__c record;
    public String instructionsText;
    public Boolean containsUpgrades;
}