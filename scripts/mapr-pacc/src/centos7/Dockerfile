FROM centos:centos7

ENV container docker

RUN yum install -y curl initscripts net-tools sudo wget which syslinux openssl file java-1.8.0-openjdk-devel unzip && yum -q clean all

LABEL mapr.os=centos7 mapr.version=6.0.0 mapr.mep_version=4.0.0

COPY mapr-setup.sh /opt/mapr/installer/docker/

COPY "rc.d" "/opt/mapr/installer/docker/rc.d"

EXPOSE  9995

RUN /opt/mapr/installer/docker/mapr-setup.sh -r "http://artifactory.devops.lab/artifactory/prestage/releases/" container client 6.0.0 4.0.0 mapr-client mapr-posix-client-container mapr-hbase mapr-pig mapr-spark mapr-kafka mapr-livy

COPY mapr-zeppelin-*.rpm /tmp
COPY preconfigure.sh /tmp
RUN chmod +x /tmp/preconfigure.sh ; /tmp/preconfigure.sh ; rm /tmp/preconfigure.sh

# Workaround for MZEP-59
ENV DRILL_HOME /opt/mapr

ENTRYPOINT ["/opt/mapr/installer/docker/mapr-setup.sh", "container"]
