#!/bin/bash -ex

MAPR_HOME=${MAPR_HOME:-/opt/mapr}

install_python_modules_debian() {
    apt-get install --no-install-recommends -q -y gcc python-dev python-setuptools
    easy_install pip
    pip install matplotlib numpy pandas
}

install_python_modules_redhat() {
    yum install -y gcc python-devel python-setuptools
    easy_install pip
    pip install matplotlib numpy pandas
}

install_r_modules_debian() {
    apt-get install --no-install-recommends -q -y r-base r-base-dev
    R --vanilla <<'EOF'
install.packages(c("data.table", "ggplot2", "googleVis", "knitr"), repos="https://cloud.r-project.org/")
EOF
}

install_r_modules_redhat() {
    yum install -y R-core R-core-devel
    R --vanilla <<'EOF'
install.packages(c("data.table", "ggplot2", "googleVis", "knitr"), repos="https://cloud.r-project.org/")
EOF
}

install_zeppelin_debian() {
    dpkg -i /tmp/mapr-zeppelin_*.deb
    rm /tmp/mapr-zeppelin_*.deb
}

install_zeppelin_redhat() {
    rpm -i /tmp/mapr-zeppelin-*.rpm
    rm /tmp/mapr-zeppelin-*.rpm
}

clean_repos_debian() {
    rm /etc/apt/sources.list.d/mapr_*
    apt-get autoremove --purge -q -y
    rm -rf /var/lib/apt/lists/*
    apt-get clean -q
}

clean_repos_redhat() {
    rm /etc/yum.repos.d/mapr_*.repo
    yum -q clean all
    rm -rf /var/lib/yum/history/*
    find /var/lib/yum/yumdb/ -name origin_url -exec rm {} \;
}

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

setup_spark_jars() {
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
}

spark_fix_log4j() { #DSR-20
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


if [ -e "/etc/debian_version" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    install_python_modules_debian
    install_r_modules_debian
    install_zeppelin_debian
    clean_repos_debian
fi

if [ -e "/etc/redhat-release" ]; then
    install_python_modules_redhat
    install_r_modules_redhat
    install_zeppelin_redhat
    clean_repos_redhat
fi

SPARK_HOME=$(get_spark_home)
if [ -e "${SPARK_HOME}" ]; then
    setup_spark_jars
    spark_fix_log4j
fi

MAPR_ENV_FILE="/etc/profile.d/mapr.sh"
cat > "$MAPR_ENV_FILE" <<'EOM'
#!/bin/bash
# USER variable may be not set on Ubuntu
if [ -x /usr/bin/id ]; then
    USER=${USER:-$(/usr/bin/id -un)}
    LOGNAME=${LOGNAME:-$USER}
    MAIL=${MAIL:-"/var/spool/mail/$USER"}
    export USER LOGNAME MAIL
fi

cd ~

EOM
