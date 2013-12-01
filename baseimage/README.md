baseimage
=========

The base OS image forms the foundation for eventstreamr. The goals are
simple:

* every host has the base image installed
* the base image includes all software required to perform all roles
* simple setup script to go from imaged to production

The actual image itself should be in the form of a clonezilla image on
removable media so it can be restored onto systems in minutes.

This part of the product directory covers what was done to build a base
image from scratch and store all the custom stuff needed such as config
scripts, images, etc...


Starting from Scratch
=====================

* Use the build-notes.txt file to install the OS, all dependencies, and
base level configuration.
* Include a copy of your eventstreamr git repo in ~av/eventstreamr
* create a clonezilla image of the disk

In production if the baseimage is stable then usage would be to flash a
system, git pull to get the latest updates, run the configure-host
script and you're done.
