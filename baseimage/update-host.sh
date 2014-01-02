#!/bin/bash

# load common configuration
. ~/eventstreamr/baseimage/common-config.sh

# update git on first pass and re-exec in case this script has changed!
gitdone=$1
if [ -z "$gitdone" ]; then
    cd $BASE; 
    git pull
    exec $IMAGE/update-host.sh gitdone
fi

# make sure we have all our dependencies
sudo apt-get install -y `cat $BASE/package.deps`

# reconfigure xchat
$IMAGE/xchat-conf.sh

exit 0
