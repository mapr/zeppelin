#!/bin/bash
set -e

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/_initialize_package_variables.sh"
. "${SCRIPT_DIR}/_utils.sh"

build_code() {
  mvn -B clean package -DskipTests -P "$MAVEN_BUILD_PROFILES"

  mkdir -p "${BUILD_ROOT}/build"

  project_version=$(mvn -B help:evaluate -Dexpression=project.version -q -DforceStdout)
  tar -xf "zeppelin-distribution/target/zeppelin-${project_version}.tar.gz" -C "${BUILD_ROOT}/build" --strip-components=1
}

main() {
  echo "Cleaning '${BUILD_ROOT}' dir..."
  rm -rf "$BUILD_ROOT"

  echo "Building project..."
  build_code

  echo "Preparing directory structure..."
  setup_role "mapr-zeppelin"

  setup_package "mapr-zeppelin"

  echo "Building packages..."
  build_package "mapr-zeppelin"

  echo "Resulting packages:"
  find "$DIST_DIR" -exec readlink -f {} \;
}

main
