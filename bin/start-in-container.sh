#!/bin/bash

MAPR_HOME=${MAPR_HOME:-/opt/mapr}
MAPR_CLUSTER=${MAPR_CLUSTER:-my.cluster.com}

SPARK_VERSION=$(cat "${MAPR_HOME}/spark/sparkversion")
SPARK_HOME="${MAPR_HOME}/spark/spark-${SPARK_VERSION}"

LIVY_VERSION=$(cat "${MAPR_HOME}/livy/livyversion")
LIVY_HOME="${MAPR_HOME}/livy/livy-${LIVY_VERSION}"

ZEPPELIN_VERSION=$(cat "${MAPR_HOME}/zeppelin/zeppelinversion")
ZEPPELIN_HOME="${MAPR_HOME}/zeppelin/zeppelin-${ZEPPELIN_VERSION}"

log_warn() {
    echo "WARN: $@"
}
log_msg() {
    echo "MSG: $@"
}
log_err() {
    echo "ERR: $@"
}

# Sielent "hadoop fs" calls
hadoop_fs_mkdir_p() {
    hadoop fs -mkdir -p "$1" &>/dev/null
}
hadoop_fs_get() {
    hadoop fs -get "$1" "$2" &>/dev/null
}
hadoop_fs_put() {
    hadoop fs -put "$1" "$2" &>/dev/null
}
hadoop_fs_test_e() {
    hadoop fs -test -e "$1" &>/dev/null
}



#
# Initialize config files
#
LIVY_CONF_TUPLES="${LIVY_HOME}/conf/livy-client.conf.container_template ${LIVY_HOME}/conf/livy-client.conf
${LIVY_HOME}/conf/livy.conf.container_template ${LIVY_HOME}/conf/livy.conf
${LIVY_HOME}/conf/livy-env.sh.template ${LIVY_HOME}/conf/livy-env.sh
${LIVY_HOME}/conf/log4j.properties.template ${LIVY_HOME}/conf/log4j.properties
${LIVY_HOME}/conf/spark-blacklist.conf.template ${LIVY_HOME}/conf/spark-blacklist.conf"

ZEPPELIN_CONF_TUPLES="${ZEPPELIN_HOME}/conf/zeppelin-site.xml.container_template ${ZEPPELIN_HOME}/conf/zeppelin-site.xml
${ZEPPELIN_HOME}/conf/zeppelin-env.sh.template ${ZEPPELIN_HOME}/conf/zeppelin-env.sh
${ZEPPELIN_HOME}/conf/shiro.ini.template ${ZEPPELIN_HOME}/conf/shiro.ini"

init_confs() {
    echo "$1" | while read conf_src conf_dsr; do
        if [ ! -e "$conf_dsr" ]; then
            cp "$conf_src" "$conf_dsr"
        fi
    done
}

init_confs "$LIVY_CONF_TUPLES"
init_confs "$ZEPPELIN_CONF_TUPLES"



#
# Configure and start Livy
#

cd "${LIVY_HOME}"


LIVY_RSC_PORT_RANGE=${LIVY_RSC_PORT_RANGE:-"10000~10010"}
LIVY_RSC_PORT_RANGE=$(echo $LIVY_RSC_PORT_RANGE | sed "s/-/~/")

# Implicitly increase LIVY_RSC_PORT_RANGE because of LIVY-451
livy_rsc_port_min=$(echo "$LIVY_RSC_PORT_RANGE" | cut -d '~' -f 1)
livy_rsc_port_max=$(echo "$LIVY_RSC_PORT_RANGE" | cut -d '~' -f 2)
livy_rsc_port_max_new=$(expr "$livy_rsc_port_max" + 10)
LIVY_RSC_PORT_RANGE_NEW="${livy_rsc_port_min}~${livy_rsc_port_max_new}"

SPARK_PORT_RANGE="${SPARK_PORT_RANGE:-11000~11010}"
SPARK_PORT_RANGE=$(echo $SPARK_PORT_RANGE | sed "s/-/~/")

REMOTE_ARCHIVES_DIR="/user/${MAPR_CONTAINER_USER}/zeppelin/archives"

