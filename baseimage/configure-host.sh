#!/bin/bash

newname=$1
existing=`hostname`
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


# finally verify user wants to continue
echo -n "continue (y/n) [n]? "
read REPLY
if [ "$REPLY" != "y" ]; then
    echo "exiting..."
    exit 0;
fi
echo ""


echo "changing hostname ($existing) to $newname"


echo "- clearing desktop icons"
rm -f $homedir/Desktop/*.desktop


echo "- updating /etc/hosts"
sed -i "s/${existing}/${newname}/g" /etc/hosts
echo "- updating /etc/hostname"
sed -i "s/${existing}/${newname}/g" /etc/hostname


echo "- (re)starting hostname service"
service hostname start


echo "- updating background image"
$confdir/update-wallpaper.sh


echo "- done, should probably reboot just in case"
exit 0
