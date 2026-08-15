#!/usr/bin/env bash
# Base OS packages shared by every repository in the organisation.
set -euo pipefail

# Downloads during the build have to survive flaky networks and proxies that do
# not speak HTTP/2 cleanly. Applies to every curl invocation run as root.
cat >/root/.curlrc <<'EOF'
--http1.1
--retry 5
--retry-all-errors
--retry-delay 3
--retry-connrefused
--connect-timeout 30
EOF

cat >/etc/apt/apt.conf.d/99-devenv-retries <<'EOF'
Acquire::Retries "5";
Acquire::http::Timeout "60";
Acquire::https::Timeout "60";
Acquire::ForceIPv4 "true";
EOF

echo "${TZ}" >/etc/timezone
apt-get update
apt-get install -y --no-install-recommends tzdata
rm -f /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

apt-get install -y --no-install-recommends \
    apt-transport-https \
    bash-completion \
    ca-certificates \
    curl \
    direnv \
    file \
    gettext \
    git \
    git-lfs \
    gnupg \
    iproute2 \
    iputils-ping \
    jq \
    less \
    libglu1-mesa \
    locales \
    lsb-release \
    make \
    nano \
    net-tools \
    nmap \
    openssh-client \
    ripgrep \
    rsync \
    sudo \
    unzip \
    vim \
    wget \
    wireguard-tools \
    xz-utils \
    zip \
    zsh

git lfs install --system

# VS Code forwards the host locale; generate the common ones to avoid warnings.
sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen

apt-get clean
rm -rf /var/lib/apt/lists/*
