#!/bin/bash

# load common configuration
. ~/eventstreamr/baseimage/common-config.sh

echo "- updating background image"
convert $IMAGE/pictures/av-background-orig.png \
	-fill "#333333" -font Ubuntu-Mono-Bold -pointsize 24 \
	-draw "text 1590,795 'hostname: ${HOSTNAME}" \
	-draw "text 1590,820 ' IP addr: ${IPADDR}" \
	-draw "text 1590,845 'MAC addr: ${MACADDR}" \
	~/Pictures/av-background.png

exit 0
