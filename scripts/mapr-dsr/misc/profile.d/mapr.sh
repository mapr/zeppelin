#!/bin/bash
# USER variable may be not set on Ubuntu
if [ -x /usr/bin/id ]; then
    USER=${USER:-$(/usr/bin/id -un)}
    LOGNAME=${LOGNAME:-$USER}
    MAIL=${MAIL:-"/var/spool/mail/$USER"}
    export USER LOGNAME MAIL

    if [ -x /usr/bin/getent ]; then
        HOME=$(/usr/bin/getent passwd $USER | cut -d ':' -f 6)
        export HOME
    fi
fi

export DRILL_HOME="${DRILL_HOME:-/opt/mapr}"

cd ~
