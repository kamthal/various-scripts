#!/bin/bash

DEBUG=
VERBOSE=
LOG_FILE="${0%.sh}.log"

function debug() {
    [[ "$DEBUG" ]] && log "$*"
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
        debug "$(declare -p REG_INSTALL_CMD)"
    elif [[ -f /etc/redhat-release ]] ; then
        verbose "System is RHEL-based"
        REG_INSTALL_CMD='dnf'
    else
        fatal "System is unsupported"
    fi
}

function install() {
    try ${REG_INSTALL_CMD} install -y $*
}

REG_MONITORING_PROTOCOL=SNMP
REG_MONITORING_PROTOCOL_SNMP_COMMUNITY=public
declare -A REG_MONITORING_PROTOCOL_SNMP_PACKAGE
REG_MONITORING_PROTOCOL_SNMP_PACKAGE=([debian]='snmpd', [el7]='net-snmp', [el8]='net-snmp', [el9]='net-snmp')
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
# configure snmpd
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

