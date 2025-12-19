#!/usr/bin/env bash
set -euo pipefail

function install_git() {
  ( apt-get install -y --no-install-recommends git \
   || apt-get install -t stable -y --no-install-recommends git )
}

function install_liblttng-ust() {
  if [[ $(apt-cache search -n liblttng-ust0 | awk '{print $1}') == "liblttng-ust0" ]]; then
    apt-get install -y --no-install-recommends liblttng-ust0
  fi

  if [[ $(apt-cache search -n liblttng-ust1 | awk '{print $1}') == "liblttng-ust1" ]]; then
    apt-get install -y --no-install-recommends liblttng-ust1
  fi
}

function install_aws-cli() {
  ( curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip -d /tmp/ \
    && /tmp/aws/install \
    && rm awscliv2.zip \
  ) \
    || pip3 install --no-cache-dir awscli
}

function install_git-lfs() {
  local DPKG_ARCH
  DPKG_ARCH="$(dpkg --print-architecture)"

  curl -s "https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-linux-${DPKG_ARCH}-v${GIT_LFS_VERSION}.tar.gz" -L -o /tmp/lfs.tar.gz
  tar -xzf /tmp/lfs.tar.gz -C /tmp
  "/tmp/git-lfs-${GIT_LFS_VERSION}/install.sh"
  rm -rf /tmp/lfs.tar.gz "/tmp/git-lfs-${GIT_LFS_VERSION}"
}

function install_docker() {
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin --no-install-recommends --allow-unauthenticated
  sed -i 's/ulimit -Hn/# ulimit -Hn/g' /etc/init.d/docker
}

function install_github-cli() {
  local DPKG_ARCH GH_CLI_VERSION GH_CLI_DOWNLOAD_URL

  DPKG_ARCH="$(dpkg --print-architecture)"

  GH_CLI_VERSION=$(curl -sL -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/cli/cli/releases/latest \
      | jq -r '.tag_name' | sed 's/^v//g')

  GH_CLI_DOWNLOAD_URL=$(curl -sL -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/cli/cli/releases/latest \
      | jq ".assets[] | select(.name == \"gh_${GH_CLI_VERSION}_linux_${DPKG_ARCH}.deb\")" \
      | jq -r '.browser_download_url')

  curl -sSLo /tmp/ghcli.deb "${GH_CLI_DOWNLOAD_URL}"
  apt-get -y install /tmp/ghcli.deb
  rm /tmp/ghcli.deb
}

function install_yq() {
  local DPKG_ARCH YQ_DOWNLOAD_URL

  DPKG_ARCH="$(dpkg --print-architecture)"

  YQ_DOWNLOAD_URL=$(curl -sL -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/mikefarah/yq/releases/latest \
      | jq ".assets[] | select(.name == \"yq_linux_${DPKG_ARCH}.tar.gz\")" \
      | jq -r '.browser_download_url')

  curl -s "${YQ_DOWNLOAD_URL}" -L -o /tmp/yq.tar.gz
  tar -xzf /tmp/yq.tar.gz -C /tmp
  mv "/tmp/yq_linux_${DPKG_ARCH}" /usr/local/bin/yq
}

function install_powershell() {
  local DPKG_ARCH PWSH_VERSION PWSH_DOWNLOAD_URL

  DPKG_ARCH="$(dpkg --print-architecture)"

  PWSH_VERSION=$(curl -sL -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/PowerShell/PowerShell/releases/latest \
      | jq -r '.tag_name' \
      | sed 's/^v//g')

  PWSH_DOWNLOAD_URL=$(curl -sL -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/PowerShell/PowerShell/releases/latest \
      | jq -r ".assets[] | select(.name == \"powershell-${PWSH_VERSION}-linux-${DPKG_ARCH//amd64/x64}.tar.gz\") | .browser_download_url")

  curl -L -o /tmp/powershell.tar.gz "$PWSH_DOWNLOAD_URL"
  mkdir -p /opt/powershell
  tar zxf /tmp/powershell.tar.gz -C /opt/powershell
  chmod +x /opt/powershell/pwsh
  ln -s /opt/powershell/pwsh /usr/bin/pwsh
}

function install_rust() {
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path --default-toolchain stable
  rustup component add clippy rustfmt
  cargo install cargo-edit
}

function install_protoc() {
  curl -Lo /tmp/protoc.zip $( \
    curl 'https://api.github.com/repos/protocolbuffers/protobuf/releases/latest' | \
    sed -rn 's/^.*browser_download_url.*(https:.*protoc.*linux-x86_64.zip).*$/\1/p' \
    ) && \
  unzip /tmp/protoc.zip -d /usr/local && \
  rm /tmp/protoc.zip
}

function install_nodejs() {
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "/usr/local/share/fnm" --skip-shell
  ln -s /usr/local/share/fnm/fnm /usr/local/bin/fnm
  fnm install 22
  fnm install 24
  fnm alias 24 default
  echo "installed node version: $(node -v)"
  echo "installed npm version: $(npm -v)"
  corepack install -g pnpm
  echo "installed pnpm version: $(pnpm -v)"
}

function install_llvm_21() {
  # LLVM
  apt-get install -y libllvm-21-ocaml-dev libllvm21 llvm-21 llvm-21-dev llvm-21-doc llvm-21-examples llvm-21-runtime
  # Clang and co
  apt-get install -y clang-21 clang-tools-21 clang-21-doc libclang-common-21-dev libclang-21-dev libclang1-21 clang-format-21 python3-clang-21 clangd-21 clang-tidy-21
  # compiler-rt
  apt-get install -y libclang-rt-21-dev
  # polly
  apt-get install -y libpolly-21-dev
  # libfuzzer
  apt-get install -y libfuzzer-21-dev
  # lldb
  apt-get install -y lldb-21
  # lld (linker)
  apt-get install -y lld-21
  # libc++
  apt-get install -y libc++-21-dev libc++abi-21-dev
  # OpenMP
  apt-get install -y libomp-21-dev
  # libclc
  apt-get install -y libclc-21-dev
  # libunwind
  apt-get install -y libunwind-21-dev
  # mlir
  apt-get install -y libmlir-21-dev mlir-21-tools
  # bolt
  apt-get install -y libbolt-21-dev bolt-21
  # flang
  apt-get install -y flang-21
  # wasm support
  apt-get install -y libclang-rt-21-dev-wasm32 libclang-rt-21-dev-wasm64 libc++-21-dev-wasm32 libc++abi-21-dev-wasm32 libclang-rt-21-dev-wasm32 libclang-rt-21-dev-wasm64
  # LLVM libc
  apt-get install -y libllvmlibc-21-dev
}

function install_tools() {
  local function_name
  # shellcheck source=/dev/null
  source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

  script_packages | while read -r package; do
    function_name="install_${package}"
    if declare -f "${function_name}" > /dev/null; then
      "${function_name}"
    else
      echo "No install script found for package: ${package}"
      exit 1
    fi
  done
}
