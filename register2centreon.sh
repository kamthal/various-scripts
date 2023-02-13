#!/bin/bash

export LC_ALL=C
#DEBUG=1
#VERBOSE=1
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
    log "FATAL: $*"
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
    OUTPUT=
    local RETURN=
    verbose "# Trying: $@"
    [[ "$DEBUG" ]] && set -x
    OUTPUT="$("$@" 2>&1)"
    RETURN=$?
    [[ "$DEBUG" ]] && set +x

    if [[ ! "$EXPECTED_OUTPUT" ]] && [[ ! "$EXPECTED_OUTPUT_RE" ]] && (( RETURN == 0 )) ; then
        verbose "-> OK"
    elif [[ "$EXPECTED_OUTPUT" ]] && [[ "$OUTPUT" == "$EXPECTED_OUTPUT" ]] ; then
        verbose "-> OK"
    elif [[ "$EXPECTED_OUTPUT_RE" ]] && [[ "$OUTPUT" =~ $EXPECTED_OUTPUT_RE ]] ; then
        verbose "-> OK"
    else
        log "********************************************************************************"
        log "*** Failed command: $@"
        log "*** ERROR ($RETURN)***"
        log "Output '$OUTPUT' does not match '${EXPECTED_OUTPUT:-$EXPECTED_OUTPUT_RE}'"
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
        try apt-get update
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
    if [[ "$REG_OS_FAMILY" == 'rhel' ]] ; then
    cat >/etc/snmp/snmpd.conf <<EOF
com2sec notConfigUser  ${REG_CENTREON_POLLER_IP:-$REG_CENTREON_CENTRAL_IP}       ${REG_MONITORING_PROTOCOL_SNMP_COMMUNITY}
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
    elif [[ "$REG_OS_FAMILY" == 'debian' ]] ; then
        cat >/etc/snmp/snmpd.conf <<EOF
agentaddress udp:161
rocommunity ${REG_MONITORING_PROTOCOL_SNMP_COMMUNITY} ${REG_CENTREON_POLLER_IP:-$REG_CENTREON_CENTRAL_IP}
syslocation Here we are
syscontact Princes of Universe
EOF
    fi

    try systemctl restart "${REG_MONITORING_PROTOCOL_SNMP_SERVICE[$REG_OS_FAMILY]}"
    try systemctl enable "${REG_MONITORING_PROTOCOL_SNMP_SERVICE[$REG_OS_FAMILY]}"
}


REG_OS_FAMILY=
REG_CENTREON_CENTRAL_IP=192.168.58.121
REG_CENTREON_CENTRAL_URL="http://${REG_CENTREON_CENTRAL_IP}"
REG_CENTREON_CENTRAL_LOGIN=admin
REG_CENTREON_CENTRAL_PASSWORD=centreon
REG_CENTREON_POLLER_NAME=Central
REG_CENTREON_POLLER_IP=192.168.58.121
REG_MONITORING_PROTOCOL=SNMP
REG_MONITORING_PROTOCOL_SNMP_COMMUNITY="$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-12} | head -n 1)"
declare -A REG_MONITORING_PROTOCOL_SNMP_PACKAGE
REG_MONITORING_PROTOCOL_SNMP_PACKAGE=([debian]='snmpd' [rhel]='net-snmp' )
REG_MONITORING_PROTOCOL_SNMP_SERVICE=([debian]='snmpd' [rhel]='snmpd' )
debug-var REG_MONITORING_PROTOCOL_SNMP_PACKAGE
REG_HOSTNAME=$(hostname -s)
REG_HOSTALIAS=$(hostname)
REG_HOSTADDRESS=$(hostname -I | awk '{print $NF}')
REG_INSTALL_CMD=
REG_HOST_TEMPLATE=OS-Linux-SNMP-custom
REG_DISK_TEMPLATE=OS-Linux-Disk-Global-SNMP-custom
REG_PROC_TEMPLATE=OS-Linux-Process-Generic-SNMP-custom

#while (( $# > 0 )) ; do
#    arg="$1"
#    case $arg in
#        --help|-h)
#            show-help
#            exit 0
#            ;;
#        --debug)
#            DEBUG=1
#            ;;
#        --verbose)
#            VERBOSE=1
#            ;;
#        *)
#            echo -e "*** Error: Argument '$arg' is not supported\n"
#            show-help
#            exit 1
#        ;;
#    esac
#    shift
#done

# Determine distro name
# Determine distro version
# Determine install command
determine-distro

# install snmpd
install curl "${REG_MONITORING_PROTOCOL_SNMP_PACKAGE[$REG_OS_FAMILY]}"

# configure snmpd
# * community
# * authorized ip
# restart snmpd
# enable snmpd
configure-snmp

# centreon authentication
EXPECTED_OUTPUT=
EXPECTED_OUTPUT_RE=authToken
try curl -s -d 'username='${REG_CENTREON_CENTRAL_LOGIN}'&password='${REG_CENTREON_CENTRAL_PASSWORD} 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=authenticate'
TOKEN="$(echo "$OUTPUT" | sed -e 's/{"authToken":"\(.*\)"}/\1/' | sed -e 's/\\\//\//g')"
debug-var TOKEN

