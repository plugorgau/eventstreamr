#!/bin/bash

SERVER=controller.local
PASSWORD=lca2014perth
MOUNT=eng-lt1.ogg
DVSWITCH=eng-lt1-1.local
NAME="Engineering Lecture Theatre 1"

#ffmpeg2theora ~/second_reality.mp4 -F 30:2 --speedlevel 0 -v 4 \
#  --optimize -V 420 --soft-target -a 4 -c 1 -H 44100 -o - | \
#  oggfwd ${SERVER} 8000 ${PASSWORD} /${MOUNT}


## NEW settings, ~500kbps rate, full quality but half framerate
/usr/bin/dvsink-command -h ${DVSWITCH} -p 1234 -- ffmpeg2theora - -f dv -F 25:2 -x 640 -y 512 \
  --speedlevel 0 -v 4 --optimize -V 420 --soft-target -a 4 -c 1 -H 44100 -o - | \
  oggfwd -n "${NAME}" ${SERVER} 8000 ${PASSWORD} /${MOUNT}

