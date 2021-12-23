#!/bin/bash
#######################################################################
# Copyright (c) 2009 & onwards. MapR Tech, Inc., All rights reserved
#######################################################################
#
# Configure script for Zeppelin
#
# This script is normally run by the core configure.sh to setup Zeppelin
# connect during install. If it is run standalone, need to correctly
# initialize the variables that it normally inherits from the master
# configure.sh
#######################################################################


RETURN_SUCCESS=0
RETURN_ERR_MAPR_HOME=1
RETURN_ERR_ARGS=2
RETURN_ERR_MAPRCLUSTER=3


# Initialize API and globals

MAPR_HOME=${MAPR_HOME:-/opt/mapr}

. ${MAPR_HOME}/server/common-ecosystem.sh 2>/dev/null
{ set +x; } 2>/dev/null

initCfgEnv

if [ $? -ne 0 ] ; then
    echo '[ERROR] MAPR_HOME seems to not be set correctly or mapr-core not installed.'
    exit $RETURN_ERR_MAPR_HOME
fi

MAPR_CONF_DIR=${MAPR_CONF_DIR:-"${MAPR_HOME}/conf"}

ZEPPELIN_VERSION=$(cat "${MAPR_HOME}/zeppelin/zeppelinversion")
ZEPPELIN_HOME="${MAPR_HOME}/zeppelin/zeppelin-${ZEPPELIN_VERSION}"

WARDEN_ZEPPELIN_SRC="${ZEPPELIN_HOME}/conf/warden.zeppelin.conf.template"
WARDEN_ZEPPELIN_CONF="${MAPR_CONF_DIR}/conf.d/warden.zeppelin.conf"

WARDEN_HEAPSIZE_MIN_KEY="service.heapsize.min"
WARDEN_HEAPSIZE_MAX_KEY="service.heapsize.max"
WARDEN_HEAPSIZE_PERCENT_KEY="service.heapsize.percent"
WARDEN_RUNSTATE_KEY="service.runstate"

ZEPPELIN_FILE_SECURE="${ZEPPELIN_HOME}/conf/.isSecure"
ZEPPELIN_FILE_NOT_CONFIGURED="${ZEPPELIN_HOME}/conf/.not_configured_yet"

ZEPPELIN_CONF_TUPLES="${ZEPPELIN_HOME}/conf/zeppelin-site.xml.template ${ZEPPELIN_HOME}/conf/zeppelin-site.xml
${ZEPPELIN_HOME}/conf/zeppelin-env.sh.template ${ZEPPELIN_HOME}/conf/zeppelin-env.sh"

ZEPPELIN_SHIRO_INI_TEMPLATE="${ZEPPELIN_HOME}/conf/shiro.ini.template"
ZEPPELIN_SHIRO_INI="${ZEPPELIN_HOME}/conf/shiro.ini"


# Set MAPR_USER and MAPR_GROUP
DAEMON_CONF="${MAPR_HOME}/conf/daemon.conf"

MAPR_USER=${MAPR_USER:-$([ -f "$DAEMON_CONF" ] && grep "mapr.daemon.user" "$DAEMON_CONF" | cut -d '=' -f 2)}
MAPR_USER=${MAPR_USER:-"mapr"}

MAPR_GROUP=${MAPR_GROUP:-$([ -f "$DAEMON_CONF" ] && grep "mapr.daemon.group" "$DAEMON_CONF" | cut -d '=' -f 2)}
MAPR_GROUP=${MAPR_GROUP:-$MAPR_USER}

# Create files from tuples like "file_source file_destination"
copy_src_dst() {
    local src dst
    echo "$1" | while read src dst; do
        cp --no-clobber "$src" "$dst"
    done
}

read_secure() {
    [ -e "$ZEPPELIN_FILE_SECURE" ] && cat "$ZEPPELIN_FILE_SECURE"
}

write_secure() {
    echo "$1" > "$ZEPPELIN_FILE_SECURE"
}

chown_component() {
    chown -R $MAPR_USER:$MAPR_GROUP "$ZEPPELIN_HOME"
}

create_restart_file() {
    mkdir -p "${MAPR_CONF_DIR}/restart"
    cat > "${MAPR_CONF_DIR}/restart/zeppelin-${ZEPPELIN_VERSION}.restart" <<'EOF'
#!/bin/bash
MAPR_HOME="${MAPR_HOME:-/opt/mapr}"
MAPR_USER="${MAPR_USER:-mapr}"

if [ -z "$MAPR_TICKETFILE_LOCATION" ]; then
  isSecured="false"
  if [ -e "${MAPR_HOME}/conf/mapr-clusters.conf" ]; then
    isSecured=$(head -n1 "${MAPR_HOME}/conf/mapr-clusters.conf" | grep -o 'secure=\w*' | cut -d '=' -f 2)
  fi
  if [ "$isSecured" = "true" ] && [ -e "${MAPR_HOME}/conf/mapruserticket" ]; then
    export MAPR_TICKETFILE_LOCATION="${MAPR_HOME}/conf/mapruserticket"
  fi
fi

maprcli node services -action restart -name zeppelin -nodes $(hostname)
EOF
    chmod +x "${MAPR_CONF_DIR}/restart/zeppelin-${ZEPPELIN_VERSION}.restart"
    chown $MAPR_USER:$MAPR_GROUP "${MAPR_CONF_DIR}/restart/zeppelin-${ZEPPELIN_VERSION}.restart"
}

