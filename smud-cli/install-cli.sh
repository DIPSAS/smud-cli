#!/usr/bin/env bash
HOME_DIR=$(dirname `readlink -f ~/.bashrc`)
smud_aliases=`cat ~/.bashrc | grep "~/smud-cli/.bash_aliases" -c`
if [ $smud_aliases -eq 0 ]; then
    echo "" >> ~/.bashrc
    echo "if [ -f ~/smud-cli/.bash_aliases ]; then" >> ~/.bashrc
    echo "  . ~/smud-cli/.bash_aliases" >> ~/.bashrc
    echo "fi" >> ~/.bashrc
fi

if [ ! -d ~/smud-cli ]; then
    mkdir ~/smud-cli
fi

BASEDIR=$(dirname "$0")

if [ ! "$HOME_DIR/smud-cli" = "$BASEDIR" ]; then
    # echo "$BASEDIR"
    cp $BASEDIR/* ~/smud-cli/ -u > /dev/null 2>&1
    cp $BASEDIR/.bash_aliases ~/smud-cli/ -u > /dev/null 2>&1
fi

if [ -f "$HOME_DIR/.bashrc" ]; then
    
    . $HOME_DIR/.bashrc 2>&1    
fi
