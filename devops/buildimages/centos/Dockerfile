ARG BASE_IMAGE
FROM ${BASE_IMAGE}

RUN unlink /opt/maven && \
    mkdir /opt/maven && \
    curl -s http://dfaf.ftc.hcocto.hpecorp.net/artifactory/buildmachine-files-copy/cross-linux/apache-maven-3.5.4-bin.tar.gz | tar -xz --strip-components=1 -C /opt/maven