conf_uncomment() {
    local file="$1"
    local name="$2"
    local delim="="
    sed -i "1,/#*\s*${name}\s*${delim}/ s|#*\s*${name}\s*${delim}|${name} ${delim}|" "${file}"
}

conf_comment() {
    local file="$1"
    local name="$2"
    local delim="="
    sed -i "s|#*\s*${name}\s*${delim}|# ${name} ${delim}|" "${file}"
}

conf_get_property() {
    local file="$1"
    local name="$2"
    local delim="="
    grep "^\s*${name}\s*${delim}" "${file}" | sed "s|^\s*${name}\s*${delim}\s*||"
}

conf_set_property() {
    local file="$1"
    local name="$2"
    local value="$3"
    local delim="="
    if grep -q "^\s*${name}\s*${delim}" "${file}"; then
        sed -i -r "1,/^\s*${name}\s*${delim}.*$/ s|^\s*${name}\s*${delim}.*$|${name}${delim}${value}|" "${file}"
    else
        echo "${name}${delim}${value}" >> "${file}"
    fi
}


setup_warden_conf() {
    local curr_heapsize_min
    local curr_heapsize_max
    local curr_heapsize_percent
    local curr_runstate

    if [ -f "$WARDEN_ZEPPELIN_CONF" ]; then
        curr_heapsize_min=$(conf_get_property "$WARDEN_ZEPPELIN_CONF" "$WARDEN_HEAPSIZE_MIN_KEY")
        curr_heapsize_max=$(conf_get_property "$WARDEN_ZEPPELIN_CONF" "$WARDEN_HEAPSIZE_MAX_KEY")
        curr_heapsize_percent=$(conf_get_property "$WARDEN_ZEPPELIN_CONF" "$WARDEN_HEAPSIZE_PERCENT_KEY")
        curr_runstate=$(conf_get_property "$WARDEN_ZEPPELIN_CONF" "$WARDEN_RUNSTATE_KEY")
    fi

    cp "$WARDEN_ZEPPELIN_SRC" "$WARDEN_ZEPPELIN_CONF"

    [ -n "$curr_heapsize_min" ] && conf_set_property "$WARDEN_ZEPPELIN_CONF" "$WARDEN_HEAPSIZE_MIN_KEY" "$curr_heapsize_min"
    [ -n "$curr_heapsize_max" ] && conf_set_property "$WARDEN_ZEPPELIN_CONF" "$WARDEN_HEAPSIZE_MAX_KEY" "$curr_heapsize_max"
    [ -n "$curr_heapsize_percent" ] && conf_set_property "$WARDEN_ZEPPELIN_CONF" "$WARDEN_HEAPSIZE_PERCENT_KEY" "$curr_heapsize_percent"
    [ -n "$curr_runstate" ] && conf_set_property "$WARDEN_ZEPPELIN_CONF" "$WARDEN_RUNSTATE_KEY" "$curr_runstate"

    chown $MAPR_USER:$MAPR_GROUP "$WARDEN_ZEPPELIN_CONF"
}

setup_shiro_ini() {
    if [ ! -e "$ZEPPELIN_SHIRO_INI" ]; then
        sed "s/__ADMIN_ROLE__/$MAPR_GROUP/g" "$ZEPPELIN_SHIRO_INI_TEMPLATE" > "$ZEPPELIN_SHIRO_INI"
    fi
}


# Initialize arguments
isOnlyRoles=${isOnlyRoles:-0}

# Parse options
USAGE="usage: $0 [-h] [-R] [--secure|--unsecure|--customSecure] [-EC <options>]"

while [ ${#} -gt 0 ]; do
    case "$1" in
        --secure)
            isSecure="true";
            shift 1;;
        --unsecure)
            isSecure="false";
            shift 1;;
        --customSecure)
            isSecure="custom";
            shift 1;;
        -R)
            isOnlyRoles=1;
            shift 1;;
        -EC)
            for i in $2 ; do
                case $i in
                    -R) isOnlyRoles=1 ;;
                    *) : ;; # unused
                esac
            done
            shift 2;;
        -h)
            echo "${USAGE}"
            exit $RETURN_SUCCESS
            ;;
        *)
            # Invalid arguments passed
            echo "${USAGE}"
            exit $RETURN_ERR_ARGS
    esac
done


if [ "$isOnlyRoles" = "1" ]; then
    oldSecure=$(read_secure)
    updSecure="false"
    if [ -n "$isSecure" ] && [ "$isSecure" != "$oldSecure" ]; then
        updSecure="true"
    fi

    copy_src_dst "$ZEPPELIN_CONF_TUPLES"
    setup_shiro_ini

    if [ "$updSecure" = "true" ]; then
        write_secure "$isSecure"

        if [ "$isSecure" = "true" ]; then
            # TODO configure secure
            :
        elif [ "$isSecure" = "false" ]; then
            # TODO configure unsecure
            :
        fi
    fi

    # This script can be launched without "isSecure" parameter, so we check the content of .isSecure file.
    if [ "$(read_secure)" = "true" ]; then
        # TODO configure_headers_secure
        :
    elif [ "$(read_secure)" = "false" ]; then
        # TODO configure_headers_unsecure
        :
    fi

    chown_component

    setup_warden_conf

    if [ -f "$ZEPPELIN_FILE_NOT_CONFIGURED" ]; then
        rm -f "$ZEPPELIN_FILE_NOT_CONFIGURED"
    elif [ "$updSecure" = "true" ]; then
        create_restart_file
    fi
fi
