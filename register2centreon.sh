#!/bin/bash

set -eEo pipefail
export LC_ALL=C
#DEBUG=1
#VERBOSE=1
#LOG_FILE="${0%.sh}.log"
LOG_FILE="register2centreon.log"
# get environment variables
declare -r \
    log_verbosity="info" \
    REG_CENTREON_CENTRAL_IP=192.168.58.121 \
    REG_CENTREON_CENTRAL_LOGIN=admin \
    REG_CENTREON_CENTRAL_PASSWORD=centreon \
    REG_CENTREON_POLLER_NAME=Central \
    REG_CENTREON_POLLER_IP=192.168.58.121

declare \
    REG_OS_FAMILY=
# set default values

declare -A REG_MONITORING_PROTOCOL_SNMP_PACKAGE=(
    [debian]='snmpd' 
    [rhel]='net-snmp'
)

declare -A REG_MONITORING_PROTOCOL_SNMP_SERVICE=(
    [debian]='snmpd' 
    [rhel]='snmpd' 
)

REG_HOSTNAME=$(hostname -s)
REG_HOSTALIAS=$(hostname)
REG_HOSTADDRESS=$(hostname -I | awk '{print $NF}')
REG_MONITORING_PROTOCOL_SNMP_COMMUNITY="$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-12} | head -n 1)"

REG_INSTALL_CMD=
REG_HOST_TEMPLATE=OS-Linux-SNMP-custom
REG_DISK_TEMPLATE=OS-Linux-Disk-Global-SNMP-custom
REG_PROC_TEMPLATE=OS-Linux-Process-Generic-SNMP-custom

function crash {
    declare -r ret_code=$?
    echo >&2 "Entering crash($*)"
    declare \
        i=1 \
        j \
        line \
        file \
        func \
        indents="|  " \
        array_results=()

    echo >&2 "Call stack trace:"
    while read -r line func file < <(caller $i) ; do
        array_results+=("[$file:$line].$func(): $(sed -n "${line}p" "$file")")
        i=$((i+1))
    done
    for (( j=${#array_results[@]} - 1 ; j>=0 ; j-- )) ; do
        echo >&2 "${indents}${array_results[j]}"
        indents+="    "
    done
    
    exit $ret_code
}

trap crash EXIT

function log {
    local log_level="$1"
    shift
    case "$log_level" in
        debug)
            if [[ "$log_verbosity" =~ ^(verbose|info|warning|error|fatal)$ ]] ; then
                return 0
            fi
            ;;
        verbose)
            if [[ "$log_verbosity" =~ ^(info|warning|error|fatal)$ ]] ; then
                return 0
            fi
            ;;
        info)
            if [[ "$log_verbosity" =~ ^(warning|error|fatal)$ ]] ; then
                return 0
            fi
            ;;
        warning)
            if [[ "$log_verbosity" =~ ^(error|fatal)$ ]] ; then
                return 0
            fi
            ;;
        error|fatal)
            ;;
        *)
            echo >&2 "[$(date "+%F %H:%M:%S")] [fatal] log_level '$log_level' not supported"
            return 1
            ;;
    esac
    echo >&2 "[$(date "+%F %H:%M:%S")] [${log_level}] $*"
}



function show-help {
    cat <<EOH
       -h, --help
              Display help text and exit.  No other output is generated.
       --debug
              Enable debug messages
       --verbose
              Enable verbose messages
EOH
}

function try {
    log "debug" "Entering try($*)"
    declare -r \
        expected_output="$1" \
        expected_output_re="$2"
    shift 2 # args 1 and 2 already stored
    declare \
        output="" \
        ret_code
    log "verbose" "Trying: " "$@"
    [[ "$TRACE" ]] && set -x
    output="$("$@")"
    ret_code=$?
    [[ "$TRACE" ]] && set +x

    if [[ ! "$expected_output" ]] && [[ ! "$expected_output_re" ]] && (( ret_code == 0 )) ; then
        log "debug" "-> OK with ret_code"
    elif [[ "$expected_output" ]] && [[ "$output" == "$expected_output" ]] ; then
        log "debug" "-> OK with expected output"
    elif [[ "$expected_output_re" ]] && [[ "$output" =~ $expected_output_re ]] ; then
        log "debug" "-> OK with expected output by regex"
    else
        log "error" "Failed command: returned $ret_code - Output '$output' does not match '${expected_output:-$expected_output_re}'"
        return 1
    fi
    log "debug" "Ending try()"
}

