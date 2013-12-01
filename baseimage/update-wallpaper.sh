#!/bin/bash

newname=`hostname`
ipaddr=`ifdata -pa eth0`
homedir="/home/av"
confdir="$homedir/eventstreamr/baseimage"

echo "- updating background image"
convert $confdir/pictures/av-background-orig.png \
	-fill "#333333" -font Ubuntu-Mono-Bold -pointsize 24 \
	-draw "text 1600,820 'hostname: ${newname}" \
	-draw "text 1600,845 ' IP addr: ${ipaddr}" \
	$homedir/Pictures/av-background.png

exit 0
