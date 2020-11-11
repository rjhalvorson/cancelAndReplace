#!/bin/bash
#convert the dx metadata to traditional
#metadata format in a ./deploy dir

if [ $# -lt 1 ]
then
    DEPLOYDIR='deploy'
    ROOTDIR='force-app/main/'
    PACKAGENAME=''
else
    DEPLOYDIR=$1
    ROOTDIR=$2
    PACKAGENAME=$3
fi

if [ -n "$PACKAGENAME" ]
then
    sfdx force:source:convert -r $ROOTDIR -d $DEPLOYDIR -n "$PACKAGENAME"
else
    sfdx force:source:convert -r $ROOTDIR -d $DEPLOYDIR
fi
