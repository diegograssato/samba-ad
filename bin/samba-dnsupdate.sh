#!/bin/bash

# Desativação dos recursos de autenticação via Kerberos pelo: Robson Vaamonde
# Criação das variaveis de DHCPUSERNAME e DHCPPASSWORD
# Modificação das linhas de ADD, DEL e UPD das Zonas.
#

sleep 5

checkvalues()
{
        [ -z "${2}" ] && echo "Error: argument '${1}' requires a parameter." && exit 1

        case ${2} in

                -*)
                        echo "Error: Invalid parameter '${2}' passed to ${1}."
                        exit 1
                ;;

                *)
                        return 0
                ;;
        esac
}

showhelp()
{
echo -e "\n"`basename ${0}` "uses samba-tool to update DNS records in Samba 4's DNS"
echo "server when using INTERNAL DNS or BIND9 DLZ plugin."
echo ""
echo "    Command line options (and variables):"
echo ""
echo "      -a | --action      Action for this script to perform"
echo "                         ACTION={add|delete}"
echo "      -c | --krb5cc      Path of the krb5 credential cache (optional)"
echo "                         Default: KRB5CC=/run/dhcpd.krb5cc"
echo "      -d | --domain      The DNS domain/zone to be updated"
echo "                         DOMAIN={domain.tld}"
echo "      -h | --help        Show this help message and exit"
echo "      -H | --hostname    Hostname of the record to be updated"
echo "                         HNAME={hostname}"
echo "      -i | --ip          IP address of the host to be updated"
echo "                         IP={0.0.0.0}"
echo "      -k | --keytab      Krb5 keytab to be used for authorization (optional)"
echo "                         Default: KEYTAB=/etc/dhcp/dhcpd.keytab"
echo "      -m | --mitkrb5     Use MIT krb5 client utilities"
echo "                         MITKRB5={YES|NO}"
echo "      -n | --nameserver  DNS server to be updated (must use FQDN, not IP)"
echo "                         NAMESERVER={server.internal.domain.tld}"
echo "      -p | --principal   Principal used for DNS updates"
echo "                         PRINCIPAL={user@domain.tld}"
echo "      -r | --realm       Authentication realm"
echo "                         REALM={DOMAIN.TLD}"
echo "      -z | --zone        Then name of the zone to be updated in AD.
echo "                         ZONE={zonename}
echo ""
echo "Example: $(basename $0) -d domain.tld -i 192.168.0.x -n 192.168.0.x \\"
echo "             -r DOMAIN.TLD -p user@domain.tld -H HOSTNAME -m"
echo ""
}

# Process arguments
[ -z "$1" ] && showhelp && exit 1
while [ -n "$1" ]; do
        case $1 in

                -a | --action)
                        checkvalues ${1} ${2}
                        ACTION=${2}
                        shift 2
                ;;

                -c | --krb5cc)
                        checkvalues ${1} ${2}
                        KRB5CC=${2}
                        shift 2
                ;;

                -d | --domain)
                        checkvalues ${1} ${2}
                        DOMAIN=${2}
                        shift 2
                ;;

                -h | --help)
                        showhelp
                        exit 0
                ;;

                -H | --hostname)
                        checkvalues ${1} ${2}
                        HNAME=${2%%.*}
                        shift 2
                ;;

                -i | --ip)
                        checkvalues ${1} ${2}
                        IP=${2}
                        shift 2
                ;;

                -k | --keytab)
                        checkvalues ${1} ${2}
                        KEYTAB=${2}
                        shift 2
                ;;

                -m | --mitkrb5)
                        KRB5MIT=YES
                        shift 1
                ;;

                -n | --nameserver)
                        checkvalues ${1} ${2}
                        NAMESERVER=${2}
                        shift 2
                ;;

                -p | --principal)
                        checkvalues ${1} ${2}
                        PRINCIPAL=${2}
                        shift 2
                ;;

                -r | --realm)
                        checkvalues ${1} ${2}
                        REALM=${2}
                        shift 2
                ;;

                -z | --zone)
                        checkvalues ${1} ${2}
                        ZONE=${2}
                        shift 2
                ;;

                *)
                        echo "Error!!! Unknown command line opion!"
                        echo "Try" `basename $0` "--help."
                        exit 1
                ;;
        esac
done

# Sanity checking
[ -z "$ACTION" ] && echo "Error: action not set." && exit 2
case "$ACTION" in
        add | Add | ADD)
                ACTION=ADD
        ;;
        del | delete | Delete | DEL | DELETE)
                ACTION=DEL
        ;;
        *)
                echo "Error: invalid action \"$ACTION\"." && exit 3
        ;;
esac
#Desativado o recurso de integração com o Kerberos, falha na execução
#[ -z "$KRB5CC" ] && KRB5CC=/run/dhcpd.krb5cc
#[ -z "$KRB5CC" ] && KRB5CC=/tmp/krb5cc_0
[ -z "$DOMAIN" ] && echo "Error: invalid domain." && exit 4
[ -z "$HNAME" ] && [ "$ACTION" == "ADD" ] && \
     echo "Error: hostname not set." && exit 5
