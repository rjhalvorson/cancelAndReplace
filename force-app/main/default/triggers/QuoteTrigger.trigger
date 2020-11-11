/****************************************************************************************
Name            : QuoteTrigger
Revision Log    : 8/21/2020 Bryan
                :
                :
Use             : Trigger for the Quote Object
*****************************************************************************************/
trigger QuoteTrigger on SBQQ__Quote__c (after update) {

    if ( Trigger.isUpdate && Trigger.isAfter) {
        QuoteDomain domain = new QuoteDomain();
        domain.onUpdate(Trigger.newMap, Trigger.oldMap);
    }

}