LOCAL_ARCHIVES_DIR="$(getent passwd $MAPR_CONTAINER_USER | cut -d':' -f6)/zeppelin/archives"
LOCAL_ARCHIVES_ZIPDIR="${LOCAL_ARCHIVES_DIR}/zip"


livy_subs_client_conf() {
    local livy_conf="${LIVY_HOME}/conf/livy-client.conf"
    local sub="$1"
    local val="$2"
    if [ -n "${val}" ]; then
        sed -i -r "s|# (.*) ${sub}|\1 ${val}|" "${livy_conf}"
    fi
}

spark_get_property() {
    local spark_conf="${SPARK_HOME}/conf/spark-defaults.conf"
    local property_name="$1"
    grep "^\s*${property_name}" "${spark_conf}" | sed "s|^\s*${property_name}\s*||"
}

spark_set_property() {
    local spark_conf="${SPARK_HOME}/conf/spark-defaults.conf"
    local property_name="$1"
    local property_value="$2"
    if grep -q "^\s*${property_name}\s*" "${spark_conf}"; then
        # modify property
        sed -i -r "s|^\s*${property_name}.*$|${property_name} ${property_value}|" "${spark_conf}"
    else
        # add property
        echo "${property_name} ${property_value}" >> "${spark_conf}"
    fi
}

spark_append_property() {
    local spark_conf="${SPARK_HOME}/conf/spark-defaults.conf"
    local property_name="$1"
    local property_value="$2"
    local old_value=$(spark_get_property "${property_name}")
    local new_value=""
    if [ -z "${old_value}" ]; then
        # new value
        new_value="${property_value}"
    elif echo "${old_value}" | grep -q -F "${property_value}"; then
        # nothing to do
        new_value="${old_value}"
    else
        # modify value
        new_value="${old_value},${property_value}"
    fi
    spark_set_property "${property_name}" "${new_value}"
}

setup_spark_jars() {
    HBASE_VERSION=$(cat "${MAPR_HOME}/hbase/hbaseversion")
    HBASE_HOME="${MAPR_HOME}/hbase/hbase-${HBASE_VERSION}"
    # Copy MapR-DB and Streaming jars into Spark
    JAR_WHILDCARDS="
        ${MAPR_HOME}/lib/kafka-clients-*-mapr-*.jar
        ${MAPR_HOME}/lib/mapr-hbase-*-mapr-*.jar
        ${HBASE_HOME}/lib/hbase-*-mapr-*.jar
        ${ZEPPELIN_HOME}/interpreter/spark/spark-interpreter*.jar
    "
    for jar_path in $JAR_WHILDCARDS; do
        jar_name=$(basename "${jar_path}")
        if [ -e "${jar_path}" ] && [ ! -e "${SPARK_HOME}/jars/${jar_name}" ]; then
            ln -s "${jar_path}" "${SPARK_HOME}/jars"
        fi
    done
}

spark_fix_log4j() {  #DSR-20
    # Copied from Spark configure.sh
    #
    # Improved default logging level (WARN instead of INFO)
    #
    if [ -e "$SPARK_HOME/conf/log4j.properties" ]; then
        sed -i 's/rootCategory=INFO/rootCategory=WARN/' "$SPARK_HOME/conf/log4j.properties"
    else
        sed 's/rootCategory=INFO/rootCategory=WARN/' "$SPARK_HOME/conf/log4j.properties.template" > "$SPARK_HOME/conf/log4j.properties"
    fi
}

spark_configure_hive_site() {
    local spark_conf="${SPARK_HOME}/conf/spark-defaults.conf"
    local spark_hive_site="${SPARK_HOME}/conf/hive-site.xml"
    if [ ! -e "${spark_hive_site}" ]; then
        cat > "${spark_hive_site}" <<'EOF'
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
</configuration>
EOF
    fi
    local spark_yarn_dist_files=$(spark_get_property "spark.yarn.dist.files")
    # Check if no "hive-site.xml" in "spark.yarn.dist.files"
    if ! spark_get_property "spark.yarn.dist.files" | grep -q "hive-site.xml"; then
        spark_append_property "spark.yarn.dist.files" "${spark_hive_site}"
    fi
}

