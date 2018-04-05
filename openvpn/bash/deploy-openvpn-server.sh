#!/usr/bin/env bash

KEY_COUNTRY=SG
KEY_PROVINCE=SG
KEY_CITY=Singapore
KEY_ORG=Dummy
KEY_EMAIL=dummy@dummy.com
KEY_OU=Dummy
KEY_NAME=server

#Install OpenVPN
sudo apt-get update
sudo apt-get install openvpn easy-rsa --assume-yes

#Set Up the CA Directory
make-cadir ~/openvpn-ca
cd ~/openvpn-ca

#Configure the CA Variables
sed -i \
 -e 's/KEY_COUNTRY="US"/KEY_COUNTRY="'"$KEY_COUNTRY"'"/g' \
 -e 's/KEY_PROVINCE="CA"/KEY_PROVINCE="'"$KEY_PROVINCE"'"/g' \
 -e 's/KEY_CITY="SanFrancisco"/KEY_CITY="'"$KEY_CITY"'"/g' \
 -e 's/KEY_ORG="Fort-Funston"/KEY_ORG="'"$KEY_ORG"'"/g' \
 -e 's/KEY_EMAIL="me@myhost.mydomain"/KEY_EMAIL="'"$KEY_EMAIL"'"/g' \
 -e 's/KEY_OU="MyOrganizationalUnit"/KEY_OU="'"$KEY_OU"'"/g' \
 -e 's/KEY_NAME="EasyRSA"/KEY_NAME="'"$KEY_NAME"'"/g' \
 vars

#Build the Certificate Authority
cd ~/openvpn-ca
source vars
./clean-all
sed -i 's/--interact//g' build-ca
./build-ca

#Create the Server Certificate, Key, and Encryption Files
sed -i 's/--interact//g' build-key-server
./build-key-server server --assume-yes

./build-dh
openvpn --genkey --secret keys/ta.key

#Configure the OpenVPN Service
cd ~/openvpn-ca/keys
sudo cp ca.crt server.crt server.key ta.key dh2048.pem /etc/openvpn

gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz | sudo tee /etc/openvpn/server.conf

sudo sed -i \
  -e 's/;tls-auth/tls-auth/g' \
  -e 's/;cipher AES-128-CBC/cipher AES-128-CBC \nauth SHA256/g' \
  -e 's/;user nobody/user nobody/g' \
  -e 's/;group nogroup/group nogroup/g' \
  -e 's/;push "redirect-gateway/push "redirect-gateway/g' \
  -e 's/;push "dhcp-option DNS 208.67.222.222"/push "dhcp-option DNS 8.8.8.8"/g' \
  -e 's/;push "dhcp-option DNS 208.67.220.220"/push "dhcp-option DNS 8.8.4.4"/g' \
  -e 's/port 1194/port 443/g' \
  -e 's/;proto tcp/proto tcp/g' \
  -e 's/proto udp/;proto udp/g' \
  /etc/openvpn/server.conf

#Adjust the Server Networking Configuration
sudo sed -i 's/#net.ipv4.ip_forward/net.ipv4.ip_forward/g' /etc/sysctl.conf
sudo sysctl -p

sudo sed -i 's/#   ufw-before-forward/#   ufw-before-forward\n*nat\
:POSTROUTING ACCEPT [0:0]\
-A POSTROUTING -s 10.8.0.0\/8 -o eth0 -j MASQUERADE\
COMMIT/' /etc/ufw/before.rules

sudo sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw

sudo ufw allow 443/tcp
sudo ufw allow OpenSSH
sudo ufw disable
sudo ufw enable --assume-yes

#Start and Enable the OpenVPN Service
sudo systemctl start openvpn@server --no-pager
sudo systemctl status openvpn@server --no-pager
sudo systemctl enable openvpn@server

ip addr show tun0

#Create Client Configuration Infrastructure
mkdir -p ~/client-configs/files
chmod 700 ~/client-configs/files
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf ~/client-configs/base.conf

IP_ADDRESS=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
echo ${IP_ADDRESS}

sed -i \
 -e 's/remote my-server-1 1194/remote '"$IP_ADDRESS"' 443/'\
 -e 's/;proto tcp/proto tcp/;'\
 -e 's/proto udp/;proto udp/;'\
 -e 's/;user nobody/user nobody/g;'\
 -e 's/;group nogroup/group nogroup/g;'\
 -e 's/ca ca.crt/#ca ca.crt/g;'\
 -e 's/cert client.crt/#cert client.crt/g;'\
 -e 's/key client.key/#key client.key\ncipher AES-128-CBC \nauth SHA256\nkey-direction 1/g;'\
 -e '12 a\
# script-security 2\
# up /etc/openvpn/update-resolv-conf\
# down /etc/openvpn/update-resolv-conf'\
 ~/client-configs/base.conf

