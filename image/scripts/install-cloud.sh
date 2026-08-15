#!/usr/bin/env bash
# Infrastructure tooling: terraform, hcloud CLI and ansible.
set -euo pipefail

arch="$(dpkg --print-architecture)"
codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://apt.releases.hashicorp.com/gpg |
    gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
chmod a+r /etc/apt/keyrings/hashicorp.gpg
# HashiCorp lags behind Debian releases; fall back to the newest suite they ship.
hashicorp_codename="${codename}"
if ! curl -fsI "https://apt.releases.hashicorp.com/dists/${hashicorp_codename}/Release" >/dev/null; then
    hashicorp_codename=bookworm
fi
echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com ${hashicorp_codename} main" \
    >/etc/apt/sources.list.d/hashicorp.list

apt-get update
apt-get install -y --no-install-recommends \
    ansible \
    terraform
apt-get clean
rm -rf /var/lib/apt/lists/*

curl -fsSL --retry 5 --retry-all-errors --retry-delay 5 \
    "https://github.com/hetznercloud/cli/releases/download/${HCLOUD_CLI_VERSION}/hcloud-linux-${arch}.tar.gz" \
    -o /tmp/hcloud.tar.gz
tar -xzf /tmp/hcloud.tar.gz -C /usr/local/bin hcloud
rm -f /tmp/hcloud.tar.gz

terraform version
hcloud version
