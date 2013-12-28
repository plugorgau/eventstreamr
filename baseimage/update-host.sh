#!/bin/bash

homedir="/home/av"
esdir="$homedir/eventstreamr"
confdir="$esdir/baseimage"
ctrl_settings="$esdir/station/settings.json"
gitdone=$1

# update git on first pass and re-exec in case this script has changed!
if [ -z "$gitdone" ]; then
    cd $confdir; 
    git pull
    exec $0 gitdone
fi

# make sure we have all our dependencies
sudo apt-get install -y `cat $esdir/package.deps`

exit 0
