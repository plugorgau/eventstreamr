#!/bin/bash

newname=$1
existing=`hostname`
gitdone=$2
ipaddr=`ifdata -pa eth0`
homedir="/home/av"
confdir="$homedir/eventstreamr/baseimage"

# initial banner (shown all the time)
echo "
--- eventstreamr HOST CONFIGURATION SCRIPT ---

This should be run after imaging to setup some initial stuff but the
main thing being setting the hostname and turning eventstreamr on. 
"

# some checks before continuing
if [ "$EUID" -ne 0 ]; then
	echo "ERROR: need to run with sudo"
	exit 1
fi

if [ -z "$newname" ]; then
	echo "ERROR: need to provide new hostname"
	exit 1
fi

if [ "$newname" == "$existing" ]; then
	echo "WARNING: new hostname is the same as the old name!"
fi 

if [ -z "$gitdone" ]; then
    echo -n "update eventstreamr from git (y/n) [n]? "
    read REPLY
    if [ "$REPLY" == "y" ]; then
        su - av -c "cd $confdir; git pull"
        echo "restarting script in 3 seconds ..."
        sleep 3
        reset
        exec $0 $newname gitdone
    else
        echo "- skipping git update"
    fi
fi


# finally verify user wants to continue
echo -n "continue (y/n) [n]? "
read REPLY
if [ "$REPLY" != "y" ]; then
    echo "exiting..."
    exit 0;
fi
echo ""


echo "- clearing desktop icons"
rm -f $homedir/Desktop/*


echo "- updating /etc/hosts"
sed -i "s/${existing}/${newname}/g" /etc/hosts
echo "- updating /etc/hostname"
sed -i "s/${existing}/${newname}/g" /etc/hostname


echo "- (re)starting hostname service"
service hostname start


echo "- updating background image"
$confdir/update-wallpaper.sh


echo "- updating /etc/rc.local to start eventstreamr bits"
cp $confdir/rc.local /etc/rc.local


echo "- done, should probably reboot just in case"
exit 0
