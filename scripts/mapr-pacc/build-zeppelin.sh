#!/bin/bash

BUILD_ALL=true
PUSH_IMAGES=false
for arg in "$@"; do
    case "$arg" in
        -d|--devel)
            export DOCKER_REPO=${DOCKER_REPO:-"maprtech/testzepplinpacc"}
            export IMAGE_VERSION=${IMAGE_VERSION:-$(date -u "+%Y%m%d%H%M")}
            export MAPR_REPO_ROOT=${MAPR_REPO_ROOT:-"http://artifactory.devops.lab/artifactory/prestage/releases-dev"}
            ;;
        -p|--push)
            PUSH_IMAGES=true
            ;;
        centos7)
            BUILD_CENTOS7=true
            BUILD_ALL=false
            ;;
        ubuntu16)
            BUILD_UBUNTU16=true
            BUILD_ALL=false
            ;;
        *)
            echo "Wrong argument: $arg"
            BUILD_ALL=false
    esac
done

if [ "${BUILD_ALL}" = "true" ]; then
    BUILD_CENTOS7=true
    BUILD_UBUNTU16=true
fi


export DOCKER_REPO=${DOCKER_REPO:-"maprtech/data-science-refinery"}
export IMAGE_VERSION=${IMAGE_VERSION:-"v1.3_6.1.0_6.0.0"}
export MAPR_REPO_ROOT=${MAPR_REPO_ROOT:-"http://package.mapr.com/releases"}


getMaprSetup() {
    DIR="${1:-.}"
    [ ! -e "${DIR}/mapr-setup.sh" ] && curl -o "${DIR}/mapr-setup.sh" "${MAPR_REPO_ROOT}/installer/mapr-setup.sh"
    chmod +x "${DIR}/mapr-setup.sh"
}


if [ "$BUILD_CENTOS7" = "true" ]; then
    echo "Building centos7"
    getMaprSetup src/
    docker build -t "${DOCKER_REPO}:${IMAGE_VERSION}_centos7" --build-arg MAPR_REPO_ROOT="${MAPR_REPO_ROOT}" -f src/centos7/Dockerfile src/
    if [ "$PUSH_IMAGES" = "true" ]; then
        docker push "${DOCKER_REPO}:${IMAGE_VERSION}_centos7"
    fi
fi

if [ "$BUILD_UBUNTU16" = "true" ]; then
    echo "Building ubuntu16"
    getMaprSetup src/
    docker build -t "${DOCKER_REPO}:${IMAGE_VERSION}_ubuntu16" --build-arg MAPR_REPO_ROOT="${MAPR_REPO_ROOT}" -f src/ubuntu16/Dockerfile src/
    if [ "$PUSH_IMAGES" = "true" ]; then
        docker push "${DOCKER_REPO}:${IMAGE_VERSION}_ubuntu16"
    fi
fi
