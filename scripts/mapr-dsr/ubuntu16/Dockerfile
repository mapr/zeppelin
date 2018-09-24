FROM ubuntu:16.04

LABEL mapr.os=ubuntu16 mapr.version=6.1.0 mapr.mep_version=6.0.0

ARG MAPR_VERSION_CORE="6.1.0"
ARG MAPR_VERSION_MEP="6.0.0"
ARG MAPR_VERSION_DSR="v1.3"
ARG MAPR_REPO_ROOT="https://package.mapr.com/releases"
ARG MAPR_SETUP_URL="${MAPR_REPO_ROOT}/installer/mapr-setup.sh"
ARG MAPR_DSR_REPO_ROOT="https://package.mapr.com/labs/data-science-refinery"

ENV container docker

RUN export DEBIAN_FRONTEND=noninteractive && apt-get update -qq && apt-get install --no-install-recommends -q -y curl sudo tzdata wget apt-utils dnsutils file iputils-ping net-tools nfs-common openssl syslinux sysv-rc-conf libssl1.0.0 openjdk-8-jdk unzip && apt-get autoremove --purge -q -y && rm -rf /var/lib/apt/lists/* && apt-get clean -q

RUN mkdir -p /opt/mapr/installer/docker/ ;\
    wget "$MAPR_SETUP_URL" -P /opt/mapr/installer/docker/ ;\
    chmod +x /opt/mapr/installer/docker/mapr-setup.sh

RUN /opt/mapr/installer/docker/mapr-setup.sh -r "$MAPR_REPO_ROOT" container client 6.1.0 6.0.0 mapr-client mapr-posix-client-container mapr-hbase mapr-pig mapr-spark mapr-kafka mapr-livy

RUN echo "deb ${MAPR_DSR_REPO_ROOT}/${MAPR_VERSION_DSR}/ubuntu binary trusty" > /etc/apt/sources.list.d/mapr_dsr.list

RUN export DEBIAN_FRONTEND=noninteractive ;\
    apt update -qq ;\
    apt install -q -y mapr-zeppelin

RUN export DEBIAN_FRONTEND=noninteractive ;\
    apt-get install --no-install-recommends -q -y gcc python-dev python-setuptools ;\
    easy_install pip ;\
    pip install matplotlib numpy pandas

RUN ZEPPELIN_VERSION="$(cat /opt/mapr/zeppelin/zeppelinversion)" ;\
    ZEPPELIN_HOME="/opt/mapr/zeppelin/zeppelin-${ZEPPELIN_VERSION}" ;\
    mkdir -p /opt/mapr/installer/docker/rc.d ;\
    cp "${ZEPPELIN_HOME}/scripts/mapr-dsr/misc/rc.d/20_zeppelin" /opt/mapr/installer/docker/rc.d/20_zeppelin ;\
    cat "${ZEPPELIN_HOME}/scripts/mapr-dsr/misc/profile.d/mapr.sh" >> /etc/profile.d/mapr.sh

RUN rm /etc/apt/sources.list.d/mapr_* ;\
    apt-get autoremove --purge -q -y ;\
    rm -rf /var/lib/apt/lists/* ;\
    apt-get clean -q

EXPOSE 9995
EXPOSE 10000-10010
EXPOSE 11000-11010

ENTRYPOINT ["/opt/mapr/installer/docker/mapr-setup.sh", "container"]