function determine_distro {
    log "debug" "Entering determine_distro($*)"
    log "info" "Determining distro family"
    [[ -n "$TRACE" ]] && set -x
    if [[ -f /etc/debian_version ]] ; then
        log "verbose" "System is Debian-based"
        REG_INSTALL_CMD="apt-get"
        REG_INSTALL_OPTS="-y"
        REG_OS_FAMILY=debian
        log "debug" "$(declare -p REG_INSTALL_CMD)"
        try "" "" "$REG_INSTALL_CMD" ${REG_INSTALL_OPTS} update
    elif [[ -f /etc/redhat-release ]] ; then
        log "verbose" "System is RHEL-based"
        REG_INSTALL_CMD='yum'
        REG_INSTALL_OPTS="-yb"
        REG_OS_FAMILY=rhel
    else
        log "fatal" "System is unsupported"
        return 1
    fi
    [[ -n "$TRACE" ]] && set +x
    log "debug" "Ending determine_distro()"
}

function install {
    log "debug" "Entering install($*)"
    log "info" "Installing $*"
    try "" "" "$REG_INSTALL_CMD" "$REG_INSTALL_OPTS" install "$@"
    log "debug" "Ending install()"
}

function get_host_name {
    log "debug" "Entering get_host_name()"
    echo "$(hostname -s)-$(date +%s)"
    log "debug" "Ending get_host_name()" 
    return 0
}

function get_host_alias {
    log "debug" "Entering get_host_alias()"
    hostname
    log "debug" "Ending get_host_alias()" 
    return 0
}

function get_host_address {
    log "debug" "Entering get_host_address()"
    hostname -I | awk '{print $NF}'
    log "debug" "Ending get_host_address()" 
    return 0
}

function configure_snmp() {
    log "debug" "Entering configure_nrpe()"
    log "info" "Configuring NRPE"
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

    try "" "" systemctl restart "${REG_MONITORING_PROTOCOL_SNMP_SERVICE[$REG_OS_FAMILY]}"
    try "" "" systemctl enable "${REG_MONITORING_PROTOCOL_SNMP_SERVICE[$REG_OS_FAMILY]}"
}


function apiv1_authenticate {
    log "debug" "Entering apiv1_authenticate($*)"
    declare \
        output="" \
        token=""

    output="$(curl -s -d 'username='${REG_CENTREON_CENTRAL_LOGIN}'&password='${REG_CENTREON_CENTRAL_PASSWORD} 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=authenticate')"
    if [[ ! "$output" =~ authToken ]] ; then
        log "fatal" "Authentication failed. Output '$output' does not match 'authToken'"
    else
        log "verbose" "Authentication succeeded"
    fi
    [[ -n "$TRACE" ]] && set -x
    token="$(echo "$output" | sed -e 's/{"authToken":"\(.*\)"}/\1/' | sed -e 's/\\\//\//g')"
    [[ -n "$TRACE" ]] && set +x
    log "debug" "$(declare -p token)"
    printf "%s" "$token"
    log "debug" "Ending apiv1_authenticate()"
    return 0
}

function apiv1_create_host {
    log "debug" "Entering apiv1_create_host($*)"
    declare -r \
        token="$1" \
        host_name="$2" \
        host_alias="$3" \
        host_address="$4"
    declare -r \
        host_creation_expected_regex='\{"result":\[\]\}|"Object already exists \('${host_name}'\)"' \
        apply_tpl_expected_output='{"result":[]}'
    declare \
        output=""
        
    [[ "$TRACE" ]] && set -x
    output="$(curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$token" -d '{"object": "host", "action": "add", "values": "'"${host_name}"';'"${host_alias}"';'"${host_address}"';'"${REG_HOST_TEMPLATE}"';'"${REG_CENTREON_POLLER_NAME}"';"}' -X POST 'http://'"${REG_CENTREON_CENTRAL_IP}"'/centreon/api/index.php?action=action&object=centreon_clapi')"
    [[ "$TRACE" ]] && set +x
    if [[ ! "$output" =~ $host_creation_expected_regex ]] ; then
        log "fatal" "Creating host: output '$output' does not match '$host_creation_expected_regex'"
        return 1
    else
        log "verbose" "Host creation succeeded"
    fi

    log "info" "Applying the template"
    [[ "$TRACE" ]] && set -x
    output="$(curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $token" -d '{"object": "host", "action": "applytpl", "values": "'"${host_name}"'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi')"
    [[ "$TRACE" ]] && set +x
    if [[ "$output" != "$apply_tpl_expected_output" ]] ; then
        log "fatal" "Applying template: Output '$output' does not match '$apply_tpl_expected_output'"
        return 1
    else
        log "verbose" "Host template application succeeded"
    fi
    log "debug" "Ending apiv1_create_host()" 
    return 0
}

