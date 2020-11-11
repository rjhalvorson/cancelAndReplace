#!/bin/bash 

VERSION=6.13.0

if [ $# -eq 1 ]
then
    VERSION=$1
fi

echo  "Installing PMD $VERSION"
cd $HOME
curl -OL https://github.com/pmd/pmd/releases/download/pmd_releases%2F$VERSION/pmd-bin-$VERSION.zip
unzip pmd-bin-$VERSION.zip
alias pmd="$HOME/pmd-bin-$VERSION/bin/run.sh pmd"
echo "PMD $VERSION Installed"
