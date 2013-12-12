#!/bin/bash

hostname=avclone
existing=`hostname`

ipaddr=`ifdata -pa eth0`
homedir="/home/av"
confdir="$homedir/eventstreamr/baseimage"
ctrl_settings="$homedir/eventstreamr/station/settings.json"
log="/tmp/station-mgr.log"



# initial banner (shown all the time)
echo "
--- eventstreamr RESET HOST ---

This will clear host configuration and probably not useful unless
you're trying to make a generic image

"

# some checks before continuing
if [ "$EUID" -ne 0 ]; then
	echo "ERROR: need to run with sudo"
	exit 1
fi



echo "- restoring default desktop"
rm -f $homedir/Desktop/*
ln -s $confdir/desktop/README-NEW-IMAGE.txt $homedir/Desktop/


echo "- remove station config"
rm -f $ctrl_settings

echo "- restoring default DHCP networking"

if [ -f "/etc/init/network-manager.override" ]; then
    rm -f /etc/init/network-manager.override
    echo "auto lo
iface lo inet loopback
" > /etc/network/interfaces
    service networking restart
fi

echo "- updating /etc/hosts"
sed -i "s/${existing}/${hostname}/g" /etc/hosts
echo "- updating /etc/hostname"
sed -i "s/${existing}/${hostname}/g" /etc/hostname


echo "- (re)starting hostname service"
service hostname start

echo "- restoring default background image"
cp $confdir/pictures/av-background-default.png $homedir/Pictures/av-background.png

echo "- restoring rc.local"
cp $confdir/rc.local.orig /etc/rc.local


echo "- done, should probably reboot just in case"
exit 0
