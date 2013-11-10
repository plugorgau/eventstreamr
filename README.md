eventstreamr
============

Single and multi room audio visual stream management.

Concepts
========

A station can have one or all rolls. Only one controller can manage stations.

Rolls
=====
controller - Web based frontend for managing stations
ingest - alsa/dv/v4l capture for sending to mixer
mixer - DVswitch/streaming live mixed video. With the intention for this to be easily replaced by gstswitch


Station Script Requirements
===========================
Apt Packages:
libdancer-perl libipc-shareable-perl libproc-daemon-perl libipc-shareable-perl libjson-perl libconfig-json-perl
