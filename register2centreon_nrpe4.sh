#!/bin/bash

set -eEo pipefail
export LC_ALL=C

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

declare -A REG_MONITORING_PROTOCOL_NRPE_PACKAGE=(
    [debian]='nagios-nrpe-server'
    [rhel]='nrpe'
)

declare -A REG_MONITORING_LOCAL_PLUGIN=(
    [debian]='centreon-plugin-operatingsystems-linux-local'
    [rhel]='centreon-plugin-Operatingsystems-Linux-Local'
)

declare -A REG_MONITORING_PROTOCOL_NRPE_SERVICE=(
    [debian]='nagios-nrpe-server'
    [rhel]='nrpe.service'
)

declare -A REG_MONITORING_PROTOCOL_NRPE_CONFD=(
    [debian]='/etc/nagios/nrpe.d/'
    [rhel]='/etc/nrpe.d/'
)

REG_INSTALL_CMD=
REG_HOST_TEMPLATE=OS-Linux-NRPE4
REG_CMD_TEMPLATE=OS-Linux-Generic-Command-NRPE4

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

function prepare_distro {
    log "debug" "Entering prepare_distro()"
    log "info" "Preparing the OS"
    if [[ "$REG_OS_FAMILY" == 'debian' ]] ; then
        cat >/etc/apt/sources.list.d/centreon.list <<EOF
deb https://apt.centreon.com/repository/22.10/ $(lsb_release -sc) main
#deb https://apt.centreon.com/repository/22.10-testing/ $(lsb_release -sc) main
#deb https://apt.centreon.com/repository/22.10-unstable/ $(lsb_release -sc) main
EOF
        log "verbose" "Centreon repo installed"
        wget -qO- https://apt-key.centreon.com | gpg --dearmor > /etc/apt/trusted.gpg.d/centreon.gpg
        log "verbose" "GPG key added"
        apt-get update
        log "verbose" "Package db updated"
    fi
    install curl "${REG_MONITORING_PROTOCOL_NRPE_PACKAGE[$REG_OS_FAMILY]}" "${REG_MONITORING_LOCAL_PLUGIN[$REG_OS_FAMILY]}"
    log "debug" "Ending prepare_distro()"
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

function configure_nrpe {
    log "debug" "Entering configure_nrpe()"
    log "info" "Configuring NRPE"
    try "" "" sed -Ei 's/^allowed_hosts=(.*)$/allowed_hosts=127.0.0.1,::1,'${REG_CENTREON_POLLER_IP:-$REG_CENTREON_CENTRAL_IP}'/' /etc/nagios/nrpe.cfg
    try "" "" openssl req -batch -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 -keyout /etc/nagios/server.key -out /etc/nagios/server.crt 2>/dev/null
    try "" "" chmod 644 /etc/nagios/server.*
    try "" "" mkdir -p /var/lib/centreon/centplugins/
    try "" "" chown nagios: /var/lib/centreon/centplugins/
    try "" "" sed -Ei 's/^#?ssl_cert_file=.*$/ssl_cert_file=\/etc\/nagios\/server.crt/' /etc/nagios/nrpe.cfg
    try "" "" sed -Ei 's/^#?ssl_privatekey_file=.*$/ssl_privatekey_file=\/etc\/nagios\/server.key/' /etc/nagios/nrpe.cfg
    #This works:
    #/usr/lib/centreon/plugins/centreon_protocol_nrpe.pl --plugin apps::protocols::nrpe::plugin --mode query --custommode nrpe --hostname 192.168.58.126 --command check_fake --ssl-opt="SSL_verify_mode => SSL_VERIFY_NONE"
    cat >"${REG_MONITORING_PROTOCOL_NRPE_CONFD[$REG_OS_FAMILY]}/custom-centreon.cfg" <<'EOF'
command[check_nrpe]=/bin/echo "NRPE4: OK"
command[check_cpu]=/usr/lib/centreon/plugins/centreon_linux_local.pl --plugin os::linux::local::plugin --mode  cpu --warning-average=80 --critical-average=90
command[check_cpu_detailed]=/usr/lib/centreon/plugins/centreon_linux_local.pl --plugin os::linux::local::plugin --mode  cpu-detailed
command[check_load]=/usr/lib/centreon/plugins/centreon_linux_local.pl --plugin os::linux::local::plugin --mode load --warning 2,3,4 --critical=4,5,6 --average
command[check_memory]=/usr/lib/centreon/plugins/centreon_linux_local.pl --plugin os::linux::local::plugin --mode memory --warning-memory-usage-prct=80 --critical-memory-usage-prct=90
EOF
    try "" "" systemctl restart "${REG_MONITORING_PROTOCOL_NRPE_SERVICE[$REG_OS_FAMILY]}"
    try "" "" systemctl enable "${REG_MONITORING_PROTOCOL_NRPE_SERVICE[$REG_OS_FAMILY]}"
    log "debug" "Ending configure_nrpe()"
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


function main {
    log "debug" "Entering main($*)"
    declare \
        token=""
    declare -r \
        host_name="$(get_host_name)" \
        host_alias="$(get_host_alias)" \
        host_address="$(get_host_address)"

    # Determine distro name
    # Determine distro version
    # Determine install command
    determine_distro
    prepare_distro
    configure_nrpe
    
    # centreon authentication
    log "info" "Authenticating"    
    token="$(apiv1_authenticate)"

    # centreon config host
    log "info" "Creating the host"
    apiv1_create_host "$token" "$host_name" "$host_alias" "$host_address"
        
    # config services/processes
    log "info" "Discovering the services"
    oIFS="$IFS"
    IFS=$'\n'
    REG_SERVICES_LIST=($(systemctl -t service --no-pager --state=enabled --no-legend list-unit-files | awk '{print  $1}'))
    IFS="$oIFS"
    log "debug" "$(declare -p REG_SERVICES_LIST)"
    log "info" "Creating the services"
    for svc in "${REG_SERVICES_LIST[@]}" ; do
        svcname="${svc%.service}"
        log "verbose" "Creating svc '$svc'"
        apiv1_create_service_systemd_svc "$token" "$host_name" "$svcname"
    done
    
    # curl centreon config disks
    log "info" "Discovering the disks"
    oIFS="$IFS"
    IFS=$'\n'
    REG_DISKS_LIST=($(df --output=target --exclude-type=tmpfs --exclude-type=devtmpfs | grep -v 'Mounted on'))
    IFS="$oIFS"
    log "debug" "$(declare -p REG_DISKS_LIST)"
    log "info" "Creating the disks"
    for disk in "${REG_DISKS_LIST[@]}" ; do
        log "verbose" "Creating disk '$disk'"
        apiv1_create_service_disk "$token" "$host_name" "$disk"
        
    done
    
    # curl centreon config interfaces
    log "info" "Restarting NRPE"
    try "" "" systemctl restart "${REG_MONITORING_PROTOCOL_NRPE_SERVICE[$REG_OS_FAMILY]}"

    log "info" "Applying the configuration"
    try "" 'Configuration files generated for poller' curl -s --header 'Content-Type: application/json' --header 'centreon-auth-token: '"$token" -d '{"action": "APPLYCFG", "values": "'${REG_CENTREON_POLLER_NAME}'"}' -X POST 'http://'${REG_CENTREON_CENTRAL_IP}'/centreon/api/index.php?action=action&object=centreon_clapi'
    log "debug" "Ending main()"

}

if [[ "$0" == "${BASH_SOURCE[0]}" ]] ; then
    main "$@"
fi
