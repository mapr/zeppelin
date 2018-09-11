FROM ubuntu:16.04

ENV container docker

ARG MAPR_REPO_ROOT=http://package.mapr.com/releases

RUN export DEBIAN_FRONTEND=noninteractive && apt-get update -qq && apt-get install --no-install-recommends -q -y curl sudo tzdata wget apt-utils dnsutils file iputils-ping net-tools nfs-common openssl syslinux sysv-rc-conf libssl1.0.0 openjdk-8-jdk unzip && apt-get autoremove --purge -q -y && rm -rf /var/lib/apt/lists/* && apt-get clean -q

LABEL mapr.os=ubuntu16 mapr.version=6.1.0 mapr.mep_version=6.0.0

COPY mapr-setup.sh /opt/mapr/installer/docker/

COPY "rc.d" "/opt/mapr/installer/docker/rc.d"

EXPOSE 9995
EXPOSE 10000-10010
EXPOSE 11000-11010

RUN /opt/mapr/installer/docker/mapr-setup.sh -r "${MAPR_REPO_ROOT}" container client 6.1.0 6.0.0 mapr-client mapr-posix-client-container mapr-hbase mapr-pig mapr-spark mapr-kafka mapr-livy

COPY mapr-zeppelin_*.deb /tmp
COPY preconfigure.sh /tmp
RUN chmod +x /tmp/preconfigure.sh ; /tmp/preconfigure.sh ; rm /tmp/preconfigure.sh

ENTRYPOINT ["/opt/mapr/installer/docker/mapr-setup.sh", "container"]
