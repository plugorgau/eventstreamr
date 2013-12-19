#!/bin/bash

hostname=
controller=
ipaddress=
netmask=
gateway=
dns=
existing=`hostname`

gitdone=$1
ipaddr=`ifdata -pa eth0`
homedir="/home/av"
confdir="$homedir/eventstreamr/baseimage"
ctrl_settings="$homedir/eventstreamr/station/settings.json"
log="/tmp/station-mgr.log"


function valid_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# initial banner (shown all the time)
echo "
--- eventstreamr HOST CONFIGURATION SCRIPT ---

This should be run after imaging to setup some initial stuff but the
main thing being setting the hostname and turning eventstreamr on. 
"

# some checks before continuing
if [ "$EUID" -ne 0 ]; then
	echo "ERROR: need to run with sudo"
	exit 1
fi

if [ -z "$gitdone" ]; then
    echo -n "update eventstreamr from git (y/n) [n]? "
    read REPLY
    if [ "$REPLY" == "y" ]; then
        su - av -c "cd $confdir; git pull"
        echo "restarting script in 3 seconds ..."
        sleep 3
        reset
        exec $0 gitdone
    fi
fi



# gather configuration information

echo -n "hostname for this system: "
read hostname
if [ -z "$hostname" ]; then
    echo "invalid hostname, exiting ..."
    exit 1;
fi

echo -n "static IP for this system (empty=DHCP): "
read ipaddress
if [ -n "$ipaddress" ]; then
    if ! valid_ip $ipaddress; then
        echo "invalid IP address, exiting ..."
	exit 1;
    fi

    echo -n "netmask (255.255.255.0): "
    read netmask
    if [ -n "$netmask"  ]; then
        if ! valid_ip $netmask; then
            echo "invalid netmask, exiting ..."
    	exit 1;
        fi
    else
        netmask="255.255.255.0"
    fi
   
    gateway_guess=`echo $ipaddress | cut -d"." -f1-3`
    gateway_guess="$gateway_guess.1" 
    echo -n "gateway ($gateway_guess): "
    read gateway
    if [ -n "$gateway"  ]; then
        if ! valid_ip $gateway; then
            echo "invalid gateway IP, exiting ..."
    	exit 1;
        fi
    else
        gateway=$gateway_guess
    fi

    echo -n "DNS ($gateway): "
    read dns
    if [ -n "$dns"  ]; then
        if ! valid_ip $dns; then
            echo "invalid DNS IP, exiting ..."
    	exit 1;
        fi
    else
        dns=$gateway
    fi
else
    ipaddress="<dhcp>"
fi


echo -n "controller IP address: "
read controller
if ! valid_ip $controller; then
    echo "invalid IP address, exiting ..."
    exit 1;
fi



# echo back responses and ask for confirmation

echo "
--- CONFIM SETTINGS ---

   Hostname: $hostname"
if [ "$ipaddress" != "<dhcp>" ]; then
    echo " IP Address: $ipaddress / $netmask
    Gateway: $gateway
        DNS: $dns"
else
    echo " IP Address: $ipaddress"
fi
echo " Controller: $controller
"

echo -n "continue (y/n) [n]? "
read REPLY
if [ "$REPLY" != "y" ]; then
    echo "exiting..."
    exit 0;
fi
echo ""



# OK do stuff now with the configuration information
echo "
--- DOING STUFF! ---
"

echo "- clearing desktop icons"
rm -f $homedir/Desktop/*

echo "- writing controller config"
echo "{
   \"controller\" : \"$controller\",
   \"logpath\" : \"/tmp/station-mgr.log\",
}" > $ctrl_settings

echo "- configuring networking"
if [ "$ipaddress" = "<dhcp>" ]; then
    rm -f /etc/init/network-manager.override
    echo "auto lo
iface lo inet loopback
" > /etc/network/interfaces
else
    echo "manual" > /etc/init/network-manager.override
    echo "auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $ipaddress
    network $netmask
    gateway $gateway
    dns-nameservers $dns
" > /etc/network/interfaces
fi


echo "- updating /etc/hosts"
sed -i "s/${existing}/${hostname}/g" /etc/hosts
echo "- updating /etc/hostname"
sed -i "s/${existing}/${hostname}/g" /etc/hostname


echo "- updating /etc/rc.local to start eventstreamr bits"
cp $confdir/rc.local /etc/rc.local

echo "- fix grub"
/usr/sbin/grub-install /dev/sda
/usr/sbin/update-grub


echo "- done: REBOOTING NOW (in 10 seconds)"
sleep 10
shutdown -r now

exit 0
