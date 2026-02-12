#!/bin/bash

GIT_COMMIT=$(git log -1 --pretty=format:"%H")
INSTALLATION_PREFIX=${INSTALLATION_PREFIX:-"/opt/mapr"}
PKG_NAME=${PKG_NAME:-"zeppelin"}
PKG_VERSION=${PKG_VERSION:-"0.10.1.400"}
PKG_3DIGIT_VERSION=$(echo "$PKG_VERSION" | cut -d '.' -f 1-3)
TIMESTAMP=${TIMESTAMP:-$(sh -c 'date "+%Y%m%d%H%M"')}
PKG_INSTALL_ROOT=${PKG_INSTALL_ROOT:-"${INSTALLATION_PREFIX}/${PKG_NAME}/${PKG_NAME}-${PKG_3DIGIT_VERSION}"}

DIST_DIR=${DIST_DIR:-"devops/dist"}
# rpmbuild does not work properly when relatve path specified here
BUILD_ROOT=${BUILD_ROOT:-"$(pwd)/devops/buildroot"}

MAVEN_BUILD_PROFILES="scala-2.11,spark-mapr,build-distr,vendor-repo-mapr,hadoop3"
PACKAGE_EZMERAL_USER_ENCODED=$(echo -n "$PACKAGE_EZMERAL_USER" | jq --raw-input --join-output '@uri')
DRILL_DRIVER_URL="https://${PACKAGE_EZMERAL_USER_ENCODED}:${PACKAGE_EZMERAL_PASS}@package.ezmeral.hpe.com/tools/MapR-JDBC/MapR_Drill/MapRDrill_jdbc_v1.6.11.1008/MapRDrillJDBC-1.6.11.1008.zip"
