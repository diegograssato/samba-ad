#!/bin/bash

. /etc/dhcpd/dhcpd-update-samba-dns.conf || exit 1

ACTION=$1
IP=$2
HNAME=$3

export DOMAIN REALM PRINCIPAL NAMESERVER ZONE DHCPUSERNAME DHCPPASSWORD ACTION IP HNAME

/etc/dhcpd/samba-dnsupdate.sh -m &
