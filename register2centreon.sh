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
}

REG_OS_FAMILY=
REG_CENTREON_CENTRAL_URL=http://192.168.58.121
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
configure-snmp
# * community
# * authorized ip
# restart snmpd
# enable snmpd
# curl centreon authentication
# curl centreon config host
# curl centreon config disks
# curl centreon config services/processes
# curl centreon config interfaces
# curl centreon config 
# curl centreon config 
# 

