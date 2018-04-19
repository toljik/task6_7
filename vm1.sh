#!/bin/bash

dir=`dirname $0`
cd $dir

. "$dir/vm1.config"

#network
modprobe 8021q

ifdown $EXTERNAL_IF
ifdown $INTERNAL_IF


if [ $EXT_IP = DHCP ]; then
 dhclient $EXTERNAL_IF
 EXTERNAL_IP=`ip -4 a show $EXTERNAL_IF | grep inet | awk '{ print $2 }'`
else
 ifconfig $EXTERNAL_IF $EXT_IP up
 route add default gw $EXT_GW
fi


ifconfig $INTERNAL_IF $INT_IP up
vconfig add $INTERNAL_IF $VLAN
ifconfig $INTERNAL_IF.$VLAN $VLAN_IP up

#echo 1 > /proc/sys/net/ipv4/ip_forward

#nginx

apt-get update > /dev/null
apt-get install nginx -y > /dev/null

#certs
openssl genrsa -out /etc/ssl/certs/root-ca.key 2048
openssl req -x509 -new -nodes -key /etc/ssl/certs/root-ca.key -sha256 -days 365\
       -out /etc/ssl/certs/root-ca.crt\
       -subj "/C=UA/ST=Kharkiv/L=Kharkiv/O=Mirantis/OU=NURE/CN=$(hostname)/"
openssl genrsa -out /etc/ssl/certs/web.key 2048
openssl req -new\
       -out /etc/ssl/certs/web.csr\
       -key /etc/ssl/certs/web.key\
       -subj "/C=UA/ST=Kharkiv/L=Kharkiv/O=Mirantis/OU=NURE/CN=$(hostname)/"



openssl x509 -req\
       -in /etc/ssl/certs/web.csr\
       -CA /etc/ssl/certs/root-ca.crt\
       -CAkey /etc/ssl/certs/root-ca.key\
       -CAcreateserial\
       -out /etc/ssl/certs/web.crt

cat /etc/ssl/certs/root-ca.crt /etc/ssl/certs/web.crt > /etc/ssl/certs/web-ca.pem

#nginx config

rm -f /etc/nginx/site-available/*
rm -f /etc/nginx/site-enabled/*

echo "server {\
    listen $NGINX_PORT;\
    server_name $(hostname);\
    ssl on; \
    ssl_certificate /etc/ssl/certs/web-ca.crt; \
    ssl_certificate_key /etc/ssl/certs/web.key;\
location / {\
proxy_pass http://$APACHE_VLAN_IP\
}\
}" > /etc/nginx/site-available/$(hostname)


ln -s /etc/nginx/site-avalable /etc/nginx/site-enabled/$(hostname)

service nginx restart



