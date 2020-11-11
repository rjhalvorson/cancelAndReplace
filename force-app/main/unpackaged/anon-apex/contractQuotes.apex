List<Order> quotesToContract = [SELECT Id, SBQQ__Contracted__c  
                                        FROM Order  
                                        WHERE SBQQ__Contracted__c=false 
                                        LIMIT 20];
for (Order o : quotesToContract){
        o.SBQQ__Contracted__c=true;
    }
update quotesToContract;