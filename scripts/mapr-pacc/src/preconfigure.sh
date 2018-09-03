#!/bin/bash -ex

MAPR_HOME=${MAPR_HOME:-/opt/mapr}

install_python_modules_debian() {
    apt-get install --no-install-recommends -q -y gcc python-dev python-setuptools
    easy_install pip
    pip install matplotlib numpy pandas jupyter grpcio protobuf
}

install_python_modules_redhat() {
    yum install -y gcc python-devel python-setuptools
    easy_install pip
    pip install matplotlib numpy pandas jupyter grpcio protobuf
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


if [ -e "/etc/debian_version" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    install_python_modules_debian
    install_zeppelin_debian
    clean_repos_debian
fi

if [ -e "/etc/redhat-release" ]; then
    install_python_modules_redhat
    install_zeppelin_redhat
    clean_repos_redhat
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

    if [ -x /usr/bin/getent ]; then
        HOME=$(/usr/bin/getent passwd $USER | cut -d ':' -f 6)
        export HOME
    fi
fi

cd ~

EOM
