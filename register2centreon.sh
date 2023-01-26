#!/bin/bash

export LC_ALL=C
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
    OUTPUT=
    local RETURN=
    log "# Trying: $*"
    [[ "$DEBUG" ]] && set -x
    $*
    [[ "$DEBUG" ]] && set +x
    OUTPUT="$($* 2>&1)"
    RETURN=$?

    if [[ ! "$EXPECTED_OUTPUT" ]] && [[ ! "$EXPECTED_OUTPUT_RE" ]] && (( RETURN == 0 )) ; then
        log "-> OK"
    elif [[ "$EXPECTED_OUTPUT" ]] && [[ "$OUTPUT" == "$EXPECTED_OUTPUT" ]] ; then
        log "-> OK"
    elif [[ "$EXPECTED_OUTPUT_RE" ]] && [[ "$OUTPUT" =~ $EXPECTED_OUTPUT_RE ]] ; then
        log "-> OK"
    else
        log "********************************************************************************"
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
com2sec notConfigUser  ${REG_CENTREON_POLLER:-$REG_CENTREON_CENTRAL_IP}       ${REG_MONITORING_PROTOCOL_SNMP_COMMUNITY}
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
rocommunity ${REG_MONITORING_PROTOCOL_SNMP_COMMUNITY} ${REG_CENTREON_POLLER:-$REG_CENTREON_CENTRAL_IP}
syslocation Here we are
syscontact Princes of Universe
EOF
    fi

    systemctl restart "${REG_MONITORING_PROTOCOL_SNMP_SERVICE[$REG_OS_FAMILY]}"
    systemctl enable "${REG_MONITORING_PROTOCOL_SNMP_SERVICE[$REG_OS_FAMILY]}"
}

function curl-apiv1-authenticate() {
    local EXPECTED_OUTPUT_RE=authToken
    TOKEN="$(curl -s -d 'username='${REG_CENTREON_CENTRAL_LOGIN}'&password='${REG_CENTREON_CENTRAL_PASSWORD} 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=authenticate' | sed -e 's/{"authToken":"\(.*\)"}/\1/' | sed -e 's/\\\//\//g')"
    debug-var TOKEN
}

function curl-apiv1-authenticate() {
    EXPECTED_OUTPUT_RE=authToken
    try curl -s -d 'username='${REG_CENTREON_CENTRAL_LOGIN}'&password='${REG_CENTREON_CENTRAL_PASSWORD} 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=authenticate'
    TOKEN="$(echo "$OUTPUT" | sed -e 's/{"authToken":"\(.*\)"}/\1/' | sed -e 's/\\\//\//g')"
    debug-var TOKEN
}

function curl-apiv1-create-host() {
    local EXPECTED_OUTPUT_RE='{"result":[]}|"Object already exists ('${REG_HOSTNAME}')"'
    curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"object": "host", "action": "add", "values": "'${REG_HOSTNAME}';'${REG_HOSTALIAS}';'${REG_HOSTADDRESS}';OS-Linux-SNMP-custom;Central;"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi' > "${TMP_DIR}/create_host_output.json"
    RET=$?
    debug-var RET
    [[ "$RET" == 0 ]] || fatal "Return code for host creation: $RET"
    OUTPUT="$(cat ${TMP_DIR}/create_host_output.json)"
    [[ "$OUTPUT" == "$EXPECTED_OUTPUT" ]] || [[ "$OUTPUT" == '"Object already exists ('${REG_HOSTNAME}')"' ]] || fatal "Unexpected output for host creation: '$OUTPUT'"
}

function curl-apiv1-create-host() {
    EXPECTED_OUTPUT_RE='{"result":[]}|"Object already exists \('${REG_HOSTNAME}'\)"'
    try curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"object": "host", "action": "add", "values": "'${REG_HOSTNAME}';'${REG_HOSTALIAS}';'${REG_HOSTADDRESS}';OS-Linux-SNMP-custom;Central;"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'
}

function curl-apiv1-set-host-community() {
    local EXPECTED_OUTPUT='{"result":[]}'
    curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"object": "host", "action": "setparam", "values": "'${REG_HOSTNAME}';host_snmp_community;'${REG_MONITORING_PROTOCOL_SNMP_COMMUNITY}';'${REG_HOSTADDRESS}';OS-Linux-SNMP-custom;Central;"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi' > "${TMP_DIR}/create_host_output.json"
    RET=$?
    debug-var RET
    [[ "$RET" == 0 ]] || fatal "Return code for host creation: $RET"
    OUTPUT="$(cat ${TMP_DIR}/create_host_output.json)"
    [[ "$OUTPUT" == "$EXPECTED_OUTPUT" ]] || [[ "$OUTPUT" == '"Object already exists (central-deb-22-10)"' ]] || fatal "Unexpected output for host community: '$OUTPUT'"
}

