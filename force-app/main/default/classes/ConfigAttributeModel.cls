/****************************************************************************************
Name            : ConfigAttributeModel
Revision Log    : 8/12/2020 Bryan
                :
                :
Use             : Used with the CPQ API, DO NOT UPDATE VARIABLES UNLESS API CHANGES
*****************************************************************************************/
public with sharing class ConfigAttributeModel {
    public String name;
    public String targetFieldName;
    public Decimal displayOrder;
    public String colmnOrder;
    public Boolean required;
    public Id featureId;
    public String position;
    public Boolean appliedImmediately;
    public Boolean applyToProductOptions;
    public Boolean autoSelect;
    public String[] shownValues;
    public String[] hiddenValues;
    public Boolean hidden;
    public String noSuchFieldName;
    public Id myId;
}