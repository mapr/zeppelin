#!/bin/sh

BASEDIR=$(dirname "$0")

MAPR_VERSION_DSR=${MAPR_VERSION_DSR:-"v1.5.0.0"}
MAPR_VERSION_CORE=${MAPR_VERSION_CORE:-"6.1.1"}
MAPR_VERSION_MEP=${MAPR_VERSION_MEP:-"6.3.4"}

DOCKER_BUILD_ARGS=${DOCKER_BUILD_ARGS:-""}
SSH_KEY_ARG=${SSH_KEY_ARG:-"--ssh default=${HOME}/.ssh/id_rsa"}

PUSH_IMAGES=false
RELEASE=false
BUILD_ALL=true
BUILD_SUCC=true
for arg in "$@"; do
    case "$arg" in
        -r|--release)
            RELEASE=true
            ;;
        -p|--push)
            PUSH_IMAGES=true
            ;;
        -n|--no-cache)
            DOCKER_BUILD_ARGS="${DOCKER_BUILD_ARGS} --no-cache"
            ;;
        *)
            echo "Wrong argument: '$arg'"
            exit 1
    esac
done

if [ "$PUSH_IMAGES" = true ] && [ "$RELEASE" = true ]; then
    echo "It's bad idea to build release images and push it without testing"
    exit 1
fi

if [ "$RELEASE" = true ]; then
    DOCKER_REPO=${DOCKER_REPO:-"maprtech/data-science-refinery"}
    IMAGE_VERSION=${IMAGE_VERSION:-"${MAPR_VERSION_DSR}_${MAPR_VERSION_CORE}_${MAPR_VERSION_MEP}"}
    ZEPPELIN_GIT_REPO=${ZEPPELIN_GIT_REPO:-"https://github.com/mapr/zeppelin.git"}
    ZEPPELIN_GIT_TAG=${ZEPPELIN_GIT_TAG:-"0.9.0-dsr-1.5.0.0"}
    MAPR_REPO_ROOT=${MAPR_REPO_ROOT:-"https://package.mapr.com/releases"}
    MAPR_MAVEN_REPO=${MAPR_MAVEN_REPO:-"http://repository.mapr.com/maven/"}
else
    DOCKER_REPO=${DOCKER_REPO:-"maprtech/testzepplinpacc"}
    IMAGE_VERSION=${IMAGE_VERSION:-$(date -u "+%Y%m%d%H%M")}
    ZEPPELIN_GIT_REPO=${ZEPPELIN_GIT_REPO:-"git@github.com:mapr/private-zeppelin.git"}
    ZEPPELIN_GIT_TAG=${ZEPPELIN_GIT_TAG:-"branch-0.9.0-mapr"}
    # MAPR_REPO_ROOT=${MAPR_REPO_ROOT:-"http://dfaf.mip.storage.hpecorp.net/artifactory/prestage/releases-dev"}
    MAPR_REPO_ROOT=${MAPR_REPO_ROOT:-"https://package.mapr.com/releases"}
    # MAPR_MAVEN_REPO=${MAPR_MAVEN_REPO:-"http://df-mvn-dev.mip.storage.hpecorp.net/nexus/content/groups/public/"}
    MAPR_MAVEN_REPO=${MAPR_MAVEN_REPO:-"http://repository.mapr.com/maven/"}
fi

docker_build() {
    dockerfile="${BASEDIR}/$1"

    export DOCKER_BUILDKIT=1
    docker build "$BASEDIR" \
        $DOCKER_BUILD_ARGS \
        $SSH_KEY_ARG \
        --build-arg MAPR_VERSION_CORE="$MAPR_VERSION_CORE" \
        --build-arg MAPR_VERSION_MEP="$MAPR_VERSION_MEP" \
        --build-arg MAPR_REPO_ROOT="$MAPR_REPO_ROOT" \
        --build-arg ZEPPELIN_GIT_REPO="$ZEPPELIN_GIT_REPO" \
        --build-arg ZEPPELIN_GIT_TAG="$ZEPPELIN_GIT_TAG" \
        --build-arg MAPR_MAVEN_REPO="$MAPR_MAVEN_REPO" \
        --file "$dockerfile" \
        --tag "$2"
    res="$?"

    return "$res"
}

echo "Building centos7 image: ${DOCKER_REPO}:${IMAGE_VERSION}_centos7"
docker_build "centos7/Dockerfile" "${DOCKER_REPO}:${IMAGE_VERSION}_centos7"
[ "$?" -ne 0 ] && BUILD_SUCC=false

if [ "$PUSH_IMAGES" = true ] && [ "$BUILD_SUCC" = true ]; then
    docker push "${DOCKER_REPO}:${IMAGE_VERSION}_centos7"
    docker tag "${DOCKER_REPO}:${IMAGE_VERSION}_centos7" "${DOCKER_REPO}:latest"
    docker push "${DOCKER_REPO}:latest"
fi
