#!/bin/bash
# use this command to run destructive changes
# from current checked-out branch 

if [ $# -lt 1 ]
then
    echo 'Usage: destructive.sh alias'
    exit
fi

ALIAS=$1
CHECKONLY=$2
DEPLOYDIR=$3

if [ -z "$CHECKONLY" ]
then
    echo 'real destroy'
else
    if [ "$CHECKONLY" == "checkonly" ]
    then
        echo 'checkonly destroy'
        CHECKONLY='--checkonly'
    else
        echo 'real destroy'
        CHECKONLY=''
    fi
fi

if [ -z "$DEPLOYDIR"  ]
then
    echo 'default destroy dir'
    DEPLOYDIR='destructive'
else
    echo 'new destroy dir'
fi

#validate legacy metadata
# --ignorewarnings is included as warnings are thrown when items in the destructiveChanges.xml do not exist in the org
#                  this happens after the initial run in an environment, and it causes subsequent builds to fail
sfdx force:mdapi:deploy $CHECKONLY -w -1 --deploydir $DEPLOYDIR -u $ALIAS --ignorewarnings

#sleep 5s

#sfdx force:mdapi:deploy:report