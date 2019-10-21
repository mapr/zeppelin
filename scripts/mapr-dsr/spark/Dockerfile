# syntax=docker/dockerfile:1.0.2-experimental
FROM centos:centos7 as zeppelin_builder

ARG ZEPPELIN_GIT_REPO="git@github.com:mapr/zeppelin.git"
ARG ZEPPELIN_GIT_TAG="0.8.2-mapr-1911"
ARG MAPR_MAVEN_REPO="http://repository.mapr.com/maven/"

RUN yum install -y git wget java-1.8.0-openjdk-devel which bzip2 && \
    mkdir /opt/maven && \
    wget https://www.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz -O maven.tar.gz && \
    tar xf maven.tar.gz --strip-components=1 -C /opt/maven && \
    ln -s /opt/maven/bin/mvn /usr/local/bin/mvn

RUN --mount=type=cache,id=mvncache,target=/root/.m2 --mount=type=cache,id=npmcache,target=/root/.npm --mount=type=ssh \
    mkdir -p -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git clone "$ZEPPELIN_GIT_REPO" zeppelin && \
    cd zeppelin && \
    git checkout "$ZEPPELIN_GIT_TAG" && \
    mvn clean package -DskipTests -P 'scala-2.11,build-distr,vendor-repo-mapr' -pl 'spark/interpreter,zeppelin-display,zeppelin-interpreter,spark/scala-2.11,spark/spark2-shims,spark/spark-shims,python,zeppelin-distribution,zeppelin-server,zeppelin-web,zeppelin-zengine' && \
    ZEPPELIN_MAVEN_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout) && \
    mv "./zeppelin-distribution/target/zeppelin-${ZEPPELIN_MAVEN_VERSION}/zeppelin-${ZEPPELIN_MAVEN_VERSION}" /zeppelin_build


FROM us.gcr.io/mapreng-1/maprtech/spark-2.4.4:latest

ARG ZEPPELIN_VERSION="0.8.2"

RUN yum install -y gcc python-devel python-setuptools && \
    easy_install pip && \
    pip install matplotlib numpy pandas && \
    yum install -y R-core R-core-devel && \
    Rscript -e 'install.packages(c("data.table", "ggplot2", "googleVis", "knitr"), repos="https://cloud.r-project.org/")'

COPY --from=zeppelin_builder /zeppelin_build "/opt/mapr/zeppelin/zeppelin-$ZEPPELIN_VERSION"
