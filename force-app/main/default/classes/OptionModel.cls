/****************************************************************************************
Name            : OptionModel
Revision Log    : 8/12/2020 Bryan
                :
                :
Use             : Used with the CPQ API, DO NOT UPDATE VARIABLES UNLESS API CHANGES
*****************************************************************************************/
public with sharing class OptionModel {
    public SBQQ__ProductOption__c record;
    public Map<String, String> externalConfigurationData;
    public Boolean configurable;
    public Boolean configurationRequired;
    public Boolean quantityEditable;
    public Boolean priceEditable;
    public Decimal productQuantityScale;
    public Boolean priorOptionExists;
    public Set<Id> dependentIds;
    public Map<String, Set<Id>> controllingGroups;
    public Map<String, Set<Id>> exclusionGroups;
    public String reconfigureDimensionWarning;
    public Boolean hasDimension;
    public Boolean isUpgrade;
    public String dynamicOptionKey;
}