#!/bin/bash

export MAPR_VERSION_DSR=${MAPR_VERSION_DSR:-"v1.3.1"}
export MAPR_VERSION_CORE=${MAPR_VERSION_CORE:-"6.1.0"}
export MAPR_VERSION_MEP=${MAPR_VERSION_MEP:-"6.0.0"}


BUILD_ALL=true
PUSH_IMAGES=false
for arg in "$@"; do
    case "$arg" in
        -d|--devel)
            export DOCKER_REPO=${DOCKER_REPO:-"maprtech/testzepplinpacc"}
            export IMAGE_VERSION=${IMAGE_VERSION:-$(date -u "+%Y%m%d%H%M")}
            export MAPR_REPO_ROOT=${MAPR_REPO_ROOT:-"http://artifactory.devops.lab/artifactory/prestage/releases-dev"}
            export MAPR_SETUP_URL=${MAPR_SETUP_URL:-"${MAPR_REPO_ROOT}/installer/redhat/mapr-setup.sh"}
            export MAPR_DSR_REPO_ROOT=${MAPR_DSR_REPO_ROOT:-"http://artifactory.devops.lab/artifactory/prestage/labs/data-science-refinery"}
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


export MAPR_REPO_ROOT=${MAPR_REPO_ROOT:-"https://package.mapr.com/releases"}
export MAPR_SETUP_URL=${MAPR_SETUP_URL:-"${MAPR_REPO_ROOT}/installer/mapr-setup.sh"}
export MAPR_DSR_REPO_ROOT=${MAPR_DSR_REPO_ROOT:-"https://package.mapr.com/labs/data-science-refinery"}

export DOCKER_REPO=${DOCKER_REPO:-"maprtech/data-science-refinery"}
export IMAGE_VERSION=${IMAGE_VERSION:-"${MAPR_VERSION_DSR}_${MAPR_VERSION_CORE}_${MAPR_VERSION_MEP}"}


if [ "$BUILD_CENTOS7" = "true" ]; then
    echo "Building centos7"
    docker build -t "${DOCKER_REPO}:${IMAGE_VERSION}_centos7" \
        --build-arg MAPR_VERSION_DSR="${MAPR_VERSION_DSR}" \
        --build-arg MAPR_VERSION_CORE="${MAPR_VERSION_CORE}" \
        --build-arg MAPR_VERSION_MEP="${MAPR_VERSION_MEP}" \
        --build-arg MAPR_REPO_ROOT="${MAPR_REPO_ROOT}" \
        --build-arg MAPR_SETUP_URL="${MAPR_SETUP_URL}" \
        --build-arg MAPR_DSR_REPO_ROOT="${MAPR_DSR_REPO_ROOT}" \
        -f centos7/Dockerfile .
    if [ "$PUSH_IMAGES" = "true" ]; then
        docker push "${DOCKER_REPO}:${IMAGE_VERSION}_centos7"
    fi
fi

if [ "$BUILD_UBUNTU16" = "true" ]; then
    echo "Building ubuntu16"
    docker build -t "${DOCKER_REPO}:${IMAGE_VERSION}_ubuntu16" \
        --build-arg MAPR_VERSION_DSR="${MAPR_VERSION_DSR}" \
        --build-arg MAPR_VERSION_CORE="${MAPR_VERSION_CORE}" \
        --build-arg MAPR_VERSION_MEP="${MAPR_VERSION_MEP}" \
        --build-arg MAPR_REPO_ROOT="${MAPR_REPO_ROOT}" \
        --build-arg MAPR_SETUP_URL="${MAPR_SETUP_URL}" \
        --build-arg MAPR_DSR_REPO_ROOT="${MAPR_DSR_REPO_ROOT}" \
        -f ubuntu16/Dockerfile .
    if [ "$PUSH_IMAGES" = "true" ]; then
        docker push "${DOCKER_REPO}:${IMAGE_VERSION}_ubuntu16"
    fi
fi