[ -z "$IP" ] && echo "Error: IP address not set." && exit 6
#Desativado o recurso de integração de chaves de criptografia com o dhcp, falha na execução
#[ -z "$KEYTAB" ] && KEYTAB=/etc/dhcp/dhcpd/dhcpd.keytab
[ -z "$NAMESERVER" ] && echo "Error: nameservers not set." && exit 7
[ -z "$PRINCIPAL" ] && echo "Error: principal not set." && exit 8
[ -z "$REALM" ] && echo "Error: realm not set." && exit 9
[ -z "$ZONE" ] && echo "Error: zone not set." && exit 10
[ -z "$DHCPUSERNAME" ] && echo "Error: DHCP Username not set." && exit 11
[ -z "$DHCPPASSWORD" ] && echo "Error: DHCP Password not set." && exit 12


# Disassemble IP for reverse lookups
OCT1=$(echo $IP | cut -d . -f 1)
OCT2=$(echo $IP | cut -d . -f 2)
OCT3=$(echo $IP | cut -d . -f 3)
OCT4=$(echo $IP | cut -d . -f 4)
RZONE="$OCT3.$OCT2.$OCT1.in-addr.arpa"

#Desativação a validação do kerberos e chaves com o dhcp
#kerberos_creds() {
#export KRB5_KTNAME="$KEYTAB"
#export KRB5CCNAME="$KRB5CC"

#if [ "$KRB5MIT" = "YES" ]; then
#    KLISTARG="-s"
#else
#    KLISTARG="-t"
#fi

#klist $KLISTARG || kinit -k -t "$KEYTAB" -c "$KRB5CC" "$PRINCIPAL" || { logger -s -p daemon.error -t dhcpd kinit for dynamic DNS failed; exit 11; }
#}

#Linhas modificadas, foi acrescentado as opções -U $DHCPUSERNAME --password=$DHCPPASSWORD
add_host(){
    logger -s -p daemon.info -t dhcpd Adding A record for host $HNAME with IP $IP to zone $ZONE on server $NAMESERVER
    samba-tool dns add $NAMESERVER $ZONE $HNAME A $IP -k yes -U $DHCPUSERNAME --password=$DHCPPASSWORD
}


delete_host(){
    logger -s -p daemon.info -t dhcpd Removing A record for host $HNAME with IP $IP from zone $ZONE on server $NAMESERVER
    samba-tool dns delete $NAMESERVER $ZONE $HNAME A $IP -k yes -U $DHCPUSERNAME --password=$DHCPPASSWORD
}


update_host(){
    logger -s -p daemon.info -t dhcpd Removing A record for host $HNAME with IP $CURIP from zone $ZONE on server $NAMESERVER
    samba-tool dns delete $NAMESERVER $ZONE $HNAME A $CURIP -k yes -U $DHCPUSERNAME --password=$DHCPPASSWORD
    add_host
}


add_ptr(){
    logger -s -p daemon.info -t dhcpd Adding PTR record $OCT4 with hostname $HNAME to zone $RZONE on server $NAMESERVER
    samba-tool dns add $NAMESERVER $RZONE $OCT4 PTR $HNAME.$DOMAIN -k yes -U $DHCPUSERNAME --password=$DHCPPASSWORD
}


delete_ptr(){
    logger -s -p daemon.info -t dhcpd Removing PTR record $OCT4 with hostname $HNAME from zone $RZONE on server $NAMESERVER
    samba-tool dns delete $NAMESERVER $RZONE $OCT4 PTR $HNAME.$DOMAIN -k yes -U $DHCPUSERNAME --password=$DHCPPASSWORD
}


update_ptr(){
    logger -s -p daemon.info -t dhcpd Removing PTR record $OCT4 with hostname $CURHNAME from zone $RZONE on server $NAMESERVER
    samba-tool dns delete $NAMESERVER $RZONE $OCT4 PTR $CURHNAME -k yes -U $DHCPUSERNAME --password=$DHCPPASSWORD
    add_ptr
}


case "$ACTION" in
    ADD)
        #kerberos_creds
        host -t A $HNAME.$DOMAIN > /dev/null
        if [ "${?}" == 0 ]; then
          CURIP=$(host -t A $HNAME.$DOMAIN | cut -d " " -f 4 )
          if [[ "$CURIP" != "$IP" ]]; then
             update_host
          fi
        else
           add_host
        fi

        host -t PTR $IP > /dev/null
        if [ "${?}" == 0 ]; then
           CURHNAME=$(host -t PTR $IP | cut -d " " -f 5 | rev | cut -c 2- | rev)
           if [[ "$CURHNAME" != "$HNAME.$DOMAIN" ]]; then
              update_ptr
           fi
        else
           add_ptr
        fi
    ;;

    DEL)
        #kerberos_creds
        host -t A $HNAME.$DOMAIN > /dev/null
        if [ "${?}" == 0 ]; then
            delete_host
        fi

        host -t PTR $IP > /dev/null
        if [ "${?}" == 0 ]; then
            delete_ptr
        fi
    ;;

    *)
        echo "Error: Invalid action '$ACTION'!" && exit 12
    ;;

esac
