#!/bin/bash
########################################################################
# Copyright (c) 2009 & onwards. MapR Tech, Inc., All rights reserved
########################################################################
#
# Configure script for Zeppelin
#
# This script is normally run by the core configure.sh to setup Zeppelin
# during install. If it is run standalone, need to correctly initialize
# the variables that it normally inherits from the master configure.sh
########################################################################

RETURN_SUCCESS=0
RETURN_ERR_MAPR_HOME=1
RETURN_ERR_ARGS=2
RETURN_ERR_MAPRCLUSTER=3
RETURN_ERR_OTHER=4



# Initialize API and globals

MAPR_HOME=${MAPR_HOME:-/opt/mapr}

. ${MAPR_HOME}/server/common-ecosystem.sh 2> /dev/null # prevent verbose output, set by 'set -x'
if [ $? -ne 0 ] ; then
  echo '[ERROR] MAPR_HOME seems to not be set correctly or mapr-core not installed.'
  exit $RETURN_ERR_MAPR_HOME
fi 2> /dev/null

{ set +x; } 2>/dev/null

initCfgEnv

# isSecure is set in server/configure.sh
if [ -n "$isSecure" ]; then
    if [ "$isSecure" == "true" ]; then
        isSecure=1
    fi
fi

# Get MAPR_USER and MAPR_GROUP
DAEMON_CONF="${MAPR_HOME}/conf/daemon.conf"
if [ -z "$MAPR_USER" ] ; then
  if [ -f "$DAEMON_CONF" ]; then
    MAPR_USER=$( awk -F = '$1 == "mapr.daemon.user" { print $2 }' "$DAEMON_CONF" )
  else
    #Zeppelin installation on edge node (not on cluster)
    MAPR_USER=`logname`
  fi
fi
if [ -z "$MAPR_GROUP" ] ; then
  if [ -f "$DAEMON_CONF" ]; then
    MAPR_GROUP=$( awk -F = '$1 == "mapr.daemon.group" { print $2 }' "$DAEMON_CONF" )
  else
    MAPR_GROUP="$MAPR_USER"
  fi
fi

# Initialize ZEPPELIN_HOME
ZEPPELIN_VERSION=$(cat "${MAPR_HOME}/zeppelin/zeppelinversion")
ZEPPELIN_HOME=${ZEPPELIN_HOME:-"${MAPR_HOME}/zeppelin/zeppelin-${ZEPPELIN_VERSION}"}
ZEPPELIN_NAME=${ZEPPELIN_NAME:-zeppelin}
MAPR_CONF_DIR=${MAPR_CONF_DIR:-"$MAPR_HOME/conf"}

# Initialize arguments
isOnlyRoles=${isOnlyRoles:-0}
doRestart=${doRestart:-0}

# internal variables used in this script
ZEPPELIN_CONFS=(
    "${ZEPPELIN_HOME}/conf/zeppelin-site.xml"
    "${ZEPPELIN_HOME}/conf/zeppelin-env.sh"
    "${ZEPPELIN_HOME}/conf/shiro.ini"
    "${ZEPPELIN_HOME}/conf/interpreter-list"
    "${ZEPPELIN_HOME}/conf/interpreter.json"
)



# Parse options

USAGE="usage: $0 [-h] [-R] [-secure] [-unsecure]"

OPTS=`getopt -n "$0" -a -o h -l R -l EC: -l secure -l unsecure -- "$@"`

eval set -- "$OPTS"

while [ $# -gt 0 ]; do
  case "$1" in
    --secure)
      isSecure=1;
      logWarn "Zeppelin configure.sh ignores -secure option"
      shift 1;;
    --unsecure)
      isSecure=0;
      logWarn "Zeppelin configure.sh ignores -unsecure option"
      shift 1;;
    --R)
      isOnlyRoles=1;
      shift 1;;
    --EC)
      ecosystemParams="$2"
      logWarn "Zeppelin configure.sh ignores -EC option"
      shift 2;;
    --h)
      echo "${USAGE}"
      exit $RETURN_SUCCESS
      ;;
    --)
      shift;;
    *)
      # Invalid arguments passed
      echo "${USAGE}"
      exit $RETURN_ERR_ARGS
  esac
done



# Main part

# Backup conf files if exists
# DATE_SUFFIX=$(date '+%Y%m%d-%H%M%S')
# for CONF in ${ZEPPELIN_CONFS[@]} ; do
#     if [ -f "${CONF}" ] ; then
#       cp "${CONF}" "${CONF}.bak-${DATE_SUFFIX}"
#     fi
# done


# Change permissions
chown -R $MAPR_USER:$MAPR_GROUP "$ZEPPELIN_HOME"


# Ask Warden to restart Zeppelin if needed
if [ "$doRestart" == 1 ] && [ "$isOnlyRoles" != 1 ] ; then
    echo "maprcli node services -action restart -name zeppelin -nodes $(hostname)" > "${MAPR_CONF_DIR}/restart/${ZEPPELIN_NAME}-${ZEPPELIN_VERSION}.restart"
fi


# Install Warden conf file
if [ "$isOnlyRoles" == 1 ] ; then
  # Configure network
  if checkNetworkPortAvailability 8080 ; then
    # Register port for Zeppelin
    registerNetworkPort zeppelin 8080

    # Copy Zeppelin Warden conf into Warden conf directory
    cp "${ZEPPELIN_HOME}/conf/warden.${ZEPPELIN_NAME}.conf" "${MAPR_CONF_DIR}/conf.d/"
    logInfo 'Warden conf for Zeppelin copied.'
  else
    logErr 'Zeppelin cannot start because its ports already has been taken.'
    exit $RETURN_ERR_MAPRCLUSTER
  fi 2> /dev/null
fi

exit $RETURN_SUCCESS
