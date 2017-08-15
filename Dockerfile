 FROM ubuntu:trusty

MAINTAINER Diego Perera Grassato <diego.grassato@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

# Avoid ERROR: invoke-rc.d: policy-rc.d denied execution of start.
# Prevent services autoload (http://jpetazzo.github.io/2013/10/06/policy-rc-d-do-not-start-services-automatically/)
RUN echo '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d

RUN apt-get update -qq

# Install samba and dependencies to make it an Active Directory Domain Controller
RUN DEBIAN_FRONTEND=noninteractive  apt-get install -y build-essential libacl1-dev libattr1-dev expect pwgen \
      libblkid-dev libgnutls-dev libreadline-dev python-dev libpam0g-dev \
      python-dnspython gdb pkg-config libpopt-dev libldap2-dev ldap-utils \
      dnsutils libbsd-dev acl attr krb5-user docbook-xsl libcups2-dev acl python-xattr
RUN apt-get install -y samba smbclient winbind ntp bind9 dnsutils rsyslog openssh-server supervisor

# Install sssd for UNIX logins to AD
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y isc-dhcp-server ldb-tools sssd sssd-tools libpam-sss libnss-sss libnss-ldap
ADD sssd.conf /etc/sssd/sssd.conf
RUN chmod 0600 /etc/sssd/sssd.conf

# apt-get upgrade -y  &&
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get purge -y && \
    apt-get clean -y && \
    apt-get autoclean -y && \
    apt-get autoremove -y && \
    rm -rf /usr/share/locale/* && \
    rm -rf /var/cache/* && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /usr/share/doc/

# Install bind9 dns server
ADD named.conf.options /etc/bind/named.conf.options

RUN mkdir -p /var/run/sshd
RUN mkdir -p /var/log/supervisor
RUN sed -ri 's/PermitRootLogin without-password/PermitRootLogin Yes/g' /etc/ssh/sshd_config

# Create run directory for bind9
RUN mkdir -p /var/run/named
RUN chown -R bind:bind /var/run/named

# Add custom script
ADD custom.sh /usr/local/bin/custom.sh
ADD dhcpd/dhcpd.conf /etc/dhcpd/dhcpd.conf
COPY bin/* /etc/dhcpd/
RUN chmod +x /usr/local/bin/custom.sh && chmod +x /etc/dhcpd/*.sh

# Add supervisord and init
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD docker-entrypoint.sh /bin/docker-entrypoint.sh
RUN chmod 755 /bin/docker-entrypoint.sh

#VOLUME ["/var/lib/samba", "/etc/samba"]
EXPOSE 22 53 389 88 135 139 138 445 464 3268 3269 67/udp 67/tcp
ENTRYPOINT ["/bin/docker-entrypoint.sh"]
CMD ["app:start"]
