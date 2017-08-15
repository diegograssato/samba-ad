#!/bin/bash

set -e

SAMBA_DOMAIN=${SAMBA_DOMAIN:-SAMDOM}
SAMBA_REALM=${SAMBA_REALM:-SAMDOM.EXAMPLE.COM}
LDAP_ALLOW_INSECURE=${LDAP_ALLOW_INSECURE:-false}
SAMBA_DNS_BACKEND=${SAMBA_DNS_BACKEND:-SAMBA_INTERNAL}
SAMBA_ROLE=${SAMBA_ROLE:-dc}
SAMBA_HOST_IP="${SAMBA_HOST_IP:-$(hostname --all-ip-addresses |cut -f 1 -d' ')}"
DHCP_USER="dhcpduser"
DHCP_PASS="!P@ssw0rd123456"
SAMBA_CONF_BACKUP=/var/lib/samba/private/smb.conf
SSSD_CONF_BACKUP=/var/lib/samba/private/sssd.conf
KRB_CONF_BACKUP=/var/lib/samba/private/krb5.conf
KRBKEYTAP_CONF_BACKUP=/var/lib/samba/private/krb5.keytab

echo "SELINUX=enforcing" > /etc/selinux/config
echo "SELINUXTYPE=ubuntu" >> /etc/selinux/config
echo "SETLOCALDEFS=0" >> /etc/selinux/config


