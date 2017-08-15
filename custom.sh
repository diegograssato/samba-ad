#!/bin/bash

#
# Custom script
#


# add groups
samba-tool group add GRP-ADMIN
samba-tool group add GRP-MANAGER
samba-tool group add GRP-AGENT
samba-tool group add GRP-COMPLIANCE

# add users
samba-tool user add user ia4uV1EeKait
samba-tool user add user2 ia4uV1EeKait
samba-tool user add user3 ia4uV1EeKait
samba-tool user add user4 ia4uV1EeKait

# add users to groups
samba-tool group addmembers GRP-ADMIN user
samba-tool group addmembers GRP-MANAGER user2,user
samba-tool group addmembers GRP-AGENT user3
samba-tool group addmembers GRP-COMPLIANCE user4

samba-tool user add admin 12345678
samba-tool user setexpiry admin --noexpiry
samba-tool group addmembers "Domain admins" admin

if [[ -n ${SAMBA_DNS_REVERSA_ADDR} ]];then

  echo "Creating reversezone ${SAMBA_DNS_REVERSA_ADDR} to ${SAMBA_REALM,,} domain."
  #samba-tool dns zonecreate ${SAMBA_REALM,,} ${SAMBA_DNS_REVERSA_ADDR} -U Administrator --password=${SAMBA_ADMIN_PASSWORD}
  # samba-tool dns zonecreate ${SAMBA_REALM,,} 10.in-addr.arpa -U Administrator --password=${SAMBA_ADMIN_PASSWORD}
  #samba-tool dns zonelist ${SAMBA_REALM,,} --reverse -U Administrator --password=${SAMBA_ADMIN_PASSWORD}

fi
# supervisorctl restart samba
# supervisorctl restart bind9
# supervisorctl restart sssd
# sss_cache -UG
#
# ad_hostname = ad.dtux.org
# ad_server = ad.dtux.org
# ad_domain = dtux.org
#samba-tool dns zonecreate ${SAMBA_REALM,,} ${SAMBA_DNS_REVERSA_ADDR} -U Administrator --password=${SAMBA_ADMIN_PASSWORD}
 # host -t A ad.dtux.org.
 # host -t SRV _kerberos._udp.dtux.org.
#samba_dnsupdate --all-names
