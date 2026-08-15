#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as a regular user with sudo access, not as root." >&2
  exit 1
fi

. /etc/os-release
if [[ "${ID}" != "ubuntu" ]]; then
  echo "This script supports Ubuntu only; detected ${PRETTY_NAME}." >&2
  exit 1
fi

architecture="$(dpkg --print-architecture)"
ubuntu_codename="${UBUNTU_CODENAME:-${VERSION_CODENAME}}"

sudo -v

remove_legacy_microsoft_sources() {
  # The official package installers create these sources with incompatible keyring paths.
  sudo rm -f \
    /etc/apt/sources.list.d/vscode.sources \
    /etc/apt/sources.list.d/microsoft-edge-dev.sources \
    /etc/apt/sources.list.d/microsoft-edge.sources \
    /etc/apt/sources.list.d/microsoft-edge-dev.list.distUpgrade \
    /etc/apt/sources.list.d/microsoft-edge.list.distUpgrade
}

apt_install() {
  sudo apt-get install -y "$@"
}

install_keyring() {
  local url="$1"
  local destination="$2"
  local temporary_keyring

  temporary_keyring="$(mktemp)"
  curl -fsSL --retry 3 --retry-all-errors "${url}" | gpg --batch --dearmor >"${temporary_keyring}"
  sudo install -m 0644 "${temporary_keyring}" "${destination}"
  rm -f "${temporary_keyring}"
}

install_binary_keyring() {
  local url="$1"
  local destination="$2"
  local temporary_keyring

  temporary_keyring="$(mktemp)"
  curl -fsSL --retry 3 --retry-all-errors -o "${temporary_keyring}" "${url}"
  sudo install -m 0644 "${temporary_keyring}" "${destination}"
  rm -f "${temporary_keyring}"
}

install_source() {
  local destination="$1"
  local source_definition="$2"
  local temporary_source

  temporary_source="$(mktemp)"
  printf '%s\n' "${source_definition}" >"${temporary_source}"
  sudo install -m 0644 "${temporary_source}" "${destination}"
  rm -f "${temporary_source}"
}

check_docker_conflicts() {
  local package
  local conflicts=()

  for package in docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc; do
    if dpkg-query -W -f='${db:Status-Abbrev}' "${package}" 2>/dev/null | grep -q '^ii '; then
      conflicts+=("${package}")
    fi
  done

  if ((${#conflicts[@]})); then
    printf 'Conflicting Docker packages are installed: %s\n' "${conflicts[*]}" >&2
    echo "Remove them before installing Docker Engine from Docker's repository." >&2
    exit 1
  fi
}

remove_legacy_microsoft_sources
sudo apt-get update
apt_install ca-certificates curl git gpg wget
sudo install -d -m 0755 /etc/apt/keyrings

# GitHub CLI
install_binary_keyring \
  "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
  "/etc/apt/keyrings/githubcli-archive-keyring.gpg"
install_source \
  "/etc/apt/sources.list.d/github-cli.list" \
  "deb [arch=${architecture} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"

# Visual Studio Code
install_keyring \
  "https://packages.microsoft.com/keys/microsoft.asc" \
  "/etc/apt/keyrings/microsoft.gpg"
install_source \
  "/etc/apt/sources.list.d/vscode.list" \
  "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main"

# Docker Engine
check_docker_conflicts
install_keyring \
  "https://download.docker.com/linux/ubuntu/gpg" \
  "/etc/apt/keyrings/docker.gpg"
install_source \
  "/etc/apt/sources.list.d/docker.list" \
  "deb [arch=${architecture} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${ubuntu_codename} stable"

# Microsoft Edge is distributed for Ubuntu on amd64 only.
if [[ "${architecture}" == "amd64" ]]; then
  install_source \
    "/etc/apt/sources.list.d/microsoft-edge.list" \
    "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main"
else
  echo "Skipping Microsoft Edge: no package is available for ${architecture}."
fi

sudo apt-get update
apt_install gh code docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if [[ "${architecture}" == "amd64" ]]; then
  apt_install microsoft-edge-stable
fi

sudo docker info >/dev/null
echo "Ubuntu development machine setup completed successfully."
