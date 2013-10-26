eventstreamr
============

Single and multi room audio visual stream management.

Station Script Requirements
===========================
Apt Packages:
libdancer-perl libipc-shareable-perl libproc-daemon-perl libipc-shareable-perl libjson-perl libconfig-json-perl libdevice-usb-perl

USB Permissions
===============
copy ./station/etc/udev/rules.d/99-usb-perms.rules to /etc/udev/rules.d/99-usb-perms.rules

Add the usb group
sudo groupadd --system usb

Add the group to the user
sudo usermod -G -a usb username

Trigger udev reload
sudo udevadm trigger reload

You can find the system rules here:
/lib/udev/rules.d/50-udev-default.rules

Our rule appends
, GROUP="usb"

To the system udev rule. Putting it in /etc/udev/rules.d with a higher number overrides the system default. 
