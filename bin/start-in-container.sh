#!/bin/bash

export MAPR_HOME=${MAPR_HOME:-/opt/mapr}
export MAPR_CLUSTER=${MAPR_CLUSTER:-my.cluster.com}

export ZEPPELIN_VERSION=$(cat "${MAPR_HOME}/zeppelin/zeppelinversion")
export ZEPPELIN_HOME="${MAPR_HOME}/zeppelin/zeppelin-${ZEPPELIN_VERSION}"
export ZEPPELIN_CONF_DIR="${ZEPPELIN_HOME}/conf"

ZEPPELIN_KEYS_DIR="${ZEPPELIN_CONF_DIR}/keys"
ZEPPELIN_SITE_PATH="${ZEPPELIN_CONF_DIR}/zeppelin-site.xml"
ZEPPELIN_SITE_TEMPLATE="${ZEPPELIN_CONF_DIR}/zeppelin-site.xml.container_template"

ZEPPELIN_SSL_PORT="${ZEPPELIN_SSL_PORT:-9995}"
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

create_zeppelin_site() {
  if [ ! -e "$ZEPPELIN_SITE_PATH" ]; then
    cp "$ZEPPELIN_SITE_TEMPLATE" "$ZEPPELIN_SITE_PATH"
    sed -i \
        -e "s|__ZEPPELIN_SSL_PORT__|$ZEPPELIN_SSL_PORT|" \
        -e "s|__ZEPPELIN_KEYSTORE_PATH__|$ZEPPELIN_KEYSTORE_PATH|" \
        -e "s|__ZEPPELIN_KEYSTORE_PASS__|$ZEPPELIN_KEYSTORE_PASS|" \
        -e "s|__ZEPPELIN_KEYSTORE_TYPE__|$ZEPPELIN_KEYSTORE_TYPE|" \
        "$ZEPPELIN_SITE_PATH"
  else
    echo "Proper zeppelin-site.xml was not created as it already exists."
  fi
}

configure_interpreter_json() {
  # Do this tricky hack, as conf/interpreter.json are created only after Zeppelin startup
  nohup bash <<'EOF' &
ZEPPELIN_INTERPRETER_JSON="${ZEPPELIN_CONF_DIR}/interpreter.json"

JDBC_URL_DRILL="jdbc:drill:drillbit=localhost:31010"
JDBC_URL_HIVE="jdbc:hive2://localhost:10000/default"
if [ -n "${MAPR_TICKETFILE_LOCATION}" ]; then
  JDBC_URL_DRILL+=";auth=MAPRSASL"
  JDBC_URL_HIVE+=";auth=MAPRSASL"
fi

RETRIES=15
while [ "${RETRIES}" -gt 0 ]; do
  if [ -e "${ZEPPELIN_INTERPRETER_JSON}" ]; then
    sed -i \
      -e "s|__USER_DRILL__|${MAPR_CONTAINER_USER}|" \
      -e "s|__USER_HIVE__|${MAPR_CONTAINER_USER}|" \
      -e "s|__JDBC_URL_DRILL__|${JDBC_URL_DRILL}|" \
      -e "s|__JDBC_URL_HIVE__|${JDBC_URL_HIVE}|" \
      "${ZEPPELIN_INTERPRETER_JSON}"
    break
  fi
  RETRIES=$(expr "${RETRIES}" - 1)
  sleep 1
done
EOF
}

create_certificates
create_zeppelin_site
configure_interpreter_json

exec "${ZEPPELIN_HOME}/bin/zeppelin-daemon.sh" start