function apiv1_create_service_systemd_svc {
    log "debug" "Entering apiv1_create_service_systemd_svc($*)"
    declare -r \
        token="$1" \
        host_name="$2" \
        svc_name="$3"
    declare -r \
        expected_output='{"result":[]}'
    declare \
        output=""
    log "verbose" "Creating the service to monitor the systemd svc"
    [[ "$TRACE" ]] && set -x
    output="$(curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$token" -d '{"object": "service", "action": "add", "values": "'"$host_name"';Svc-'"$svc_name"';'"$REG_CMD_TEMPLATE"'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi')"
    [[ "$TRACE" ]] && set +x
    if [[ "$output" != "$expected_output" ]] ; then
        log "fatal" "Service creation: output '$output' does not match '$expected_output'"
        return 1
    else
        log "verbose" "Service created"
    fi
    log "verbose" "Setting the NRPECOMMAND macro"
    [[ "$TRACE" ]] && set -x
    output="$(curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $token" -d '{"object": "service", "action": "setmacro", "values": "'"$host_name"';Svc-'"$svc_name"';nrpecommand;check_svc_'"${svc_name}"'"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi")"
    [[ "$TRACE" ]] && set +x
    if [[ "$output" != "$expected_output" ]] ; then
        log "fatal" "Service NRPECOMMAND macro: output '$output' does not match '$expected_output'"
        return 1
    else
        log "verbose" "Service NRPECOMMAND macro succeeded"
    fi
    # Add the right command in the NRPE configuration
    log "verbose" "Adding the right command in the NRPE configuration"
    cat >>"${REG_MONITORING_PROTOCOL_NRPE_CONFD[$REG_OS_FAMILY]}/custom-centreon.cfg" <<EOF
command[check_svc_${svc_name}]=/usr/lib/centreon/plugins/centreon_linux_local.pl --plugin os::linux::local::plugin --mode systemd-sc-status --filter-name='^${svc_name}.service\$\$' --critical-total-running='1:'
EOF
    log "debug" "Ending apiv1_create_service_systemd_svc()" 
    return 0
}

function apiv1_create_service_disk {
    log "debug" "Entering apiv1_create_service_disk($*)"
    declare -r \
        token="$1" \
        host_name="$2" \
        disk_name="$3"
    declare -r \
        expected_setmacro_output='{"result":[]}' \
        expected_creation_output_regex='\{"result":\[\]\}|"Object already exists"'
    declare \
        output=""
    log "verbose" "Creating the service to monitor the disk"
    [[ "$TRACE" ]] && set -x
    output="$(curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$token" -d '{"object": "service", "action": "add", "values": "'"${host_name}"';Disk-'"${disk_name}"';'"${REG_CMD_TEMPLATE}"'"}' -X POST 'http://'"${REG_CENTREON_CENTRAL_IP}"'/centreon/api/index.php?action=action&object=centreon_clapi')"
    [[ "$TRACE" ]] && set +x
    if [[ ! "$output" =~ $expected_creation_output_regex ]] ; then
        log "fatal" "Disk service creation: output '$output' does not match '$expected_creation_output_regex'"
        return 1
    else
        log "verbose" "Service created"
    fi
    log "verbose" "Setting the NRPECOMMAND macro"
    [[ "$TRACE" ]] && set -x
    output="$(curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $token" -d '{"object": "service", "action": "setmacro", "values": "'"${host_name}"';Disk-'"${disk_name}"';nrpecommand;check_disk_'"${disk_name}"'"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi")"
    [[ "$TRACE" ]] && set +x
    if [[ "$output" != "$expected_setmacro_output" ]] ; then
        log "fatal" "Service NRPECOMMAND macro: output '$output' does not match '$expected_setmacro_output'"
        return 1
    else
        log "verbose" "Service NRPECOMMAND macro succeeded"
    fi
    # Add the right command in the NRPE configuration
    log "verbose" "Adding the right command in the NRPE configuration"
    cat >>"${REG_MONITORING_PROTOCOL_NRPE_CONFD[$REG_OS_FAMILY]}/custom-centreon.cfg" <<EOF
