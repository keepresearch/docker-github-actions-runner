#!/usr/bin/env bash
set -euo pipefail

function configure_docker() {
  # shellcheck source=/dev/null
  source /etc/os-release

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] $DOCKER_DOWNLOAD_URL/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
}

function configure_llvm() {
  curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key -o /etc/apt/keyrings/llvm-snapshot.gpg
  chmod a+r /etc/apt/keyrings/llvm-snapshot.gpg
  cat << EOF | tee /etc/apt/sources.list.d/llvm-trixie.sources
Types: deb
URIs: http://apt.llvm.org/trixie/
Suites: llvm-toolchain-trixie llvm-toolchain-trixie-21
Components: main
Signed-By: /etc/apt/keyrings/llvm-snapshot.gpg
EOF
}

function configure_sources() {
  configure_docker
  configure_llvm
}

function remove_sources() {
  rm -f /etc/apt/sources.list.d/git-core.list
  rm -f /etc/apt/sources.list.d/docker.list
  rm -f /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
}