appSetup () {
    echo "Initializing samba database..."

    # Generate passwords or re-use them from the environment
    ROOT_PASSWORD=${ROOT_PASSWORD:-$(pwgen -c -n -1 12)}
    SAMBA_ADMIN_PASSWORD=${SAMBA_ADMIN_PASSWORD:-$(pwgen -cny 10 1)}
    SAMBA_DNS=${SAMBA_DNS:-SAMBA_INTERNAL}

    echo "root:${ROOT_PASSWORD}" | chpasswd
    echo Root password: ${ROOT_PASSWORD}
    echo Samba administrator password: $SAMBA_ADMIN_PASSWORD

    # Provision Samba
    rm -f /etc/samba/smb.conf
    rm -rf /var/lib/samba/private/*
    samba-tool domain provision \
              --use-rfc2307 \
              --domain=${SAMBA_DOMAIN} \
              --use-xattr=no \
              --use-ntvfs \
              --realm=${SAMBA_REALM} \
              --server-role=${SAMBA_ROLE}\
              --dns-backend=${SAMBA_DNS_BACKEND} \
              --adminpass=${SAMBA_ADMIN_PASSWORD}  \
              --adminpass=${SAMBA_ADMIN_PASSWORD}  \
              --host-ip=${SAMBA_HOST_IP}

    cp -v /var/lib/samba/private/krb5.conf /etc/krb5.conf
    if [ "${LDAP_ALLOW_INSECURE,,}" == "true" ]; then
  	  sed -i "/\[global\]/a \
  	    \\\t\# enable unencrypted passwords\n\
      	ldap server require strong auth = no\
      	" /etc/samba/smb.conf
	  fi
    sed -i "s/SAMBA_REALM/${SAMBA_REALM}/" /etc/sssd/sssd.conf
    samba-tool domain passwordsettings set --complexity=off

    KRB5_SSSD_HOSTNAME=$(hostname -s)
    samba-tool domain exportkeytab /etc/krb5.sssd.keytab --principal=$KRB5_SSSD_HOSTNAME\$
    klist -k /etc/krb5.sssd.keytab

    echo "Configure create home dir on longin"
    echo "session    required    pam_mkhomedir.so    skel=/etc/skel/    umask=0022" >> /etc/pam.d/common-session
    echo "Set adminsitrator admin computer"
    echo "administrator   ALL=(ALL:ALL) ALL" >>/etc/sudoers
    echo "%${SAMBA_DOMAIN}\\\domain\ admins ALL=(ALL:ALL) ALL" >>  /etc/sudoers

    mkdir -p /var/cache/bind
    chown bind. -R /var/cache/bind -R
    echo "domain ${SAMBA_REALM}" > /etc/resolv.conf
    echo "nameserver ${SAMBA_HOST_IP}" >> /etc/resolv.conf

    if [[ ${SAMBA_DHCP} == "true" ]]; then
      samba-tool user create dhcpduser --description="Unprivileged user for TSIG-GSSAPI DNS updates via ISC DHCP server" ${DHCP_PASS}
      samba-tool user setexpiry dhcpduser --noexpiry
      samba-tool group addmembers DnsAdmins ${DHCP_USER}
      #samba-tool domain exportkeytab /etc/dhcpd/dhcpd.keytab --principal=dhcpduser@$SAMBA_REALM
      samba-tool domain exportkeytab /etc/dhcpd/dhcp-dns.keytab --principal=${DHCP_USER}@$SAMBA_REALM
      samba-tool domain exportkeytab /etc/dhcpd/dhcp-dns.keytab --principal=DNS/${HOSTNAME}@$SAMBA_REALM

    fi


    if [[ ${SAMBA_TLS} == "true" ]];then
      SAMBA_TLS_KEY_PEM="/var/lib/samba/private/tls/${SAMBA_REALM,,}.key.pem"
      SAMBA_TLS_KEY_CSR="/var/lib/samba/private/tls/${SAMBA_REALM,,}.csr.pem"
      SAMBA_TLS_KEY_CERT="/var/lib/samba/private/tls/${SAMBA_REALM,,}.cert.pem"
      openssl genrsa -out ${SAMBA_TLS_KEY_PEM} 2048 -config /usr/lib/ssl/openssl.cnf
      openssl req -key ${SAMBA_TLS_KEY_PEM} -new -sha256 \
              -config /usr/lib/ssl/openssl.cnf \
              -subj "/C=KG/ST=NA/O=OpenVPN-TEST/CN=Test-Server-DSA/emailAddress=me@myhost.mydomain" \
              -out ${SAMBA_TLS_KEY_CSR}

    sed -i "/\[global\]/a \
        \\\t\# Enable TLS\n\
        tls keyfile  = /var/lib/samba/private/tls/${SAMBA_REALM}.key.pem\n\
        tls certfile  = /var/lib/samba/private/tls/${SAMBA_REALM}.kert.pem\n\
        tls cafile  = \n\
        " /etc/samba/smb.conf

    fi
    echo "Generating backup"
    cp -v /etc/samba/smb.conf ${SAMBA_CONF_BACKUP}
    cp -v /etc/sssd/sssd.conf ${SSSD_CONF_BACKUP}
    cp -v /etc/krb5.conf ${KRB_CONF_BACKUP}
    [ -f $KRBKEYTAP_CONF_BACKUP ] && cp $KRBKEYTAP_CONF_BACKUP /etc/krb5.keytab

    if [[ ${SAMBA_DNS_BACKEND} == "BIND9_DLZ" ]]; then
      echo "[program:bind9]" >> /etc/supervisor/conf.d/supervisord.conf
      echo "command=/usr/sbin/named -c /etc/bind/named.conf -u bind -f"  >> /etc/supervisor/conf.d/supervisord.conf
    else
      apt-get remove bind9 dnsutils -y
    fi

    # if [[ ${SAMBA_ENABLE_NTP} == "true" ]];then
    #   echo "[program:ntp]" >> /etc/supervisor/conf.d/supervisord.conf
    #   echo "command=/usr/sbin/named -c /etc/bind/named.conf -u bind -f"  >> /etc/supervisor/conf.d/supervisord.conf
    #
    #   chown root:ntp /var/lib/samba/ntp_signd/
    #   chmod 750 -R /var/lib/samba/ntp_signd/
    #
    # else
    #   apt-get remove ntp -y
    # fi

}

appStart () {
    if [ -f ${SAMBA_CONF_BACKUP} ]; then

        echo "Skipping setup and restore configurations..."
        cp ${SAMBA_CONF_BACKUP} /etc/samba/smb.conf
        cp ${SSSD_CONF_BACKUP} /etc/sssd/sssd.conf
        cp ${KRB_CONF_BACKUP} /etc/krb5.conf

    else
        appSetup
    fi

    # Start the services
    /usr/bin/supervisord
}

appHelp () {
	echo "Available options:"
	echo " app:start          - Starts all services needed for Samba AD DC"
	echo " app:setup          - First time setup."
	echo " app:setup_start    - First time setup and start."
	echo " app:help           - Displays the help"
	echo " [command]          - Execute the specified linux command eg. /bin/bash."
}

case "$1" in
	app:start)
		appStart
		;;
	app:setup)
		appSetup
		;;
	app:setup_start)
		appSetup
		appStart
		;;
	app:help)
		appHelp
		;;
	*)
		if [ -x $1 ]; then
			$1
		else
			prog=$(which $1)
			if [ -n "${prog}" ] ; then
				shift 1
				$prog $@
			else
				appHelp
			fi
		fi
		;;
esac

exit 0
