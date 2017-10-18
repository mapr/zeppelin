#!/bin/bash

MEP_RELEASE=mep400

BUILD_CENTOS7=false
BUILD_UBUNTU16=false
if [ -z "$@" ]; then
    BUILD_CENTOS7=true
    BUILD_UBUNTU16=true
else
    for arg in "$@"; do
        case "$arg" in
            centos7)
                BUILD_CENTOS7=true
                ;;
            ubuntu16)
                BUILD_UBUNTU16=true
                ;;
            *)
                echo "Wrong argument: $arg"
        esac
    done
fi


getMaprSetup() {
    DIR="${1:-.}"
    [ ! -e "${DIR}/mapr-setup.sh" ] && curl -o "${DIR}/mapr-setup.sh" "http://package.mapr.com/releases/installer/mapr-setup.sh"
    chmod +x "${DIR}/mapr-setup.sh"
}


if [ "$BUILD_CENTOS7" = "true" ]; then
    echo "Building centos7"
    getMaprSetup src/
    docker build -t "maprtech/pacc-zeppelin-centos7:${MEP_RELEASE}" -f src/centos7/Dockerfile src/
fi

if [ "$BUILD_UBUNTU16" = "true" ]; then
    echo "Building ubuntu16"
    getMaprSetup src/
    docker build -t "maprtech/pacc-zeppelin-ubuntu16:${MEP_RELEASE}" -f src/ubuntu16/Dockerfile src/
fi
