FROM centos:centos7

LABEL mapr.os=centos7 mapr.version=6.1.0 mapr.mep_version=6.0.0

ARG MAPR_VERSION_CORE="6.1.0"
ARG MAPR_VERSION_MEP="6.0.0"
ARG MAPR_VERSION_DSR="v1.3"
ARG MAPR_REPO_ROOT="https://package.mapr.com/releases"
ARG MAPR_SETUP_URL="${MAPR_REPO_ROOT}/installer/mapr-setup.sh"
ARG MAPR_DSR_REPO_ROOT="https://package.mapr.com/labs/data-science-refinery"

ENV container docker

RUN yum install -y curl initscripts net-tools sudo wget which syslinux openssl file java-1.8.0-openjdk-devel unzip

RUN mkdir -p /opt/mapr/installer/docker/ ;\
    wget "$MAPR_SETUP_URL" -P /opt/mapr/installer/docker/ ;\
    chmod +x /opt/mapr/installer/docker/mapr-setup.sh

RUN /opt/mapr/installer/docker/mapr-setup.sh -r "$MAPR_REPO_ROOT" container client "$MAPR_VERSION_CORE" "$MAPR_VERSION_MEP" mapr-client mapr-posix-client-container mapr-hbase mapr-pig mapr-spark mapr-kafka mapr-livy

RUN echo -e "[MapR_DSR] \n\
name=MapR DSR Components \n\
baseurl=${MAPR_DSR_REPO_ROOT}/${MAPR_VERSION_DSR}/redhat/ \n\
gpgcheck=1 \n\
enabled=1 \n\
protected=1 \n\
" > /etc/yum.repos.d/mapr_dsr.repo

RUN yum install -y mapr-zeppelin

RUN yum install -y gcc python-devel python-setuptools ;\
    easy_install pip ;\
    pip install matplotlib numpy pandas

RUN ZEPPELIN_VERSION="$(cat /opt/mapr/zeppelin/zeppelinversion)" ;\
    ZEPPELIN_HOME="/opt/mapr/zeppelin/zeppelin-${ZEPPELIN_VERSION}" ;\
    mkdir -p /opt/mapr/installer/docker/rc.d ;\
    cp "${ZEPPELIN_HOME}/scripts/mapr-dsr/misc/rc.d/20_zeppelin" /opt/mapr/installer/docker/rc.d ;\
    cat "${ZEPPELIN_HOME}/scripts/mapr-dsr/misc/profile.d/mapr.sh" >> /etc/profile.d/mapr.sh

RUN rm /etc/yum.repos.d/mapr_*.repo ;\
    yum -q clean all ;\
    rm -rf /var/lib/yum/history/* ;\
    find /var/lib/yum/yumdb/ -name origin_url -exec rm {} \;

EXPOSE 9995
EXPOSE 10000-10010
EXPOSE 11000-11010

ENTRYPOINT ["/opt/mapr/installer/docker/mapr-setup.sh", "container"]
