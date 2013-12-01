
README FOR NEW BASEIMAGE
------------------------

If you can see this readme then the configure script hasn't been run
yet. Here's what you need to do:

1. make sure this host is already on the network. DHCP or static IP
   is fine, just do it first. Don't worry about the hostname yet.

2. have a unique hostname for this host in mind

3. know the IP address (or hostname) for the controller

4. cd ~/eventstreamr/baseimage/

5. run: sudo ./configure-host.sh <new_hostname>

6. reboot.

The configure host script will deal with the hostname change and
registering with the controller. Once configured by the controller 
this host should be able to run completely headless for most roles
except for dvswitch.
