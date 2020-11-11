List<SBQQ__Quote__c > quotesToOrder = [SELECT Id, SBQQ__Ordered__c  
                                        FROM SBQQ__Quote__c  
                                        WHERE SBQQ__Ordered__c=false 
                                        LIMIT 20];
for (SBQQ__Quote__c q : quotesToOrder){
        q.SBQQ__Ordered__c=true;
    }
update quotesToOrder;