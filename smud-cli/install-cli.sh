#!/usr/bin/env bash
HOME_DIR="~"
HOME_ABS_DIR=$(dirname `readlink -f ~/.bashrc`)
DEST_DIR="$HOME_ABS_DIR/smud-cli"

# echo "HOME_DIR: $HOME_DIR"
# echo "DEST_DIR: $DEST_DIR"

smud_aliases=0
if [ -f $HOME_ABS_DIR/.bashrc ]; then
    smud_aliases=`cat $HOME_ABS_DIR/.bashrc | grep "/smud-cli/.bash_aliases" -c`
fi

if [ $smud_aliases -eq 0 ]; then
    echo "" >> $HOME_ABS_DIR/.bashrc
    echo "if [ -f ~/smud-cli/.bash_aliases ]; then" >> $HOME_ABS_DIR/.bashrc
    echo "  . ~/smud-cli/.bash_aliases" >> $HOME_ABS_DIR/.bashrc
    echo "fi" >> $HOME_ABS_DIR/.bashrc

    if [ "$HOMEDRIVE" ] && [ -f $HOME_ABS_DIR/.bash_profile ]; then
        bashrc_count=`cat $HOME_ABS_DIR/.bash_profile | grep "~/.bashrc" -c`
        if [ $bashrc_count -eq 0 ]; then
            echo "" >> $HOME_ABS_DIR/.bash_profile
            echo "if [ -f ~/.bashrc ]; then" >> $HOME_ABS_DIR/.bash_profile
            echo "  . ~/.bashrc" >> $HOME_ABS_DIR/.bash_profile
            echo "fi" >> $HOME_ABS_DIR/.bash_profile
        fi        
    fi

fi

if [ ! -d $DEST_DIR ]; then
    mkdir $DEST_DIR
fi

BASEDIR=$(dirname "$0")

if [ ! "$DEST_DIR" = "$BASEDIR" ]; then
    # echo "BASEDIR: $BASEDIR"
    
    cp $BASEDIR/*.sh $DEST_DIR/  > /dev/null 2>&1
    cp $BASEDIR/.bash_aliases $DEST_DIR/ -u > /dev/null 2>&1

    if [ -f "$BASEDIR/CHANGELOG.md" ];then
      cp $BASEDIR/*.md $DEST_DIR/ -u > /dev/null 2>&1
    fi   

    # ls -la $DEST_DIR/*
fi

if [ $HOMEDRIVE ] && [ -f $HOME_ABS_DIR/.bash_profile ]; then
    . ~/.bash_profile 
elif [ -f $HOME_ABS_DIR/.bashrc ]; then
    . ~/.bashrc
fi
