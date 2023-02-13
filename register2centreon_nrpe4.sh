#!/bin/bash

export LC_ALL=C
DEBUG=1
VERBOSE=1
#LOG_FILE="${0%.sh}.log"
LOG_FILE="register2centreon.log"

REG_OS_FAMILY=
REG_CENTREON_CENTRAL_IP=192.168.58.121
REG_CENTREON_CENTRAL_URL="http://${REG_CENTREON_CENTRAL_IP}"
REG_CENTREON_CENTRAL_LOGIN=admin
REG_CENTREON_CENTRAL_PASSWORD=centreon
REG_CENTREON_POLLER_NAME=Central
REG_CENTREON_POLLER_IP=192.168.58.121
REG_MONITORING_PROTOCOL=NRPE
REG_MONITORING_PROTOCOL_SNMP_COMMUNITY="$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-12} | head -n 1)"
declare -A REG_MONITORING_PROTOCOL_NRPE_PACKAGE REG_MONITORING_PROTOCOL_NRPE_SERVICE
REG_MONITORING_PROTOCOL_NRPE_PACKAGE=([debian]='nagios-nrpe-server' [rhel]='nrpe' )
REG_MONITORING_PROTOCOL_NRPE_SERVICE=([debian]='nagios-nrpe-server' [rhel]='nrpe.service' )
REG_HOSTNAME=$(hostname -s)
REG_HOSTALIAS=$(hostname)
REG_HOSTADDRESS=$(hostname -I | awk '{print $NF}')
REG_INSTALL_CMD=
REG_HOST_TEMPLATE=OS-Linux-NRPE4
REG_DISK_TEMPLATE=OS-Linux-Disks-NRPE3-custom
REG_PROC_TEMPLATE=OS-Linux-Process-Generic-NRPE3-custom

function debug() {
    [[ "$DEBUG" ]] && log "$*"
}

function debug-var() {
        debug "$(declare -p $*)"
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

function configure-nrpe() {
    sed -Ei 's/^allowed_hosts=(.*)$/allowed_hosts=127.0.0.1,::1,'${REG_CENTREON_POLLER_IP:-$REG_CENTREON_CENTRAL_IP}'/' /etc/nagios/nrpe.cfg
    openssl req -batch -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 -keyout /etc/nagios/server.key -out /etc/nagios/server.crt
    chmod 644 /etc/nagios/server.*
    mkdir -p /var/lib/centreon/centplugins/
    chown nagios: /var/lib/centreon/centplugins/
    sed -Ei 's/^#?ssl_cert_file=.*$/ssl_cert_file=\/etc\/nagios\/server.crt/' /etc/nagios/nrpe.cfg
    sed -Ei 's/^#?ssl_privatekey_file=.*$/ssl_privatekey_file=\/etc\/nagios\/server.key/' /etc/nagios/nrpe.cfg
    #This works:
    #/usr/lib/centreon/plugins/centreon_protocol_nrpe.pl --plugin apps::protocols::nrpe::plugin --mode query --custommode nrpe --hostname 192.168.58.126 --command check_fake --ssl-opt="SSL_verify_mode => SSL_VERIFY_NONE"
    cat >/etc/nagios/nrpe.d/custom-centreon.cfg <<EOF
command[check_host]=/bin/echo "NRPE4: OK"
command[check_cpu]=/usr/lib/centreon/plugins/centreon_linux_local.pl --plugin os::linux::local::plugin --mode  cpu --warning-average=80 --critical-average=90
command[check_cpu_detailed]=/usr/lib/centreon/plugins/centreon_linux_local.pl --plugin os::linux::local::plugin --mode  cpu-detailed
command[check_load]=/usr/lib/centreon/plugins/centreon_linux_local.pl --plugin os::linux::local::plugin --mode load --warning 2,3,4 --critical=4,5,6 --average
command[check_memory]=/usr/lib/centreon/plugins/centreon_linux_local.pl --plugin os::linux::local::plugin --mode memory --warning-memory-usage-prct=80 --critical-memory-usage-prct=90
EOF
    try systemctl restart "${REG_MONITORING_PROTOCOL_NRPE_SERVICE[$REG_OS_FAMILY]}"
    try systemctl enable "${REG_MONITORING_PROTOCOL_NRPE_SERVICE[$REG_OS_FAMILY]}"
}


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
install curl "${REG_MONITORING_PROTOCOL_NRPE_PACKAGE[$REG_OS_FAMILY]}" centreon-plugin-operatingsystems-linux-local

# configure snmpd
# * community
# * authorized ip
# restart snmpd
# enable snmpd
configure-nrpe

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

#EXPECTED_OUTPUT='{"result":[]}'
#EXPECTED_OUTPUT_RE=
#try curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "host", "action": "setparam", "values": "'${REG_HOSTNAME}';host_snmp_community;'${REG_MONITORING_PROTOCOL_SNMP_COMMUNITY}'"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"

#curl-apiv1-apply-template
EXPECTED_OUTPUT='{"result":[]}'
EXPECTED_OUTPUT_RE=
try curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "host", "action": "applytpl", "values": "'${REG_HOSTNAME}'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'
exit
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
    #process=$(ps -e -o unit,exe | grep -E '^'$svc | awk '{print $2}' | sort -u)
    #debug-var process
    #[[ "$process" ]] || continue
    #EXPECTED_OUTPUT=''
    #EXPECTED_OUTPUT_RE='\{"result":\[\]\}|"Object already exists"'
    #try curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"object": "service", "action": "add", "values": "'${REG_HOSTNAME}';Svc-'${svc%.service}';'${REG_PROC_TEMPLATE}'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'
    #EXPECTED_OUTPUT='{"result":[]}'
    #EXPECTED_OUTPUT_RE=''
    #try curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "service", "action": "setmacro", "values": "'${REG_HOSTNAME}';Svc-'${svc%.service}';processname;'${process##*/}'"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"
    #try curl -s --header "Content-Type: application/json" --header "centreon-auth-token: $TOKEN" -d '{"object": "service", "action": "setmacro", "values": "'${REG_HOSTNAME}';Svc-'${svc%.service}';processpath;'${process}'"}' -X POST "http://${REG_CENTREON_CENTRAL_IP}/centreon/api/index.php?action=action&object=centreon_clapi"
done
# curl centreon config interfaces

EXPECTED_OUTPUT=''
EXPECTED_OUTPUT_RE='Configuration files generated for poller'
try curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$TOKEN" -d '{"action": "APPLYCFG", "values": "'${REG_CENTREON_POLLER_NAME}'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'


