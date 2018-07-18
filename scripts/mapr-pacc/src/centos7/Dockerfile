FROM centos:centos7

ENV container docker

ARG MAPR_REPO_ROOT=http://package.mapr.com/releases

RUN yum install -y curl initscripts net-tools sudo wget which syslinux openssl file java-1.8.0-openjdk-devel unzip && yum -q clean all

LABEL mapr.os=centos7 mapr.version=6.1.0 mapr.mep_version=6.0.0

COPY mapr-setup.sh /opt/mapr/installer/docker/

COPY "rc.d" "/opt/mapr/installer/docker/rc.d"

EXPOSE 9995
EXPOSE 10000-10010
EXPOSE 11000-11010

RUN /opt/mapr/installer/docker/mapr-setup.sh -r "${MAPR_REPO_ROOT}" container client 6.1.0 6.0.0 mapr-client mapr-posix-client-container mapr-hbase mapr-pig mapr-spark mapr-kafka mapr-livy

COPY mapr-zeppelin-*.rpm /tmp
COPY preconfigure.sh /tmp
RUN chmod +x /tmp/preconfigure.sh ; /tmp/preconfigure.sh ; rm /tmp/preconfigure.sh

# Workaround for MZEP-59
ENV DRILL_HOME /opt/mapr

ENTRYPOINT ["/opt/mapr/installer/docker/mapr-setup.sh", "container"]