command[check_disk_${disk_name}]=/usr/lib/centreon/plugins/centreon_linux_local.pl --plugin os::linux::local::plugin --mode storage --filter-mountpoint='^${disk_name}\$\$' --warning-usage='80' --critical-usage='90'
EOF
    log "debug" "Ending apiv1_create_service_disk()" 
    return 0
}

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
configure_snmp

# centreon authentication
try "" "authToken" curl -s -d 'username='${REG_CENTREON_CENTRAL_LOGIN}'&password='${REG_CENTREON_CENTRAL_PASSWORD} 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=authenticate'
TOKEN="$(echo "$OUTPUT" | sed -e 's/{"authToken":"\(.*\)"}/\1/' | sed -e 's/\\\//\//g')"
debug-var TOKEN

# centreon config host
try "" '\{"result":\[\]\}|"Object already exists \('${REG_HOSTNAME}'\)"' curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"object": "host", "action": "add", "values": "'${REG_HOSTNAME}';'${REG_HOSTALIAS}';'${REG_HOSTADDRESS}';'${REG_HOST_TEMPLATE}';'${REG_CENTREON_POLLER_NAME}';"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'
#curl-apiv1-create-host

try '{"result":[]}' "" curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "host", "action": "setparam", "values": "'${REG_HOSTNAME}';host_snmp_community;'${REG_MONITORING_PROTOCOL_SNMP_COMMUNITY}'"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"

#curl-apiv1-apply-template

try '{"result":[]}' "" curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "host", "action": "applytpl", "values": "'${REG_HOSTNAME}'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'

# curl centreon config disks
oIFS="$IFS"
IFS=$'\n'
REG_DISKS_LIST=($(df --output=target --exclude-type=tmpfs --exclude-type=devtmpfs | grep -v 'Mounted on'))
IFS="$oIFS"
debug-var REG_DISKS_LIST
for disk in "${REG_DISKS_LIST[@]}" ; do
    try "" '\{"result":\[\]\}|"Object already exists"' curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"object": "service", "action": "add", "values": "'${REG_HOSTNAME}';Disk-'${disk}';'${REG_DISK_TEMPLATE}'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'
    try '{"result":[]}' "" curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "service", "action": "setmacro", "values": "'${REG_HOSTNAME}';Disk-'${disk}';filter;^'${disk}'$"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"
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
    oIFS="$IFS"
    IFS=$'\n'
    processes=($(ps -e -o unit,cmd | sort -u | grep '^'"$svc "))
    IFS="$oIFS"
    debug-var processes
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
            try "" '\{"result":\[\]\}|"Object already exists"' curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"object": "service", "action": "add", "values": "'${REG_HOSTNAME}';Svc-'"${svcname}${svcsuffix}"';'${REG_PROC_TEMPLATE}'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'
            try '{"result":[]}' "" curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "service", "action": "setmacro", "values": "'${REG_HOSTNAME}';Svc-'"${svcname}${svcsuffix}"';processname;^'"${pgexec:0:15}"'$"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"
            try '{"result":[]}' "" curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "service", "action": "setmacro", "values": "'${REG_HOSTNAME}';Svc-'"${svcname}${svcsuffix}"';processpath;^'"${pgpath:0:128}"'$"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"
        else
            ((current_proc_nb++))
            try '{"result":[]}' "" curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "service", "action": "setmacro", "values": "'${REG_HOSTNAME}';Svc-'"${svcname}${svcsuffix}"';critical;'"${current_proc_nb}"':"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"
        fi
        #try curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "service", "action": "setmacro", "values": "'${REG_HOSTNAME}';Svc-'${svcname}${svcsuffix}';processargs;'"${list_args}"'"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"

    done
done
# curl centreon config interfaces


try "" 'Configuration files generated for poller' curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"action": "APPLYCFG", "values": "'${REG_CENTREON_POLLER_NAME}'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'