out_archive_local=""
out_archive_extracted=""
out_archive_remote=""
out_archive_filename=""
setup_archive() {
    local archive_path="$1"
    local archive_filename=$(basename "$archive_path")
    local archive_local=""
    local archive_remote=""
    if hadoop_fs_test_e "$archive_path"; then
        archive_remote="$archive_path"
        archive_local="${LOCAL_ARCHIVES_ZIPDIR}/${archive_filename}"
        if [ ! -e "$archive_local" ]; then
            log_msg "Copying archive from MapR-FS: ${archive_remote} -> ${archive_local}"
            hadoop_fs_get "$archive_remote" "$archive_local"
        else
            log_msg "Skip copying archive from MapR-FS as it already exists"
        fi
    elif [ -e "$archive_path" ]; then
        archive_local="$archive_path"
        archive_remote="${REMOTE_ARCHIVES_DIR}/${archive_filename}"
        # Copy archive to MapR-FS
        if ! hadoop_fs_test_e "$archive_remote"; then
            log_msg "Copying archive to MapR-FS: ${archive_local} -> ${archive_remote}"
            hadoop_fs_put "$archive_local" "$archive_remote"
        else
            log_msg "Skip copying archive to MapR-FS as it already exists"
        fi
    else
        log_err "Archive '${archive_path}' not found"
        return 1
    fi
    local archive_extracted="${LOCAL_ARCHIVES_DIR}/${archive_filename}"
    if [ ! -e "$archive_extracted" ]; then
        log_msg "Extracting archive locally"
        mkdir -p "$archive_extracted"
        unzip -qq "$archive_local" -d "$archive_extracted" || return 1
    else
        log_msg "Skip extracting archive locally as it already exists"
    fi

    out_archive_local="$archive_local"
    out_archive_extracted="$archive_extracted"
    out_archive_remote=$(echo "$archive_remote" | sed "s|maprfs://||")
    out_archive_filename="$archive_filename"
    return 0
}

spark_configure_python() {
    log_msg "Setting up Python archive"
    setup_archive "$ZEPPELIN_ARCHIVE_PYTHON" || return 1
    log_msg "Configuring Spark to use custom Python"
    spark_append_property "spark.yarn.dist.archives" "maprfs://${out_archive_remote}"
    spark_set_property "spark.yarn.appMasterEnv.PYSPARK_PYTHON" "./${out_archive_filename}/bin/python"
    log_msg "Configuring Zeppelin to use custom Python with Spark interpreter"
    local zeppelin_env_sh="${ZEPPELIN_HOME}/conf/zeppelin-env.sh"
    cat >> "$zeppelin_env_sh" << EOF
export ZEPPELIN_SPARK_YARN_DIST_ARCHIVES="maprfs://${out_archive_remote}"
export PYSPARK_PYTHON='./${out_archive_filename}/bin/python'

EOF
    return 0
}

spark_configure_custom_envs() {
    if ! hadoop_fs_test_e "/user/${MAPR_CONTAINER_USER}/"; then
        log_warn "/user/${MAPR_CONTAINER_USER} does not exist in MapR-FS"
        return 1
    fi

    hadoop_fs_mkdir_p "$REMOTE_ARCHIVES_DIR"
    mkdir -p "$LOCAL_ARCHIVES_DIR" "$LOCAL_ARCHIVES_ZIPDIR"

    if [ -n "$ZEPPELIN_ARCHIVE_PYTHON" ]; then
        spark_configure_python || log_msg "Using default Python"
    else
        log_msg "Using default Python"
    fi

    if [ -n "$ZEPPELIN_ARCHIVE_PYTHON3" ]; then
       log_warn "Property 'ZEPPELIN_ARCHIVE_PYTHON3' is deprecated. Ignoring."
    fi
}


if [ -e "${SPARK_HOME}" ]; then
    if [ ! -e "${SPARK_HOME}/conf/spark-defaults.conf" ]; then
        cp "${SPARK_HOME}/conf/spark-defaults.conf.template" "${SPARK_HOME}/conf/spark-defaults.conf"
    fi

    setup_spark_jars
    spark_fix_log4j
    spark_configure_hive_site
    spark_configure_custom_envs

    if [ -n "$HOST_IP" ]; then
        spark_ports=$(echo "$SPARK_PORT_RANGE" | sed 's/~/\n/')
        read -a ports <<< $(seq $spark_ports)
        spark_set_property "spark.driver.bindAddress" "0.0.0.0"
        spark_set_property "spark.driver.host" "${HOST_IP}"
        spark_set_property "spark.driver.port" "${ports[0]}"
        spark_set_property "spark.blockManager.port" "${ports[1]}"
        spark_set_property "spark.ui.port" "${ports[2]}"
    else
      log_err "Can't configure Spark networking because HOST_IP is not set"
    fi
