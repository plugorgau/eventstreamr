#!/bin/bash

# load common configuration
. ~/eventstreamr/baseimage/common-config.sh

hostname=avclone
existing=$HOSTNAME


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


echo "- killing manager (in case it's running)"
killall -TERM perl


echo "- restoring default desktop"
rm -f $HOMEDIR/Desktop/*
ln -s $IMAGE/desktop/README-NEW-IMAGE.txt $HOMEDIR/Desktop/


echo "- remove station config"
rm -f "$STATION/settings.json"
rm -f "$STATION/station.json"

echo "- remove station logs"
rm -rf "$STATION/logs"

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
cp $IMAGE/pictures/av-background-default.png $HOMEDIR/Pictures/av-background.png

echo "- restoring rc.local"
cp $IMAGE/rc.local.orig /etc/rc.local


echo "- done, should probably reboot just in case"
exit 0
