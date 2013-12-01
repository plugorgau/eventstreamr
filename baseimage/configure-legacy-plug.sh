#!/bin/bash

newname=`hostname`
master=$1
homedir="/home/av"
confdir="$homedir/eventstreamr/baseimage"

# initial banner (shown all the time)
echo "
--- LEGACY PLUG CONFIGURATION ---

Run this after host configuration. Run with the parameter 'avmaster'
to configure the host as a master vs ingest machine.
"

echo "- updating desktop icons"
cp $confdir/desktop/avmumble.desktop $homedir/Desktop
sed -i "s/\/\/avclone/${newname}/" $homedir/Desktop/avmumble.desktop

if [ "$master" == "avmaster" ]; then 
	cp $confdir/desktop/dvmenu.desktop $homedir/Desktop
else
	cp $confdir/desktop/dvsource-fw.desktop $homedir/Desktop
fi
