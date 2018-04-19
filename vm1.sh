#!/bin/bash

dir=`dirname $0`
cd $dir

. "$dir/vm1.config"

#network

ifdown $EXTERNAL_IF
ifdown $INTERNAL_IF

ifconfig $EXTERNAL_IF $EXT_IP up
route add default gw $EXT_GW
ifconfig $INTERNAL_IF $INT_IP up

vconfig add $INTERNAL_IF $VLAN
ifconfig $INTERNAL_IF.$VLAN $VLAN_IP up

echo 1 > /proc/sys/net/ipv4/ip_forward
#nginx

apt-get update
apt-get install nginx -y

#certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/certs/root-ca.key -out /etc/ssl/certs/root-ca.crt –subj "/C=UA/ST=Kharkiv/L=Kharkiv/O=NURE/OU=Mirantis/CN=vm1"
openssl req -newkey -keyout /etc/ssl/certs/web.key –out /etc/ssl/certs/web.csr –subj "/C=UA/ST=Kharkiv/L=Kharkiv/O=NURE/OU=Mirantis/CN=vm1"
#thik about it
open ssl –req -x509 -extfile <(printf "subjectAltName=IP:$EXT_IP") -days 365 in /etc/ssl/certs/web.csr -CA /etc/ssl/certs/root-ca.crt -CAkey /etc/ssl/certs/root-ca.key -CAcreateserial -out /etc/ssl/certs/web.crt
cat /etc/ssl/certs/root-ca.crt /etc/ssl/certs/web.crt > /etc/ssl/certs/web-ca.pem

#nginx config

APACHE_IP=`echo "$APACHE_VLAN_IP" | awk -F"/" '{print $1}'`

rm -f /etc/nginx/site-available/*
rm -f /etc/nginx/site-enabled/*


echo "server {
    listen $NGINX_PORT;
    server_name $(hostname);

    ssl on; 
    ssl_certificate /etc/ssl/certs/web-ca.crt; 
    ssl_certificate_key /etc/ssl/certs/web.key;


location / {
proxy_pass http://$APACHE_IP
}
}" > /etc/nginx/site-available/$(hostname)


ln -s /etc/nginx/site-avalable /etc/nginx/site-enabled/$(hostname)

service nginx restart