else
    log_warn '$SPARK_HOME can not be found'
fi

livy_subs_client_conf "__LIVY_HOST_IP__" "$HOST_IP"
livy_subs_client_conf "__LIVY_RSC_PORT_RANGE__" "$LIVY_RSC_PORT_RANGE_NEW"
# TODO: refactor setup of livy.conf.
# MZEP-162:
sed -i 's/^.*livy\.ui\.enabled.*$/livy.ui.enabled=false/g' "${LIVY_HOME}/conf/livy.conf"


"${LIVY_HOME}/bin/livy-server" start &



#
# Configure and start Zeppelin
#

# Explicitly set Zeppelin working directory
# To prevent issues when Zeppelin started in / and its subprocesses cannot write to CWD
cd "${ZEPPELIN_HOME}"

ZEPPELIN_KEYS_DIR="${ZEPPELIN_HOME}/conf/keys"
ZEPPELIN_SITE_PATH="${ZEPPELIN_HOME}/conf/zeppelin-site.xml"

export ZEPPELIN_SSL_PORT="${ZEPPELIN_SSL_PORT:-9995}"
ZEPPELIN_KEYSTORE_PATH="${ZEPPELIN_KEYS_DIR}/ssl_keystore"
ZEPPELIN_KEYSTORE_PASS="mapr123"
ZEPPELIN_KEYSTORE_TYPE="JKS"


create_certificates() {
    if [ "$JAVA_HOME"x = "x" ]; then
        KEYTOOL=`which keytool`
    else
        KEYTOOL=$JAVA_HOME/bin/keytool
    fi

    DOMAINNAME=`hostname -d`
    if [ "$DOMAINNAME"x = "x" ]; then
        CERTNAME=`hostname`
    else
        CERTNAME="*."$DOMAINNAME
    fi

    if [ ! -e "$ZEPPELIN_KEYSTORE_PATH" ]; then
        echo "Creating 10 year self signed certificate for Zeppelin with subjectDN='CN=$CERTNAME'"
        mkdir -p "$ZEPPELIN_KEYS_DIR"
        $KEYTOOL -genkeypair -sigalg SHA512withRSA -keyalg RSA -alias "$MAPR_CLUSTER" -dname "CN=$CERTNAME" -validity 3650 \
                 -storepass "$ZEPPELIN_KEYSTORE_PASS" -keypass "$ZEPPELIN_KEYSTORE_PASS" \
                 -keystore "$ZEPPELIN_KEYSTORE_PATH" -storetype "$ZEPPELIN_KEYSTORE_TYPE"
        if [ $? -ne 0 ]; then
            echo "Keytool command to generate key store failed"
        fi
    else
        echo "Creating of Zeppelin keystore was skipped as it already exists: ${ZEPPELIN_KEYSTORE_PATH}."
    fi
}

zeppelin_configure() {
    zeppelin_callback_port_range=$(echo "$SPARK_PORT_RANGE" | sed 's/~/:/')
    sed -i \
        -e "s|__ZEPPELIN_KEYSTORE_PATH__|$ZEPPELIN_KEYSTORE_PATH|" \
        -e "s|__ZEPPELIN_KEYSTORE_PASS__|$ZEPPELIN_KEYSTORE_PASS|" \
        -e "s|__ZEPPELIN_KEYSTORE_TYPE__|$ZEPPELIN_KEYSTORE_TYPE|" \
        -e "s|__ZEPPELIN_CALLBACK_PORT_RANGE__|$zeppelin_callback_port_range|" \
        "$ZEPPELIN_SITE_PATH"
}


create_certificates
zeppelin_configure


if [ "$DEPLOY_MODE" = "kubernetes" ]; then
    exec "${ZEPPELIN_HOME}/bin/zeppelin.sh" start
else
    exec "${ZEPPELIN_HOME}/bin/zeppelin-daemon.sh" start
fi
