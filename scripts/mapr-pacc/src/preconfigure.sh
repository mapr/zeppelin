#!/bin/bash -ex

MAPR_HOME=${MAPR_HOME:-/opt/mapr}

mkdir -p "${MAPR_HOME}/zeppelin/thirdparty/jdbc-mapr-drill"

curl -o /tmp/DrillJDBC41.zip "http://package.mapr.com/tools/MapR-JDBC/MapR_Drill/MapRDrill_jdbc_v1.5.3.1006/DrillJDBC41.zip"
unzip -d "${MAPR_HOME}/zeppelin/thirdparty/jdbc-mapr-drill" /tmp/DrillJDBC41.zip
rm /tmp/DrillJDBC41.zip
