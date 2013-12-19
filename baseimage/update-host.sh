#!/bin/bash

homedir="/home/av"
confdir="$homedir/eventstreamr/baseimage"
ctrl_settings="$homedir/eventstreamr/station/settings.json"

# update git repo
cd $confdir; 
git pull

exit 0
