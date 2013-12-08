eventstreamr
============

Single and multi room audio visual stream management.

Concepts
========

A station can have one or more roles. Only one controller can manage stations.

Roles
=====
* controller - Web based frontend for managing stations
* ingest - alsa/dv/v4l capture for sending to mixer
* mixer - DVswitch/streaming live mixed video. With the intention for this to be easily replaced by gstswitch
* stream - stream mixed video
* record - stream mixed video

Directories
===========
* baseimage - docs, notes, and tools for the base (OS) image
* station - station management scripts
* controller - controller stack


Station Script Requirements
===========================
Apt Packages:
libdancer-perl libproc-daemon-perl libipc-shareable-perl libjson-perl libconfig-json-perl libproc-processtable-perl libfile-slurp-perl libmoo-perl libhash-merge-simple-perl liblog-log4perl-perl
moreutils

