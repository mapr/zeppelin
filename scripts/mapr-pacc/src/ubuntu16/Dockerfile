FROM ubuntu:16.04

ENV container docker

RUN export DEBIAN_FRONTEND=noninteractive && apt-get update -qq && apt-get install --no-install-recommends -q -y curl sudo tzdata wget apt-utils dnsutils file iputils-ping net-tools nfs-common openssl syslinux sysv-rc-conf libssl1.0.0 openjdk-8-jdk unzip && apt-get autoremove --purge -q -y && rm -rf /var/lib/apt/lists/* && apt-get clean -q

LABEL mapr.os=ubuntu16 mapr.version=6.0.0 mapr.mep_version=4.0.0

COPY mapr-setup.sh /opt/mapr/installer/docker/

COPY "rc.d" "/opt/mapr/installer/docker/rc.d"

EXPOSE  9995

RUN /opt/mapr/installer/docker/mapr-setup.sh container client 6.0.0 4.0.0 mapr-client mapr-posix-client-container mapr-hbase mapr-pig mapr-spark mapr-kafka mapr-zeppelin mapr-livy

RUN yum install -y gcc python-dev python-pip && pip install matplotlib numpy pandas

COPY preconfigure.sh /tmp
RUN chmod +x /tmp/preconfigure.sh ; /tmp/preconfigure.sh

ENTRYPOINT ["/opt/mapr/installer/docker/mapr-setup.sh", "container"]
