/****************************************************************************************
Name            : PicklistMsg
Revision Log    : 8/19/2020 Bryan
                :
                :
Use             : Message class for picklist values
*****************************************************************************************/
public with sharing class PicklistMsg {
    @AuraEnabled public String label {get; set;}
    @AuraEnabled public String value {get; set;}

    public PicklistMsg(String value,String label){
        this.label = label;
        this.value = value;
    }
}