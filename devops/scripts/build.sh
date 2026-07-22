#!/bin/bash
set -e
set -x

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/_initialize_package_variables.sh"
. "${SCRIPT_DIR}/_utils.sh"

build_code() {
  mvn -B clean install -DskipTests -Drat.skip=true -P "$MAVEN_BUILD_PROFILES"

  mkdir -p "${BUILD_ROOT}/build"

  project_version=$(mvn -B help:evaluate -Dexpression=project.version -q -DforceStdout)
  tar -xf "zeppelin-distribution/target/zeppelin-${project_version}.tar.gz" -C "${BUILD_ROOT}/build" --strip-components=1

  mkdir -p devops/buildmeta

  # Pre-seed the dependency plugin into the local repo while online, so the offline `dependency:tree -o` will work without issues
  mvn -B dependency:resolve -DskipTests -P "$MAVEN_BUILD_PROFILES" > /dev/null
  mvn -B dependency:tree -o -DskipTests -P "$MAVEN_BUILD_PROFILES" > devops/buildmeta/dependency-tree.txt
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
