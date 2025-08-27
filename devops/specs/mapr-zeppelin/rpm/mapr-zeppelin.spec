%undefine __check_files

summary:     HPE DataFabric Ecosystem Pack: Apache Zeppelin
license:     Hewlett Packard Enterprise, CopyRight
vendor:      Hewlett Packard Enterprise
name:        mapr-zeppelin
version:     __RELEASE_VERSION__
release:     1
prefix:      /
group:       HPE
buildarch:   x86_64
obsoletes:   mapr-zeppelin
requires:    mapr-client, mapr-hadoop-core
AutoReqProv: no

%description
Apache Zeppelin distribution included in HPE DataFabric Software Ecosystem Pack
Tag: __RELEASE_BRANCH__
Commit: __GIT_COMMIT__


%clean
echo "NOOP"


%files
__PREFIX__/zeppelin
__PREFIX__/roles


%pretrans
# stop service if running
if [ -e "__PREFIX__/zeppelin/zeppelinversion" ]; then
    DAEMON_CONF="__PREFIX__/conf/daemon.conf"
    MAPR_USER=${MAPR_USER:-$([ -f "$DAEMON_CONF" ] && grep "mapr.daemon.user" "$DAEMON_CONF" | cut -d '=' -f 2)}
    MAPR_USER=${MAPR_USER:-"mapr"}

    if [ -z "${MAPR_TICKETFILE_LOCATION}" ] && [ -e "__PREFIX__/conf/mapruserticket" ]; then
        export MAPR_TICKETFILE_LOCATION="__PREFIX__/conf/mapruserticket"
    fi

    ZEPPELIN_VERSION=$(cat "__PREFIX__/zeppelin/zeppelinversion")
    ZEPPELIN_HOME="__PREFIX__/zeppelin/zeppelin-${ZEPPELIN_VERSION}"

    if sudo -u $MAPR_USER -E "${ZEPPELIN_HOME}/bin/zeppelin-daemon.sh" status >/dev/null 2>&1; then
        RESULT=$(sudo -u $MAPR_USER -E "${ZEPPELIN_HOME}/bin/zeppelin-daemon.sh" stop 2>&1)
        STATUS=$?
        if [ $STATUS -ne 0 ] ; then
            echo "$RESULT"
        fi
    fi
fi


%pre
if [ "$1" = "2" ]; then
    OLD_TIMESTAMP=$(rpm --queryformat='%%{VERSION}' -q mapr-zeppelin)
    OLD_VERSION=$(echo "$OLD_TIMESTAMP" | grep -o '^[0-9]*\.[0-9]*\.[0-9]*')

    OLD_TIMESTAMP_FILE="%{_localstatedir}/lib/rpm-state/mapr-zeppelin-old-timestamp"
    OLD_VERSION_FILE="%{_localstatedir}/lib/rpm-state/mapr-zeppelin-old-version"

    STATE_DIR="$(dirname $OLD_TIMESTAMP_FILE)"
    if [ ! -d "$STATE_DIR" ]; then
        mkdir -p "$STATE_DIR"
    fi

    echo "$OLD_TIMESTAMP" > "$OLD_TIMESTAMP_FILE"
    echo "$OLD_VERSION" > "$OLD_VERSION_FILE"

    #
    # Backup of old configuration files
    #
    OLD_DIR="__PREFIX__/zeppelin/zeppelin-${OLD_VERSION}"
    OLD_CONF_DIR="${OLD_DIR}/conf/"
    BCK_DIR="__PREFIX__/zeppelin/zeppelin-${OLD_TIMESTAMP}"

    mkdir -p "$BCK_DIR"
    if [ -e "$OLD_CONF_DIR" ]; then
        cp -r "$OLD_CONF_DIR" "$BCK_DIR"
    fi
fi


%post
# clean install:
if [ "$1" = "1" ]; then
  touch "__INSTALL_3DIGIT__/conf/.not_configured_yet"
fi


%preun
# Stop service before uninstall.
# (Code in %pretrans is not executed on uninstall.)
if [ -e "__PREFIX__/zeppelin/zeppelinversion" ]; then
    DAEMON_CONF="__PREFIX__/conf/daemon.conf"
    MAPR_USER=${MAPR_USER:-$([ -f "$DAEMON_CONF" ] && grep "mapr.daemon.user" "$DAEMON_CONF" | cut -d '=' -f 2)}
    MAPR_USER=${MAPR_USER:-"mapr"}

    if [ -z "${MAPR_TICKETFILE_LOCATION}" ] && [ -e "__PREFIX__/conf/mapruserticket" ]; then
        export MAPR_TICKETFILE_LOCATION="__PREFIX__/conf/mapruserticket"
    fi

    ZEPPELIN_VERSION=$(cat "__PREFIX__/zeppelin/zeppelinversion")
    ZEPPELIN_HOME="__PREFIX__/zeppelin/zeppelin-${ZEPPELIN_VERSION}"

    if sudo -u $MAPR_USER -E "${ZEPPELIN_HOME}/bin/zeppelin-daemon.sh" status >/dev/null 2>&1; then
        RESULT=$(sudo -u $MAPR_USER -E "${ZEPPELIN_HOME}/bin/zeppelin-daemon.sh" stop 2>&1)
        STATUS=$?
        if [ $STATUS -ne 0 ] ; then
            echo "$RESULT"
        fi
    fi
fi


%postun
# uninstall:
if [ "$1" = "0" ]; then
    rm -rf __PREFIX__/zeppelin/
fi

if [ -f __PREFIX__/conf/conf.d/warden.zeppelin.conf ]; then
    rm -f __PREFIX__/conf/conf.d/warden.zeppelin.conf
fi


%posttrans
OLD_TIMESTAMP_FILE="%{_localstatedir}/lib/rpm-state/mapr-zeppelin-old-timestamp"
OLD_VERSION_FILE="%{_localstatedir}/lib/rpm-state/mapr-zeppelin-old-version"

# This files will exist only on upgrade
if [ -e "$OLD_TIMESTAMP_FILE" ] && [ -e "$OLD_VERSION_FILE" ]; then 
    OLD_TIMESTAMP=$(cat "$OLD_TIMESTAMP_FILE")
    OLD_VERSION=$(cat "$OLD_VERSION_FILE")

    rm "$OLD_TIMESTAMP_FILE" "$OLD_VERSION_FILE"

    # Remove directory with old version
    NEW_VERSION=$(cat __PREFIX__/zeppelin/zeppelinversion)

    if [ "$OLD_VERSION" != "$NEW_VERSION" ]; then
        rm -rf "__PREFIX__/zeppelin/zeppelin-${OLD_VERSION}"
    fi
fi
