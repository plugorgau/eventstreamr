#!/bin/bash

homedir="/home/av"
esdir="$homedir/eventstreamr"
confdir="$esdir/baseimage"
ctrl_settings="$esdir/station/settings.json"

# update git repo
cd $confdir; 
git pull

# make sure we have all our dependencies
sudo apt-get install -y `cat $esdir/package.deps`

exit 0
