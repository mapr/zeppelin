FROM centos:centos7 as zeppelin_builder

ARG ZEPPELIN_GIT_REPO="git@github.com:mapr/zeppelin.git"
ARG ZEPPELIN_GIT_TAG="0.8.2-mapr-1912"
ARG MAPR_MAVEN_REPO="http://repository.mapr.com/maven/"

RUN yum install -y git wget java-1.8.0-openjdk-devel which bzip2 && \
    mkdir /opt/maven && \
    wget https://www.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz -O maven.tar.gz && \
    tar xf maven.tar.gz --strip-components=1 -C /opt/maven && \
    ln -s /opt/maven/bin/mvn /usr/local/bin/mvn

RUN \
    mkdir -p -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git clone "$ZEPPELIN_GIT_REPO" zeppelin && \
    cd zeppelin && \
    git checkout "$ZEPPELIN_GIT_TAG" && \
    mvn clean package -DskipTests -P 'scala-2.11,build-distr,vendor-repo-mapr' && \
    ZEPPELIN_MAVEN_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout) && \
    mv "./zeppelin-distribution/target/zeppelin-${ZEPPELIN_MAVEN_VERSION}/zeppelin-${ZEPPELIN_MAVEN_VERSION}" /zeppelin_build


FROM centos:centos7

ARG ZEPPELIN_VERSION="0.8.2"
ARG MAPR_VERSION_CORE="6.1.0"
ARG MAPR_VERSION_MEP="6.3.0"
ARG MAPR_REPO_ROOT="https://package.mapr.com/releases"

LABEL mapr.os=centos7 mapr.version=$MAPR_VERSION_CORE mapr.mep_version=$MAPR_VERSION_MEP

ENV container docker

RUN yum install -y curl initscripts net-tools sudo wget which syslinux openssl file java-1.8.0-openjdk-devel unzip

RUN mkdir -p /opt/mapr/installer/docker/ && \
    wget "${MAPR_REPO_ROOT}/installer/redhat/mapr-setup.sh" -P /opt/mapr/installer/docker/ && \
    chmod +x /opt/mapr/installer/docker/mapr-setup.sh

RUN /opt/mapr/installer/docker/mapr-setup.sh -r "$MAPR_REPO_ROOT" container client "$MAPR_VERSION_CORE" "$MAPR_VERSION_MEP" mapr-client mapr-hbase mapr-spark mapr-kafka

RUN mkdir -p /opt/mapr/zeppelin && \
    echo "$ZEPPELIN_VERSION" > /opt/mapr/zeppelin/zeppelinversion

RUN yum install -y git less nano patch vim && \
    yum install -y gcc python-devel python-setuptools && \
    easy_install pip && \
    pip install matplotlib numpy pandas requests

COPY --from=zeppelin_builder /zeppelin_build "/opt/mapr/zeppelin/zeppelin-$ZEPPELIN_VERSION"

RUN ZEPPELIN_HOME="/opt/mapr/zeppelin/zeppelin-${ZEPPELIN_VERSION}" ;\
    ln -s "${ZEPPELIN_HOME}/bin/entrypoint.sh" "/entrypoint.sh" ;\
    cat "${ZEPPELIN_HOME}/scripts/mapr-dsr/misc/profile.d/mapr.sh" >> /etc/profile.d/mapr.sh

RUN echo -e "\n\
[kubernetes] \n\
name=Kubernetes \n\
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64 \n\
enabled=1 \n\
gpgcheck=1 \n\
repo_gpgcheck=1 \n\
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg \n\
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg \n\
" > /etc/yum.repos.d/cloud-sdk-el7-x86_64.repo && \
    yum install -y kubectl

RUN rm /etc/yum.repos.d/mapr_*.repo && \
    yum -q clean all && \
    rm -rf /var/lib/yum/history/* && \
    find /var/lib/yum/yumdb/ -name origin_url -exec rm {} \;

EXPOSE 9995
EXPOSE 10000-10010
EXPOSE 11000-11010

ENTRYPOINT [ "/entrypoint.sh" ]