function curl-apiv1-apply-template() {
    local EXPECTED_OUTPUT='{"result":[]}'
    curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"object": "host", "action": "applytpl", "values": "'${REG_HOSTNAME}'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi' > "${TMP_DIR}/apply_tpl_output.json"
    RET=$?
    debug-var RET
    [[ "$RET" == 0 ]] || fatal "Return code for template application: $RET"
    OUTPUT="$(cat ${TMP_DIR}/apply_tpl_output.json)"
    [[ "$OUTPUT" == "$EXPECTED_OUTPUT" ]] || fatal "Unexpected output for apply template: '$OUTPUT'"
}

function curl-apiv1-apply-cfg() {
    local EXPECTED_OUTPUT='{"result":[]}'
    curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"action": "APPLYCFG", "values": "1"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi' > "${TMP_DIR}/apply_cfg_output.json"
    debug-var RET
    [[ "$RET" == 0 ]] || fatal "Return code for config application: $RET"
    OUTPUT="$(cat ${TMP_DIR}/apply_cfg_output.json)"
    [[ "$OUTPUT" == "$EXPECTED_OUTPUT" ]] || fatal "Unexpected output for apply cfg: '$OUTPUT'"
}
REG_OS_FAMILY=
REG_CENTREON_CENTRAL_IP=192.168.58.121
REG_CENTREON_CENTRAL_URL="http://${REG_CENTREON_CENTRAL_IP}"
REG_CENTREON_CENTRAL_LOGIN=admin
REG_CENTREON_CENTRAL_PASSWORD=centreon
REG_CENTREON_POLLER=192.168.58.121
REG_MONITORING_PROTOCOL=SNMP
REG_MONITORING_PROTOCOL_SNMP_COMMUNITY="$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-12} | head -n 1)"
declare -A REG_MONITORING_PROTOCOL_SNMP_PACKAGE
REG_MONITORING_PROTOCOL_SNMP_PACKAGE=([debian]='snmpd' [rhel]='net-snmp' )
REG_MONITORING_PROTOCOL_SNMP_SERVICE=([debian]='snmpd' [rhel]='snmpd' )
debug-var REG_MONITORING_PROTOCOL_SNMP_PACKAGE
REG_HOSTNAME=$(hostname -s)
REG_HOSTALIAS=$(hostname -f)
REG_HOSTADDRESS=$(hostname -I | awk '{print $NF}')
TMP_DIR="$(mktemp -d)"
debug-var TMP_DIR
[[ "$TMP_DIR" && -d "$TMP_DIR" ]] || fatal "error with mktemp"

REG_INSTALL_CMD=

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
install "${REG_MONITORING_PROTOCOL_SNMP_PACKAGE[$REG_OS_FAMILY]}"

# configure snmpd
# * community
# * authorized ip
# restart snmpd
# enable snmpd
configure-snmp

# curl centreon authentication
#curl-apiv1-authenticate
EXPECTED_OUTPUT_RE=authToken
try curl -s -d 'username='${REG_CENTREON_CENTRAL_LOGIN}'&password='${REG_CENTREON_CENTRAL_PASSWORD} 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=authenticate'
TOKEN="$(echo "$OUTPUT" | sed -e 's/{"authToken":"\(.*\)"}/\1/' | sed -e 's/\\\//\//g')"
debug-var TOKEN

# curl centreon config host
#curl-apiv1-create-host
EXPECTED_OUTPUT=
EXPECTED_OUTPUT_RE='\{"result":\[\]\}|"Object already exists \('${REG_HOSTNAME}'\)"'
try curl -s --header Content-Type:application/json --header "centreon-auth-token:${TOKEN}" -d "{\"object\":\"host\",\"action\":\"add\",\"values\":\"${REG_HOSTNAME};${REG_HOSTALIAS};${REG_HOSTADDRESS};OS-Linux-SNMP-custom;Central;\"}" -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"

#curl-apiv1-set-host-community
EXPECTED_OUTPUT_RE=
EXPECTED_OUTPUT='{"result":[]}'
try curl -s --header 'Content-Type:application/json' --header "centreon-auth-token:$TOKEN" -d "{\"object\":\"host\",\"action\":\"setparam\",\"values\":\"${REG_HOSTNAME};host_snmp_community;${REG_MONITORING_PROTOCOL_SNMP_COMMUNITY};${REG_HOSTADDRESS};OS-Linux-SNMP-custom;Central;\"}" -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"
curl-apiv1-apply-template

curl-apiv1-apply-cfg

# curl centreon config disks
IFS=$'\n' REG_DISKS_LIST=($(df --output=target --exclude-type=tmpfs --exclude-type=devtmpfs | grep -v 'Mounted on'))
debug-var REG_DISKS_LIST
# curl centreon config services/processes
IFS=$'\n' REG_SERVICES_LIST=($(systemctl -t service --no-pager --state=enabled --no-legend list-unit-files | awk '{print  $1}'))
debug-var REG_SERVICES_LIST
# curl centreon config interfaces
# curl centreon config 
# curl centreon config 
# 

#rm -fr "$TMP_DIR"
