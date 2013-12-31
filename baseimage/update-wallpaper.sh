#!/bin/bash

# load common configuration
. ~/eventstreamr/baseimage/common-config.sh

echo "- updating background image"
convert $IMAGE/pictures/av-background-orig.png \
	-fill "#333333" -font Ubuntu-Mono-Bold -pointsize 24 \
	-draw "text 1600,820 'hostname: ${HOSTNAME}" \
	-draw "text 1600,845 ' IP addr: ${IPADDR}" \
	~/Pictures/av-background.png

exit 0
