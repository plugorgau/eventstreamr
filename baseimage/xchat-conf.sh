#!/bin/bash

# load common configuration
. ~/eventstreamr/baseimage/common-config.sh

if [ -z "${ROOM}" ]; then
	ROOM="no-room-defined"
fi 

killall xchat
rm -rf ~/.xchat2
mkdir -p ~/.xchat2
cat > ~/.xchat2/xchat.conf << EOF
version = 2.8.8
irc_nick1 = ${ROOM}
irc_nick2 = ${ROOM}_
irc_nick3 = ${ROOM}__
irc_real_name = AV ${ROOM}
gui_slist_skip = 1
gui_join_dialog = 0

EOF

cat > ~/.xchat2/servlist_.conf << EOF
v=2.8.8

N=LCA
J=#AV
E=IRC (Latin/Unicode Hybrid)
F=27
D=2
S=${CTRL_HOST}
P=lca2014perth

EOF

exit 0
