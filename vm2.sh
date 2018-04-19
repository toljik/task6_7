#!/bin/bash

dir=`dirname $0`
cd $dir

. "$dir/vm2.config"

#network
modprobe 8021q
ifdown $INTERNAL_IF
route add -net $INT_IP gw $GW_IP
ifconfig $INTERNAL_IF $INT_IP up
vconfig add $INTERNAL_IF $VLAN
ifconfig $INTERNAL_IF.$VLAN $APACHE_VLAN_IP up

#echo 1 > /proc/sys/net/ipv4/ip_forward

#apache

apt update -y
apt install apache2 -y

APACHE_IP=`echo "$APACHE_VLAN_IP" | awk -F"/" '{print $1}'`

echo "<VirtualHost $APACHE_IP:80>
        ServerName $(hostname)
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html

        ErrorLog  /var/log/apache2/error.log
        CustomLog /var/log/apache2/access.log combined
 </VirtualHost>
" > /etc/apache2/sites-available/$(hostname)

ln -s /etc/apache2/sites-available/$(hostname) /etc/apache2/sites-enabled/$(hostname)
