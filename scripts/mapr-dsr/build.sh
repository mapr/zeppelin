#!/bin/sh

MAPR_VERSION_DSR=${MAPR_VERSION_DSR:-"v1.4.0"}
MAPR_VERSION_CORE=${MAPR_VERSION_CORE:-"6.1.0"}
MAPR_VERSION_MEP=${MAPR_VERSION_MEP:-"6.2.0"}

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
        centos7)
            BUILD_CENTOS7=true
            BUILD_ALL=false
            ;;
        ubuntu16)
            BUILD_UBUNTU16=true
            BUILD_ALL=false
            ;;
        kubeflow)
            BUILD_KUBEFLOW=true
            BUILD_ALL=false
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
    ZEPPELIN_GIT_TAG=${ZEPPELIN_GIT_TAG:-"0.8.1-mapr-1904"}
    MAPR_REPO_ROOT=${MAPR_REPO_ROOT:-"https://package.mapr.com/releases"}
    MAPR_MAVEN_REPO=${MAPR_MAVEN_REPO:-"http://repository.mapr.com/maven/"}
else
    DOCKER_REPO=${DOCKER_REPO:-"maprtech/testzepplinpacc"}
    IMAGE_VERSION=${IMAGE_VERSION:-$(date -u "+%Y%m%d%H%M")}
    ZEPPELIN_GIT_REPO=${ZEPPELIN_GIT_REPO:-"git@github.com:mapr/private-zeppelin.git"}
    ZEPPELIN_GIT_TAG=${ZEPPELIN_GIT_TAG:-"branch-0.8.1-mapr"}
    MAPR_REPO_ROOT=${MAPR_REPO_ROOT:-"http://artifactory.devops.lab/artifactory/prestage/releases-dev"}
    MAPR_MAVEN_REPO=${MAPR_MAVEN_REPO:-"http://maven.corp.maprtech.com/nexus/content/groups/public/"}
fi
KUBEFLOW_REPO=${KUBEFLOW_REPO:-"us.gcr.io/mapreng-1/maprtech/zeppelin"}
KUBEFLOW_IMAGE_VERSION=${KUBEFLOW_IMAGE_VERSION:-"$IMAGE_VERSION"}

if [ "$BUILD_ALL" = true ]; then
    BUILD_UBUNTU16=true
    BUILD_CENTOS7=true
    BUILD_KUBEFLOW=true
fi

docker_build() {
    docker build . \
        --no-cache \
        --build-arg MAPR_VERSION_CORE="$MAPR_VERSION_CORE" \
        --build-arg MAPR_VERSION_MEP="$MAPR_VERSION_MEP" \
        --build-arg MAPR_REPO_ROOT="$MAPR_REPO_ROOT" \
        --build-arg ZEPPELIN_GIT_REPO="$ZEPPELIN_GIT_REPO" \
        --build-arg ZEPPELIN_GIT_TAG="$ZEPPELIN_GIT_TAG" \
        --build-arg MAPR_MAVEN_REPO="$MAPR_MAVEN_REPO" \
        --file "$1" \
        --tag "$2"
    res="$?"

    return "$res"
}

if [ "$BUILD_UBUNTU16" = true ]; then
    echo "Building ubuntu16"
    docker_build "ubuntu16/Dockerfile" "${DOCKER_REPO}:${IMAGE_VERSION}_ubuntu16"
    [ "$?" -ne 0 ] && BUILD_SUCC=false
fi

if [ "$BUILD_CENTOS7" = true ]; then
    echo "Building centos7"
    docker_build "centos7/Dockerfile" "${DOCKER_REPO}:${IMAGE_VERSION}_centos7"
    [ "$?" -ne 0 ] && BUILD_SUCC=false
fi

if [ "$BUILD_KUBEFLOW" = true ]; then
    echo "Building kubeflow"
    docker_build "kubeflow/Dockerfile" "${KUBEFLOW_REPO}:${KUBEFLOW_IMAGE_VERSION}"
    [ "$?" -ne 0 ] && BUILD_SUCC=false
fi

if [ "$PUSH_IMAGES" = true ] && [ "$BUILD_SUCC" = true ]; then
    if [ "$BUILD_UBUNTU16" = true ]; then
        docker push "${DOCKER_REPO}:${IMAGE_VERSION}_ubuntu16"
    fi

    if [ "$BUILD_CENTOS7" = true ]; then
        docker push "${DOCKER_REPO}:${IMAGE_VERSION}_centos7"
        docker tag "${DOCKER_REPO}:${IMAGE_VERSION}_centos7" "${DOCKER_REPO}:latest"
        docker push "${DOCKER_REPO}:latest"
    fi

    if [ "$BUILD_KUBEFLOW" = true ]; then
        docker push "${KUBEFLOW_REPO}:${KUBEFLOW_IMAGE_VERSION}"
        docker tag "${KUBEFLOW_REPO}:${KUBEFLOW_IMAGE_VERSION}" "${KUBEFLOW_REPO}:latest"
        docker push "${KUBEFLOW_REPO}:latest"
    fi
fi
