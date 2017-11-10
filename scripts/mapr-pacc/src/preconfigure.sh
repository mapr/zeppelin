#!/bin/bash -ex

MAPR_HOME=${MAPR_HOME:-/opt/mapr}


get_spark_home() {
    local SPARK_HOME=""
    local SPARK_VERSION=""
    local spark_home_legacy=""
    if [ -e "${MAPR_HOME}/spark/sparkversion" ]; then
        SPARK_VERSION=$(cat "${MAPR_HOME}/spark/sparkversion")
        SPARK_HOME="${MAPR_HOME}/spark/spark-${SPARK_VERSION}"
    else
        # Legacy way to find SPARK_HOME
        spark_home_legacy=$(find "${MAPR_HOME}/spark/" -maxdepth 1 -name "spark-*" -type d | tail -n1)
        [ -e "${spark_home_legacy}" ] && SPARK_HOME="${spark_home_legacy}"
    fi
    echo "${SPARK_HOME}"
}


mkdir -p "${MAPR_HOME}/zeppelin/thirdparty/jdbc-mapr-drill"

curl -o /tmp/DrillJDBC41.zip "http://package.mapr.com/tools/MapR-JDBC/MapR_Drill/MapRDrill_jdbc_v1.5.3.1006/DrillJDBC41.zip"
unzip -d "${MAPR_HOME}/zeppelin/thirdparty/jdbc-mapr-drill" /tmp/DrillJDBC41.zip
rm /tmp/DrillJDBC41.zip


SPARK_HOME=$(get_spark_home)
if [ -e "${SPARK_HOME}" ]; then
    HBASE_VERSION=$(cat "${MAPR_HOME}/hbase/hbaseversion")
    HBASE_HOME="${MAPR_HOME}/hbase/hbase-${HBASE_VERSION}"
    # Copy MapR-DB and Streaming jars into Spark
    JAR_WHILDCARDS="
        ${MAPR_HOME}/lib/kafka-clients-*-mapr-*.jar
        ${MAPR_HOME}/lib/mapr-hbase-*-mapr-*.jar
        ${HBASE_HOME}/lib/hbase-*-mapr-*.jar
    "
    for jar_path in $JAR_WHILDCARDS; do
        jar_name=$(basename "${jar_path}")
        if [ -e "${jar_path}" ] && [ ! -e "${SPARK_HOME}/jars/${jar_name}" ]; then
            ln -s "${jar_path}" "${SPARK_HOME}/jars"
        fi
    done
fi

echo 'cd ~' >> /etc/profile.d/mapr.sh
