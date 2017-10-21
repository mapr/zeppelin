#!/bin/bash -ex

MAPR_HOME=${MAPR_HOME:-/opt/mapr}

mkdir -p "${MAPR_HOME}/zeppelin/thirdparty/jdbc-mapr-drill"

curl -o /tmp/DrillJDBC41.zip "http://package.mapr.com/tools/MapR-JDBC/MapR_Drill/MapRDrill_jdbc_v1.5.3.1006/DrillJDBC41.zip"
unzip -d "${MAPR_HOME}/zeppelin/thirdparty/jdbc-mapr-drill" /tmp/DrillJDBC41.zip
rm /tmp/DrillJDBC41.zip


if [ -e "${MAPR_HOME}/spark/sparkversion" ]; then
    SPARK_VERSION=$(cat "${MAPR_HOME}/spark/sparkversion")
    SPARK_HOME="${MAPR_HOME}/spark/spark-${SPARK_VERSION}"

    # Copy MapR-DB and Streaming jars into Spark
    JAR_WHILDCARDS="
        ${MAPR_HOME}/lib/kafka-clients-*-mapr-*.jar
    "
    for jar_path in $JAR_WHILDCARDS; do
        jar_name=$(basename "${jar_path}")
        if [ -e "${jar_path}" ] && [ ! -e "${SPARK_HOME}/jars/${jar_name}" ]; then
            ln -s "${jar_path}" "${SPARK_HOME}/jars"
        fi
    done
fi
