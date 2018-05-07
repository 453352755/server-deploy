#!/usr/bin/env bash

CLIENT_NAME=$1

#Generate a Client Certificate and Key Pair
cd ~/openvpn-ca
source vars
sed -i 's/--interact//g' build-key
./build-key ${CLIENT_NAME} --assume-yes

KEY_DIR=~/openvpn-ca/keys
OUTPUT_DIR=~/client-configs/files
BASE_CONFIG=~/client-configs/base.conf
IP_ADDRESS=`curl https://api.ipify.org`


cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${CLIENT_NAME}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${CLIENT_NAME}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${IP_ADDRESS}${CLIENT_NAME}.ovpn

