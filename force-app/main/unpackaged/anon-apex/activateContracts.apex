List<Contract > contractsToActivate = [SELECT Id, Status  
                                        FROM Contract  
                                        WHERE Status!='Activated' 
                                        LIMIT 20];
for (Contract c : contractsToActivate){
        c.Status='Activated';
    }
update contractsToActivate;