# centreon config host
EXPECTED_OUTPUT=
EXPECTED_OUTPUT_RE='\{"result":\[\]\}|"Object already exists \('${REG_HOSTNAME}'\)"'
try curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"object": "host", "action": "add", "values": "'${REG_HOSTNAME}';'${REG_HOSTALIAS}';'${REG_HOSTADDRESS}';'${REG_HOST_TEMPLATE}';'${REG_CENTREON_POLLER_NAME}';"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'
#curl-apiv1-create-host

EXPECTED_OUTPUT='{"result":[]}'
EXPECTED_OUTPUT_RE=
try curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "host", "action": "setparam", "values": "'${REG_HOSTNAME}';host_snmp_community;'${REG_MONITORING_PROTOCOL_SNMP_COMMUNITY}'"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"

#curl-apiv1-apply-template
EXPECTED_OUTPUT='{"result":[]}'
EXPECTED_OUTPUT_RE=
try curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "host", "action": "applytpl", "values": "'${REG_HOSTNAME}'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'

# curl centreon config disks
oIFS="$IFS"
IFS=$'\n'
REG_DISKS_LIST=($(df --output=target --exclude-type=tmpfs --exclude-type=devtmpfs | grep -v 'Mounted on'))
IFS="$oIFS"
debug-var REG_DISKS_LIST
for disk in "${REG_DISKS_LIST[@]}" ; do
    EXPECTED_OUTPUT=''
    EXPECTED_OUTPUT_RE='\{"result":\[\]\}|"Object already exists"'
    try curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"object": "service", "action": "add", "values": "'${REG_HOSTNAME}';Disk-'${disk}';'${REG_DISK_TEMPLATE}'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'
    EXPECTED_OUTPUT='{"result":[]}'
    EXPECTED_OUTPUT_RE=''
    try curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "service", "action": "setmacro", "values": "'${REG_HOSTNAME}';Disk-'${disk}';filter;^'${disk}'$"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"
done

# config services/processes
oIFS="$IFS"
IFS=$'\n'
REG_SERVICES_LIST=($(systemctl -t service --no-pager --state=enabled --no-legend list-unit-files | awk '{print  $1}'))
IFS="$oIFS"
debug-var REG_SERVICES_LIST
for svc in "${REG_SERVICES_LIST[@]}" ; do
    svcname="${svc%.service}"
    debug-var svc
    #process=$(ps -e -o unit,cmd | sort -u | grep -E '^'$svc | awk '{print $2}')
    oIFS="$IFS"
    IFS=$'\n'
    processes=($(ps -e -o unit,cmd | sort -u | grep '^'"$svc "))
    #processes=($(ps -e -o unit,cmd | grep -E '^'"$svc" | sort -u))
    IFS="$oIFS"
    debug-var processes
    #declare -p processes
    PROC_REGEX='^'"$svc"' +([^:]*:)? ([^ ]+) ?(.*)$'
    list_args=
    current_proc=
    current_proc_nb=0
    for process in "${processes[@]}" ; do
        #declare -p process
        if [[ "$process" =~ $PROC_REGEX ]] ; then
            #declare -p BASH_REMATCH
            pgpath="${BASH_REMATCH[2]}"
            pgexec="${pgpath##*/}"
            pgargs="${BASH_REMATCH[3]}"
            echo "${svc};${pgexec};${pgpath};${pgargs}"
            [[ "$pgargs" ]] && [[ "$list_args" ]] && list_args+='|'
            [[ "$pgargs" ]] && list_args+="${BASH_REMATCH[3]:0:128}"
            debug-var pgpath pgexec pgargs
        else
            fatal "Process '${process}' does not match /${PROC_REGEX}/"
        fi
        debug-var -p list_args
        if [[ "${#processes[@]}" > 1 ]] ; then
            svcsuffix="-${pgexec}"
        else
            svcsuffix=
        fi
        if [[ "$pgexec" != "$current_proc" ]] ; then
            current_proc="$pgexec"
            current_proc_nb=0
            EXPECTED_OUTPUT=''
            EXPECTED_OUTPUT_RE='\{"result":\[\]\}|"Object already exists"'
            try curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"object": "service", "action": "add", "values": "'${REG_HOSTNAME}';Svc-'"${svcname}${svcsuffix}"';'${REG_PROC_TEMPLATE}'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'
            EXPECTED_OUTPUT='{"result":[]}'
            EXPECTED_OUTPUT_RE=''
            try curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "service", "action": "setmacro", "values": "'${REG_HOSTNAME}';Svc-'"${svcname}${svcsuffix}"';processname;^'"${pgexec:0:15}"'$"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"
            try curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "service", "action": "setmacro", "values": "'${REG_HOSTNAME}';Svc-'"${svcname}${svcsuffix}"';processpath;^'"${pgpath:0:128}"'$"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"
        else
            ((current_proc_nb++))
            try curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "service", "action": "setmacro", "values": "'${REG_HOSTNAME}';Svc-'"${svcname}${svcsuffix}"';critical;'"${current_proc_nb}"':"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"
        fi
        #try curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "service", "action": "setmacro", "values": "'${REG_HOSTNAME}';Svc-'${svcname}${svcsuffix}';processargs;'"${list_args}"'"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"

    done
done
# curl centreon config interfaces

EXPECTED_OUTPUT=''
EXPECTED_OUTPUT_RE='Configuration files generated for poller'
try curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"action": "APPLYCFG", "values": "'${REG_CENTREON_POLLER_NAME}'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'


