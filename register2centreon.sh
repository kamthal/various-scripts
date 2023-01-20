#!/bin/bash

DEBUG=1
VERBOSE=1
#LOG_FILE="${0%.sh}.log"
LOG_FILE="register2centreon.log"

function debug() {
    [[ "$DEBUG" ]] && log "$*"
}
function debug-var() {
        debug "$(declare -p $1)"
}

function verbose() {
    [[ "$VERBOSE" ]] && log "$*"
}

function log() {
    echo "$*" | tee -a "$LOG_FILE"
}

function fatal(){
    log "$*"
    exit 1
}

function show-help() {
    cat <<EOH
       -h, --help
              Display help text and exit.  No other output is generated.
       --debug
              Enable debug messages
       --verbose
              Enable verbose messages
EOH
}

function try() {
    local OUTPUT=
    local RETURN=
    log "# Trying: $*"
    OUTPUT="$($* 2>&1)"
    RETURN=$?
    if (( RETURN == 0 )) ; then
        log "-> OK"
    else
        log "********************************************************************************"
        log "*** ERROR ($RETURN)***"
        log "$OUTPUT"
        log "********************************************************************************"
        exit
    fi
}

function determine-distro() {
    if [[ -f /etc/debian_version ]] ; then
        verbose "System is Debian-based"
        REG_INSTALL_CMD='apt-get'
        REG_OS_FAMILY=debian
        debug-var REG_INSTALL_CMD
    elif [[ -f /etc/redhat-release ]] ; then
        verbose "System is RHEL-based"
        REG_INSTALL_CMD='yum'
        REG_OS_FAMILY=rhel
    else
        fatal "System is unsupported"
    fi
}

function install() {
    try ${REG_INSTALL_CMD} install -y $*
}
function configure-snmp() {
    cat >/etc/snmp/snmpd.conf <<EOF
com2sec notConfigUser  ${REG_CENTREON_POLLER:-$REG_CENTREON_POLLER}       ${REG_MONITORING_PROTOCOL_SNMP_COMMUNITY}
group   notConfigGroup v2c           notConfigUser
access notConfigGroup "" any noauth exact centreon none none
syslocation Unknown (edit /etc/snmp/snmpd.conf)
syscontact Root <root@localhost> (configure /etc/snmp/snmp.local.conf)
access  notConfigGroup ""      any       noauth    exact  systemview none none
dontLogTCPWrappersConnects yes
view centreon included .1.3.6.1
view    systemview    included   .1.3.6.1.2.1.1
view    systemview    included   .1.3.6.1.2.1.25.1.1
includeAllDisks 5%
EOF
    systemctl restart "${REG_MONITORING_PROTOCOL_SNMP_SERVICE[$REG_OS_FAMILY]}"
    systemctl enable "${REG_MONITORING_PROTOCOL_SNMP_SERVICE[$REG_OS_FAMILY]}"
}

REG_OS_FAMILY=
REG_CENTREON_CENTRAL_IP=192.168.58.121
REG_CENTREON_CENTRAL_URL="http://${REG_CENTREON_CENTRAL_IP}"
REG_CENTREON_CENTRAL_LOGIN=admin
REG_CENTREON_CENTRAL_PASSWORD=centreon
REG_CENTREON_POLLER=192.168.58.121
REG_MONITORING_PROTOCOL=SNMP
REG_MONITORING_PROTOCOL_SNMP_COMMUNITY=public
declare -A REG_MONITORING_PROTOCOL_SNMP_PACKAGE
REG_MONITORING_PROTOCOL_SNMP_PACKAGE=([debian]='snmpd', [rhel]='net-snmp')
REG_MONITORING_PROTOCOL_SNMP_SERVICE=([debian]='snmpd', [rhel]='snmpd')
debug-var REG_MONITORING_PROTOCOL_SNMP_PACKAGE

REG_INSTALL_CMD=

while (( $# > 0 )) ; do
    arg="$1"
    case $arg in
        --help|-h)
            show-help
            exit 0
            ;;
        --debug)
            DEBUG=1
            ;;
        --verbose)
            VERBOSE=1
            ;;
        *)
            echo -e "*** Error: Argument '$arg' is not supported\n"
            show-help
            exit 1
        ;;
    esac
    shift
done

# Determine distro name
# Determine distro version
# Determine install command
determine-distro
# install snmpd
install "${REG_MONITORING_PROTOCOL_SNMP_PACKAGE[$REG_OS_FAMILY]}"
# configure snmpd
# * community
# * authorized ip
# restart snmpd
# enable snmpd
configure-snmp
# curl centreon authentication
TOKEN="$(curl -s -d 'username='${REG_CENTREON_CENTRAL_LOGIN}'&password='${REG_CENTREON_CENTRAL_PASSWORD} 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=authenticate' | sed -e 's/{"authToken":"\(.*\)"}/\1/')"
debug-var TOKEN
# curl centreon config host
REG_HOSTNAME=$(hostname -s)
REG_HOSTALIAS=$(hostname -f)
REG_HOSTADDRESS=$(hostname -I | awk '{print $NF}')
curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"object": "host", "action": "add", "values": "'${REG_HOSTNAME}';'${REG_HOSTALIAS}';'${REG_HOSTADDRESS}';OS-Linux-SNMP-custom;Central;"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'

# curl centreon config disks
IFS=$'\n' REG_DISKS_LIST=($(df --output=target --exclude-type=tmpfs --exclude-type=devtmpfs | grep -v 'Mounted on'))
debug-var REG_DISKS_LIST
# curl centreon config services/processes
IFS=$'\n' REG_SERVICES_LIST=($(systemctl -t service --no-pager --state=enabled --no-legend list-unit-files | awk '{print  $1}'))
# curl centreon config interfaces
# curl centreon config 
# curl centreon config 
# 

