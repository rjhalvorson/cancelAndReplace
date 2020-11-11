#!/bin/bash 

VERSION=6.13.0
SCANDIR=force-app/main/default
OUTPUTDIR=pmd/results
FILENAME=PMD_results.html
RULESET=pmd/pmd_rules.xml

while getopts ":s:o:f:r:" opt; do
  case $opt in
    s)
      SCANDIR=$OPTARG
      ;;
    o)
      OUTPUTDIR=$OPTARG
      ;;
    f)
      FILENAME=$OPTARG
      ;;
    r)
      RULESET=$OPTARG
      ;;

    \?)
      echo "Invalid  option: -$OPTARG" >&2
      ;;
  esac
done

if [ ! -d "$OUTPUTDIR" ]; then
  # Control will enter here if $DIRECTORY doesn't exist.
  mkdir -p $OUTPUTDIR
fi

alias pmd="$HOME/pmd-bin-$VERSION/bin/run.sh pmd"
echo "Scanning $SCANDIR folder with $RULESET rules"
echo "output to $OUTPUTDIR/$FILENAME"
$HOME/pmd-bin-$VERSION/bin/run.sh pmd -d $SCANDIR -R $RULESET -f summaryhtml -r $OUTPUTDIR/$FILENAME -failOnViolation false
