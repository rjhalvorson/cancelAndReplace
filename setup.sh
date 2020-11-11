#!/bin/bash
# use this command to configure a CPQ scratch org
# based on the current local branch
#
# Pre-steps
# - pull remote branch and connect to Dev Hub
#
# Run-steps
# $ ./setup.sh orgname [cpqPackageid]   
#
#


# bring in config file variables
source config/config.file


# assign variable defaults
packageversion=$SBQQ_PACKAGE_ID
duration=$DEFAULT_SCRATCH_ORG_LENGTH
defaultpermsets="Salesforce_CPQ_Cancel_and_Replace SBQQ__SteelBrickCPQAdmin SBQQ__SteelBrickCPQUser"

# assign variables
if [ $# -lt 1 ]
then
    echo Usage: setup.sh orgName [duration]
    exit
fi

alias=$1

if [ -n "$2" ]
then
    packageversion=$2
fi

# validate alias
if [ "$alias" = "" ] ; then
    echo Usage: setup.sh orgName [duration]
    exit 1
fi


#create a scratch org
echo "Creating scratch org: $alias"
sfdx force:org:create -s -f config/project-scratch-def.json -a $alias -d $duration;
sfdx force:config:set defaultusername=$alias


#push local code artifacts to scratch org
echo "Opening $alias"
sfdx force:org:open


#install cpq package
echo "Installing Salesforce CPQ [SBBQ] package version: $packageversion"
sfdx force:package:install -r -p $packageversion -w 30 -u $alias -s AllUsers



#push local code artifacts to scratch org
echo "Pushing source in current branch to: $alias"
sfdx force:source:push -f

# validate push
exit_code=$# 
if [ exit_code ]; then
    echo "Fix the build issue then resume" 
    exit 
fi


#create cpq test user
echo "Creating test user `cpq-user`"
sfdx force:user:create --setalias cpq-user --definitionfile config/cpquser.json


#assign any required permission sets
for permset in $defaultpermsets
do
  echo "Assigning permission set [$permset] to default user"
  sfdx force:user:permset:assign --permsetname $permset
done


#create test data

if [ $# -eq 1 ]
then
    # open new scratch org in browser to default page
    echo "Now go to: Setup > Installed Packages > "
    echo "Salesforce CPQ Configure > Pricing and Calculation > "
    echo "Click Authorize new calculation service then run " 
    echo
    echo "sfdx force:apex:execute -f force-app/main/unpackaged/anon-apex/loadQuotes.apex"
    echo
    echo "then go to the Apex Jobs queue in Setup to monitor the completion of the queue"
    echo "refer to README.md for the final data seeding scripts"
    exit
fi