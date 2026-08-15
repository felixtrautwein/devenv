#!/usr/bin/env bash
# kubectl and helm.
set -euo pipefail

install -m 0755 -d /etc/apt/keyrings

curl -fsSL "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_APT_MINOR}/deb/Release.key" |
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_APT_MINOR}/deb/ /" \
    >/etc/apt/sources.list.d/kubernetes.list
chmod 644 /etc/apt/sources.list.d/kubernetes.list

# helm comes from its apt repository rather than get.helm.sh, because the latter
# is not reliably reachable from inside build containers.
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey |
    gpg --dearmor -o /etc/apt/keyrings/helm.gpg
chmod a+r /etc/apt/keyrings/helm.gpg
echo "deb [signed-by=/etc/apt/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" \
    >/etc/apt/sources.list.d/helm.list

# The repository also ships helm 4; pin the major version for reproducibility.
cat >/etc/apt/preferences.d/helm <<EOF
Package: helm
Pin: version ${HELM_MAJOR}.*
Pin-Priority: 1000
EOF

apt-get update
apt-get install -y --no-install-recommends helm kubectl
apt-get clean
rm -rf /var/lib/apt/lists/*

kubectl version --client
helm version --short
