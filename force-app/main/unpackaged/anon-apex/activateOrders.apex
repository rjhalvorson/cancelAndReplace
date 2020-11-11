List<Order > ordersToActivate = [SELECT Id, Status  
                                        FROM Order  
                                        WHERE Status!='Activated' 
                                        LIMIT 20];
for (Order o : ordersToActivate){
        o.Status='Activated';
    }
update ordersToActivate;