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
stream - stream mixed video


Station Script Requirements
===========================
Apt Packages:
libdancer-perl libipc-shareable-perl libproc-daemon-perl libipc-shareable-perl libjson-perl libconfig-json-perl libproc-processtable-perl libfile-slurp-perl libmoo-perl libhash-merge-simple-perl

station.json
============

Config file can appear as below and take fixed array of devices:

{ 
  "roles" : [{"role":"ingest"}],
  "nickname" : "",
  "room" : "",
  "mixer" : {"port":"1234", "host":"localhost"},
  "devices" : [ 
                {"type":"dv","id":"0x080046010368430a"},
                {"type":"alsa","id":"4"},
                {"type":"alsa","id":"0"}
              ],
  "run" : "0"
}

or set to pickup all attached devices:

{ 
  "roles" : [{"role":"ingest"}],
  "nickname" : "",
  "room" : "",
  "mixer" : {"port":"1234", "host":"localhost"},
  "devices" : "all" 
  "run" : "0"
}

