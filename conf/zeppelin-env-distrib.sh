ZEPPELIN_FILE_SECURE="${ZEPPELIN_HOME}/conf/.isSecure"
if [ -e "$ZEPPELIN_FILE_SECURE" ]; then
    isSecure=$(cat "$ZEPPELIN_FILE_SECURE")
fi


# HTTPS by default
# export ZEPPELIN_SSL=${ZEPPELIN_SSL:-"true"}
export ZEPPELIN_PORT=${ZEPPELIN_PORT:-"9995"}
export ZEPPELIN_SSL_PORT=${ZEPPELIN_SSL_PORT:-"$ZEPPELIN_PORT"}

# Configure the Custom Headers
if [ "$isSecure" = "true" ]; then
    export ZEPPELIN_SERVER_CUSTOM_HEADERS_FILE="${ZEPPELIN_HOME}/conf/jetty-headers-secure.xml"
elif [ "$isSecure" != "custom" ]; then
    export ZEPPELIN_SERVER_CUSTOM_HEADERS_FILE="${ZEPPELIN_HOME}/conf/jetty-headers-unsecure.xml"
fi

# Configure the Livy interpreter
if [ "$isSecure" = "true" ]; then
    export ZEPPELIN_LIVY_ISMAPRSECURED=true
    export ZEPPELIN_LIVY_SSL_AUTOCONFIG=true
fi


# Explicitly set Java Trust Store, as it can be overwritten on initialization of MapR libs
# to /opt/mapr/conf/ssl_truststore, which is not exists on client setup, and may cause problems
# on fetching something from internet using HTTPS
if [ -e "/etc/debian_version" ]; then
    export ZEPPELIN_JAVA_OPTS="$ZEPPELIN_JAVA_OPTS -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts "
elif [ -e "/etc/redhat-release" ]; then
    export ZEPPELIN_JAVA_OPTS="$ZEPPELIN_JAVA_OPTS -Djavax.net.ssl.trustStore=/etc/pki/java/cacerts "
fi


# Notebook Storage setup
if [ -n "$ZEPPELIN_NOTEBOOK_DIR" ]; then
    if echo "$ZEPPELIN_NOTEBOOK_DIR" | grep -q "^maprfs:"; then
        export ZEPPELIN_NOTEBOOK_STORAGE="org.apache.zeppelin.notebook.repo.FileSystemNotebookRepo"
    else
        mkdir -p "$ZEPPELIN_NOTEBOOK_DIR"
    fi
fi

# Config Storage setup
if [ -n "$ZEPPELIN_CONFIG_FS_DIR" ]; then
    if echo "$ZEPPELIN_CONFIG_FS_DIR" | grep -q "^maprfs:"; then
        export ZEPPELIN_CONFIG_STORAGE_CLASS="org.apache.zeppelin.storage.FileSystemConfigStorage"
    else
        mkdir -p "$ZEPPELIN_CONFIG_FS_DIR"
    fi
fi


# Container specific configuration
if [ -n "${MAPR_CONTAINER_USER}" ]; then
    export ZEPPELIN_INTERPRETER_USER="${MAPR_CONTAINER_USER}"
fi

ensure_port() {
    local links="$1"
    local default_port="$2"
    local res=""
    local link host port
    local IFS=","
    for link in $links; do
        host=$(echo "$link" | cut -d ':' -f 1)
        port=$(echo "$link" | cut -d ':' -f 2)
        if [ "$host" = "$port" ]; then
            port="$default_port"
        fi
        if [ -z "$res" ]; then
            res="$host:$port"
        else
            res="$res,$host:$port"
        fi
    done
    echo "$res"
}

# Build Hive JDBC URL
ZEPPELIN_JDBC_URL_HIVE="jdbc:hive2://localhost:10000/default"
if [ -e "${MAPR_TICKETFILE_LOCATION}" ]; then
    ZEPPELIN_JDBC_URL_HIVE+=";auth=MAPRSASL;ssl=true"
fi
export ZEPPELIN_JDBC_URL_HIVE

# Build Drill JDBC URL
if [ -n "$MAPR_DRILLBITS_HOSTS" ]; then
    mapr_drillbits_hosts_cleaned=$(ensure_port "$MAPR_DRILLBITS_HOSTS" 31010)
    ZEPPELIN_JDBC_URL_DRILL="jdbc:drill:drillbit=${mapr_drillbits_hosts_cleaned}"
elif [ -n "$MAPR_ZK_QUORUM" ]; then
    mapr_zk_quorum_cleaned=$(ensure_port "$MAPR_ZK_QUORUM" 5181)
    ZEPPELIN_JDBC_URL_DRILL="jdbc:drill:zk=${mapr_zk_quorum_cleaned}/drill/${MAPR_CLUSTER}-drillbits"
else
    ZEPPELIN_JDBC_URL_DRILL="jdbc:drill:drillbit=localhost:31010"
fi
if [ -e "${MAPR_TICKETFILE_LOCATION}" ]; then
    ZEPPELIN_JDBC_URL_DRILL+=";auth=MAPRSASL"
fi
export ZEPPELIN_JDBC_URL_DRILL


if [ -e "${MAPR_HOME}/hbase/hbaseversion" ]; then
    HBASE_VERSION=$(cat "${MAPR_HOME}/hbase/hbaseversion")
    export HBASE_HOME=${HBASE_HOME:-"${MAPR_HOME}/hbase/hbase-${HBASE_VERSION}"}
fi
