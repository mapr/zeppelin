# syntax=docker/dockerfile:1.0.2-experimental
FROM ubuntu:16.04 as zeppelin_builder

ARG ZEPPELIN_GIT_REPO="git@github.com:mapr/zeppelin.git"
ARG ZEPPELIN_GIT_TAG="0.8.2-mapr-1911"
ARG MAPR_MAVEN_REPO="http://repository.mapr.com/maven/"

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update -qq && \
    apt install --no-install-recommends -q -y git openssh-client wget openjdk-8-jdk bzip2 && \
    mkdir /opt/maven && \
    wget https://www.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz -O maven.tar.gz && \
    tar xf maven.tar.gz --strip-components=1 -C /opt/maven && \
    ln -s /opt/maven/bin/mvn /usr/local/bin/mvn

RUN --mount=type=cache,id=mvncache,target=/root/.m2 --mount=type=cache,id=npmcache,target=/root/.npm --mount=type=ssh \
    mkdir -p -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git clone "$ZEPPELIN_GIT_REPO" zeppelin && \
    cd zeppelin && \
    git checkout "$ZEPPELIN_GIT_TAG" && \
    mvn clean package -DskipTests -P 'scala-2.11,build-distr,vendor-repo-mapr' && \
    ZEPPELIN_MAVEN_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout) && \
    mv "./zeppelin-distribution/target/zeppelin-${ZEPPELIN_MAVEN_VERSION}/zeppelin-${ZEPPELIN_MAVEN_VERSION}" /zeppelin_build


FROM ubuntu:16.04

ARG ZEPPELIN_VERSION="0.8.2"
ARG MAPR_VERSION_CORE="6.1.0"
ARG MAPR_VERSION_MEP="6.3.0"
ARG MAPR_REPO_ROOT="https://package.mapr.com/releases"

LABEL mapr.os=ubuntu16 mapr.version=$MAPR_VERSION_CORE mapr.mep_versiona=$MAPR_VERSION_MEP

ENV container docker

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update -qq && \
    apt install --no-install-recommends -q -y curl sudo tzdata wget apt-transport-https apt-utils dnsutils file iputils-ping net-tools nfs-common openssl syslinux sysv-rc-conf libssl1.0.0 openjdk-8-jdk unzip

RUN mkdir -p /opt/mapr/installer/docker/ && \
    wget "${MAPR_REPO_ROOT}/installer/ubuntu/mapr-setup.sh" -P /opt/mapr/installer/docker/ && \
    chmod +x /opt/mapr/installer/docker/mapr-setup.sh

RUN /opt/mapr/installer/docker/mapr-setup.sh -r "$MAPR_REPO_ROOT" container client "$MAPR_VERSION_CORE" "$MAPR_VERSION_MEP" mapr-client mapr-posix-client-container mapr-hbase mapr-pig mapr-spark mapr-kafka mapr-livy

RUN mkdir -p /opt/mapr/zeppelin && \
    echo "$ZEPPELIN_VERSION" > /opt/mapr/zeppelin/zeppelinversion

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && \
    apt install --no-install-recommends -q -y gcc python-dev python-setuptools && \
    easy_install pip && \
    pip install matplotlib numpy pandas

COPY --from=zeppelin_builder /zeppelin_build "/opt/mapr/zeppelin/zeppelin-$ZEPPELIN_VERSION"

RUN ZEPPELIN_HOME="/opt/mapr/zeppelin/zeppelin-${ZEPPELIN_VERSION}" && \
    ln -s "${ZEPPELIN_HOME}/bin/entrypoint.sh" "/entrypoint.sh" && \
    cat "${ZEPPELIN_HOME}/scripts/mapr-dsr/misc/profile.d/mapr.sh" >> /etc/profile.d/mapr.sh

RUN rm /etc/apt/sources.list.d/mapr_* && \
    apt-get autoremove --purge -q -y && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean -q

EXPOSE 9995
EXPOSE 10000-10010
EXPOSE 11000-11010

ENTRYPOINT [ "/entrypoint.sh" ]
