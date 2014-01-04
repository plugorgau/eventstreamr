#!/bin/bash

HOMEDIR="/home/av"
BASE="$HOMEDIR/eventstreamr"
STATION="$BASE/station"
CONTROLLER="$BASE/controller"
IMAGE="$BASE/baseimage"
HOSTNAME=`hostname`
IPADDR=`ifdata -pa eth0`
MACADDR=`ifdata -ph eth0`

if [ -f "$STATION/settings.json" ]; then
    CTRL_HOST=`cat $STATION/settings.json | grep 'controller' | sed 's/^.*\/\/\([^:]*\):.*$/\1/'`
fi

if [ -f "$STATION/station.json" ]; then
    ROOM=`cat $STATION/station.json | grep '"room"' | sed 's/^.*"room" : "\([^"]*\)".*$/\1/'`
fi
