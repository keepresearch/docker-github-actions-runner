#!/bin/bash -ex
GH_RUNNER_VERSION=$1
TARGETPLATFORM=$2

export TARGET_ARCH="x64"
if [[ $TARGETPLATFORM == "linux/arm64" ]]; then
  export TARGET_ARCH="arm64"
fi
curl --fail --location --retry 3 "https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-${TARGET_ARCH}-${GH_RUNNER_VERSION}.tar.gz" --output actions.tar.gz
tar -zxf actions.tar.gz
rm -f actions.tar.gz
./bin/installdependencies.sh
mkdir -p /_work
